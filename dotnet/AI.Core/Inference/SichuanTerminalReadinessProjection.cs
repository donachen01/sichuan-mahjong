using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using System.Numerics;
using SichuanMahjong.AI.Core.Decision;

namespace SichuanMahjong.AI.Core.Inference;

public sealed record SichuanTerminalReadinessEstimate(bool Supported, double[] ReadyProbabilities,
    int Samples, double EffectiveSampleSize, string Reason)
{
    public int ConcreteOpponentDraws { get; init; }
    public int TailEstimates { get; init; }
}

/// <summary>
/// Projects development to wall exhaustion instead of treating today's
/// non-ready opponents as guaranteed future cha-jiao payers. This is a public
/// hypothesis model, not a calibrated probability: fixed active-seat turns,
/// forced missing-suit discards, minimum distance then live progress, no claims
/// or exits. The blood-battle value model separately handles opponent exits.
/// </summary>
public sealed class SichuanTerminalReadinessProjection
{
    public SichuanTerminalReadinessEstimate Evaluate(SichuanStateView state,
        SichuanBeliefSnapshot belief, int samples = 32, int seed = 20261011)
    {
        using var timing = SichuanMahjong.AI.Core.Decision.SichuanPolicyTiming.Measure("terminal_readiness");
        bool fast = SichuanSearchBudget.FastTerminal;
        if (fast) samples = Math.Min(samples, 8);
        var ready=Enumerable.Range(0,4).Select(s=>belief.SeatReadyPosterior.GetValueOrDefault(s)).ToArray();
        var value=SichuanPolicyExecutionScope.Memoize(
            $"terminal-readiness/{SichuanDecisionCommand.Fingerprint(state)}/{samples}/{seed}/{fast}",
            (ready[0],ready[1],ready[2],ready[3]),()=>EvaluateCore(state,belief,samples,seed,fast));
        // Keep the public result independently owned even when the underlying
        // exact-input calculation is reused within this decision.
        return value with { ReadyProbabilities=value.ReadyProbabilities.ToArray() };
    }

    private SichuanTerminalReadinessEstimate EvaluateCore(SichuanStateView state,
        SichuanBeliefSnapshot belief,int samples,int seed,bool fast)
    {
        using var timing=SichuanPolicyTiming.Measure("terminal_readiness_compute");
        var baseline = Enumerable.Range(0, 4).Select(s =>
            Math.Clamp(belief.SeatReadyPosterior.GetValueOrDefault(s), 0, 1)).ToArray();
        if (state.WallCount == 0) return new(true, baseline, 0, 0, "TERMINAL_READINESS_CURRENT_AT_EXHAUSTION");
        var seats = Enumerable.Range(0, 4).Where(s => state.ActiveSeats[s] && !state.HasHu[s]).ToArray();
        if (state.SeatIndex is < 0 or > 3 || state.CurrentSeat != state.SeatIndex
            || !seats.Contains(state.SeatIndex) || seats.Length < 2
            || state.HandCounts[state.SeatIndex] != state.Hand18.Sum()
            || state.Remaining18.Sum() != state.WallCount + Enumerable.Range(0, 4)
                .Where(s => s != state.SeatIndex).Sum(s => state.HandCounts[s])
            || Enumerable.Range(0, 27).Any(t => state.Hand18[t] + state.Visible18[t] + state.Remaining18[t] != 4)
            || seats.Any(s => s != state.SeatIndex && state.HandCounts[s] + state.MeldCount(s) * 3 != 13))
            return new(false, baseline, 0, 0, "TERMINAL_READINESS_INCOMPLETE_PUBLIC_STATE");

        var particles = new SichuanHiddenHandInferenceEngine().SampleParticles(state, samples,
            seed, SichuanHiddenHandProposal.PublicPriorThenLikelihood, minimumParticleCount: fast ? 8 : 32);
        if (particles.Count == 0 || particles.Any(p => p.Wall27.Sum() != state.WallCount))
            return new(false, baseline, 0, 0, "TERMINAL_READINESS_INVALID_PUBLIC_ALLOCATION");
        var order = SichuanHiddenHandInferenceEngine.CanonicalPublicTileOrder(state);
        // This is the same exact structural distance, including seven-pairs
        // and physical four-copy constraints. Use its shared mathematical cache
        // while updating only the tile changed in each hypothetical step.
        var before = new double[4]; var after = new double[4];
        var seatOrder = Enumerable.Range(1, 4).Select(n => (state.SeatIndex + n) % 4)
            .Where(seats.Contains).ToArray();
        var random = new Random(seed);
        var discardDistances = new int[27];
        var drawCopies = new int[27];
        int concreteDraws = 0, tails = 0;
        foreach (var particle in particles)
        {
            var wall = order.SelectMany(t => Enumerable.Repeat(t, particle.Wall27[t])).ToArray();
            for (var i = wall.Length - 1; i > 0; i--)
            { var j = random.Next(i + 1); (wall[i], wall[j]) = (wall[j], wall[i]); }
            var hands = particle.Hands27.Select(h => h.ToArray()).ToArray();
            var cursors=Enumerable.Range(0,4).Select(s=>new SichuanHandDistanceCursor(hands[s],state.MeldCount(s))).ToArray();
            var seen = state.Visible18.ToArray();
            bool Ready(int s) => !Enumerable.Range(0, 27).Any(t => t / 9 == state.DingQueSuits[s] && hands[s][t] > 0)
                && cursors[s].Best() == 0;
            foreach (var s in seats.Where(s => s != state.SeatIndex))
                if (Ready(s)) before[s] += particle.Weight;
            // Ordinary forecasts explicitly play at most one active-seat round.
            // Their remaining development is priced below, never discarded.
            int limit = fast ? Math.Min(wall.Length, seatOrder.Length) : wall.Length;
            for (var turn = 0; turn < limit; turn++)
            {
                var s = seatOrder[turn % seatOrder.Length];
                // The observer's later policy is not invented here. Its draw
                // still consumes a physical wall position in the fixed schedule.
                if (s == state.SeatIndex) continue;
                concreteDraws++;
                var h = hands[s];var cursor=cursors[s];cursor.Change(wall[turn],1);
                var missing = state.DingQueSuits[s];
                var mustClear = order.Any(t => t / 9 == missing && h[t] > 0);
                var bestTile = -1; var bestDistance = 99; var bestLive = -1;
                Array.Fill(discardDistances,99);
                // For candidate discard d, afterHand[t]=drawnHand[t]-[t=d].
                // Hence 4-afterHand[t]-seen[t]-[t=d] is simply
                // 4-drawnHand[t]-seen[t], independent of the candidate.
                // The discarded tile remains public, never new wall supply.
                uint allowed=0;
                foreach(var draw in order)
                {
                    int copies=draw/9==missing?0:Math.Max(0,4-h[draw]-seen[draw]);
                    drawCopies[draw]=copies;
                    if(copies>0)allowed|=1u<<draw;
                }
                // The forecast's existing rule is lexicographic: minimum
                // distance, then maximum live supply, then the original tile
                // order. A worse-distance discard can never win, so identify
                // the minimum before enumerating its possible future draws.
                foreach (var discard in order)
                {
                    if (h[discard] == 0 || mustClear && discard / 9 != missing) continue;
                    cursor.Change(discard,-1);
                    var d = cursor.Best();
                    cursor.Change(discard,1);
                    discardDistances[discard]=d;bestDistance=Math.Min(bestDistance,d);
                }
                foreach(var discard in order)
                {
                    if(discardDistances[discard]!=bestDistance)continue;
                    cursor.Change(discard,-1);var live=0;
                    uint improving=cursor.ImprovingDrawMask(allowed);
                    // Only structural membership is reused. Public supply is
                    // still priced from this hypothesis and current discard.
                    for(uint bits=improving;bits!=0;bits&=bits-1)
                        live+=drawCopies[BitOperations.TrailingZeroCount(bits)];
                    cursor.Change(discard,1);
                    if(live>bestLive){bestTile=discard;bestLive=live;}
                }
                cursor.Change(bestTile,-1); seen[bestTile]++;
            }
            foreach (var s in seats.Where(s => s != state.SeatIndex))
            {
                double probability = Ready(s) ? 1 : 0;
                if (fast && probability == 0 && limit < wall.Length)
                {
                    tails++;
                    int draws = Enumerable.Range(limit, wall.Length - limit)
                        .Count(turn => seatOrder[turn % seatOrder.Length] == s);
                    // Fixed progress-set approximation: count required structural
                    // improvements using the actual remaining particle supply.
                    // Later changes in shape/claims/exits are not modelled here.
                    var clean = hands[s].ToArray();
                    int missing = state.DingQueSuits[s];
                    int missingCount = missing is >= 0 and < 3 ? clean.Skip(missing * 9).Take(9).Sum() : 0;
                    if (missing is >= 0 and < 3) Array.Clear(clean, missing * 9, 9);
                    var tailCursor = new SichuanHandDistanceCursor(clean, state.MeldCount(s));
                    int steps = Math.Max(missingCount, Math.Max(0, tailCursor.Best()));
                    uint allowed = 0;
                    for (int tile = 0; tile < 27; tile++)
                        if (tile / 9 != missing && clean[tile] < 4) allowed |= 1u << tile;
                    uint progress = tailCursor.ImprovingDrawMask(allowed);
                    int useful = wall.Skip(limit).Count(tile => (progress & (1u << tile)) != 0);
                    probability = FixedProgressProbability(wall.Length - limit, useful, draws, steps);
                }
                after[s] += probability * particle.Weight;
            }
        }
        // Keep the existing current-readiness estimate; apply only the sampled
        // conditional transition from non-ready to ready during the remaining
        // draws. No generated opponent hand is presented as an observed hand.
        var projected = baseline.ToArray();
        foreach (var s in seats.Where(s => s != state.SeatIndex))
        {
            var progress = before[s] >= 1 - 1e-9 ? 0
                : Math.Clamp((after[s] - before[s]) / (1 - before[s]), 0, 1);
            projected[s] += (1 - projected[s]) * progress;
        }
        return new(true, projected, particles.Count,
            1 / particles.Sum(p => p.Weight * p.Weight), fast
                ? "TERMINAL_READINESS_ONE_ROUND_FIXED_PROGRESS_TAIL"
                : "TERMINAL_READINESS_PUBLIC_DEVELOPMENT_MODEL")
            { ConcreteOpponentDraws = concreteDraws, TailEstimates = tails };
    }
    /// <summary>Without-replacement probability of at least required useful
    /// draws from a fixed progress set. Exact for that simplified model only.</summary>
    public static double FixedProgressProbability(int population, int useful, int draws, int required)
    {
        if (required <= 0) return 1;
        useful = Math.Clamp(useful, 0, Math.Max(0, population));
        draws = Math.Clamp(draws, 0, Math.Max(0, population));
        if (required > draws || required > useful || population <= 0) return 0;
        var mass = new double[draws + 1]; mass[0] = 1;
        for (int n = 0; n < draws; n++)
        {
            var next = new double[draws + 1];
            for (int successes = 0; successes <= n; successes++)
            {
                if (mass[successes] == 0) continue;
                double p = Math.Clamp((useful - successes) / (double)(population - n), 0, 1);
                next[successes + 1] += mass[successes] * p;
                next[successes] += mass[successes] * (1 - p);
            }
            mass = next;
        }
        return Math.Clamp(mass.Skip(required).Sum(), 0, 1);
    }

}
