using System.Diagnostics;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanStageEvaluator
{
    public SichuanStageContext Evaluate(SichuanStateView state, SichuanBeliefSnapshot belief)
    {
        var maxDiscards = state.Discards18.Max(list => list.Count);
        var exposedMeldCount = state.Melds18.Sum(list => list.Count / 3);
        var hasLikelyReady = Enumerable.Range(0, 4)
            .Where(seat => seat != state.SeatIndex && !state.HasHu[seat])
            .Any(seat => state.IsCalled[seat] || state.IsReady[seat] || belief.SeatReadyPosterior.GetValueOrDefault(seat, 0.0) >= 0.55);
        var riskRaised = exposedMeldCount >= 3 || hasLikelyReady;

        if (state.WallCount <= 6)
            return Build("late", 2, "STAGE_LATE_BY_REMAINING_TILES", state, maxDiscards, exposedMeldCount, hasLikelyReady, riskRaised);
        if (hasLikelyReady && state.WallCount <= 8)
            return Build("late", 2, "STAGE_LATE_BY_READY_PRESSURE", state, maxDiscards, exposedMeldCount, hasLikelyReady, true);
        if (maxDiscards >= 10 || state.WallCount <= 13 || exposedMeldCount >= 5)
            return Build("middle", 1, "STAGE_MIDDLE_BY_PROGRESS", state, maxDiscards, exposedMeldCount, hasLikelyReady, riskRaised);
        if (hasLikelyReady && state.WallCount <= 10)
            return Build("middle", 1, "STAGE_MIDDLE_BY_READY_PRESSURE", state, maxDiscards, exposedMeldCount, hasLikelyReady, true);
        return Build("early", 0, "STAGE_EARLY_BY_LOW_PROGRESS", state, maxDiscards, exposedMeldCount, hasLikelyReady, riskRaised);
    }

    private static SichuanStageContext Build(
        string stage,
        int stageIndex,
        string reasonCode,
        SichuanStateView state,
        int maxDiscards,
        int exposedMeldCount,
        bool hasLikelyReady,
        bool riskRaised) => new()
        {
            Stage = stage,
            StageIndex = stageIndex,
            ReasonCode = reasonCode,
            WallCount = state.WallCount,
            MaxDiscardCount = maxDiscards,
            ExposedMeldCount = exposedMeldCount,
            HasLikelyReadyOpponent = hasLikelyReady,
            RiskRaised = riskRaised
        };
}

public sealed class SichuanHandEvaluator
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanUkeireEngine _ukeire = new();
    private readonly Dictionary<string, SichuanHandAnalysis> _cache = new();

    public SichuanHandAnalysis Evaluate(SichuanStateView state, SichuanBeliefSnapshot belief)
    {
        var key = BuildHandKey(state);
        if (_cache.TryGetValue(key, out var cached))
            return cached;

        var stopwatch = Stopwatch.StartNew();
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        var shanten = _shanten.CalcBestShanten(state.Hand18, meldCount);
        var bestUkeire = 0;
        var bestLiveUkeire = 0;
        foreach (var tileType in Enumerable.Range(0, 27).Where(tile => state.Hand18[tile] > 0))
        {
            var (_, live, improvingTiles) = _ukeire.CalcUkeire(state.Hand18, state.Remaining18, tileType, meldCount);
            bestUkeire = Math.Max(bestUkeire, improvingTiles.Count);
            bestLiveUkeire = Math.Max(bestLiveUkeire, live);
        }

        var pairCount = state.Hand18.Count(count => count >= 2);
        var isolatedCount = CountIsolatedSingles(state.Hand18);
        var taatsuCount = CountTaatsu(state.Hand18);
        var bigHandPotential = EstimateBigHandPotential(state, pairCount);
        var highRiskWasteCount = CountHighRiskWasteTiles(state, belief);
        var quality = Math.Clamp(
            100 - shanten * 22 + taatsuCount * 6 + pairCount * 5 + Math.Min(20, bestLiveUkeire * 2) + bigHandPotential / 3 - isolatedCount * 4,
            0,
            100);

        stopwatch.Stop();
        var result = new SichuanHandAnalysis
        {
            HandKey = key,
            Shanten = shanten,
            TaatsuCount = taatsuCount,
            PairCount = pairCount,
            IsolatedCount = isolatedCount,
            UkeireCount = bestUkeire,
            LiveUkeireCount = bestLiveUkeire,
            DingQueClear = state.OwnDingQueSuit is not (>= 0 and < 3)
                || !Enumerable.Range(state.OwnDingQueSuit * 9, 9).Any(tile => state.Hand18[tile] > 0),
            BigHandPotential = bigHandPotential,
            HighRiskWasteCount = highRiskWasteCount,
            HandQuality = quality,
            ReasonCode = ResolveReasonCode(shanten, quality, bigHandPotential),
            ElapsedMs = stopwatch.Elapsed.TotalMilliseconds
        };
        _cache[key] = result;
        if (_cache.Count > 256)
            _cache.Remove(_cache.Keys.First());
        return result;
    }

    public static string BuildHandKey(SichuanStateView state)
        => string.Join(',', state.Hand18) + $"|m:{string.Join(',', state.Melds18[state.SeatIndex])}|w:{state.WallCount}";

    private static int CountIsolatedSingles(int[] hand18)
    {
        var count = 0;
        for (var tile = 0; tile < 27; tile++)
        {
            if (hand18[tile] != 1) continue;
            var rank = tile % 9;
            var left = rank > 0 && hand18[tile - 1] > 0;
            var right = rank < 8 && hand18[tile + 1] > 0;
            if (!left && !right) count++;
        }
        return count;
    }

    private static int CountTaatsu(int[] hand18)
    {
        var count = 0;
        for (var start = 0; start <= 18; start += 9)
        {
            for (var rank = 0; rank < 8; rank++)
            {
                if (hand18[start + rank] > 0 && hand18[start + rank + 1] > 0)
                    count++;
                if (rank <= 6 && hand18[start + rank] > 0 && hand18[start + rank + 2] > 0)
                    count++;
            }
        }
        return Math.Min(count, 8);
    }

    private static int EstimateBigHandPotential(SichuanStateView state, int pairCount)
    {
        var suitCounts = new[] { 0, 0, 0 };
        for (var tile = 0; tile < 27; tile++)
            suitCounts[tile / 9] += state.Hand18[tile];
        foreach (var tile in state.Melds18[state.SeatIndex])
            suitCounts[tile / 9]++;
        var maxSuit = suitCounts.Max();
        var tripletLike = state.Hand18.Count(count => count >= 3) + state.Melds18[state.SeatIndex].Count / 3;
        return Math.Clamp(maxSuit * 5 + pairCount * 6 + tripletLike * 10, 0, 100);
    }

    private static int CountHighRiskWasteTiles(SichuanStateView state, SichuanBeliefSnapshot belief)
    {
        var count = 0;
        for (var tile = 0; tile < 27; tile++)
        {
            if (state.Hand18[tile] <= 0) continue;
            var maxWait = belief.SeatTileWaitProbability.Values
                .Select(map => map.GetValueOrDefault(tile, 0.0))
                .DefaultIfEmpty(0.0)
                .Max();
            if (maxWait >= 0.26 && CountNeighbors(state.Hand18, tile) == 0)
                count += state.Hand18[tile];
        }
        return count;
    }

    private static int CountNeighbors(int[] hand18, int tile)
    {
        var rank = tile % 9;
        var total = 0;
        if (rank > 0) total += hand18[tile - 1];
        if (rank < 8) total += hand18[tile + 1];
        if (rank > 1) total += hand18[tile - 2];
        if (rank < 7) total += hand18[tile + 2];
        return total;
    }

    private static string ResolveReasonCode(int shanten, int quality, int bigHandPotential)
    {
        if (shanten <= 0) return "HAND_READY_OR_TENPAI";
        if (shanten <= 1 && quality >= 68) return "HAND_FAST_HIGH_QUALITY";
        if (bigHandPotential >= 70) return "HAND_BIG_HAND_POTENTIAL";
        if (quality <= 35) return "HAND_WEAK_LOW_QUALITY";
        return "HAND_BALANCED";
    }
}

public sealed class SichuanLongTermEVPolicy
{
    public (SichuanScoreSituation Score, SichuanRiskTolerance Risk, SichuanRoundGoalContext Goal) Evaluate(SichuanStateView state)
    {
        var scores = state.Scores is { Length: >= 4 } ? state.Scores : new int[4];
        var selfScore = state.SeatIndex is >= 0 and < 4 ? scores[state.SeatIndex] : 0;
        var ordered = scores.Select((score, seat) => new { score, seat }).OrderByDescending(item => item.score).ToArray();
        var rank = Array.FindIndex(ordered, item => item.seat == state.SeatIndex) + 1;
        if (rank <= 0) rank = 1;
        var leaderScore = ordered.FirstOrDefault()?.score ?? selfScore;
        var gapToLeader = leaderScore - selfScore;
        var nextHigher = ordered.Where(item => item.score > selfScore).Select(item => item.score).DefaultIfEmpty(selfScore).Min();
        var gapToNext = Math.Max(0, nextHigher - selfScore);
        var remainingRounds = state.RemainingRounds > 0 ? state.RemainingRounds : Math.Max(0, state.TotalRounds - state.RoundIndex + 1);
        var finalStretch = remainingRounds is > 0 and <= 2;

        var behind = gapToLeader >= 12;
        var mustChase = behind && (finalStretch || gapToLeader >= 24);
        var situation = behind ? "behind" : rank == 1 && gapToLeader <= 0 && scores.Max() - scores.Min() >= 12 ? "leading" : "close";
        var risk = situation switch
        {
            "leading" when finalStretch => 32,
            "leading" => 40,
            "behind" when mustChase && finalStretch => 72,
            "behind" when mustChase => 64,
            "behind" => 56,
            _ => 52
        };
        var goal = situation == "leading"
            ? "protect_lead"
            : mustChase ? "chase_score" : "balanced_ev";
        return (
            new SichuanScoreSituation
            {
                SelfScore = selfScore,
                LeaderScore = leaderScore,
                Rank = rank,
                GapToLeader = gapToLeader,
                GapToNext = gapToNext,
                Situation = situation
            },
            new SichuanRiskTolerance
            {
                Value = risk,
                ReasonCode = situation switch
                {
                    "leading" => "RISK_LOW_PROTECT_LEAD",
                    "behind" when mustChase => "RISK_HIGH_CHASE_SCORE",
                    "behind" => "RISK_MODERATE_TRAILING_BALANCED",
                    _ => "RISK_BALANCED_CLOSE_SCORE"
                }
            },
            new SichuanRoundGoalContext
            {
                Goal = goal,
                ReasonCode = goal switch
                {
                    "protect_lead" => "ROUND_GOAL_PROTECT_LEAD",
                    "chase_score" => "ROUND_GOAL_CHASE_SCORE",
                    _ => "ROUND_GOAL_BALANCED_EV"
                }
            });
    }
}

public sealed class SichuanOpponentDangerEvaluator
{
    public IReadOnlyDictionary<int, SichuanOpponentDangerProfile> Evaluate(
        SichuanStateView state,
        SichuanBeliefSnapshot belief,
        SichuanStageContext stage)
    {
        var result = new Dictionary<int, SichuanOpponentDangerProfile>();
        for (var seat = 0; seat < 4; seat++)
        {
            if (seat == state.SeatIndex || state.HasHu[seat]) continue;
            var meldCount = state.Melds18[seat].Count / 3;
            var discardCount = state.Discards18[seat].Count;
            var readyPosterior = belief.SeatReadyPosterior.GetValueOrDefault(seat, 0.0);
            var bigHandRisk = EstimateBigHandRisk(state, seat);
            var danger = (int)Math.Round(
                readyPosterior * 45
                + meldCount * 12
                + (state.IsCalled[seat] || state.IsReady[seat] ? 30 : 0)
                + (stage.StageIndex >= 2 ? 10 : stage.StageIndex * 4)
                + bigHandRisk * 0.22
                + Math.Min(12, discardCount));
            var missingSuit = ResolveLikelyMissingSuit(state, seat);
            var reasonCodes = new List<string>();
            if (state.IsCalled[seat] || state.IsReady[seat]) reasonCodes.Add("OPPONENT_READY_DECLARED");
            if (readyPosterior >= 0.55) reasonCodes.Add("OPPONENT_LIKELY_READY_POSTERIOR");
            if (meldCount >= 2) reasonCodes.Add("OPPONENT_MANY_EXPOSED_MELDS");
            if (bigHandRisk >= 65) reasonCodes.Add("OPPONENT_BIG_HAND_RISK");
            if (stage.StageIndex >= 2) reasonCodes.Add("OPPONENT_LATE_STAGE_PRESSURE");
            result[seat] = new SichuanOpponentDangerProfile
            {
                Seat = seat,
                DangerLevel = Math.Clamp(danger, 0, 100),
                LikelyReady = state.IsCalled[seat] || state.IsReady[seat] || readyPosterior >= 0.55,
                LikelyMissingSuit = missingSuit,
                BigHandRisk = bigHandRisk,
                ExposedMeldCount = meldCount,
                DangerReasonCodes = reasonCodes.Count == 0 ? new[] { "OPPONENT_LOW_INFORMATION" } : reasonCodes
            };
        }
        return result;
    }

    private static int EstimateBigHandRisk(SichuanStateView state, int seat)
    {
        var melds = state.Melds18[seat];
        if (melds.Count == 0) return state.Discards18[seat].Count >= 8 ? 22 : 8;
        var suitCounts = new[] { 0, 0, 0 };
        foreach (var tile in melds)
            suitCounts[tile / 9]++;
        var sameSuitRatio = melds.Count == 0 ? 0.0 : (double)suitCounts.Max() / melds.Count;
        var pungLike = melds.Count / 3;
        return Math.Clamp((int)Math.Round(sameSuitRatio * 58 + pungLike * 12), 0, 100);
    }

    private static int ResolveLikelyMissingSuit(SichuanStateView state, int seat)
    {
        if (seat is >= 0 and < 4 && state.DingQueSuits[seat] is >= 0 and < 3)
            return state.DingQueSuits[seat];
        var discardSuitCounts = new[] { 0, 0, 0 };
        foreach (var tile in state.Discards18[seat])
            discardSuitCounts[tile / 9]++;
        var ordered = Enumerable.Range(0, 3)
            .OrderByDescending(suit => discardSuitCounts[suit])
            .ToArray();
        return discardSuitCounts[ordered[0]] >= discardSuitCounts[ordered[1]] + 3 ? ordered[0] : -1;
    }
}

public sealed class SichuanTileDangerEvaluator
{
    private readonly SichuanDangerEngine _danger = new();

    public IReadOnlyDictionary<int, SichuanTileDangerProfile> Evaluate(
        SichuanStateView state,
        SichuanBeliefSnapshot belief,
        IReadOnlyDictionary<int, SichuanOpponentDangerProfile> opponents,
        SichuanStageContext stage)
    {
        var result = new Dictionary<int, SichuanTileDangerProfile>();
        for (var tile = 0; tile < 27; tile++)
        {
            var global = _danger.EvaluateDetail(tile, state, belief);
            var byOpponent = new Dictionary<int, SichuanSeatTileDanger>();
            foreach (var (seat, profile) in opponents)
            {
                var score = EstimateSeatTileDanger(state, belief, seat, tile, profile, stage);
                byOpponent[seat] = new SichuanSeatTileDanger
                {
                    Seat = seat,
                    Score = score,
                    Level = ResolveLevel(score),
                    ReasonCodes = BuildTileReasonCodes(state, belief, seat, tile, score, stage)
                };
            }
            result[tile] = new SichuanTileDangerProfile
            {
                TileType = tile,
                MaxDangerScore = Math.Max(global.Risk, byOpponent.Values.Select(item => item.Score).DefaultIfEmpty(0).Max()),
                TopThreatSeat = global.TopThreatSeat,
                Level = ResolveLevel(global.Risk),
                ByOpponent = byOpponent,
                ReasonCodes = ConvertRiskReasons(global.Reasons, global.Risk, stage)
            };
        }
        return result;
    }

    private static int EstimateSeatTileDanger(
        SichuanStateView state,
        SichuanBeliefSnapshot belief,
        int seat,
        int tile,
        SichuanOpponentDangerProfile profile,
        SichuanStageContext stage)
    {
        var score = profile.DangerLevel * 0.48;
        var wait = belief.SeatTileWaitProbability.TryGetValue(seat, out var waitMap) ? waitMap.GetValueOrDefault(tile, 0.0) : 0.0;
        var hold = belief.SeatTileHoldProbability.TryGetValue(seat, out var holdMap) ? holdMap.GetValueOrDefault(tile, 0.0) : 0.0;
        score += wait * 38 + hold * 16;
        if (belief.SeatExactSafeTiles.TryGetValue(seat, out var safeTiles) && safeTiles.Contains(tile))
            score *= stage.StageIndex >= 2 ? 0.45 : 0.20;
        if (state.Visible18[tile] <= 0 && stage.StageIndex >= 2)
            score += 10;
        var suit = tile / 9;
        if (profile.LikelyMissingSuit == suit)
            score *= 0.64;
        return Math.Clamp((int)Math.Round(score), 0, 100);
    }

    private static IReadOnlyList<string> BuildTileReasonCodes(
        SichuanStateView state,
        SichuanBeliefSnapshot belief,
        int seat,
        int tile,
        int score,
        SichuanStageContext stage)
    {
        var reasons = new List<string>();
        if (belief.SeatExactSafeTiles.TryGetValue(seat, out var safeTiles) && safeTiles.Contains(tile))
            reasons.Add("SAFE_DISCARDED_BY_OPPONENT");
        if (state.Visible18[tile] <= 0 && stage.StageIndex >= 2)
            reasons.Add("HIGH_LIVE_TILE_LATE_STAGE");
        if (score >= 85) reasons.Add("EXTREME_READY_BIG_HAND_RISK");
        else if (score >= 65) reasons.Add("HIGH_OPPONENT_WAIT_RISK");
        if (reasons.Count == 0) reasons.Add(score <= 25 ? "LOW_TILE_DANGER" : "MEDIUM_TILE_DANGER");
        return reasons;
    }

    private static IReadOnlyList<string> ConvertRiskReasons(IReadOnlyList<string> reasons, int risk, SichuanStageContext stage)
    {
        var codes = new List<string>();
        if (risk <= 25) codes.Add("LOW_TILE_DANGER");
        if (risk >= 65 && stage.StageIndex >= 2) codes.Add("HIGH_LIVE_TILE_LATE_STAGE");
        if (reasons.Any(item => item.Contains("现物"))) codes.Add("SAFE_DISCARDED_BY_OPPONENT");
        if (reasons.Any(item => item.Contains("已报叫"))) codes.Add("HIGH_READY_OPPONENT_RISK");
        if (codes.Count == 0) codes.Add(risk >= 45 ? "MEDIUM_TILE_DANGER" : "LOW_TILE_DANGER");
        return codes.Distinct().ToArray();
    }

    public static string ResolveLevel(int score) => score switch
    {
        >= 85 => "extreme",
        >= 65 => "high",
        >= 42 => "medium",
        >= 22 => "low",
        _ => "safe"
    };
}

public sealed class SichuanAttackEligibilityEvaluator
{
    public SichuanAttackEligibility Evaluate(
        SichuanHandAnalysis hand,
        SichuanStageContext stage,
        IReadOnlyDictionary<int, SichuanOpponentDangerProfile> opponents,
        SichuanScoreSituation scoreSituation,
        SichuanRiskTolerance riskTolerance)
    {
        var maxOpponentDanger = opponents.Values.Select(item => item.DangerLevel).DefaultIfEmpty(0).Max();
        var score = hand.HandQuality + Math.Max(0, 2 - hand.Shanten) * 18 + hand.BigHandPotential / 4
            - maxOpponentDanger / 2 - stage.StageIndex * 7 + (riskTolerance.Value - 50) / 2;
        if (scoreSituation.Situation == "behind")
            score += 8;
        if (scoreSituation.Situation == "leading")
            score -= 8;

        if (stage.StageIndex >= 2 && maxOpponentDanger >= 72 && hand.Shanten >= 1)
            return Build("fold", "FOLD_LATE_DANGEROUS_OPPONENT", score);
        if (maxOpponentDanger >= 62 && hand.Shanten >= 2)
            return Build("defense", "DEFENSE_WEAK_HAND_DANGEROUS_OPPONENT", score);
        if (hand.Shanten <= 0 && maxOpponentDanger <= 62)
            return Build("strong_attack", "ATTACK_READY_HAND_ACCEPTABLE_RISK", score);
        if (hand.Shanten <= 1 && hand.HandQuality >= 60 && riskTolerance.Value >= 45)
            return Build("attack", "ATTACK_FAST_HAND_LOW_RISK", score);
        if (score <= 34)
            return Build("defense", "DEFENSE_LOW_ATTACK_SCORE", score);
        return Build("balanced", "ATTACK_BALANCED_BY_SCORE", score);
    }

    private static SichuanAttackEligibility Build(string level, string reasonCode, int score) => new()
    {
        Level = level,
        ReasonCode = reasonCode,
        Score = Math.Clamp(score, 0, 100)
    };
}

public sealed class SichuanStrategyModeStateMachine
{
    public SichuanStrategyModeContext Evaluate(
        string previousMode,
        SichuanRoundGoalContext roundGoal,
        SichuanAttackEligibility eligibility,
        SichuanStageContext stage,
        SichuanScoreSituation scoreSituation,
        IReadOnlyDictionary<int, SichuanOpponentDangerProfile> opponents)
    {
        var maxDanger = opponents.Values.Select(item => item.DangerLevel).DefaultIfEmpty(0).Max();
        var mode = eligibility.Level switch
        {
            "strong_attack" => "attack",
            "attack" => "attack",
            "defense" => "defense",
            "fold" => "fold",
            _ => "balanced"
        };
        var reason = "MODE_FROM_ATTACK_ELIGIBILITY";
        if (roundGoal.Goal == "chase_score" && eligibility.Level is not "fold")
        {
            mode = "chase";
            reason = "MODE_CHASE_BY_SCORE_SITUATION";
        }
        if (roundGoal.Goal == "protect_lead" && stage.StageIndex >= 1 && maxDanger >= 55 && eligibility.Level is not "strong_attack")
        {
            mode = "defense";
            reason = "MODE_DEFENSE_PROTECT_LEAD";
        }
        if (stage.StageIndex >= 2 && maxDanger >= 78 && eligibility.Level is not "strong_attack")
        {
            mode = "fold";
            reason = "MODE_FOLD_LATE_EXTREME_RISK";
        }
        return new SichuanStrategyModeContext
        {
            Mode = mode,
            PreviousMode = previousMode,
            Changed = !string.IsNullOrEmpty(previousMode) && previousMode != mode,
            ReasonCode = reason
        };
    }
}

public sealed class SichuanDealInPolicyEvaluator
{
    public SichuanDealInPolicy Evaluate(int tileType, SichuanAiContext context)
    {
        var danger = context.TileDangerMap.TryGetValue(tileType, out var profile) ? profile : null;
        var maxDanger = danger?.MaxDangerScore ?? 0;
        var topOpponent = danger is null || danger.TopThreatSeat < 0
            ? null
            : context.OpponentDangerProfiles.GetValueOrDefault(danger.TopThreatSeat);
        var bigHandRisk = topOpponent?.BigHandRisk ?? 0;
        var mode = context.StrategyMode.Mode;

        if (maxDanger >= 82 && bigHandRisk >= 65)
            return new SichuanDealInPolicy
            {
                TileType = tileType,
                AdjustmentScore = -900,
                BlockBigHandDealIn = true,
                ReasonCode = "DEAL_IN_BLOCK_BIG_HAND_HIGH_RISK"
            };
        if (maxDanger >= 72 && mode is "defense" or "fold")
            return new SichuanDealInPolicy
            {
                TileType = tileType,
                AdjustmentScore = -650,
                ReasonCode = "DEAL_IN_BLOCK_DEFENSE_HIGH_RISK"
            };
        if (maxDanger <= 38 && mode is "attack" or "chase")
            return new SichuanDealInPolicy
            {
                TileType = tileType,
                AdjustmentScore = 120,
                AllowSmallDealInRisk = true,
                ReasonCode = "DEAL_IN_ALLOW_SMALL_RISK_ATTACK"
            };
        return new SichuanDealInPolicy
        {
            TileType = tileType,
            AdjustmentScore = Math.Clamp(50 - maxDanger, -160, 80),
            ReasonCode = "DEAL_IN_COMPARE_RISK_EV"
        };
    }
}
