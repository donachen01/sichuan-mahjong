using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanMeldCounterfactual(
    string Action,
    int Shanten,
    int LiveUkeire,
    double RouteLoss,
    double Risk,
    double Value,
    double ExpectedFan)
{
    public int BestDiscardTile { get; init; } = -1;
    public double ReplacementWinProbability { get; init; }
    public string Transition { get; init; } = string.Empty;
}

public sealed class SichuanMeldCounterfactualEvaluator
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanUkeireEngine _ukeire = new();
	private readonly SichuanBeliefEngine _belief = new();
	private readonly SichuanWallAvailabilityEngine _wall = new();
    private readonly SichuanActionTreeEvaluator _tree = new();
    private readonly SichuanExactHandAnalyzer _hands = new();
    private readonly SichuanFanProjectionEngine _fans = new();

	public SichuanMeldCounterfactual Evaluate(
		SichuanStateView state,
		string action,
		int tileType,
		int removeCount,
		int meldCountAfter,
		double routeLoss,
		double risk,
		double gangGain,
		SichuanBeliefSnapshot? belief = null)
    {
		var wallAvailability = _wall.Build(state, belief ?? _belief.Build(state));
        var hand = (int[])state.Hand18.Clone();
        if (tileType is >= 0 and < 27) hand[tileType] = Math.Max(0, hand[tileType] - removeCount);
        var melds = state.MeldViews[state.SeatIndex].Count > 0
            ? state.MeldViews[state.SeatIndex].ToArray()
            : InferMeldViews(state);
        var projectedMelds = ProjectMelds(melds, action, tileType, state.EventVersion);
        var activeSeatList = state.ActiveSeats
            .Select((active, seat) => (active, seat))
            .Where(item => item.active)
            .Select(item => item.seat)
            .ToArray();
        var settlement = new SichuanSettlementProjectionEngine();

        // Reaction timing matters. Pass keeps the thirteen-tile concealed hand
        // and waits for a later draw; Peng must discard immediately; Gang must
        // receive and evaluate the replacement draw before any discard.
		var isPass = action == "pass";
		var isContinue = action == "continue";
		var isGang = action.Contains("gang", StringComparison.OrdinalIgnoreCase);
        var followUp = isPass
			? EvaluateWaitingHand(hand, state, wallAvailability, meldCountAfter, projectedMelds, activeSeatList, settlement)
            : isGang
				? EvaluateGangReplacement(hand, state, wallAvailability, meldCountAfter, projectedMelds, activeSeatList, settlement)
				: EvaluatePostClaimDiscards(hand, state, wallAvailability, meldCountAfter, projectedMelds, activeSeatList, settlement);

        var activePlayers = Math.Clamp(state.ActiveSeats.Count(value => value), 2, 4);
        var winScore = followUp.Shanten == 0 ? Math.Max(3.5, followUp.ExpectedSelfDrawGain) : 1.5;
		var opponentLoss = followUp.Shanten == 0 ? 2.4 : 1.2;
		var ownTurnOffset = isPass
			? SichuanTurnOrder.DrawsBeforeSeatAfterDiscard(state, state.CurrentSeat, state.SeatIndex)
			: isGang ? 0 : SichuanTurnOrder.DrawsBeforeOwnTurnAfterClaim(state);
        var chance = _tree.SearchChanceNodes(new SichuanActionTreeEvaluator.ChanceSearchRequest(
            followUp.LiveUkeire,
			Math.Max(0, state.WallCount),
            activePlayers,
			ownTurnOffset,
            winScore,
            state.IsReady.Count(value => value) * 0.006,
            opponentLoss,
            GangOpportunityProbability: gangGain > 0 ? 0.08 : 0,
            GangGain: gangGain,
			ChaJiaoValue: followUp.Shanten == 0 ? 0.35 : 0,
            MaxDraws: Math.Min(12, Math.Max(4, state.WallCount)),
			Simulations: 256,
			Seed: 20260809 ^ state.RoundIndex ^ tileType ^ (int)(state.EventVersion % int.MaxValue)));
		var value = followUp.BaseValue
			+ gangGain
			+ chance.ExpectedNetScore * 0.32
			+ Math.Clamp(followUp.ExpectedFan - 1.0, 0, 3) * 0.35
			+ Math.Clamp(followUp.ExpectedSelfDrawGain / 8.0, 0, 4) * 0.12
			+ Math.Clamp(followUp.ExpectedGangDrawBonus / 8.0, 0, 4) * 0.08
			+ EvaluateTerminalReadyValue(state, followUp)
			- routeLoss
			- risk;
        return new SichuanMeldCounterfactual(action, followUp.Shanten, followUp.LiveUkeire, routeLoss, risk, value, followUp.ExpectedFan)
        {
            BestDiscardTile = followUp.BestDiscardTile,
            ReplacementWinProbability = followUp.ReplacementWinProbability,
			Transition = isPass
				? "pass_wait_draw"
				: isContinue ? "continue_then_discard" : isGang ? "gang_replacement_draw_then_discard" : "peng_then_discard"
        };
	}

	private static double EvaluateTerminalReadyValue(SichuanStateView state, FollowUpEvaluation followUp)
	{
		if (state.WallCount > 8) return 0;
		var urgency = 1.0 - Math.Clamp(state.WallCount, 0, 8) / 9.0;
		if (followUp.Shanten <= 0)
			return 1.8 * urgency + Math.Min(1.2, followUp.LiveUkeire * 0.08);
		return -2.6 * urgency * Math.Min(2, followUp.Shanten);
	}

    private FollowUpEvaluation EvaluateWaitingHand(
        int[] hand,
        SichuanStateView state,
		SichuanWallAvailability wallAvailability,
        int meldCount,
        IReadOnlyList<SichuanMeldView> melds,
        IReadOnlyList<int> activeSeats,
        SichuanSettlementProjectionEngine settlement)
    {
        var shanten = _shanten.CalcBestShanten(hand, meldCount, meldCount == 0);
        var improving = new List<int>();
		var liveTiles = new List<int>();
        for (var draw = 0; draw < 27; draw++)
        {
			if (wallAvailability.ExpectedCounts18[draw] <= 0 || hand[draw] >= 4) continue;
            hand[draw]++;
            var after = _shanten.CalcBestShanten(hand, meldCount, meldCount == 0);
            hand[draw]--;
			if (after >= shanten) continue;
            improving.Add(draw);
			liveTiles.Add(draw);
        }
		var expectedLive = wallAvailability.SumExpected(liveTiles);
		var live = expectedLive <= 0.000001 ? 0 : (int)Math.Ceiling(expectedLive);
        var waits = shanten == 0
			? _hands.EnumerateWaits(hand, state.Remaining18, meldCount, meldCount == 0)
            : Array.Empty<SichuanWaitAnalysis>();
		var priced = PriceWaits(hand, waits, wallAvailability, melds, state, activeSeats, settlement, false);
        return new FollowUpEvaluation(
            shanten,
            live,
            -1,
            priced.ExpectedFan,
            priced.ExpectedSelfDrawGain,
            0,
            0,
            -shanten * 2.4 + live * 0.12);
    }

    private FollowUpEvaluation EvaluatePostClaimDiscards(
        int[] hand,
        SichuanStateView state,
		SichuanWallAvailability wallAvailability,
        int meldCount,
        IReadOnlyList<SichuanMeldView> melds,
        IReadOnlyList<int> activeSeats,
        SichuanSettlementProjectionEngine settlement)
    {
		var analyses = _hands.AnalyzeDiscards(hand, state.Remaining18, meldCount, meldCount == 0);
        FollowUpEvaluation? best = null;
        foreach (var analysis in analyses)
        {
			var afterDiscard = (int[])hand.Clone();
            afterDiscard[analysis.DiscardTileType]--;
			var priced = PriceWaits(afterDiscard, analysis.Waits, wallAvailability, melds, state, activeSeats, settlement, false);
			var expectedLive = wallAvailability.SumExpected(
				analysis.Shanten == 0 ? analysis.Waits.Select(wait => wait.TileType) : analysis.ImprovingTiles);
			var live = expectedLive <= 0.000001 ? 0 : (int)Math.Ceiling(expectedLive);
			var deadReadyPenalty = analysis.Shanten == 0 && expectedLive <= 0.000001 && state.WallCount > 0
				? 3.2
				: 0.0;
            var baseValue = -analysis.Shanten * 2.4
				+ expectedLive * 0.12
				+ priced.ExpectedFan * 0.20
				+ priced.ExpectedSelfDrawGain * 0.025
				- analysis.StructuralLoss * 0.025
				- deadReadyPenalty;
            var candidate = new FollowUpEvaluation(
				analysis.Shanten,
				live,
                analysis.DiscardTileType,
                priced.ExpectedFan,
                priced.ExpectedSelfDrawGain,
                0,
                0,
                baseValue);
            if (best is null || candidate.BaseValue > best.BaseValue)
                best = candidate;
        }
        return best ?? new FollowUpEvaluation(8, 0, -1, 0, 0, 0, 0, -20);
    }

    private FollowUpEvaluation EvaluateGangReplacement(
        int[] handAfterGang,
        SichuanStateView state,
		SichuanWallAvailability wallAvailability,
        int meldCount,
        IReadOnlyList<SichuanMeldView> melds,
        IReadOnlyList<int> activeSeats,
        SichuanSettlementProjectionEngine settlement)
    {
		var totalRemaining = wallAvailability.ExpectedCounts18.Sum(value => Math.Max(0, value));
        if (totalRemaining <= 0)
			return EvaluateWaitingHand(handAfterGang, state, wallAvailability, meldCount, melds, activeSeats, settlement);

        var shanten = 0.0;
        var live = 0.0;
        var expectedFan = 0.0;
        var expectedGain = 0.0;
        var gangBonus = 0.0;
        var replacementWin = 0.0;
        var baseValue = 0.0;
        var discardWeights = new Dictionary<int, double>();
        for (var draw = 0; draw < 27; draw++)
        {
			var copies = Math.Max(0.0, wallAvailability.ExpectedCounts18[draw]);
            if (copies <= 0 || handAfterGang[draw] >= 4) continue;
            var weight = copies / (double)totalRemaining;
            var drawn = (int[])handAfterGang.Clone();
            drawn[draw]++;
            if (_hands.IsWinning(drawn, meldCount, meldCount == 0))
            {
                var fan = _fans.Project(drawn, melds, SichuanWinType.GangSelfDraw);
                var gain = settlement.ProjectWin(state.SeatIndex, -1, activeSeats, fan, SichuanWinType.GangSelfDraw).WinnerGain;
                expectedFan += fan.CappedFan * weight;
                expectedGain += gain * weight;
                gangBonus += gain * weight;
                replacementWin += weight;
                shanten -= weight;
                baseValue += gain * 0.20 * weight;
                continue;
            }

			var branch = EvaluatePostClaimDiscards(
				drawn,
				state,
				RemoveWallTile(wallAvailability, draw),
				meldCount,
				melds,
				activeSeats,
				settlement);
            shanten += branch.Shanten * weight;
            live += branch.LiveUkeire * weight;
            expectedFan += branch.ExpectedFan * weight;
            expectedGain += branch.ExpectedSelfDrawGain * weight;
            baseValue += branch.BaseValue * weight;
            if (branch.BestDiscardTile >= 0)
                discardWeights[branch.BestDiscardTile] = discardWeights.GetValueOrDefault(branch.BestDiscardTile) + weight;
        }
        var bestDiscard = discardWeights.OrderByDescending(item => item.Value).ThenBy(item => item.Key).Select(item => item.Key).DefaultIfEmpty(-1).First();
        return new FollowUpEvaluation(
            (int)Math.Round(shanten),
            (int)Math.Round(live),
            bestDiscard,
            expectedFan,
            expectedGain,
            gangBonus,
            replacementWin,
            baseValue);
    }

	private static SichuanWallAvailability RemoveWallTile(SichuanWallAvailability source, int tileType)
	{
		var representative = (int[])source.RepresentativeCounts18.Clone();
		var expected = (double[])source.ExpectedCounts18.Clone();
		if (tileType is >= 0 and < 27)
		{
			representative[tileType] = Math.Max(0, representative[tileType] - 1);
			expected[tileType] = Math.Max(0.0, expected[tileType] - 1.0);
		}
		var target = Math.Max(0, source.WallCount - 1);
		var total = expected.Sum();
		if (total > 0.000001 && Math.Abs(total - target) > 0.000001)
		{
			var scale = target / total;
			for (var tile = 0; tile < expected.Length; tile++)
				expected[tile] *= scale;
		}
		return new SichuanWallAvailability(
			expected,
			representative,
			Math.Max(0, source.WallCount - 1));
	}

    private WaitPricing PriceWaits(
        int[] hand,
        IReadOnlyList<SichuanWaitAnalysis> waits,
		SichuanWallAvailability wallAvailability,
        IReadOnlyList<SichuanMeldView> melds,
        SichuanStateView state,
        IReadOnlyList<int> activeSeats,
        SichuanSettlementProjectionEngine settlement,
        bool gangSelfDraw)
    {
		var total = waits.Sum(wait => wallAvailability.ExpectedCounts18[wait.TileType]);
        if (total <= 0) return new WaitPricing(0, 0);
        var expectedFan = 0.0;
        var expectedGain = 0.0;
        foreach (var wait in waits)
        {
            var completed = (int[])hand.Clone();
            completed[wait.TileType]++;
            var winType = gangSelfDraw ? SichuanWinType.GangSelfDraw : SichuanWinType.SelfDraw;
            var fan = _fans.Project(completed, melds, winType);
			var weight = wallAvailability.ExpectedCounts18[wait.TileType] / total;
            expectedFan += fan.CappedFan * weight;
            expectedGain += settlement.ProjectWin(state.SeatIndex, -1, activeSeats, fan, winType).WinnerGain * weight;
        }
        return new WaitPricing(expectedFan, expectedGain);
    }

    private static SichuanMeldView[] InferMeldViews(SichuanStateView state)
        => state.Melds18[state.SeatIndex]
            .Where(tile => tile is >= 0 and < 27)
            .GroupBy(tile => tile)
            .Select((group, index) => new SichuanMeldView(
                group.Count() >= 4 ? SichuanMeldType.MeldedGang : SichuanMeldType.Peng,
                group.Key,
                -1,
                index))
            .ToArray();

    private static SichuanMeldView[] ProjectMelds(
        IReadOnlyList<SichuanMeldView> current,
        string action,
        int tileType,
        long eventVersion)
    {
		if (action is "pass" or "continue") return current.ToArray();
        if (action == "add_gang")
        {
            var upgraded = current.ToArray();
            var index = Array.FindIndex(upgraded, meld => meld.TileType == tileType && meld.Type == SichuanMeldType.Peng);
            if (index >= 0)
            {
                upgraded[index] = upgraded[index] with { Type = SichuanMeldType.AddedGang, EventIndex = eventVersion };
                return upgraded;
            }
            return current.Concat(new[] { new SichuanMeldView(SichuanMeldType.AddedGang, tileType, -1, eventVersion) }).ToArray();
        }
        var type = action switch
        {
            "an_gang" or "concealed_gang" => SichuanMeldType.ConcealedGang,
            "gang" or "melded_gang" => SichuanMeldType.MeldedGang,
            _ => SichuanMeldType.Peng
        };
        return current.Concat(new[] { new SichuanMeldView(type, tileType, -1, eventVersion) }).ToArray();
    }

    private sealed record FollowUpEvaluation(
        int Shanten,
        int LiveUkeire,
        int BestDiscardTile,
        double ExpectedFan,
        double ExpectedSelfDrawGain,
        double ExpectedGangDrawBonus,
        double ReplacementWinProbability,
        double BaseValue);

    private sealed record WaitPricing(double ExpectedFan, double ExpectedSelfDrawGain);
}
