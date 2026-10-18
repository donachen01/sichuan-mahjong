using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Decision;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanSelfActionDecisionEngine
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanUkeireEngine _ukeire = new();
    private readonly SichuanBeliefEngine _belief = new();
    private readonly SichuanDangerEngine _danger = new();
	private readonly SichuanUnifiedDecisionEngine _unified = new();
	private readonly SichuanMeldCounterfactualEvaluator _meldCounterfactual = new();

    public SichuanSelfActionDecisionResult DecideSelfAction(
        SichuanStateView state,
        bool canSelfHu,
        IReadOnlyList<int> anGangTileTypes,
        IReadOnlyList<int> addGangTileTypes,
        IReadOnlyDictionary<int, int>? addGangQiangGangCounts = null,
        IReadOnlyList<int>? mandatoryGangTileTypes = null,
        SichuanRoundBrainSnapshot? roundBrain = null)
    {
        using var searchBudget = SichuanSearchBudget.Enter(state);
        using var decisionScope = Decision.SichuanPolicyExecutionScope.EnterDecision();
        SichuanSearchBudget.AllowRootDiscardSearch(state, anGangTileTypes.Count == 0 && addGangTileTypes.Count == 0);
        var scores = new Dictionary<string, int>();

        if (canSelfHu)
        {
			var confirmation = _unified.ConfirmSelfDrawHu(state);
			var huCandidate = confirmation.Candidates.First(candidate => candidate.Action.ActionType == SichuanActionType.Hu);
			var passCandidate = confirmation.Candidates.First(candidate => candidate.Action.ActionType == SichuanActionType.Pass);
			var huScore = (int)Math.Round(huCandidate.ExpectedNetScore * 1000.0);
			var passEvScore = (int)Math.Round(passCandidate.ExpectedNetScore * 1000.0);
			scores["hu"] = huScore;
			scores["pass"] = passEvScore;
            return new SichuanSelfActionDecisionResult
            {
				Action = new SichuanAction(SichuanActionType.Hu, state.LastDrawTileType, huScore, confirmation.Summary),
				Reasons = confirmation.Reasons,
                ActionScores = scores,
                CandidateReasons = confirmation.Candidates.ToDictionary(c=>c.Action.ActionType.ToString().ToLowerInvariant(),c=>c.ReasonCodes.ToArray())
            };
        }

        var meldCount = state.OwnMeldCount;
        var belief = _belief.Build(state);
        var roundStage = new SichuanStageEvaluator().Evaluate(state, belief).StageIndex;
        var maxReadyPosterior = belief.SeatReadyPosterior.Values.DefaultIfEmpty(0.0).Max();
		var threatLevel = ResolveThreatLevel(state, belief);
		var currentValue = _meldCounterfactual.Evaluate(state, "continue", -1, 0, meldCount, 0, 0, 0, belief);
		var current = new FollowUpSummary(
			currentValue.Shanten,
			currentValue.LiveUkeire,
			currentValue.LiveUkeire,
			currentValue.BestDiscardTile,
			Array.Empty<int>());
		var passDiscardRisk = current.BestDiscardTile >= 0
			? _danger.EvaluateDetail(current.BestDiscardTile, state, belief).Risk : 0;
		var passScore = (int)Math.Round(Math.Clamp(currentValue.Value, -20, 20) * 100.0);
		scores["pass"] = passScore;

        var best = new SichuanSelfActionDecisionResult
        {
            Action = new SichuanAction(SichuanActionType.Pass, -1, passScore, "保留已比较的具体弃牌后手"),
            ContinuationDiscardTile = current.BestDiscardTile,
            ShantenAfter = current.Shanten,
            LiveUkeireAfter = current.LiveUkeire,
			Reasons = new[] { $"当前后手向听 {current.Shanten}", $"当前活张 {current.LiveUkeire}", $"继续出牌统一净值 {currentValue.Value:F2}", "CONTINUATION_LEGAL_READY_CONTEXT",
					$"SELF_PASS_PLANNED_DISCARD_{current.BestDiscardTile}", $"当前后手弃牌风险已计价 {currentValue.ExpectedDiscardRisk:F4}",
					"SELF_GANG_ROUTE_PRICED_BY_EXECUTABLE_CONTINUATION" }
				.Concat(BuildContinuationRouteReasons(state, current.BestDiscardTile))
                .ToArray(),
            ActionScores = scores
        };
        var budgetOptions = new List<SichuanSearchBudget.Option> {
            new("continue", passScore, current.Shanten, current.LiveUkeire, currentValue.ExpectedDiscardRisk) };
        var candidateReasons = new Dictionary<string,string[]> { ["pass"] = best.Reasons.ToArray() };
        SichuanSelfActionDecisionResult? mandatoryGang = null;
        var mandatoryTiles = (mandatoryGangTileTypes ?? Array.Empty<int>()).ToHashSet();

        foreach (var tileType in anGangTileTypes.Where(tile => tile is >= 0 and < 27).Distinct())
        {
            if (state.Hand18[tileType] < 4) continue;
			var candidate = EvaluateSelfGang(state, belief, tileType, "an_gang", current, meldCount, roundStage, threatLevel, maxReadyPosterior);
            scores[$"an_gang:{tileType}"] = candidate.Action.Score;
            candidateReasons[$"an_gang:{tileType}"] = candidate.Reasons.ToArray();
            if(!candidate.OpponentWideBedDefenseAllowed&&!mandatoryTiles.Contains(tileType))
            {scores[$"an_gang:{tileType}"]=int.MinValue/4;continue;}
            budgetOptions.Add(new("an_gang", candidate.Action.Score, candidate.ShantenAfter, candidate.LiveUkeireAfter, candidate.ContinuationDiscardRisk));
            if (mandatoryTiles.Contains(tileType) && (mandatoryGang is null || candidate.Action.Score > mandatoryGang.Action.Score))
                mandatoryGang = candidate;
            if (candidate.Action.Score > best.Action.Score)
                best = candidate;
        }

        foreach (var tileType in addGangTileTypes.Where(tile => tile is >= 0 and < 27).Distinct())
        {
            if (!Rules.SichuanAddedGangRules.CanUpgrade(state, tileType)) continue;
            // Retain the old argument for transport compatibility, but never
            // condition a fair decision on concealed-hand-derived legal counts.
            var robGangRisk = PublicRobGangRisk(state, belief, tileType);
			var candidate = EvaluateSelfGang(state, belief, tileType, "add_gang", current, meldCount, roundStage, threatLevel, maxReadyPosterior, robGangRisk);
            scores[$"add_gang:{tileType}"] = candidate.Action.Score;
            candidateReasons[$"add_gang:{tileType}"] = candidate.Reasons.ToArray();
            if(!candidate.OpponentWideBedDefenseAllowed&&!mandatoryTiles.Contains(tileType))
            {scores[$"add_gang:{tileType}"]=int.MinValue/4;continue;}
            budgetOptions.Add(new("add_gang", candidate.Action.Score, candidate.ShantenAfter, candidate.LiveUkeireAfter, candidate.ContinuationDiscardRisk));
            if (mandatoryTiles.Contains(tileType) && (mandatoryGang is null || candidate.Action.Score > mandatoryGang.Action.Score))
                mandatoryGang = candidate;
            if (robGangRisk > 0 && candidate.Action.Score <= best.Action.Score)
            {
                best.Reasons = best.Reasons
                    .Concat(new[] { $"补杠 {tileType} 存在公开后验风险，C# 已比较补杠代价；不读取实际可抢杠人数" })
                    .ToArray();
            }
            if (candidate.Action.Score > best.Action.Score)
                best = candidate;
        }

        if (mandatoryGang is not null)
        {
            mandatoryGang.Action = mandatoryGang.Action with
            {
                Score = Math.Max(mandatoryGang.Action.Score, best.Action.Score + 96),
                Reason = "规则要求执行杠牌"
            };
            mandatoryGang.Reasons = mandatoryGang.Reasons
                .Concat(new[] { "规则强制杠已通过 C# 合法动作合同执行" })
                .ToArray();
            scores[$"{mandatoryGang.GangSubtype}:{mandatoryGang.Action.TileType}"] = mandatoryGang.Action.Score;
            best = mandatoryGang;
        }

        if (mandatoryTiles.Count == 0)
        {
            using var upgrade = SichuanSearchBudget.TryDeep(state,
                SichuanSearchBudget.Qualify(state, budgetOptions, maxReadyPosterior >= 0.55), meld: true, terminal: true);
            if (upgrade is not null)
                return DecideSelfAction(state, canSelfHu, anGangTileTypes, addGangTileTypes,
                    addGangQiangGangCounts, mandatoryGangTileTypes, roundBrain);
        }
        if(SichuanOpponentWideBedDefense.Applies(state))
            best.Reasons=best.Reasons.Prepend(SichuanOpponentWideBedDefense.ActiveCode).ToArray();
        best.CandidateReasons = candidateReasons;
        best.ActionScores = new Dictionary<string, int>(scores);
        best.Reasons = best.Reasons.Append(SichuanSearchBudget.Reason).ToArray();
        return best;
    }

    private SichuanSelfActionDecisionResult EvaluateSelfGang(
        SichuanStateView state,
        SichuanBeliefSnapshot belief,
        int tileType,
        string subtype,
        FollowUpSummary current,
        int meldCount,
        int roundStage,
        int threatLevel,
        double maxReadyPosterior,
		double robGangRisk = 0)
    {
        var removeCount = subtype == "an_gang" ? 4 : 1;
        var meldCountAfter = subtype == "an_gang" ? meldCount + 1 : meldCount;
        var counterfactual = _meldCounterfactual.Evaluate(
            state,
            subtype,
            tileType,
            removeCount,
            meldCountAfter,
			// The competing continuation already evaluates the actual closed
			// hand's legal distance and, when ready, all wait/fan prices. A route
			// label is not an additional asset worth a fixed twelve units.
			routeLoss: 0,
            risk: 0,
			gangGain: 0,
			belief: belief);
        var followUp = new FollowUpSummary(
            counterfactual.Shanten,
            counterfactual.LiveUkeire,
            counterfactual.LiveUkeire,
            counterfactual.BestDiscardTile,
            Array.Empty<int>());
        var discardRisk = followUp.BestDiscardTile >= 0
            ? _danger.EvaluateDetail(followUp.BestDiscardTile, state, belief).Risk
            : 0;
        // The common evaluator already prices risk at every concrete child;
        // never charge only the representative Gang discard a second time.
        var score = (int)Math.Round(Math.Clamp(counterfactual.Value, -20, 20) * 100.0);

        var robGangLoss = 0;
        if (subtype == "add_gang" && robGangRisk > 0)
        {
            // Existing score conversion is heuristic, not calibrated net EV.
            robGangLoss = (int)Math.Round(robGangRisk * (8.0 + counterfactual.ExpectedFan * 6.0));
            score -= robGangLoss;
        }

        var label = subtype == "an_gang" ? "暗杠" : "补杠";
        var ongoingBranches = counterfactual.ReplacementBranches.Where(b => !b.ImmediateWin).ToArray();
        var hasBranchProfile = counterfactual.ReplacementBranches.Count > 0;
        var minBranchShanten = ongoingBranches.Select(b => b.Shanten).DefaultIfEmpty(-1).Min();
        var maxBranchShanten = ongoingBranches.Select(b => b.Shanten).DefaultIfEmpty(-1).Max();
        var reasons = new List<string>
        {
            $"{label}后模型向听摘要 {followUp.Shanten}（补牌分支加权取整）",
            $"{label}后模型活张摘要 {followUp.LiveUkeire}",
            $"{label}后代表弃牌危险 {discardRisk}（补牌后重新决策）",
            $"{label}规则杠分收益纳入 C# 决策",
            $"GANG_IMMEDIATE_RULE_GAIN_{counterfactual.ImmediateGangGain}",
            $"GANG_REFUND_EXPECTED_LOSS_{counterfactual.ExpectedGangRefundLoss:F4}",
            "GANG_REFUND_PUBLIC_PROGRESS_APPROXIMATION",
            $"GANG_DISCARD_EXTRA_LOSS_PUBLIC_APPROX_{counterfactual.ExpectedGangDiscardExtraLoss:F4}",
			$"GANG_BROKEN_READY_OPPORTUNITY_LOSS_{counterfactual.BrokenReadyOpportunityLoss:F4}",
			$"GANG_DEAD_READY_BRANCH_MASS_{counterfactual.DeadReadyBranchMass:F4}",
            "GANG_RULE_CASHFLOW",
            $"统一副露反事实 {counterfactual.Value:F2}（向听 {counterfactual.Shanten}，活张 {counterfactual.LiveUkeire}）"
        };
		if (subtype == "add_gang" && counterfactual.ImmediateGangGain == 0)
			reasons.Add("手上原有第四张补杠，本次不计杠分");
		if (counterfactual.ReplacementWallConstraintsRebuilt)
            reasons.Add("GANG_REPLACEMENT_PUBLIC_WALL_REBUILT");
        if (counterfactual.ContinuationLegalContextApplied)
            reasons.Add("CONTINUATION_LEGAL_READY_CONTEXT");
		if (hasBranchProfile)
		{
			reasons.Add("GANG_REPLACEMENT_BRANCH_PROFILE");
			reasons.Add($"GANG_REPLACEMENT_SHANTEN_RANGE_{minBranchShanten}_{maxBranchShanten}");
			if (ongoingBranches.Length > 0)
				reasons.Add($"公开模型评估的补牌后手向听范围 {minBranchShanten}～{maxBranchShanten}；实际补牌后按最新状态选择弃牌");
			if (ongoingBranches.Any(b => b.Shanten == 0) && ongoingBranches.Any(b => b.Shanten > 0))
				reasons.Add("仅部分补牌后手能听，向听摘要不代表所有后手均已听牌");
		}
		reasons.Add("SELF_GANG_ROUTE_PRICED_BY_EXECUTABLE_CONTINUATION");
        if (hasBranchProfile && ongoingBranches.Length > 0 && ongoingBranches.All(b => b.Shanten <= current.Shanten))
            reasons.Add("所评估的补牌后手均不增加向听，实际杠分仍需与改良机会比较");
        if (hasBranchProfile && ongoingBranches.Length == 0)
            reasons.Add("所评估补牌均可直接胡牌，已比较杠上花收益");
        if (hasBranchProfile && ongoingBranches.Length > 0 && ongoingBranches.All(b => b.Shanten == 0))
            reasons.Add("所评估的未胡补牌后手均可下叫，已比较杠分收益");
        if (hasBranchProfile && ongoingBranches.Any(b => b.Shanten > current.Shanten))
            reasons.Add("部分补牌后手向听增加，不能只按取整摘要判断成叫速度");
        if (subtype == "add_gang" && robGangRisk > 0)
            reasons.Add($"公开听口后验的补杠风险启发式扣分 {robGangLoss}，不是已知可抢杠人数或校准净收益");
        if (subtype == "add_gang" && ongoingBranches.Any(b => b.Shanten > 0))
            reasons.Add("补杠存在未成叫后手，需保留手牌效率");
        if (subtype == "add_gang" && roundStage >= 2 && ongoingBranches.Any(b => b.Shanten > 0))
            reasons.Add("后期存在未听后手，需比较补杠收益与公开危险");

        var defenseAllowed=SichuanOpponentWideBedDefense.SafeGang(state,belief,current.Shanten,current.LiveUkeire,counterfactual);
        if(!defenseAllowed)reasons.Add("OPPONENT_WIDE_BED_REJECT_UNSAFE_GANG_BRANCH");
        return new SichuanSelfActionDecisionResult
        {
            OpponentWideBedDefenseAllowed=defenseAllowed,
            ContinuationDiscardRisk=counterfactual.ExpectedDiscardRisk,
            Action = new SichuanAction(SichuanActionType.Gang, tileType, score, reasons[0]),
            GangSubtype = subtype,
            ShantenAfter = followUp.Shanten,
            LiveUkeireAfter = followUp.LiveUkeire,
            Reasons = reasons
        };
    }

    private FollowUpSummary EvaluateBestFollowUp(int[] hand18, int[] remaining18, int meldCount)
    {
        var currentShanten = _shanten.CalcBestShanten(hand18, meldCount);
        if (hand18.Sum() <= 1)
            return new FollowUpSummary(currentShanten, 0, 0, -1, Array.Empty<int>());
        var bestShanten = int.MaxValue;
        var bestUkeire = 0;
        var bestLive = 0;
        var bestTile = -1;
        for (var tileType = 0; tileType < hand18.Length; tileType++)
        {
            if (hand18[tileType] <= 0) continue;
            var shanten = _shanten.CalcShantenAfterDiscard(hand18, tileType, meldCount);
            var (ukeire, liveUkeire, _) = _ukeire.CalcUkeire(hand18, remaining18, tileType, meldCount);
            if (shanten < bestShanten
                || (shanten == bestShanten && liveUkeire > bestLive)
                || (shanten == bestShanten && liveUkeire == bestLive && ukeire > bestUkeire))
            {
                bestShanten = shanten;
                bestUkeire = ukeire;
                bestLive = liveUkeire;
                bestTile = tileType;
            }
        }
        if (bestTile < 0)
            return new FollowUpSummary(currentShanten, 0, 0, -1, Array.Empty<int>());
        var (_, _, improvingTiles) = _ukeire.CalcUkeire(hand18, remaining18, bestTile, meldCount);
        return new FollowUpSummary(bestShanten, bestUkeire, bestLive, bestTile, improvingTiles.ToArray());
    }

    private int ResolveThreatLevel(SichuanStateView state, SichuanBeliefSnapshot belief)
    {
        var total = 0;
        for (var seat = 0; seat < state.HasHu.Length; seat++)
        {
            if (seat == state.SeatIndex || state.HasHu[seat]) continue;
            if (belief.SeatReadyPosterior.GetValueOrDefault(seat, 0.0) >= 0.56) total += 2;
            else if (belief.SeatReadyPosterior.GetValueOrDefault(seat, 0.0) >= 0.40) total += 1;
            if (state.IsCalled[seat] || state.IsReady[seat]) total += 1;
            if (state.MeldCount(seat) >= 2) total += 1;
        }
        return Math.Clamp(total, 0, 5);
    }

    private IReadOnlyList<string> BuildContinuationRouteReasons(SichuanStateView state, int discardTile)
    {
        if (state.OwnMeldCount > 0 || CountPairs(state.Hand18) < 5 || discardTile is < 0 or >= 27)
            return Array.Empty<string>();
        var after = (int[])state.Hand18.Clone(); after[discardTile]--;
        var beforeDistance = _shanten.CalcSevenPairsShanten(state.Hand18);
        var afterDistance = _shanten.CalcSevenPairsShanten(after);
        var retained = CountPairs(after) >= CountPairs(state.Hand18) && afterDistance <= beforeDistance;
        return retained
            ? new[] { "SEVEN_PAIRS_CONTINUATION_RETAINED", $"七对路线：具体弃牌后保留对子结构，七对向听 {afterDistance}" }
            : new[] { "SEVEN_PAIRS_CONTINUATION_ABANDONED", $"具体弃牌后七对向听 {beforeDistance}→{afterDistance}，按实际后手比较，不声称保留七对" };
    }

    public static double PublicRobGangRisk(SichuanStateView state, SichuanBeliefSnapshot belief, int tileType)
    {
        if (tileType is < 0 or >= 27) throw new ArgumentOutOfRangeException(nameof(tileType));
        var none = 1.0;
        for (var seat = 0; seat < 4; seat++)
        {
            if (seat == state.SeatIndex || !state.ActiveSeats[seat] || state.HasHu[seat]
                || state.DingQueSuits[seat] == tileType / 9) continue;
            // Marginal public wait estimates are combined with an independence
            // approximation. They are not calibrated real-game probabilities.
            var estimate = belief.SeatTileWaitProbability.TryGetValue(seat, out var waits)
                ? waits.GetValueOrDefault(tileType, 0.0) : 0.0;
            if (!double.IsFinite(estimate)) throw new ArgumentException("Nonfinite public wait estimate");
            none *= 1.0 - Math.Clamp(estimate, 0.0, 1.0);
        }
        return 1.0 - none;
    }

    private static int CountPairs(int[] hand18)
        => hand18.Sum(count => count / 2);

    private static int[] RemoveCopies(int[] hand18, int tileType, int removeCount)
    {
        var clone = (int[])hand18.Clone();
        if (tileType < 0 || tileType >= clone.Length) return clone;
        clone[tileType] = Math.Max(0, clone[tileType] - removeCount);
        return clone;
    }

    private sealed record FollowUpSummary(int Shanten, int Ukeire, int LiveUkeire, int BestDiscardTile, int[] ImprovingTiles);
}
