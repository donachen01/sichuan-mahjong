using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

internal sealed class SichuanCriticalContinuationSelector
{
    private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, long> Counts = new();
    internal static IReadOnlyDictionary<string, long> Diagnostics() => new Dictionary<string, long>(Counts);
    private static (int Tile, string Reason)? Reject(string reason)
    {
        Counts.AddOrUpdate(reason, 1, (_, count) => count + 1);
        return null;
    }
    private readonly SichuanPublicEndgameEvaluator _evaluator = new();

    public (int Tile, string Reason)? Select(SichuanStateView state,
        IReadOnlyList<SichuanCandidateDetail> candidates, int incumbent)
    {
        var maximumWall = Strategy.SichuanSingleLaneEvaluator.ResolveSuit(state) >= 0 ? 20 : 12;
        if (state.InformationMode != "public" || state.WallCount < 1 || state.WallCount > maximumWall
            || candidates.Count < 2 || incumbent < 0) return Reject("outside_scope");
        var reference = candidates.First(c => c.TileType == incumbent);
        var choices = candidates.Where(c => c.Shanten <= reference.Shanten + 1)
            .OrderByDescending(c => c.UnifiedActionValue).Select(c => c.TileType)
            .Prepend(incumbent).Distinct().Take(3).ToArray();
        if (choices.Length < 2) return Reject("one_candidate");
        // Candidate selection and confirmation use disjoint particle seeds.
        // Both compare paired outcomes against the same incumbent and account
        // for the effective sample size, not just the requested sample count.
        var discovery = _evaluator.AnalyzeContinuation(state, choices, maximumWall, 32,
            20260928 ^ state.RoundIndex ^ state.TurnIndex, includeUnready: true);
        if (discovery.EffectiveSampleSize < 16) return Reject("discovery_" + discovery.Status);
        var contender = discovery.Comparisons.Where(c => c.TileType != incumbent)
            .OrderByDescending(c => c.MeanNetDifference).FirstOrDefault();
        if (contender is null || contender.MeanNetDifference <= Math.Max(0.25, 2.4*contender.StandardError)) return Reject("discovery_no_advantage");
        var confirmation = _evaluator.AnalyzeContinuation(state, new[] {incumbent, contender.TileType}, maximumWall, 48,
            7919 ^ state.RoundIndex ^ state.TurnIndex, includeUnready: true);
        var paired = confirmation.Comparisons.FirstOrDefault(c => c.TileType == contender.TileType);
        if (confirmation.EffectiveSampleSize < 24 || paired is null
            || paired.MeanNetDifference <= Math.Max(0.25, 2.4*paired.StandardError)) return Reject("confirmation_no_advantage");
        Counts.AddOrUpdate("selected", 1, (_, count) => count + 1);
        return (contender.TileType,
            $"PUBLIC_BLOOD_BATTLE_SELECTION 净分差 {paired.MeanNetDifference:F2}，标准误 {paired.StandardError:F2}，有效样本 {confirmation.EffectiveSampleSize:F1}；模拟进张、碰杠、血战和查叫");
    }
}
