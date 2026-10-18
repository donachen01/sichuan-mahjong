using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanHuContinuationEstimate(
    SichuanActionType Action, double NetScore, double DifferenceFromHu, double DifferenceStandardError,
    double WinGain, double GangNet, double DrawSettlement, double DealInLoss, double OpponentLoss,
    double WinProbability, double SelfDrawProbability, double ExpectedSelfDrawPayers,
    double ExpectedOwnDraws, double ExpectedLockedRonDenied)
{
    public double ExpectedStrategicRefusals { get; init; }
    public int RefusalDiscardTile { get; init; } = -1;
}

public sealed record SichuanHuContinuationReport(
    IReadOnlyList<SichuanHuContinuationEstimate> Candidates, int Samples, double EffectiveSampleSize,
    int Seed, string Status)
{
    public string ContinuationPolicy => SichuanPolicyExecutionScope.PolicyDescription;
}

public sealed partial class SichuanPublicEndgameEvaluator
{
    internal sealed record HuReactionRoot(int Tile, int SourceSeat, SichuanWinType WinType,
        SichuanActionType Action, int PengDiscard, SichuanMeldType GangType, int GangSource,
        int[] GangPayers, int[] PriorWinners, bool GangScoreEligible = true);

    // Both actions run through the same complete wall and actual terminal
    // settlement. Hu includes later settlement under the frozen rules. No hidden runtime hand,
    // readiness flag, wall order or opponent private lock enters this model.
    public SichuanHuContinuationReport AnalyzeHuContinuation(SichuanStateView state,
        int tile, int sourceSeat, string reactionType = "discard", int samples = 128,
        int seed = 20261002, int pengDiscard = -1, bool canGang = false)
    {
        SichuanPolicyExecutionScope.RequireResearchContext();
        SichuanHuContinuationReport Empty(string reason) => new([], 0, 0, seed, reason);
        if (tile is < 0 or > 26) return Empty("invalid_reaction_tile");
        var rob = reactionType == "qiang_gang_hu";
        if (!SichuanPublicInferenceBoundary.TryProject(state, out var projection, out var reason,
            reaction: true, sourceSeat: sourceSeat, robGang: rob)) return Empty(reason);
        var root = PrepareReactionRoot(state, tile, sourceSeat, reactionType);
        if (root is null) return Empty("reaction_context_incomplete");
        var complete = (int[])state.Hand18.Clone(); complete[tile]++;
        var ownMelds = Melds(state, state.SeatIndex);
        if (complete[tile] > 4 || !_hands.IsWinning(complete, ownMelds.Count)
            || HasMissing(complete, state.OwnDingQueSuit)) return Empty("offered_hu_not_legal");
        var offeredFan = _fans.Project(complete, ownMelds, root.WinType);
        if (state.LockedFans[state.SeatIndex] >= offeredFan.CappedFan)
            return Empty("offered_hu_locked");
        // Only our own private rule lock is observable. Other seats' private
        // pass choices must not change particles or the seed.
        projection.LockedFans[state.SeatIndex] = state.LockedFans[state.SeatIndex];
        projection.UnlockOnOwnDraw[state.SeatIndex] = true;
        if (rob && state.HandCounts[sourceSeat] == 14 - 3 * Melds(state, sourceSeat).Count)
        {
            // The publicly offered fourth tile is still physically in the
            // actor's hand. Reserve it before sampling rather than rejection
            // sampling or allowing it to appear in the future wall.
            if (projection.Remaining18[tile] <= 0) return Empty("rob_tile_not_available");
            projection.Remaining18[tile]--;
            projection.Visible18[tile]++;
            projection.HandCounts[sourceSeat]--;
        }
        var actions = new List<SichuanActionType> { SichuanActionType.Hu, SichuanActionType.Pass };
        if (!rob && root.PriorWinners.Length == 0 && pengDiscard is >= 0 and < 27
            && state.Hand18[tile] >= 2 && state.Hand18[pengDiscard] - (pengDiscard == tile ? 2 : 0) > 0)
            actions.Add(SichuanActionType.Peng);
        if (!rob && root.PriorWinners.Length == 0 && canGang && state.Hand18[tile] >= 3 && state.WallCount > 0)
            actions.Add(SichuanActionType.Gang);
        samples = Math.Clamp(samples, 32, 512);
        var particles = _inference.SampleParticles(projection, samples, seed,
            SichuanHiddenHandProposal.PublicPriorThenLikelihood);
        if (particles.Count != samples || particles.Any(p => !SichuanPublicInferenceBoundary.ParticleConserves(projection, p)))
            return Empty("particle_conservation_failed");
        var total = particles.Sum(p => p.Weight);
        if (!(total > 0)) return Empty("zero_particle_weight");
        var ess = 1.0 / particles.Sum(p => Math.Pow(p.Weight / total, 2));
        SichuanPublicInferenceBoundary.RestorePolicyHistory(state,projection);
        var outcomes = actions.ToDictionary(a => a, _ => new List<(SimulationOutcome Value, double Weight, double Delta)>());
        // Independent worlds; each worker owns engines, caches and seat plans.
        // Aggregate in sample-index order so scheduling cannot affect results.
        var sampled = new SimulationOutcome[particles.Count][];
        Parallel.For(0, particles.Count, new ParallelOptions { MaxDegreeOfParallelism = Math.Min(4, Environment.ProcessorCount) }, i =>
        {
            using var beliefCache = Engines.SichuanBeliefEngine.UseCache(new Engines.SichuanBeliefEngine.ScopedCache());
            var evaluator = new SichuanPublicEndgameEvaluator();
            var particle = particles[i];
            var wall = ShuffledWall(particle, seed ^ projection.RoundIndex ^ i * 7919, SichuanHiddenHandInferenceEngine.CanonicalPublicTileOrder(projection));
            sampled[i] = actions.Select(action => evaluator.Simulate(projection, particle, wall, -1,
                reaction: root with { Action = action, PengDiscard = pengDiscard })).ToArray();
        });
        for (var i = 0; i < particles.Count; i++)
        {
            var hu = sampled[i][0].NetScore;
            for (var a = 0; a < actions.Count; a++)
            {
                var result = sampled[i][a];
                outcomes[actions[a]].Add((result, particles[i].Weight / total, result.NetScore - hu));
            }
        }
        var estimates = actions.Select(action =>
        {
            var rows = outcomes[action];
            double Mean(Func<SimulationOutcome,double> value) => rows.Sum(r => value(r.Value) * r.Weight);
            var delta = rows.Sum(r => r.Delta * r.Weight);
            var variance = rows.Sum(r => r.Weight * Math.Pow(r.Delta - delta, 2));
            return new SichuanHuContinuationEstimate(action, Mean(r => r.NetScore), delta,
                Math.Sqrt(variance / Math.Max(1, ess - 1)), Mean(r => r.WinGain), Mean(r => r.GangNet),
                Mean(r => r.DrawSettlement), Mean(r => r.DealInLoss), Mean(r => r.OpponentLoss),
                Mean(r => r.OwnWon ? 1 : 0), Mean(r => r.OwnSelfDraw ? 1 : 0),
                Mean(r => r.SelfDrawPayers), Mean(r => r.OwnDraws), Mean(r => r.LockedRonDenied))
            { ExpectedStrategicRefusals = Mean(r=>r.OwnStrategicRefusals) };
        }).ToArray();
        return new(estimates, samples, ess, seed, "complete_public_continuation");
    }

    internal static HuReactionRoot? PrepareReactionRoot(SichuanStateView state, int tile, int source, string reactionType)
    {
        if (source is < 0 or > 3 || source == state.SeatIndex) return null;
        var events = state.PublicEvents.ToArray();
        var rob = reactionType == "qiang_gang_hu";
        var discardIndex = Array.FindLastIndex(events, e => e.Type == SichuanPublicEventType.Discard
            && e.Seat == source && e.TileType == tile);
        if (!rob && discardIndex < 0) return null;
        var preceding = !rob ? events.Take(discardIndex).LastOrDefault(e => e.Type is not SichuanPublicEventType.Draw and not SichuanPublicEventType.Pass) : null;
        var gangDiscard = !rob && (reactionType == "gang_discard" || preceding?.Seat == source && preceding.Type is
            SichuanPublicEventType.MeldedGang or SichuanPublicEventType.ConcealedGang or SichuanPublicEventType.AddedGang);
        var gang = gangDiscard ? events.Take(discardIndex).LastOrDefault(e => e.Seat == source && e.Type is
            SichuanPublicEventType.MeldedGang or SichuanPublicEventType.ConcealedGang or SichuanPublicEventType.AddedGang) : null;
        if (gangDiscard && gang is null) return null;
        if (rob && !Melds(state, source).Any(m => m.Type == SichuanMeldType.Peng && m.TileType == tile)) return null;
        if (rob && state.WallCount == 0) return null;
        if (rob && state.PendingAddedGangScoreEligible is null) return null;
        var prior = rob
            ? events.Reverse().TakeWhile(e => e.Type is SichuanPublicEventType.Hu or SichuanPublicEventType.Pass)
                .Where(e => e.Type == SichuanPublicEventType.Hu && e.SourceSeat == source && e.TileType == tile).Select(e => e.Seat).Distinct().ToArray()
            : events.Skip(discardIndex + 1).Where(e => e.Type == SichuanPublicEventType.Hu && e.SourceSeat == source && e.TileType == tile)
                .Select(e => e.Seat).Distinct().ToArray();
        if (rob && state.HandCounts[source] == 13 - 3 * Melds(state, source).Count && prior.Length == 0) return null;
        var exitedBeforeGang = gang is null ? new HashSet<int>() : events.Where(e => e.EventIndex < gang.EventIndex && e.Type == SichuanPublicEventType.Hu).Select(e => e.Seat).ToHashSet();
        var gangPayers = gang is null ? Array.Empty<int>() : Enumerable.Range(0,4).Where(s => s != source && !exitedBeforeGang.Contains(s)).ToArray();
        return new(tile, source, rob ? SichuanWinType.RobAddedGang : gangDiscard ? SichuanWinType.GangDiscard : SichuanWinType.Discard,
            SichuanActionType.Hu, -1, gang?.Type == SichuanPublicEventType.MeldedGang ? SichuanMeldType.MeldedGang
                : gang?.Type == SichuanPublicEventType.ConcealedGang ? SichuanMeldType.ConcealedGang : SichuanMeldType.AddedGang,
            gang?.SourceSeat ?? -1, gangPayers, prior,
            rob ? state.PendingAddedGangScoreEligible!.Value : gang?.GangScoreEligible ?? true);
    }
}
