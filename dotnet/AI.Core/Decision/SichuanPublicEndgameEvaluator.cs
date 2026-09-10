using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanPublicEndgameEstimate(int TileType, double NetScore, int Samples);

public sealed record SichuanPublicContinuationEstimate(
    int TileType,
    double NetScore,
    double ImmediateScore,
    double ContinuationScore,
    double InitialDealInProbability,
    int Samples);

public sealed record SichuanPublicContinuationReport(
    IReadOnlyList<SichuanPublicContinuationEstimate> Candidates,
    int ParticleCount,
    double EffectiveSampleSize,
    int Seed,
    int MaximumWall,
    bool AppliedToPolicy,
    string Status);

/// <summary>
/// Small, public-only endgame counterfactuals. Every candidate uses the same
/// sampled hidden pool and wall permutations. No actual opponent hand or wall
/// order is accepted. This is a bounded policy model, not an optimal-play oracle.
/// </summary>
public sealed class SichuanPublicEndgameEvaluator
{
    private const int MaximumWall = 4;
    private const int SampleCount = 32;
    private readonly SichuanHiddenHandInferenceEngine _inference = new();
    private readonly SichuanExactHandAnalyzer _hands = new();
    private readonly SichuanFanProjectionEngine _fans = new();
    private readonly SichuanSettlementProjectionEngine _settlement = new();
    private readonly Engines.SichuanShantenEngine _shanten = new();

    /// <summary>
    /// Read-only, public-information diagnostic for blood-battle continuation.
    /// Unlike <see cref="Evaluate"/>, this can inspect a longer wall, but its
    /// result is never consumed by candidate scoring. Callers must calibrate and
    /// promote the mechanism separately before policy use.
    /// </summary>
    public SichuanPublicContinuationReport AnalyzeContinuation(
        SichuanStateView state,
        IEnumerable<int> discardTiles,
        int maximumWall = 32,
        int sampleCount = 128,
        int seed = 20260909)
    {
        maximumWall = Math.Clamp(maximumWall, 4, 72);
        sampleCount = Math.Clamp(sampleCount, 32, 4096);
        // The current public projection does not preserve win locks or gang
        // settlement context. Reject these states instead of silently erasing
        // legal constraints before simulation.
        if (state.LockedFans.Any(value => value >= 0))
            return EmptyContinuation(0, seed, maximumWall, "win_lock_not_supported");
        var preceding = state.PublicEvents.LastOrDefault(item =>
            item.Type is not SichuanPublicEventType.Draw and not SichuanPublicEventType.Pass);
        if (preceding?.Type is SichuanPublicEventType.MeldedGang
            or SichuanPublicEventType.ConcealedGang or SichuanPublicEventType.AddedGang)
            return EmptyContinuation(0, seed, maximumWall, "pending_gang_context_not_supported");
        if (!SichuanPublicInferenceBoundary.TryProject(state, out var projection, out var reason))
            return EmptyContinuation(0, seed, maximumWall, reason);
        if (projection.WallCount > maximumWall)
            return EmptyContinuation(0, seed, maximumWall, "wall_out_of_scope");
        if (!TryPrepare(
            projection, discardTiles, maximumWall, out _, out var tiles, out _, includeExitedSeats: true))
            return EmptyContinuation(0, seed, maximumWall, "state_out_of_scope");

        var particles = _inference.SampleParticles(
            projection,
            sampleCount,
            seed,
            SichuanHiddenHandProposal.PublicPriorThenLikelihood);
        if (particles.Count != sampleCount
            || particles.Any(particle => !SichuanPublicInferenceBoundary.ParticleConserves(projection, particle)))
            return EmptyContinuation(particles.Count, seed, maximumWall, "particle_conservation_failed");

        var totalWeight = particles.Sum(p => p.Weight);
        if (totalWeight <= 0)
            return EmptyContinuation(particles.Count, seed, maximumWall, "zero_particle_weight");

        var net = tiles.ToDictionary(t => t, _ => 0.0);
        var immediate = tiles.ToDictionary(t => t, _ => 0.0);
        var continuation = tiles.ToDictionary(t => t, _ => 0.0);
        var dealIn = tiles.ToDictionary(t => t, _ => 0.0);
        var sumSquaredWeights = 0.0;
        for (var i = 0; i < particles.Count; i++)
        {
            var particle = particles[i];
            var normalizedWeight = particle.Weight / totalWeight;
            sumSquaredWeights += normalizedWeight * normalizedWeight;
            var wall = ShuffledWall(particle, seed ^ projection.RoundIndex ^ i * 7919);
            foreach (var tile in tiles)
            {
                var outcome = Simulate(projection, particle, wall, tile);
                net[tile] += outcome.NetScore * normalizedWeight;
                immediate[tile] += outcome.ImmediateScore * normalizedWeight;
                continuation[tile] += outcome.ContinuationScore * normalizedWeight;
                if (outcome.InitialDealIn) dealIn[tile] += normalizedWeight;
            }
        }

        var estimates = tiles.Select(tile => new SichuanPublicContinuationEstimate(
            tile,
            net[tile],
            immediate[tile],
            continuation[tile],
            dealIn[tile],
            particles.Count)).ToArray();
        var effectiveSampleSize = sumSquaredWeights <= 0 ? 0 : 1.0 / sumSquaredWeights;
        return new SichuanPublicContinuationReport(
            estimates,
            particles.Count,
            effectiveSampleSize,
            seed,
            maximumWall,
            AppliedToPolicy: false,
            Status: estimates.Length > 0 ? "diagnostic_only" : "no_ready_candidates");
    }

    public IReadOnlyList<SichuanPublicEndgameEstimate> Evaluate(SichuanStateView state, IEnumerable<int> discardTiles)
    {
        if (!TryPrepare(state, discardTiles, MaximumWall, out var seats, out var tiles, out _))
            return Array.Empty<SichuanPublicEndgameEstimate>();
        var particles = _inference.SampleParticles(state, SampleCount, 20260901 ^ state.RoundIndex ^ state.TurnIndex);
        if (!ParticlesMatchPublicState(state, seats, particles))
            return Array.Empty<SichuanPublicEndgameEstimate>();
        var values = tiles.ToDictionary(t => t, _ => 0.0);
        var totalWeight = particles.Sum(p => p.Weight);
        if (totalWeight <= 0) return Array.Empty<SichuanPublicEndgameEstimate>();
        for (var i = 0; i < particles.Count; i++)
        {
            var p = particles[i];
            var wall = ShuffledWall(p, 20260901 ^ state.RoundIndex ^ i * 7919);
            foreach (var tile in tiles)
                values[tile] += Simulate(state, p, wall, tile).NetScore * p.Weight / totalWeight;
        }
        return tiles.Select(t => new SichuanPublicEndgameEstimate(t, values[t], particles.Count)).ToArray();
    }

    private sealed record SimulationOutcome(
        double NetScore,
        double ImmediateScore,
        double ContinuationScore,
        bool InitialDealIn);

    private SimulationOutcome Simulate(SichuanStateView state, SichuanHiddenHandParticle particle, int[] wall, int firstDiscard)
    {
        var hands = particle.Hands27.Select(h => (int[])h.Clone()).ToArray();
        hands[state.SeatIndex] = (int[])state.Hand18.Clone();
        var melds = Enumerable.Range(0, 4).Select(s => Melds(state, s)).ToArray();
        var active = Enumerable.Range(0, 4).Select(s => state.ActiveSeats[s] && !state.HasHu[s]).ToArray();
        var changes = new int[4];
        var publicVisible = (int[])state.Visible18.Clone();
        var won = new Dictionary<int, int>();
        var wallIndex = 0;
        var current = state.SeatIndex;
        var tile = firstDiscard;
        var initialDecisionPending = true;
        var initialDealIn = false;
        var immediateScore = 0.0;
        hands[current][tile]--;
        publicVisible[tile]++;
        var precedingAction = state.PublicEvents.LastOrDefault(e => e.Type is not SichuanPublicEventType.Draw and not SichuanPublicEventType.Pass);
        var afterGang = precedingAction?.Seat == current && precedingAction.Type is
            SichuanPublicEventType.MeldedGang or SichuanPublicEventType.ConcealedGang or SichuanPublicEventType.AddedGang;
        var lastGangType = precedingAction?.Type == SichuanPublicEventType.ConcealedGang ? SichuanMeldType.ConcealedGang
            : precedingAction?.Type == SichuanPublicEventType.MeldedGang ? SichuanMeldType.MeldedGang : SichuanMeldType.AddedGang;
        var lastGangPayers = afterGang && lastGangType == SichuanMeldType.MeldedGang && precedingAction!.SourceSeat is >= 0 and < 4
            ? new[] { precedingAction.SourceSeat }
            : afterGang ? ActiveSeats().Where(s => s != current).ToArray() : Array.Empty<int>();
        // A wall-proportional hard budget allows diagnostic continuations while
        // protecting callers from malformed claim loops without inventing an action.
        var stepBudget = Math.Min(320, Math.Max(32, wall.Length * 4 + 16));
        for (var step = 0; step < stepBudget; step++)
        {
            var winners = OrderAfter(current).Where(s => active[s] && CanWin(s, tile)).ToArray();
            foreach (var winner in winners)
            {
                hands[winner][tile]++;
                var type = afterGang ? SichuanWinType.GangDiscard : SichuanWinType.Discard;
                var fan = _fans.Project(hands[winner], melds[winner], type);
                Add(_settlement.ProjectWin(winner, current, ActiveSeats(), fan, type).ScoreChanges);
                hands[winner][tile]--;
                active[winner] = false;
                won[winner] = fan.HandScore;
            }
            if (winners.Length > 0 && afterGang)
                Add(_settlement.ProjectScenario(new(TransferEvents: winners.Select(w =>
                    new SichuanHuJiaoTransferEvent(w, lastGangType, lastGangPayers, current)).ToArray())).ScoreChanges);
            if (initialDecisionPending)
            {
                initialDealIn = winners.Length > 0;
                immediateScore = changes[state.SeatIndex];
                initialDecisionPending = false;
            }
            if (active.Count(x => x) <= 1) break;
            var claimed = false;
            if (winners.Length == 0)
            {
                // Model policy: claim a Gang only when it does not worsen the
                // waiting hand; Peng only when it strictly improves shanten.
                // Uses that seat's sampled hand, never its future wall draws.
                foreach (var seat in OrderAfter(current).Where(s => active[s] && state.DingQueSuits[s] != tile / 9)
                    .OrderByDescending(s => hands[s][tile] >= 3))
                {
                    if (hands[seat][tile] < 2 || melds[seat].Count >= 4) continue;
                    var before = Shanten(hands[seat], melds[seat].Count);
                    var gang = hands[seat][tile] >= 3;
                    var probe = (int[])hands[seat].Clone();
                    probe[tile] -= gang ? 3 : 2;
                    var nextMelds = melds[seat].Append(new SichuanMeldView(gang ? SichuanMeldType.MeldedGang : SichuanMeldType.Peng, tile, current, 0)).ToList();
                    var claimedVisible = (int[])publicVisible.Clone();
                    claimedVisible[tile] += gang ? 3 : 2;
                    var discard = gang ? -1 : BestDiscard(probe, nextMelds, state.DingQueSuits[seat], claimedVisible);
                    if (!gang && discard < 0) continue;
                    if (!gang) probe[discard]--;
                    var after = Shanten(probe, nextMelds.Count);
                    if (gang ? after > before : after >= before) continue;
                    var source = current;
                    hands[seat][tile] -= gang ? 3 : 2;
                    publicVisible = claimedVisible;
                    melds[seat] = nextMelds;
                    current = seat;
                    claimed = true;
                    if (gang)
                    {
                        lastGangPayers = new[] { source };
                        lastGangType = SichuanMeldType.MeldedGang;
                        Add(_settlement.ProjectScenario(new(GangEvents: new[] { new SichuanGangScoreEvent(seat, lastGangType, lastGangPayers) })).ScoreChanges);
                        // Current GameState permits a final-discard Gang and
                        // settles when no replacement remains. Do not import
                        // a video's different last-tile rule into the AI.
                        if (wallIndex >= wall.Length) return Finish();
                        if (DrawAndDiscard(seat, true, out tile)) break;
                        afterGang = true;
                    }
                    else
                    {
                        tile = discard;
                        hands[seat][tile]--;
                        publicVisible[tile]++;
                        afterGang = false;
                    }
                    break;
                }
            }
            // Robbing an added gang consumes the tile but may leave the actor
            // active. Only a real emitted discard enters the reaction loop.
            if (claimed && active[current] && tile >= 0) continue;
            if (active.Count(x => x) <= 1 || wallIndex >= wall.Length) break;
            var next = OrderAfter(current).First(s => active[s]);
            current = next;
            afterGang = false;
            if (DrawAndDiscard(next, false, out tile))
            {
                // A self-draw emits no discard. Advance until a surviving seat
                // actually discards or the wall/battle ends.
                while (active.Count(x => x) > 1 && wallIndex < wall.Length)
                {
                    current = OrderAfter(current).First(s => active[s]);
                    if (!DrawAndDiscard(current, false, out tile)) break;
                }
                if (!active[current] || tile < 0) break;
            }
        }
        return Finish();

        bool DrawAndDiscard(int seat, bool replacement, out int discard)
        {
            afterGang = replacement;
            discard = -1;
            var draw = wall[wallIndex++];
            hands[seat][draw]++;
            if (IsLegalWinning(seat, hands[seat]))
            {
                var type = replacement ? SichuanWinType.GangSelfDraw : SichuanWinType.SelfDraw;
                var fan = _fans.Project(hands[seat], melds[seat], type);
                Add(_settlement.ProjectWin(seat, -1, ActiveSeats(), fan, type).ScoreChanges);
                active[seat] = false;
                won[seat] = fan.HandScore;
                return true;
            }
            // Added Gang is considered from own known tiles, before observing
            // the replacement. Rob-Gang winners take priority over payment.
            var added = melds[seat].FindIndex(m => m.Type == SichuanMeldType.Peng && m.TileType == draw && state.DingQueSuits[seat] != draw / 9);
            if (added >= 0 && wallIndex < wall.Length)
            {
                var robbers = OrderAfter(seat).Where(s => active[s] && CanWin(s, draw)).ToArray();
                if (robbers.Length > 0)
                {
                    foreach (var robber in robbers)
                    {
                        hands[robber][draw]++;
                        var fan = _fans.Project(hands[robber], melds[robber], SichuanWinType.RobAddedGang);
                        Add(_settlement.ProjectWin(robber, seat, ActiveSeats(), fan, SichuanWinType.RobAddedGang).ScoreChanges);
                        hands[robber][draw]--;
                        active[robber] = false;
                        won[robber] = fan.HandScore;
                    }
                    hands[seat][draw]--;
                    publicVisible[draw]++;
                    // The robbed tile is consumed; no discard is emitted.
                    return true;
                }
                hands[seat][draw]--;
                publicVisible[draw]++;
                melds[seat][added] = melds[seat][added] with { Type = SichuanMeldType.AddedGang };
                lastGangPayers = ActiveSeats().Where(s => s != seat).ToArray();
                lastGangType = SichuanMeldType.AddedGang;
                Add(_settlement.ProjectScenario(new(GangEvents: new[] { new SichuanGangScoreEvent(seat, lastGangType, lastGangPayers) })).ScoreChanges);
                afterGang = true;
                return DrawAndDiscard(seat, true, out discard);
            }
            discard = BestDiscard(hands[seat], melds[seat], state.DingQueSuits[seat], publicVisible);
            if (discard < 0) return true;
            hands[seat][discard]--;
            publicVisible[discard]++;
            return false;
        }
        bool CanWin(int seat, int candidate)
        {
            if (candidate < 0 || state.DingQueSuits[seat] == candidate / 9 || hands[seat][candidate] >= 4) return false;
            hands[seat][candidate]++;
            var result = IsLegalWinning(seat, hands[seat]);
            hands[seat][candidate]--;
            return result;
        }
        bool IsLegalWinning(int seat, int[] hand) => !HasMissing(hand, state.DingQueSuits[seat]) && _hands.IsWinning(hand, melds[seat].Count);
        int[] ActiveSeats() => Enumerable.Range(0, 4).Where(s => active[s]).ToArray();
        void Add(int[] value) { for (var s = 0; s < 4; s++) changes[s] += value[s]; }
        SimulationOutcome Finish()
        {
            if (active.Count(x => x) > 1 && wallIndex >= wall.Length)
            {
                var assessments = new List<SichuanDrawAssessment>();
                for (var seat = 0; seat < 4; seat++)
                {
                    if (won.TryGetValue(seat, out var score))
                    {
                        assessments.Add(new(seat, false, false, 0, HasWon: true, WonScore: score));
                        continue;
                    }
                    if (!active[seat]) continue;
                    var missing = HasMissing(hands[seat], state.DingQueSuits[seat]);
                    // GameState's cha-jiao is structural ting, not live-wall
                    // ukeire. A tile held elsewhere does not cancel ting.
                    var waits = missing ? Array.Empty<SichuanWaitAnalysis>() : _hands.EnumerateWaits(hands[seat], OwnRemaining(hands[seat], melds[seat]), melds[seat].Count).ToArray();
                    var best = 0;
                    foreach (var wait in waits)
                    {
                        hands[seat][wait.TileType]++;
                        best = Math.Max(best, _fans.Project(hands[seat], melds[seat], SichuanWinType.Discard).HandScore);
                        hands[seat][wait.TileType]--;
                    }
                    assessments.Add(new(seat, waits.Length > 0, missing, best));
                }
                Add(_settlement.ProjectScenario(new(DrawAssessments: assessments)).ScoreChanges);
            }
            if (initialDecisionPending)
            {
                immediateScore = changes[state.SeatIndex];
                initialDecisionPending = false;
            }
            var netScore = changes[state.SeatIndex];
            return new SimulationOutcome(netScore, immediateScore, netScore - immediateScore, initialDealIn);
        }
    }

    private bool TryPrepare(
        SichuanStateView state,
        IEnumerable<int> discardTiles,
        int maximumWall,
        out int[] seats,
        out int[] tiles,
        out int ownMeldCount,
        bool includeExitedSeats = false)
    {
        seats = Array.Empty<int>();
        tiles = Array.Empty<int>();
        ownMeldCount = 0;
        if (state.InformationMode == "oracle" || state.WallCount is < 0 || state.WallCount > maximumWall
            || state.SeatIndex is < 0 or >= 4 || state.LockedFans.Any(f => f >= 0))
            return false;
        if (!state.ActiveSeats[state.SeatIndex] || state.HasHu[state.SeatIndex])
            return false;
        ownMeldCount = Melds(state, state.SeatIndex).Count;
        if (state.Hand18.Sum() != 14 - 3 * ownMeldCount
            || Enumerable.Range(0, 27).Any(t => state.Hand18[t] is < 0 or > 4 || state.Remaining18[t] is < 0 or > 4
                || state.Visible18[t] < 0 || state.Hand18[t] + state.Visible18[t] + state.Remaining18[t] != 4))
            return false;
        var activeOpponents = Enumerable.Range(0, 4)
            .Where(s => s != state.SeatIndex && state.ActiveSeats[s] && !state.HasHu[s])
            .ToArray();
        seats = Enumerable.Range(0, 4)
            .Where(s => s != state.SeatIndex && (includeExitedSeats || activeOpponents.Contains(s)))
            .ToArray();
        if (activeOpponents.Length == 0 || seats.Any(s => state.HandCounts[s] != 13 - 3 * Melds(state, s).Count
            && !(includeExitedSeats && state.HasHu[s] && state.HandCounts[s] == 14 - 3 * Melds(state, s).Count)))
            return false;
        // If exited concealed hands have not been removed from the public pool,
        // do not silently relabel their tiles as drawable wall tiles.
        if (state.Remaining18.Sum() != state.WallCount + seats.Sum(s => state.HandCounts[s]))
            return false;
        // Only compare continuations which keep the caller ready. The compact
        // state has no per-winner historical cha-jiao liability, so breaking
        // ready must remain with the existing general evaluator.
        var readyMeldCount = ownMeldCount;
        tiles = discardTiles.Distinct().Where(t => t is >= 0 and < 27 && state.Hand18[t] > 0
            && !HasMissing(state.Hand18, state.OwnDingQueSuit)).Where(t =>
            {
                var hand = (int[])state.Hand18.Clone();
                hand[t]--;
                return Shanten(hand, readyMeldCount) == 0;
            }).ToArray();
        return tiles.Length > 0;
    }

    private static bool ParticlesMatchPublicState(
        SichuanStateView state,
        IReadOnlyList<int> seats,
        IReadOnlyList<SichuanHiddenHandParticle> particles)
        => particles.Count > 0 && particles.All(p =>
            p.Wall27.Sum() == state.WallCount
            && seats.All(s => p.Hands27[s].Sum() == state.HandCounts[s]));

    private static int[] ShuffledWall(SichuanHiddenHandParticle particle, int seed)
    {
        var wall = Enumerable.Range(0, 27).SelectMany(t => Enumerable.Repeat(t, particle.Wall27[t])).ToArray();
        var random = new Random(seed);
        for (var j = wall.Length - 1; j > 0; j--)
        {
            var k = random.Next(j + 1);
            (wall[j], wall[k]) = (wall[k], wall[j]);
        }
        return wall;
    }

    private static SichuanPublicContinuationReport EmptyContinuation(
        int particleCount,
        int seed,
        int maximumWall,
        string status)
        => new(
            Array.Empty<SichuanPublicContinuationEstimate>(),
            particleCount,
            0,
            seed,
            maximumWall,
            AppliedToPolicy: false,
            Status: status);

    private int BestDiscard(int[] hand, List<SichuanMeldView> melds, int missing, int[] visible)
    {
        var forced = HasMissing(hand, missing) ? missing : -1;
        return _hands.AnalyzeDiscards(hand, PublicRemaining(hand, visible), melds.Count, melds.Count == 0, forced)
            .OrderBy(a => a.Shanten).ThenByDescending(a => a.LiveUkeire).ThenBy(a => a.DiscardTileType)
            .Select(a => a.DiscardTileType).DefaultIfEmpty(-1).First();
    }
    private static bool HasMissing(int[] hand, int suit) => suit is >= 0 and < 3 && Enumerable.Range(suit * 9, 9).Any(t => hand[t] > 0);
    private static int[] PublicRemaining(int[] hand, int[] visible)
        => Enumerable.Range(0, 27).Select(t => Math.Max(0, 4 - hand[t] - visible[t])).ToArray();
    private static int[] OwnRemaining(int[] hand, List<SichuanMeldView> melds)
    {
        var counts = Enumerable.Range(0, 27).Select(t => 4 - hand[t]).ToArray();
        foreach (var meld in melds) counts[meld.TileType] -= meld.Type == SichuanMeldType.Peng ? 3 : 4;
        return counts.Select(n => Math.Max(0, n)).ToArray();
    }
    private int Shanten(int[] hand, int meldCount) => _shanten.CalcBestShanten(hand, meldCount, meldCount == 0);
    private static IEnumerable<int> OrderAfter(int seat) => Enumerable.Range(1, 3).Select(offset => (seat + offset) % 4);
    private static List<SichuanMeldView> Melds(SichuanStateView state, int seat) => state.MeldViews[seat].Count > 0
        ? state.MeldViews[seat].ToList()
        : state.Melds18[seat].GroupBy(t => t).Select(g => new SichuanMeldView(g.Count() >= 4 ? SichuanMeldType.MeldedGang : SichuanMeldType.Peng, g.Key, -1, 0)).ToList();
}
