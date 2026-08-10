using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Decision;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanSelfActionDecisionEngine
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanUkeireEngine _ukeire = new();
    private readonly SichuanBeliefEngine _belief = new();
    private readonly SichuanDangerEngine _danger = new();
	private readonly SichuanRoutePlanEngine _routePlan = new();
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
                ActionScores = scores
            };
        }

        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        var belief = _belief.Build(state);
        var roundStage = ResolveRoundStage(state);
        var currentPlan = _routePlan.Evaluate(state, roundBrain);
        var maxReadyPosterior = belief.SeatReadyPosterior.Values.DefaultIfEmpty(0.0).Max();
		var threatLevel = ResolveThreatLevel(state, belief);
		var currentValue = _meldCounterfactual.Evaluate(state, "continue", -1, 0, meldCount, 0, 0, 0, belief);
		var current = new FollowUpSummary(
			currentValue.Shanten,
			currentValue.LiveUkeire,
			currentValue.LiveUkeire,
			currentValue.BestDiscardTile,
			Array.Empty<int>());
		var passScore = (int)Math.Round(Math.Clamp(currentValue.Value, -20, 20) * 100.0);
		var preservesSevenPairs = meldCount == 0 && state.Hand18.Sum(count => count / 2) >= 5;
		scores["pass"] = passScore;

        var best = new SichuanSelfActionDecisionResult
        {
            Action = new SichuanAction(SichuanActionType.Pass, -1, passScore, "保留当前最快成叫路径"),
            ShantenAfter = current.Shanten,
            LiveUkeireAfter = current.LiveUkeire,
			Reasons = new[] { $"当前最快向听 {current.Shanten}", $"当前活张 {current.LiveUkeire}", $"继续出牌统一净值 {currentValue.Value:F2}" }
				.Concat(preservesSevenPairs ? new[] { "七对路线：五对以上保留门清与四张牌的 2+2 结构" } : Array.Empty<string>())
				.Concat(BuildRouteProtectionPassReasons(state, currentPlan))
                .Concat(currentPlan.Reasons)
                .ToArray(),
            ActionScores = scores
        };
        SichuanSelfActionDecisionResult? mandatoryGang = null;
        var mandatoryTiles = (mandatoryGangTileTypes ?? Array.Empty<int>()).ToHashSet();

        foreach (var tileType in anGangTileTypes.Where(tile => tile is >= 0 and < 27).Distinct())
        {
            if (state.Hand18[tileType] < 4) continue;
			var candidate = EvaluateSelfGang(state, belief, tileType, "an_gang", current, currentPlan, meldCount, roundStage, threatLevel, maxReadyPosterior, preservesSevenPairs: preservesSevenPairs);
            scores[$"an_gang:{tileType}"] = candidate.Action.Score;
            if (mandatoryTiles.Contains(tileType) && (mandatoryGang is null || candidate.Action.Score > mandatoryGang.Action.Score))
                mandatoryGang = candidate;
            if (candidate.Action.Score > best.Action.Score)
                best = candidate;
        }

        foreach (var tileType in addGangTileTypes.Where(tile => tile is >= 0 and < 27).Distinct())
        {
            if (state.Hand18[tileType] < 1) continue;
            var qiangGangCount = Math.Max(0, addGangQiangGangCounts?.GetValueOrDefault(tileType, 0) ?? 0);
			var candidate = EvaluateSelfGang(state, belief, tileType, "add_gang", current, currentPlan, meldCount, roundStage, threatLevel, maxReadyPosterior, qiangGangCount, preservesSevenPairs);
            scores[$"add_gang:{tileType}"] = candidate.Action.Score;
            if (mandatoryTiles.Contains(tileType) && (mandatoryGang is null || candidate.Action.Score > mandatoryGang.Action.Score))
                mandatoryGang = candidate;
            if (qiangGangCount > 0 && candidate.Action.Score <= best.Action.Score)
            {
                best.Reasons = best.Reasons
                    .Concat(new[] { $"补杠 {tileType} 存在 {qiangGangCount} 家可抢杠胡，C# 已压低补杠权重" })
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

        best.ActionScores = new Dictionary<string, int>(scores);
        return best;
    }

    private SichuanSelfActionDecisionResult EvaluateSelfGang(
        SichuanStateView state,
        SichuanBeliefSnapshot belief,
        int tileType,
        string subtype,
        FollowUpSummary current,
        SichuanRoutePlanResult currentPlan,
        int meldCount,
        int roundStage,
        int threatLevel,
        double maxReadyPosterior,
		int qiangGangCandidateCount = 0,
		bool preservesSevenPairs = false)
    {
        var removeCount = subtype == "an_gang" ? 4 : 1;
        var meldCountAfter = subtype == "an_gang" ? meldCount + 1 : meldCount;
        var counterfactual = _meldCounterfactual.Evaluate(
            state,
            subtype,
            tileType,
            removeCount,
            meldCountAfter,
			routeLoss: currentPlan.ForbidsGangs || preservesSevenPairs ? 12.0 : 0,
            risk: 0,
			gangGain: subtype == "an_gang" ? 2.0 : 1.0,
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
        var taxBonus = subtype == "an_gang" ? 116 : 72;
        var score = taxBonus
            - followUp.Shanten * 118
            + followUp.LiveUkeire * 10
            + (current.Shanten - followUp.Shanten) * 132
            + (followUp.LiveUkeire - current.LiveUkeire) * 7
            - (int)Math.Round(discardRisk * 0.76)
            - threatLevel * 10
            - roundStage * 8;

        if (followUp.Shanten <= current.Shanten) score += 76;
        if (followUp.Shanten == 0) score += 176;
        if (followUp.Shanten < current.Shanten) score += 132;
        if (followUp.Shanten <= current.Shanten && followUp.LiveUkeire + 3 >= current.LiveUkeire && discardRisk < 64)
            score += roundStage <= 1 ? 84 : 42;
        if (followUp.Shanten <= 0 && discardRisk < 70)
            score += 112;
        if (followUp.Shanten > current.Shanten) score -= 180;
        if (roundStage <= 1 && maxReadyPosterior < 0.58 && followUp.Shanten <= current.Shanten) score += 68;
        if (roundStage >= 2 && followUp.Shanten > 0) score -= 74;
        if (subtype == "add_gang" && followUp.Shanten > 0) score -= 190;
        if (subtype == "add_gang" && roundStage >= 2 && followUp.Shanten > 0) score -= 160;
        if (subtype == "add_gang" && maxReadyPosterior >= 0.56 && followUp.Shanten > 0) score -= 120;
		if (currentPlan.ForbidsGangs || preservesSevenPairs) score -= 6000;

		var legacyTieBreak = Math.Clamp(score, -40, 40);
		score = (int)Math.Round(Math.Clamp(counterfactual.Value - discardRisk / 100.0, -20, 20) * 100.0)
			+ legacyTieBreak
			- (currentPlan.ForbidsGangs || preservesSevenPairs ? 1200 : 0);

        var robGangLoss = 0;
        if (subtype == "add_gang" && qiangGangCandidateCount > 0)
        {
            var perOpponentRobProbability = Math.Clamp(0.16 + maxReadyPosterior * 0.18 + roundStage * 0.04, 0.12, 0.42);
            var robGangProbability = 1.0 - Math.Pow(1.0 - perOpponentRobProbability, qiangGangCandidateCount);
            robGangLoss = (int)Math.Round(robGangProbability * (8.0 + counterfactual.ExpectedFan * 6.0));
            score -= robGangLoss;
        }

        var label = subtype == "an_gang" ? "暗杠" : "补杠";
        var reasons = new List<string>
        {
            $"{label}后最快向听 {followUp.Shanten}",
            $"{label}后活张 {followUp.LiveUkeire}",
            $"{label}后首打危险 {discardRisk}",
            $"{label}税收益纳入 C# 决策",
            $"统一副露反事实 {counterfactual.Value:F2}（向听 {counterfactual.Shanten}，活张 {counterfactual.LiveUkeire}）"
        };
		if (currentPlan.ForbidsGangs || preservesSevenPairs)
			reasons.Add($"七对路线：{currentPlan.PrimaryRoute} 禁止{label}，杠牌会破坏七对");
        if (followUp.Shanten <= current.Shanten) reasons.Add("杠后不拖慢成叫");
        if (followUp.Shanten == 0) reasons.Add("杠后仍可下叫，优先收杠分");
        if (followUp.Shanten <= current.Shanten && followUp.LiveUkeire + 3 >= current.LiveUkeire && discardRisk < 64)
            reasons.Add("老手进攻：杠税收益明确且速度不亏");
        if (followUp.Shanten > current.Shanten) reasons.Add("杠后向听变差，降权");
        if (subtype == "add_gang" && qiangGangCandidateCount > 0)
            reasons.Add($"存在 {qiangGangCandidateCount} 家可抢杠胡，概率化损失 {robGangLoss}");
        if (subtype == "add_gang" && followUp.Shanten > 0)
            reasons.Add("补杠后仍未成叫，先保留手牌效率");
        if (subtype == "add_gang" && roundStage >= 2 && followUp.Shanten > 0)
            reasons.Add("后期未听补杠风险高，C# 继续降权");

        return new SichuanSelfActionDecisionResult
        {
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
            if (state.Melds18[seat].Count / 3 >= 2) total += 1;
        }
        return Math.Clamp(total, 0, 5);
    }

    private static int ResolveRoundStage(SichuanStateView state)
    {
        var maxDiscards = state.Discards18.Max(list => list.Count);
        var hasLikelyReady = state.IsCalled.Any(value => value) || state.IsReady.Any(value => value);
        var exposedMeldCount = state.Melds18.Sum(list => list.Count / 3);
        if (state.WallCount <= 6) return 2;
        if (hasLikelyReady && state.WallCount <= 8) return 2;
        if (maxDiscards >= 10 || state.WallCount <= 13 || exposedMeldCount >= 5) return 1;
        if (hasLikelyReady && state.WallCount <= 10) return 1;
        return 0;
    }

    private static IReadOnlyList<string> BuildRouteProtectionPassReasons(
        SichuanStateView state,
        SichuanRoutePlanResult currentPlan)
    {
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        if (currentPlan.ForbidsGangs || meldCount > 0 || CountPairs(state.Hand18) < 5)
            return Array.Empty<string>();
        return new[] { "七对路线：五对以上门清牌优先过牌，保留七对/龙七对" };
    }

    private static int CountPairs(int[] hand18)
        => hand18.Count(count => count >= 2);

    private static int[] RemoveCopies(int[] hand18, int tileType, int removeCount)
    {
        var clone = (int[])hand18.Clone();
        if (tileType < 0 || tileType >= clone.Length) return clone;
        clone[tileType] = Math.Max(0, clone[tileType] - removeCount);
        return clone;
    }

    private sealed record FollowUpSummary(int Shanten, int Ukeire, int LiveUkeire, int BestDiscardTile, int[] ImprovingTiles);
}
