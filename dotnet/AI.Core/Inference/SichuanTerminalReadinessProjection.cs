using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Inference;

public sealed record SichuanTerminalReadinessEstimate(bool Supported, double[] ReadyProbabilities,
    int Samples, double EffectiveSampleSize, string Reason);

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
            seed, SichuanHiddenHandProposal.PublicPriorThenLikelihood);
        if (particles.Count == 0 || particles.Any(p => p.Wall27.Sum() != state.WallCount))
            return new(false, baseline, 0, 0, "TERMINAL_READINESS_INVALID_PUBLIC_ALLOCATION");
        var order = SichuanHiddenHandInferenceEngine.CanonicalPublicTileOrder(state);
        var distance = new SichuanStructuralDistance();
        var before = new double[4]; var after = new double[4];
        var seatOrder = Enumerable.Range(1, 4).Select(n => (state.SeatIndex + n) % 4)
            .Where(seats.Contains).ToArray();
        var random = new Random(seed);
        foreach (var particle in particles)
        {
            var wall = order.SelectMany(t => Enumerable.Repeat(t, particle.Wall27[t])).ToArray();
            for (var i = wall.Length - 1; i > 0; i--)
            { var j = random.Next(i + 1); (wall[i], wall[j]) = (wall[j], wall[i]); }
            var hands = particle.Hands27.Select(h => h.ToArray()).ToArray();
            var seen = state.Visible18.ToArray();
            bool Ready(int s) => !Enumerable.Range(0, 27).Any(t => t / 9 == state.DingQueSuits[s] && hands[s][t] > 0)
                && distance.Best(hands[s], state.MeldCount(s)) == 0;
            foreach (var s in seats.Where(s => s != state.SeatIndex))
                if (Ready(s)) before[s] += particle.Weight;
            for (var turn = 0; turn < wall.Length; turn++)
            {
                var s = seatOrder[turn % seatOrder.Length];
                // The observer's later policy is not invented here. Its draw
                // still consumes a physical wall position in the fixed schedule.
                if (s == state.SeatIndex) continue;
                var h = hands[s]; h[wall[turn]]++;
                var missing = state.DingQueSuits[s]; var melds = state.MeldCount(s);
                var mustClear = order.Any(t => t / 9 == missing && h[t] > 0);
                var bestTile = -1; var bestDistance = 99; var bestLive = -1;
                foreach (var discard in order)
                {
                    if (h[discard] == 0 || mustClear && discard / 9 != missing) continue;
                    h[discard]--;
                    var d = distance.Best(h, melds); var live = 0;
                    if (d <= bestDistance)
                        foreach (var draw in order)
                        {
                            if (draw / 9 == missing || h[draw] == 4) continue;
                            var copies = Math.Max(0, 4 - h[draw] - seen[draw] - (draw == discard ? 1 : 0));
                            if (copies == 0) continue;
                            h[draw]++;
                            if (distance.Best(h, melds) < d) live += copies;
                            h[draw]--;
                        }
                    h[discard]++;
                    if (d < bestDistance || d == bestDistance && live > bestLive)
                    { bestTile = discard; bestDistance = d; bestLive = live; }
                }
                h[bestTile]--; seen[bestTile]++;
            }
            foreach (var s in seats.Where(s => s != state.SeatIndex))
                if (Ready(s)) after[s] += particle.Weight;
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
            1 / particles.Sum(p => p.Weight * p.Weight), "TERMINAL_READINESS_PUBLIC_DEVELOPMENT_MODEL");
    }
}
