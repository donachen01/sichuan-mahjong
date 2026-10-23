using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>
/// 4.4 放飞鸽：对手弃出本家可胡牌时，比较“立即胡”与“碰后首打、重新下叫”。
/// 这是一个反应时序策略，不是普通的过胡估值，也不把“碰后再补杠”塞进同一动作。
/// </summary>
public sealed record SichuanFlyingBranch(
    int DiscardTile,
    int Shanten,
    int WaitCount,
    int BeforeWaitCount,
    double DrawableMass,
    double BeforeDrawableMass,
    double WeightedWaitDelta,
    double CounterfactualValue,
    double RewaitWeightedFan,
    double RewaitSelfDrawPerPayer,
    double RewaitWeightedHandScore,
    double FutureSelfDrawValue,
    double FutureGangProbability,
    double FutureGangValue,
    int FutureGangOptionCount,
    double Danger,
    bool Broadens,
    bool IsAdmissible,
    IReadOnlyList<string> Reasons);

public sealed record SichuanFlyingDecision(
    bool IsAdmissible,
    int DiscardTile,
    double Value,
    double ImmediateHuValue,
    IReadOnlyList<SichuanFlyingBranch> Branches,
    IReadOnlyList<string> Reasons)
{
    public SichuanExpectedValueBreakdown? Financial { get; init; }
    public static SichuanFlyingDecision Rejected(string reason, double hu = 0)
        => new(false, -1, double.NegativeInfinity, hu, Array.Empty<SichuanFlyingBranch>(), new[] { reason });
}

public sealed class SichuanFlyingDecisionPolicy
{
    private readonly SichuanBeliefEngine _belief = new();
    private readonly SichuanWallAvailabilityEngine _wall = new();
    private readonly SichuanReadyWaitPricing _pricing = new();
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanMeldCounterfactualEvaluator _melds = new();
    private readonly SichuanDangerEngine _danger = new();
    private readonly SichuanRoutePlanEngine _routePlan = new();

    private sealed record FutureGangEstimate(double Probability, double Value, int OptionCount,
        IReadOnlyList<string> Codes);

    public SichuanFlyingDecision Decide(
        SichuanStateView state,
        int winningTileType,
        int sourceSeat,
        SichuanHuRefusalAssessment evidence,
        SichuanBeliefSnapshot? belief = null)
    {
        // The source rule is specifically the discard-Hu -> Peng -> discard
        // chain. It does not apply to self-draw, robbing an added Gang, or a
        // discard whose public source is not known.
        if (evidence.EffectiveWinType != SichuanWinType.Discard)
            return SichuanFlyingDecision.Rejected("FLYING_ONLY_DISCARD_HU");
        if (sourceSeat < 0 || sourceSeat == state.SeatIndex)
            return SichuanFlyingDecision.Rejected("FLYING_SOURCE_SEAT_UNKNOWN");
        if (winningTileType is < 0 or >= 27 || state.Hand18[winningTileType] < 2)
            return SichuanFlyingDecision.Rejected("FLYING_PENG_NOT_LEGAL", evidence.ImmediateHuGain);
        if (state.WallCount <= 0)
            return SichuanFlyingDecision.Rejected("FLYING_NO_FUTURE_WALL", evidence.ImmediateHuGain);
        if (SichuanOpponentWideBedDefense.Applies(state))
            return SichuanFlyingDecision.Rejected("FLYING_OPPONENT_WIDE_BED_DEFENSE", evidence.ImmediateHuGain);
        var routePlan = _routePlan.Evaluate(state);
        if (routePlan.ForbidsMelds)
            return SichuanFlyingDecision.Rejected("FLYING_ROUTE_FORBIDS_MELDS", evidence.ImmediateHuGain);

        // Two concealed pairs and three exposed sets are the concrete 5.3
        // Hu -> Peng -> split the OTHER pair -> single wait chain. Its price
        // gain must not be vetoed by 4.4's wait-broadening requirement.
        if (SichuanGoldenHookPolicy.Applies(state, winningTileType))
            return new SichuanGoldenHookPolicy().Decide(state, winningTileType, sourceSeat, evidence);

        belief ??= _belief.Build(state);
        var wall = _wall.Build(state, belief);
        var before = _pricing.Build(state, state.Hand18, wall.ExpectedCounts18);
        if (before is not { HasDrawableWait: true })
            return SichuanFlyingDecision.Rejected("FLYING_CURRENT_WAIT_NOT_PRICED", evidence.ImmediateHuGain);

        var stage = new SichuanStageEvaluator().Evaluate(state, belief);
        var maxReadyPosterior = belief.SeatReadyPosterior.Values.DefaultIfEmpty(0.0).Max();
        var handAfterPeng = (int[])state.Hand18.Clone();
        handAfterPeng[winningTileType] -= 2;
        var meldsAfterPeng = SichuanUnifiedDecisionEngine.ProjectPengContinuation(
            state, handAfterPeng, winningTileType, sourceSeat).MeldViews[state.SeatIndex].ToArray();

        var branches = new List<SichuanFlyingBranch>();
        foreach (var discard in Enumerable.Range(0, 27).Where(t => handAfterPeng[t] > 0))
        {
            // A post-Peng first discard is a normal discard. The missing suit
            // restriction remains active and the claimed tile is never added
            // back to the concealed hand.
            if (state.OwnDingQueSuit >= 0 && discard / 9 == state.OwnDingQueSuit
                && handAfterPeng.Skip(state.OwnDingQueSuit * 9).Take(9).Any(n => n > 0))
                continue;

            var afterDiscard = (int[])handAfterPeng.Clone();
            afterDiscard[discard]--;
            var shanten = _shanten.CalcLegalShanten(
                afterDiscard, state.OwnMeldCount + 1, state.OwnDingQueSuit, false);
            if (shanten != 0) continue;

            var after = _pricing.Build(state, afterDiscard, wall.ExpectedCounts18, meldsAfterPeng);
            if (after is null) continue;

            var danger = _danger.EvaluateDetail(discard, state, belief);
            var timing = _melds.Evaluate(
                state, "peng", winningTileType, 2, state.OwnMeldCount + 1,
                routeLoss: 0, risk: 0, gangGain: 0, belief,
                plannedDiscardTile: discard, gangSourceSeat: sourceSeat);
            var waitDelta = after.Waits.Count - before.Waits.Count;
            var massDelta = after.PublicDrawableMass - before.PublicDrawableMass;
            var weightedDelta = SichuanRootWeightedWaitPolicy.Compare(before, after).Delta;
            var broadens = waitDelta > 0 || massDelta >= 2.0 || weightedDelta >= 2.0;
            var keyPriceUpgrade = after.Waits.Any(w => w.PublicWallWeight>0
                && w.HandScore>evidence.ImmediateHuGain
                && SichuanKeyTileRetention.Assess(state,w.TileType).Grade is "S" or "A")
                && timing.ContinuationModel=="shared_executable_ready_action_value"
                && SichuanDistinctDingQueHuPolicy.AssessDanger(state,new())<2;

            // Structural broadening is a source-derived signal. Exact
            // continuation value and danger remain independent terms; the
            // premium is deliberately small and cannot turn a dangerous
            // first discard into an automatic claim.
            var structuralPremium = Math.Max(0, waitDelta) * 0.34
                + Math.Max(0, massDelta) * 0.12
                + Math.Max(0, weightedDelta) * 0.10
                + Math.Max(0, after.WeightedSelfDrawPerPayer - before.WeightedSelfDrawPerPayer) * 0.05;
            var continuationValue = SichuanMeldCounterfactualEvaluator.CommonContinuationValue(
                shanten, after.PublicDrawableMass, after.WeightedFan,
                after.WeightedSelfDrawPerPayer, wall.WallCount);
            var futureGang = EstimateFutureGangOpportunity(state, afterDiscard, meldsAfterPeng);
            var futureSelfDraw = EstimateFutureSelfDrawValue(state, after, wall.WallCount);
            // Self-draw and future Gang are competing continuation outcomes,
            // but a Gang can be followed by another own draw. Keep most of the
            // stronger route and only a bounded fraction of the second route;
            // this avoids treating both independent opportunities as certain
            // cash while preserving the source's “碰后杠/自摸联动” idea.
            var futureRouteValue = Math.Max(futureSelfDraw, futureGang.Value)
                + Math.Min(futureSelfDraw, futureGang.Value) * 0.35;
            // Danger is a variable cost of the forced first discard. Keep it
            // on the same small continuation-value scale rather than feeding
            // the integer diagnostic risk directly into an EV-like number.
            var value = keyPriceUpgrade ? timing.Value : continuationValue + structuralPremium + futureRouteValue
                - Math.Clamp(danger.Risk, 0, 100) * 0.03;
            var reasons = new List<string>
            {
                $"碰后首打 {discard}",
                $"重新听牌 {after.Waits.Count} 张，原听口 {before.Waits.Count} 张",
                $"公开可见听张质量差 {massDelta:+0.##;-0.##;0}",
                $"根加权听张差 {weightedDelta:+0.##;-0.##;0}",
                $"后续自摸局部收益 {futureSelfDraw:F3}",
                $"后续自然杠机会 {futureGang.OptionCount} 组，概率 {futureGang.Probability:F3}，局部杠收益 {futureGang.Value:F3}",
                $"首打危险 {danger.Risk}",
                $"反事实续走向听 {timing.Shanten}，最佳首打 {timing.BestDiscardTile}，续走值 {continuationValue:F3}",
                "FLYING_CHAIN_PENG_DISCARD_REENTER_TENPAI",
                "FLYING_NO_IMMEDIATE_ADDED_GANG"
            };
            reasons.AddRange(futureGang.Codes);
            if(keyPriceUpgrade)reasons.Add("KEY_TILE_RETENTION_PRICE_UPGRADE_SHARED_READY_VALUE_NOT_GUARANTEED_RELEASE");
            if (waitDelta > 0) reasons.Add("FLYING_WAIT_WIDTH_GAIN");
            if (massDelta >= 2.0) reasons.Add("FLYING_DRAWABLE_SUPPLY_GAIN");
            if (after.RootWeightedDrawableMass > before.RootWeightedDrawableMass + 1e-9)
                reasons.Add("FLYING_ROOT_WEIGHTED_ROUTE_GAIN");
            if (after.WeightedSelfDrawPerPayer > before.WeightedSelfDrawPerPayer + 1e-9)
                reasons.Add("FLYING_SELF_DRAW_PRICE_GAIN");

            var admissible = (broadens || futureGang.Value >= 0.25 || keyPriceUpgrade)
                && danger.Risk < 78;
            if (stage.StageIndex >= 2 || maxReadyPosterior >= 0.72)
            {
                // Late or strongly pressured tables require a larger gain and
                // a clearly safe first discard. This is the source's “midgame
                // preferred, late game conservative” boundary made explicit.
                admissible = admissible && danger.Risk < 42
                    && (waitDelta >= 2 && massDelta >= 3.0 || keyPriceUpgrade);
                reasons.Add("FLYING_LATE_OR_HIGH_PRESSURE_GATE");
            }
            if (!broadens) reasons.Add("FLYING_NO_MATERIAL_WAIT_GAIN");
            if (danger.Risk >= 78) reasons.Add("FLYING_FIRST_DISCARD_TOO_DANGEROUS");
            branches.Add(new(discard, shanten, after.Waits.Count, before.Waits.Count,
                after.PublicDrawableMass, before.PublicDrawableMass, weightedDelta,
                value, after.WeightedFan, after.WeightedSelfDrawPerPayer,
                after.WeightedHandScore, futureSelfDraw, futureGang.Probability, futureGang.Value, futureGang.OptionCount,
                danger.Risk, broadens, admissible, reasons));
        }

        if (branches.Count == 0)
            return SichuanFlyingDecision.Rejected("FLYING_NO_LEGAL_RE_TENPAI_BRANCH", evidence.ImmediateHuGain);

        var best = branches.OrderByDescending(b => b.CounterfactualValue).First();
        // Hu remains the hard financial baseline. The branch must beat it by a
        // visible margin after structural premium; a bare one-tile reshaping
        // never overrides a certain Hu.
        var beatsHu = best.CounterfactualValue > evidence.ImmediateHuGain + 0.12;
        var finalAdmissible = best.IsAdmissible && beatsHu;
        var decisionReasons = best.Reasons.ToList();
        decisionReasons.Add($"放飞候选净值 {best.CounterfactualValue:F3}；立即胡基线 {evidence.ImmediateHuGain:F3}");
        decisionReasons.Add(beatsHu ? "FLYING_BEATS_IMMEDIATE_HU_BASELINE" : "FLYING_HU_BASELINE_RETAINS_PRIORITY");
        if (!finalAdmissible) decisionReasons.Add("FLYING_NOT_ADMISSIBLE_IN_CURRENT_STATE");
        return new(finalAdmissible, best.DiscardTile, best.CounterfactualValue, evidence.ImmediateHuGain,
            branches, decisionReasons);
    }

    private FutureGangEstimate EstimateFutureGangOpportunity(
        SichuanStateView state,
        IReadOnlyList<int> afterDiscard,
        IReadOnlyList<SichuanMeldView> projectedMelds)
    {
        var activePayers = state.ActiveSeats
            .Select((active, seat) => (active, seat))
            .Count(item => item.active && item.seat != state.SeatIndex && !state.HasHu[item.seat]);
        var activeSeats = Math.Max(1, state.ActiveSeats.Count(active => active));
        var ownDrawOffset = SichuanTurnOrder.DrawsBeforeOwnTurnAfterClaim(state);
        var ownDraws = Math.Max(0,
            (state.WallCount - ownDrawOffset + activeSeats - 1) / activeSeats);
        if (state.WallCount <= 1 || activePayers <= 0)
            return new(0, 0, 0, new[] { "FLYING_NO_FUTURE_OWN_DRAW_FOR_GANG" });

        var probability = 0.0;
        var value = 0.0;
        var options = 0;
        var codes = new List<string>();
        var expectedWall = _wall.Build(state, _belief.Build(state));
        for (var tile = 0; tile < 27; tile++)
        {
            if (tile / 9 == state.OwnDingQueSuit || state.Remaining18[tile] <= 0) continue;
            var hasPeng = projectedMelds.Any(m => m.Type == SichuanMeldType.Peng && m.TileType == tile);
            var isConcealedTriplet = !hasPeng && afterDiscard[tile] == 3;
            if (!hasPeng && !isConcealedTriplet) continue;

            // One fourth copy can arrive on a later own draw or via a forced
            // missing-suit discard (only for a concealed triplet). These are
            // disjoint wall positions, and the final tile cannot start a Gang.
            // This fixed-turn opportunity is not a guarantee of survival.
            var supply = expectedWall.ExpectedCounts18[tile];
            var chances = SichuanNaturalGangSupply.FixedTurn(state,tile,supply,isConcealedTriplet);
            if(chances.OwnDraw+chances.ForcedDiscard<=0)continue;
            var unit = isConcealedTriplet
                ? SichuanSettlementProjectionEngine.GangUnit(SichuanMeldType.ConcealedGang)
                : SichuanSettlementProjectionEngine.GangUnit(SichuanMeldType.AddedGang);
            probability = Math.Max(probability, chances.OwnDraw + chances.ForcedDiscard);
            value += chances.OwnDraw * unit * activePayers
                + chances.ForcedDiscard * SichuanSettlementProjectionEngine.GangUnit(SichuanMeldType.MeldedGang);
            if(chances.ForcedDiscard>0)codes.Add($"FLYING_FORCED_MELDED_GANG_OPTION_{tile}");
            options++;
            codes.Add(isConcealedTriplet
                ? $"FLYING_FUTURE_CONCEALED_GANG_OPTION_{tile}"
                : $"FLYING_FUTURE_ADDED_GANG_OPTION_{tile}");
        }

        if (options == 0)
            codes.Add("FLYING_NO_LIVE_FUTURE_GANG_OPTION");
        else
            codes.Add("FLYING_FUTURE_GANG_IS_CONDITIONAL_PUBLIC_OPPORTUNITY");
        return new(probability, Math.Min(6.0, value), options, codes);
    }

    private static double EstimateFutureSelfDrawValue(
        SichuanStateView state,
        SichuanReadyPrice after,
        int wallCount)
    {
        var activePayers = state.ActiveSeats
            .Select((active, seat) => (active, seat))
            .Count(item => item.active && item.seat != state.SeatIndex && !state.HasHu[item.seat]);
        var activeSeats = Math.Max(1, state.ActiveSeats.Count(active => active));
        var ownDrawOffset = SichuanTurnOrder.DrawsBeforeOwnTurnAfterClaim(state);
        var ownDraws = Math.Max(0,
            (state.WallCount - ownDrawOffset + activeSeats - 1) / activeSeats);
        if (ownDraws <= 0 || activePayers <= 0 || wallCount <= 0 || !after.HasDrawableWait)
            return 0;
        var hit = 1.0 - Math.Pow(
            Math.Max(0, 1.0 - after.PublicDrawableMass / Math.Max(1, wallCount)), ownDraws);
        return Math.Min(6.0, Math.Clamp(hit, 0, 1) * after.WeightedSelfDrawPerPayer * activePayers);
    }
}
