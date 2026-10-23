using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Strategy;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanHuWaitingEstimate(bool Supported, string Status,
    int Samples, double EffectiveSampleSize, int UnseenWaitCopies,
    double ExpectedWallWaitCopies, int ScheduledOwnDraws,
    double SelfDrawOpportunity, double SelfDrawProbability, double SelfDrawGain,
    double OpponentSelfDrawLoss, double DealInLoss, double GangPaymentLoss,
    double SelfDrawPayerMass)
{
    public double WaitingLoss => OpponentSelfDrawLoss + DealInLoss + GangPaymentLoss;
    public double LocalNet => SelfDrawGain - WaitingLoss;
    public double ConditionalSelfDrawPayers => SelfDrawProbability > 0
        ? SelfDrawPayerMass / SelfDrawProbability : 0;
}

/// <summary>
/// Local finite-wall opportunity/cost model, NOT a terminal policy rollout.
/// Public allocations are integrated, never taken from the actual hidden wall.
/// Own hand is held ready, misses are discarded; opponent hazards retain their
/// current waits, plus a measured one-draw transition into readiness. The draw
/// schedule excludes future claims/replacements and newly freed exit turns.
/// Marginal opponent survival prices exits and losses together. These declared
/// approximations are not a calibrated whole-game probability or terminal EV.
/// </summary>
public sealed class SichuanHuWaitingModel
{
    private readonly SichuanExactHandAnalyzer _hands = new();
    private readonly SichuanFanProjectionEngine _fans = new();
    private readonly Engines.SichuanShantenEngine _shanten = new();
    internal static double GangDiscardPrice(double score) => SichuanRuleSnapshot.Frozen.FanCap>0
        ? Math.Min(SichuanRuleSnapshot.Frozen.BaseScore*Math.Pow(2,SichuanRuleSnapshot.Frozen.FanCap),2*score):2*score;

    internal static IReadOnlyList<SichuanHiddenHandParticle> SharedPublicParticles(SichuanStateView s)
        => SichuanPolicyExecutionScope.Memoize("hu_public_posterior",SichuanDecisionCommand.Fingerprint(s),
            ()=>new SichuanHiddenHandInferenceEngine().SampleParticles(s,32,20261017,
                SichuanHiddenHandProposal.PublicPriorThenLikelihood));

    public SichuanHuWaitingEstimate Estimate(SichuanStateView state)
    {
        SichuanHuWaitingEstimate Empty(string why) => new(false, why, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        if (!SichuanPublicInferenceBoundary.TryProject(state, out var s, out var reason,
            reaction: true, sourceSeat: state.CurrentSeat)) return Empty(reason);
        var prices = new SichuanReadyWaitPricing().Build(s, s.Hand18,
            s.Remaining18.Select(n => (double)n).ToArray());
        if (prices is null) return Empty("not_a_legal_ready_hand");
        // No private flags, pass matrices, hidden draws or runtime-only version
        // counter participates in this seed or in the projected allocations.
        var particles = SharedPublicParticles(s);
        if (particles.Count != 32 || particles.Any(p => !SichuanPublicInferenceBoundary.ParticleConserves(s, p)))
            return Empty("waiting_model_conservation_failed");
        var total = particles.Sum(p => p.Weight);
        if (!(total > 0)) return Empty("waiting_model_zero_weight");
        var rows = particles.Select(p => (Value: AssessAllocation(s, p, prices), Weight: p.Weight / total)).ToArray();
        double Mean(Func<SichuanHuWaitingEstimate, double> f) => rows.Sum(r => r.Weight * f(r.Value));
        return new(true, "public_finite_wall_local_waiting_model_v1", rows.Length,
            1 / rows.Sum(r => r.Weight * r.Weight), prices.Waits.Sum(w => s.Remaining18[w.TileType]),
            Mean(r => r.ExpectedWallWaitCopies), rows[0].Value.ScheduledOwnDraws,
            Mean(r => r.SelfDrawOpportunity), Mean(r => r.SelfDrawProbability), Mean(r => r.SelfDrawGain),
            Mean(r => r.OpponentSelfDrawLoss), Mean(r => r.DealInLoss), Mean(r => r.GangPaymentLoss),
            Mean(r => r.SelfDrawPayerMass));
    }

    internal sealed record SeatHazard(double[] RonPrice, double[] SelfPrice,
        double ReadyTransition, double[] DevelopedRonPrice, double[] DevelopedSelfPrice,
        double[] DrawGangPrice, double[] DiscardGangPrice)
    {
        public double[] DevelopedRonChance { get; init; } = new double[27];
        public double[] DevelopedSelfChance { get; init; } = new double[27];
        public double[] DevelopedGangDiscardPrice { get; init; } = new double[27];
    }

    internal SeatHazard Hazard(SichuanStateView s, SichuanHiddenHandParticle p, int seat)
        => SichuanPolicyExecutionScope.Memoize("hu_public_seat_hazard",
            (p,seat,s.DingQueSuits[seat],string.Join("/",SichuanDevelopmentPolicy.Melds(s,seat).Select(m=>$"{m.Type}:{m.TileType}"))),
            ()=>BuildHazard(s,p,seat));

    private SeatHazard BuildHazard(SichuanStateView s,SichuanHiddenHandParticle p,int seat)
    {
        var hand = p.Hands27[seat];
        var melds = SichuanDevelopmentPolicy.Melds(s, seat);
        var missing = s.DingQueSuits[seat];
        var ron = new double[27]; var self = new double[27];
        var developedRon = new double[27]; var developedSelf = new double[27];
        var developedRonChance = new double[27]; var developedSelfChance = new double[27];
        var developedGangRon = new double[27];
        var drawGang = new double[27]; var discardGang = new double[27];
        var wall = p.Wall27; var size = wall.Sum();
        bool LegalReady(int[] h, IReadOnlyList<SichuanMeldView> m) =>
            !h.Skip(missing * 9).Take(9).Any(n => n > 0)
            && Enumerable.Range(0, 27).Any(t => t / 9 != missing && h[t]
                + m.Where(g => g.TileType == t).Sum(g => g.Type == SichuanMeldType.Peng ? 3 : 4) < 4
                && Wins(h, m.Count, t));
        bool ready = LegalReady(hand, melds);
        FillPrices(hand, melds, missing, ron, self);

        // Measure a concrete one-draw path into tenpai, not a per-round penalty
        // or a guessed readiness growth coefficient. Further rebuilding and
        // future claims are deliberately outside this bounded model.
        double transition = 0;
        if (!ready && size > 1 && _shanten.CalcBestShanten(hand, melds.Count) <= 1)
        {
            for (int draw = 0; draw < 27; draw++)
            {
                if (wall[draw] <= 0 || hand[draw] >= 4) continue;
                var h = (int[])hand.Clone(); h[draw]++;
                var mustClear = h.Skip(missing * 9).Take(9).Any(n => n > 0);
                double best = 0; double[]? bestRon = null, bestSelf = null;
                for (int discard = 0; discard < 27; discard++)
                {
                    if (h[discard] == 0 || mustClear && discard / 9 != missing) continue;
                    h[discard]--;
                    if (_shanten.CalcBestShanten(h, melds.Count) == 0 && LegalReady(h, melds))
                    {
                        var r = new double[27]; var z = new double[27];
                        FillPrices(h, melds, missing, r, z);
                        double value = Enumerable.Range(0, 27).Sum(t => (wall[t] - (t == draw ? 1 : 0)) * z[t]);
                        if (value > best) { best = value; bestRon = r; bestSelf = z; }
                    }
                    h[discard]++;
                }
                if (bestRon is null) continue;
                double weight = wall[draw] / (double)size;
                transition += weight;
                for (int t = 0; t < 27; t++)
                {
                    developedRon[t] += weight * bestRon[t];
                    developedGangRon[t] += weight * GangDiscardPrice(bestRon[t]);
                    developedSelf[t] += weight * bestSelf![t];
                    if (bestRon[t] > 0) developedRonChance[t] += weight;
                    if (bestSelf[t] > 0) developedSelfChance[t] += weight;
                }
            }
            if (transition > 0) for (int t = 0; t < 27; t++)
            {
                developedRon[t] /= transition; developedSelf[t] /= transition;
                developedGangRon[t] /= transition;
                developedRonChance[t] /= transition; developedSelfChance[t] /= transition;
            }
        }
        // Price only ready-preserving, legal cash Gangs. A hand-held upgrade is
        // not drawn here and earns no added-Gang money. A missing-suit tile is
        // never a scored option. One copy cannot produce repeated payments.
        for (int t = 0; t < 27; t++)
        {
            if (wall[t] == 0 || t / 9 == missing || self[t] > 0) continue;
            var peng = melds.Any(m => m.Type == SichuanMeldType.Peng && m.TileType == t);
            if (hand[t] != 3 && !(peng && hand[t] == 0)) continue;
            var h = (int[])hand.Clone(); var m = melds.ToList();
            if (peng)
            {
                var index = m.FindIndex(g => g.Type == SichuanMeldType.Peng && g.TileType == t);
                m[index] = m[index] with { Type = SichuanMeldType.AddedGang };
            }
            else { h[t] -= 3; m.Add(new(SichuanMeldType.ConcealedGang, t, -1, 0)); }
            if (!LegalReady(h, m)) continue;
            drawGang[t] = peng ? SichuanRuleSnapshot.Frozen.BaseScore : 2 * SichuanRuleSnapshot.Frozen.BaseScore;
            if (!peng) discardGang[t] = 2 * SichuanRuleSnapshot.Frozen.BaseScore;
        }
        return new(ron, self, transition, developedRon, developedSelf, drawGang, discardGang)
        { DevelopedRonChance = developedRonChance, DevelopedSelfChance = developedSelfChance,
            DevelopedGangDiscardPrice = developedGangRon };
    }

    private bool Wins(int[] hand, int meldCount, int tile)
    {
        hand[tile]++; var win = _hands.IsWinning(hand, meldCount, meldCount == 0); hand[tile]--;
        return win;
    }

    private void FillPrices(int[] hand, IReadOnlyList<SichuanMeldView> melds, int missing,
        double[] ron, double[] self)
    {
        if (hand.Skip(missing * 9).Take(9).Any(n => n > 0)) return;
        for (int t = 0; t < 27; t++)
        {
            int owned = hand[t] + melds.Where(m => m.TileType == t).Sum(m => m.Type == SichuanMeldType.Peng ? 3 : 4);
            if (t / 9 == missing || owned >= 4 || !Wins(hand, melds.Count, t)) continue;
            hand[t]++;
            ron[t] = _fans.Project(hand, melds, SichuanWinType.Discard).HandScore;
            self[t] = _fans.Project(hand, melds, SichuanWinType.SelfDraw).PerPayerScore;
            hand[t]--;
        }
    }

    internal SichuanHuWaitingEstimate AssessAllocation(SichuanStateView s, SichuanHiddenHandParticle p,
        SichuanReadyPrice prices)
    {
        var hazards = new SeatHazard?[4];
        for (int seat = 0; seat < 4; seat++)
            if (seat != s.SeatIndex && s.ActiveSeats[seat] && !s.HasHu[seat]) hazards[seat] = Hazard(s, p, seat);
        return Integrate(s, p.Wall27, prices, hazards);
    }

    // Integrate finite-wall events without sampling future wall orders. Each
    // payer's survival is JOINT with our particular winning tile and all prior
    // misses, rather than multiplying unconditional win and survival means.
    // Fixed current waits are exact on the declared initial schedule; the
    // one-draw readiness projection and all-opponent-exit union remain moments.
    internal static SichuanHuWaitingEstimate Integrate(SichuanStateView s, int[] wall,
        SichuanReadyPrice prices, SeatHazard?[] hazards)
    {
        int size = wall.Sum();
        var schedule = SichuanSingleLaneSupply.DrawSchedule(s);
        var ownPrices = prices.Waits.ToDictionary(w => w.TileType, w => w.SelfDrawPerPayer);
        int hits = ownPrices.Keys.Sum(t => wall[t]);
        var opponents = Enumerable.Range(0, 4).Where(i => i != s.SeatIndex && s.ActiveSeats[i] && !s.HasHu[i]).ToArray();
        var visits = new int[4]; var developingAlive = Enumerable.Repeat(1.0, 4).ToArray();
        var ownWait = Enumerable.Range(0, 27).Select(ownPrices.ContainsKey).ToArray();
        var oppWait = Enumerable.Range(0, 4).Select(i => Enumerable.Range(0, 27)
            .Select(t => hazards[i]?.SelfPrice[t] > 0).ToArray()).ToArray();
        var cache = new Dictionary<(int, int, int, int, int, int), double>();
        double Joint(int tile, int other, bool includeRon, bool excludeGang = false)
        {
            var buckets = new int[4];
            for (int t = 0; t < 27; t++)
            {
                bool o = other >= 0 && oppWait[other][t];
                bool a = ownWait[t] || includeRon && o || excludeGang && t == tile;
                bool b = o || excludeGang && t == tile;
                buckets[(a ? 1 : 0) + (b ? 2 : 0)] += wall[t] - (t == tile ? 1 : 0);
            }
            var key = (buckets[0], buckets[1], buckets[2], buckets[3], visits[s.SeatIndex], other < 0 ? 0 : visits[other]);
            if (!cache.TryGetValue(key, out var value))
                cache[key] = value = JointMiss(key.Item1, key.Item2, key.Item3, key.Item4, key.Item5, key.Item6);
            return value;
        }
        double opportunity = 0, win = 0, gain = 0, selfLoss = 0, ronLoss = 0, gangLoss = 0, payerMass = 0;
        for (int position = 0; position < schedule.Length; position++)
        {
            int seat = schedule[position];
            if (seat == s.SeatIndex)
            {
                for (int t = 0; t < 27; t++)
                {
                    if (wall[t] == 0) continue;
                    double w = wall[t] / (double)size;
                    double raw = w * Joint(t, -1, false);
                    if (ownPrices.TryGetValue(t, out var perPayer))
                    {
                        opportunity += raw;
                        double allExited = 1;
                        foreach (var other in opponents)
                        {
                            double joint = w * Joint(t, other, true) * developingAlive[other];
                            payerMass += joint; gain += joint * perPayer;
                            allExited *= 1 - (raw > 0 ? Math.Clamp(joint / raw, 0, 1) : 0);
                        }
                        win += raw * (1 - allExited);
                        continue;
                    }
                    foreach (var other in opponents)
                    {
                        if (hazards[other] is not { } h) continue;
                        double developed = 1 - Math.Pow(1 - h.ReadyTransition, visits[other]);
                        ronLoss += w * Joint(t, other, true) * h.RonPrice[t];
                        ronLoss += raw * developingAlive[other] * developed * h.DevelopedRonPrice[t];
                        if (position + 1 < schedule.Length && h.DiscardGangPrice[t] > 0)
                            gangLoss += w * Joint(t, other, true, true) * h.DiscardGangPrice[t];
                    }
                }
                foreach (var other in opponents)
                    if (hazards[other] is { } h && size > hits)
                    {
                        double q = Enumerable.Range(0, 27).Where(t => !ownWait[t]).Sum(t => wall[t] * h.DevelopedRonChance[t]) / (size - hits);
                        developingAlive[other] *= 1 - q * (1 - Math.Pow(1 - h.ReadyTransition, visits[other]));
                    }
            }
            else if (hazards[seat] is { } h)
            {
                double developed = 1 - Math.Pow(1 - h.ReadyTransition, visits[seat]);
                double q = 0;
                for (int t = 0; t < 27; t++)
                {
                    double w = size == 0 ? 0 : wall[t] / (double)size;
                    if (w == 0) continue;
                    selfLoss += w * Joint(t, seat, true) * h.SelfPrice[t];
                    selfLoss += w * Joint(t, -1, false) * developingAlive[seat] * developed * h.DevelopedSelfPrice[t];
                    q += w * developed * h.DevelopedSelfChance[t];
                    if (position + 1 < schedule.Length && h.DrawGangPrice[t] > 0)
                    {
                        gangLoss += w * Joint(t, seat, true, true) * h.DrawGangPrice[t];
                    }
                }
                developingAlive[seat] *= 1 - Math.Clamp(q, 0, 1);
            }
            visits[seat]++;
        }
        return new(true, "conditional_local_allocation", 1, 1,
            prices.Waits.Sum(w => s.Remaining18[w.TileType]), hits, visits[s.SeatIndex],
            opportunity, win, gain, selfLoss, ronLoss, gangLoss, payerMass);
    }

    // Two disjoint sets of draw positions from one finite population. Group A
    // must avoid A-only/both, group B must avoid B-only/both. Sum over the
    // B-only copies consumed by A, then choose B from its remaining safe pool.
    // Interleaving positions does not change this random-allocation identity.
    internal static double JointMiss(int neither, int aOnly, int bOnly, int both, int a, int b)
    {
        int n = neither + aOnly + bOnly + both;
        if (a < 0 || b < 0 || a + b > n) return 0;
        double denominatorA = Choose(n, a), denominatorB = Choose(n - a, b);
        if (denominatorA == 0 || denominatorB == 0) return 0;
        double value = 0;
        for (int x = Math.Max(0, a - neither); x <= Math.Min(a, bOnly); x++)
            value += Choose(bOnly, x) * Choose(neither, a - x) / denominatorA
                * Choose(aOnly + neither - (a - x), b) / denominatorB;
        return Math.Clamp(value, 0, 1);
    }

    private static double Choose(int n, int k)
    {
        if (n < 0 || k < 0 || k > n) return 0;
        k = Math.Min(k, n - k); double c = 1;
        for (int i = 1; i <= k; i++) c *= (n - k + i) / (double)i;
        return c;
    }
}
