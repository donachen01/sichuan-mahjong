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
    int Samples)
{
    public double WinProbability { get; init; }
    public double ReadyAtEndProbability { get; init; }
    public double ExpectedOwnPengClaims { get; init; }
}

public sealed record SichuanPublicContinuationReport(
    IReadOnlyList<SichuanPublicContinuationEstimate> Candidates,
    int ParticleCount,
    double EffectiveSampleSize,
    int Seed,
    int MaximumWall,
    bool AppliedToPolicy,
    string Status)
{
    public string ContinuationPolicy => SichuanPolicyExecutionScope.PolicyDescription;
    public IReadOnlyList<SichuanContinuationComparison> Comparisons { get; init; } = Array.Empty<SichuanContinuationComparison>();
}

public sealed record SichuanContinuationComparison(int TileType, int ReferenceTile,
    double MeanNetDifference, double StandardError);

/// <summary>
/// Small, public-only endgame counterfactuals. Every candidate uses the same
/// sampled hidden pool and wall permutations. No actual opponent hand or wall
/// order is accepted. This is a bounded policy model, not an optimal-play oracle.
/// </summary>
public sealed partial class SichuanPublicEndgameEvaluator
{
    private const int MaximumWall = 4;
    private const int SampleCount = 16;
    private readonly SichuanHiddenHandInferenceEngine _inference = new();
    private readonly SichuanExactHandAnalyzer _hands = new();
    private readonly SichuanFanProjectionEngine _fans = new();
    private readonly SichuanSettlementProjectionEngine _settlement = new();
    private readonly Engines.SichuanShantenEngine _shanten = new();

    /// <summary>
    /// Public-information blood-battle continuation with paired candidate samples.
    /// Policy callers must apply independent confirmation and uncertainty gates.
    /// </summary>
    public SichuanPublicContinuationReport AnalyzeContinuation(
        SichuanStateView state,
        IEnumerable<int> discardTiles,
        int maximumWall = 32,
        int sampleCount = 128,
        int seed = 20260909,
        bool includeUnready = false,
        bool fastStructural = false)
    {
        SichuanPolicyExecutionScope.RequireResearchContext();
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
            projection, discardTiles, maximumWall, out _, out var tiles, out _, includeExitedSeats: true,
            includeUnready: includeUnready))
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
        var wins = tiles.ToDictionary(t => t, _ => 0.0);
        var readyAtEnd = tiles.ToDictionary(t => t, _ => 0.0);
        var pengClaims = tiles.ToDictionary(t => t, _ => 0.0);
        var sumSquaredWeights = 0.0;
        var differences = tiles.ToDictionary(t => t, _ => new List<(double Delta, double Weight)>());
        SichuanPublicInferenceBoundary.RestorePolicyHistory(state,projection);
        var sampled = new SimulationOutcome[particles.Count][];
        Parallel.For(0,particles.Count,new ParallelOptions { MaxDegreeOfParallelism=Math.Min(4,Environment.ProcessorCount) }, i =>
        {
            using var cache = Engines.SichuanBeliefEngine.UseCache(new Engines.SichuanBeliefEngine.ScopedCache());
            var evaluator = new SichuanPublicEndgameEvaluator();
            var wall = ShuffledWall(particles[i], seed ^ projection.RoundIndex ^ i * 7919, SichuanHiddenHandInferenceEngine.CanonicalPublicTileOrder(projection));
            sampled[i] = tiles.Select(tile=>evaluator.Simulate(projection,particles[i],wall,tile)).ToArray();
        });
        // Reduce in the original sample order, independently of worker scheduling.
        for (var i = 0; i < particles.Count; i++)
        {
            var particle = particles[i];
            var normalizedWeight = particle.Weight / totalWeight;
            sumSquaredWeights += normalizedWeight * normalizedWeight;
            var referenceScore = 0.0;
            for (var candidateIndex=0;candidateIndex<tiles.Length;candidateIndex++)
            {
                var tile=tiles[candidateIndex];
                var outcome = sampled[i][candidateIndex];
                if (tile == tiles[0]) referenceScore = outcome.NetScore;
                differences[tile].Add((outcome.NetScore - referenceScore, normalizedWeight));
                net[tile] += outcome.NetScore * normalizedWeight;
                immediate[tile] += outcome.ImmediateScore * normalizedWeight;
                continuation[tile] += outcome.ContinuationScore * normalizedWeight;
                if (outcome.InitialDealIn) dealIn[tile] += normalizedWeight;
                if (outcome.OwnWon) wins[tile] += normalizedWeight;
                if (outcome.OwnReadyAtEnd) readyAtEnd[tile] += normalizedWeight;
                pengClaims[tile] += outcome.OwnPengClaims * normalizedWeight;
            }
        }

        var estimates = tiles.Select(tile => new SichuanPublicContinuationEstimate(
            tile,
            net[tile],
            immediate[tile],
            continuation[tile],
            dealIn[tile],
            particles.Count) { WinProbability = wins[tile], ReadyAtEndProbability = readyAtEnd[tile],
                ExpectedOwnPengClaims = pengClaims[tile] }).ToArray();
        var effectiveSampleSize = sumSquaredWeights <= 0 ? 0 : 1.0 / sumSquaredWeights;
        return new SichuanPublicContinuationReport(
            estimates,
            particles.Count,
            effectiveSampleSize,
            seed,
            maximumWall,
            AppliedToPolicy: false,
            Status: estimates.Length > 0 ? "diagnostic_only" : "no_ready_candidates")
        {
            Comparisons = tiles.Select(tile =>
            {
                var mean = differences[tile].Sum(x => x.Delta*x.Weight);
                var variance = differences[tile].Sum(x => x.Weight * Math.Pow(x.Delta-mean, 2));
                return new SichuanContinuationComparison(tile, tiles[0], mean,
                    Math.Sqrt(variance / Math.Max(1, effectiveSampleSize-1)));
            }).ToArray()
        };
    }

    public IReadOnlyList<SichuanPublicEndgameEstimate> Evaluate(SichuanStateView state, IEnumerable<int> discardTiles)
    {
        SichuanPolicyExecutionScope.RequireResearchContext();
        // Exited winners still hold concealed tiles. Sampling them as wall tiles
        // overstates every surviving player's live waits.
        if (!TryPrepare(state, discardTiles, MaximumWall, out var seats, out var tiles, out _, includeExitedSeats: true))
            return Array.Empty<SichuanPublicEndgameEstimate>();
        var particles = _inference.SampleParticles(state, SampleCount, 20260901 ^ state.RoundIndex ^ state.TurnIndex,
            SichuanHiddenHandProposal.PublicPriorThenLikelihood, minimumParticleCount: SampleCount);
        if (!ParticlesMatchPublicState(state, seats, particles))
            return Array.Empty<SichuanPublicEndgameEstimate>();
        var values = tiles.ToDictionary(t => t, _ => 0.0);
        var totalWeight = particles.Sum(p => p.Weight);
        if (totalWeight <= 0) return Array.Empty<SichuanPublicEndgameEstimate>();
        for (var i = 0; i < particles.Count; i++)
        {
            var p = particles[i];
            var wall = ShuffledWall(p, 20260901 ^ state.RoundIndex ^ i * 7919, SichuanHiddenHandInferenceEngine.CanonicalPublicTileOrder(state));
            foreach (var tile in tiles)
                values[tile] += Simulate(state, p, wall, tile).NetScore * p.Weight / totalWeight;
        }
        return tiles.Select(t => new SichuanPublicEndgameEstimate(t, values[t], particles.Count)).ToArray();
    }

    internal sealed record SimulationOutcome(
        double NetScore,
        double ImmediateScore,
        double ContinuationScore,
        bool InitialDealIn,
        bool OwnWon,
        bool OwnReadyAtEnd,
        int OwnPengClaims)
    {
        public double WinGain { get; init; }
        public double GangNet { get; init; }
        public double DrawSettlement { get; init; }
        public double DealInLoss { get; init; }
        public double OpponentLoss { get; init; }
        public int OwnDraws { get; init; }
        public int SelfDrawPayers { get; init; }
        public bool OwnSelfDraw { get; init; }
        public int LockedRonDenied { get; init; }
        public int OwnStrategicRefusals { get; init; }
        public IReadOnlyList<SichuanPublicEvent> Events { get; init; } = [];
    }

    internal SimulationOutcome Simulate(SichuanStateView state, SichuanHiddenHandParticle particle, int[] wall, int firstDiscard,
        Engines.SichuanStructuralDistance? structural = null,
        Dictionary<DiscardCacheKey,int>? discardCache = null, HuReactionRoot? reaction = null, bool selfHuRoot = false)
    {
        SichuanPolicyExecutionScope.RequireResearchContext();
        using var policyScope = new SichuanPolicyExecutionScope();
        var policyBrains = Enumerable.Range(0,4).Select(_ => new Engines.SichuanRoundBrainEngine()).ToArray();
        var startingPlan = SichuanPolicyExecutionScope.OwnPlan;
        if (startingPlan is not null && startingPlan.SeatIndex == state.SeatIndex)
            policyBrains[state.SeatIndex].Restore(state, new Agents.AgentBrainMemory(
                startingPlan.Revision, startingPlan.Stage, startingPlan.PrimaryRoute, startingPlan.FallbackRoute,
                startingPlan.TargetSuit, startingPlan.Commitment, new(startingPlan.RouteWeights),
                startingPlan.BrokenTriplets.ToArray(), startingPlan.DecisionHistory.ToArray()));
        var discardPolicy = new Engines.SichuanDecisionEngine();
        var reactionPolicy = new Engines.SichuanReactionDecisionEngine();
        var selfPolicy = new Engines.SichuanSelfActionDecisionEngine();
        var rivers = state.Discards18.Select(r => r.ToList()).ToArray();
        var hands = particle.Hands27.Select(h => (int[])h.Clone()).ToArray();
        hands[state.SeatIndex] = (int[])state.Hand18.Clone();
        var melds = Enumerable.Range(0, 4).Select(s => Melds(state, s)).ToArray();
        var active = Enumerable.Range(0, 4).Select(s => state.ActiveSeats[s] && !state.HasHu[s]).ToArray();
        var changes = new int[4];
        var publicVisible = (int[])state.Visible18.Clone();
        var won = Enumerable.Range(0, 4).Where(s => state.HasHu[s])
            .ToDictionary(s => s, s => state.WonScores[s]);
        var singleLane = Strategy.SichuanSingleLaneEvaluator.ResolveSuit(state);
        var development = new SichuanDevelopmentPolicy();
        var observedEvents = state.PublicEvents.ToList();
        var lastDrawTiles = Enumerable.Repeat(-1, 4).ToArray();
        var drawReasons = new string[4];
        if (state.CurrentSeat == state.SeatIndex && state.LastDrawOrigin == SichuanTileOrigin.Draw)
        {
            lastDrawTiles[state.SeatIndex] = state.LastDrawTileType;
            drawReasons[state.SeatIndex] = state.OwnDrawReason;
        }
        var eventIndex = observedEvents.Select(e=>e.EventIndex).DefaultIfEmpty(0).Max();
        var strategicRefusals = 0;
        var refusedLocks = new Dictionary<int,int>();
        var wallIndex = 0;
        var current = reaction?.SourceSeat ?? state.SeatIndex;
        var tile = reaction?.Tile ?? firstDiscard;
        var locks = (int[])state.LockedFans.Clone();
        var winGain = 0.0; var gangNet = 0.0; var drawSettlement = 0.0;
        var dealInLoss = 0.0; var opponentLoss = 0.0;
        var ownDraws = 0; var selfDrawPayers = 0; var ownSelfDraw = false; var lockedRonDenied = 0;
        if (reaction is not null && reaction.Action == SichuanActionType.Pass)
        {
            hands[state.SeatIndex][tile]++;
            locks[state.SeatIndex] = _fans.Project(hands[state.SeatIndex], melds[state.SeatIndex], reaction.WinType).CappedFan;
            hands[state.SeatIndex][tile]--;
        }
        if (reaction is not null && reaction.Action != SichuanActionType.Hu)
            Record(state.SeatIndex, SichuanPublicEventType.Pass, tile, true);
        var initialDecisionPending = true;
        var initialDealIn = false;
        var immediateScore = 0.0;
        var ownPengClaims = 0;
        if (reaction is null && !selfHuRoot)
        {
            hands[current][tile]--;
            publicVisible[tile]++;
            Record(current, SichuanPublicEventType.Discard, tile);
        }
        var precedingAction = state.PublicEvents.LastOrDefault(e => e.Type is not SichuanPublicEventType.Draw and not SichuanPublicEventType.Pass);
        var afterGang = precedingAction?.Seat == current && precedingAction.Type is
            SichuanPublicEventType.MeldedGang or SichuanPublicEventType.ConcealedGang or SichuanPublicEventType.AddedGang;
        var lastGangType = precedingAction?.Type == SichuanPublicEventType.ConcealedGang ? SichuanMeldType.ConcealedGang
            : precedingAction?.Type == SichuanPublicEventType.MeldedGang ? SichuanMeldType.MeldedGang : SichuanMeldType.AddedGang;
        var lastGangScoreEligible = !afterGang || precedingAction!.GangScoreEligible;
        var lastGangSource = afterGang ? precedingAction!.SourceSeat : -1;
        var lastGangPayers = afterGang ? ActiveSeats().Where(s => s != current).ToArray() : Array.Empty<int>();
        if (reaction is not null)
        {
            afterGang = reaction.WinType == SichuanWinType.GangDiscard;
            lastGangType = reaction.GangType;
            lastGangSource = reaction.GangSource;
            lastGangPayers = reaction.GangPayers;
            lastGangScoreEligible = reaction.GangScoreEligible;
        }
        if (selfHuRoot)
        {
            if (reaction is not null || state.CurrentSeat!=state.SeatIndex || SichuanSelfDrawContext.Resolve(state).WinType!=SichuanWinType.SelfDraw
                || state.LastDrawOrigin!=SichuanTileOrigin.Draw || !IsLegalWinning(state.SeatIndex,hands[state.SeatIndex]))
                throw new InvalidOperationException("ordinary_self_hu_root_required");
            var winner=state.SeatIndex;
            var fan=_fans.Project(hands[winner],melds[winner],SichuanWinType.SelfDraw);
            ownSelfDraw=true;selfDrawPayers=ActiveSeats().Count(s=>s!=winner);
            AddWin(winner,-1,fan,SichuanWinType.SelfDraw);
            active[winner]=false;won[winner]=fan.HandScore;
            immediateScore=changes[winner];initialDecisionPending=false;
            // No discarded tile exists at self-Hu. Resume normal draws until a
            // surviving seat emits a real discard, or the battle/wall ends.
            tile=-1;afterGang=false;
            while(active.Count(x=>x)>1 && wallIndex<wall.Length)
            {
                current=OrderAfter(current).First(s=>active[s]);
                if(!DrawAndDiscard(current,false,out tile))break;
            }
            if(tile<0 || !active[current])return Finish();
        }
        // A wall-proportional hard budget allows diagnostic continuations while
        // protecting callers from malformed claim loops without inventing an action.
        var stepBudget = Math.Min(320, Math.Max(32, wall.Length * 4 + 16));
        for (var step = 0; step < stepBudget; step++)
        {
            refusedLocks.Clear();
            var rootPending = initialDecisionPending && reaction is not null;
            var ronType = rootPending ? reaction!.WinType : afterGang ? SichuanWinType.GangDiscard : SichuanWinType.Discard;
            var winners = OrderAfter(current).Where(s => active[s]
                && !(rootPending && s == state.SeatIndex && reaction!.Action != SichuanActionType.Hu)
                && CanWin(s, tile, ronType)
                && (rootPending && s == state.SeatIndex || !Refuse(s, tile, ronType))).ToArray();
            foreach (var winner in winners)
            {
                hands[winner][tile]++;
                var type = ronType;
                var fan = _fans.Project(hands[winner], melds[winner], type);
                AddWin(winner, current, fan, type, tile);
                hands[winner][tile]--;
                active[winner] = false;
                won[winner] = fan.HandScore;
            }
            if (winners.Length > 0 && afterGang)
                Add(_settlement.ProjectScenario(new(TransferEvents: winners.Select(w =>
                    new SichuanHuJiaoTransferEvent(w, lastGangType, lastGangPayers, current, lastGangSource,
                        lastGangScoreEligible)).ToArray())).ScoreChanges, "gang");
            if (initialDecisionPending)
            {
                initialDealIn = current == state.SeatIndex && winners.Length > 0;
                immediateScore = changes[state.SeatIndex];
                initialDecisionPending = false;
            }
            if (active.Count(x => x) <= 1) break;
            var claimed = false;
            var priorWinners = rootPending ? reaction!.PriorWinners : Array.Empty<int>();
            var rootRob = rootPending && reaction!.WinType == SichuanWinType.RobAddedGang;
            if (rootRob && winners.Length == 0 && priorWinners.Length == 0)
            {
                var actor = current;
                var index = melds[actor].FindIndex(m => m.Type == SichuanMeldType.Peng && m.TileType == tile);
                melds[actor][index] = melds[actor][index] with { Type = SichuanMeldType.AddedGang };
                lastGangScoreEligible = reaction!.GangScoreEligible;
                Record(actor, SichuanPublicEventType.AddedGang, tile, gangScoreEligible: lastGangScoreEligible);
                lastGangType = SichuanMeldType.AddedGang;
                lastGangSource = actor;
                lastGangPayers = ActiveSeats().Where(s => s != actor).ToArray();
                Add(_settlement.ProjectScenario(new(GangEvents: new[] {
                    new SichuanGangScoreEvent(actor, lastGangType, lastGangPayers, ScoreEligible: lastGangScoreEligible) })).ScoreChanges, "gang");
                DrawAndDiscard(actor, true, out tile);
                claimed = true;
            }
            if (winners.Length == 0 && priorWinners.Length == 0 && !rootRob)
            {
                // Shared public-information development policy permits equal-
                // distance Peng with better supply or a live added-Gang route.
                foreach (var seat in OrderAfter(current).Where(s => active[s] && state.DingQueSuits[s] != tile / 9)
                    .OrderByDescending(s => hands[s][tile] >= 3))
                {
                    if (rootPending && seat == state.SeatIndex && reaction!.Action == SichuanActionType.Pass) continue;
                    if (hands[seat][tile] < 2 || melds[seat].Count >= 4) continue;
                    var forcedClaim = rootPending && seat == state.SeatIndex && reaction!.Action is SichuanActionType.Peng or SichuanActionType.Gang;
                    var policyView = Observe(seat);
                    var choice = forcedClaim ? null : reactionPolicy.DecideReaction(policyView,tile,false,
                        hands[seat][tile]>=2,hands[seat][tile]>=3 && wallIndex<wall.Length,current,
                        forceLightweight:false,roundBrain:policyBrains[seat].Observe(policyView));
                    if (!forcedClaim && choice!.Action.ActionType == SichuanActionType.Pass) continue;
                    var gang = forcedClaim ? reaction!.Action == SichuanActionType.Gang
                        : choice!.Action.ActionType == SichuanActionType.Gang;
                    var nextMelds = melds[seat].Append(new SichuanMeldView(gang ? SichuanMeldType.MeldedGang : SichuanMeldType.Peng, tile, current, 0) { AddedGangBlockedUntilOwnDraw = !gang }).ToList();
                    var claimedVisible = (int[])publicVisible.Clone(); claimedVisible[tile] += gang ? 3 : 2;
                    var discard = gang ? -1 : forcedClaim ? reaction!.PengDiscard : choice!.PlannedDiscardTile;
                    // A public reaction may choose Peng followed by an unrelated
                    // concealed Gang; immediate added Gang is forbidden.  The reaction result carries that
                    // transition with PlannedSelfAction and therefore has no
                    // immediate discard yet.  It must be executed after the Peng
                    // is materialized instead of being treated as a malformed
                    // missing-discard result.
                    var immediateSelfAction = !forcedClaim && !gang && choice!.PlannedSelfAction is "an_gang" or "concealed_gang"
                        ? choice.PlannedSelfAction : string.Empty;
                    var source = current;
                    var claimApplied = false;
                    if (!gang && discard < 0 && immediateSelfAction.Length == 0)
                    {
                        // Keep the sampled public continuation total rather than
                        // aborting on a stale policy plan.  Rebuild a legal
                        // post-Peng discard from the actual projected state.
                        var previousVisible = (int[])publicVisible.Clone();
                        var previousMelds = melds[seat];
                        var previousCurrent = current;
                        hands[seat][tile] -= 2;
                        publicVisible = claimedVisible;
                        melds[seat] = nextMelds;
                        current = seat;
                        var fallbackView = Observe(seat, true);
                        discard = discardPolicy.DecideDiscard(fallbackView, false,
                            policyBrains[seat].Observe(fallbackView)).Action.TileType;
                        if (discard < 0 || hands[seat][discard] <= 0)
                        {
                            hands[seat][tile] += 2;
                            publicVisible = previousVisible;
                            melds[seat] = previousMelds;
                            current = previousCurrent;
                            continue;
                        }
                        claimApplied = true;
                        immediateSelfAction = string.Empty;
                    }
                    if (!claimApplied)
                    {
                        hands[seat][tile] -= gang ? 3 : 2;
                        publicVisible = claimedVisible;
                        melds[seat] = nextMelds;
                        current = seat;
                    }
                    var refusedHu = refusedLocks.TryGetValue(seat, out var previousLock);
                    if (refusedHu)
                    {
                        locks[seat] = previousLock; // choosing Peng/Gang does not create a Pass lock
                        var passIndex=observedEvents.FindLastIndex(e=>e.Seat==seat&&e.Type==SichuanPublicEventType.Pass&&e.CanHu);
                        if(passIndex>=0)observedEvents[passIndex]=observedEvents[passIndex] with {CanHu=false};
                    }
                    Record(seat, gang ? SichuanPublicEventType.MeldedGang : SichuanPublicEventType.Peng, tile, refusedHu, source);
                    claimed = true;
                    if (gang)
                    {
                        lastGangPayers = ActiveSeats().Where(s => s != seat).ToArray();
                        lastGangSource = source;
                        lastGangType = SichuanMeldType.MeldedGang;
                        lastGangScoreEligible = true;
                        Add(_settlement.ProjectScenario(new(GangEvents: new[] { new SichuanGangScoreEvent(seat, lastGangType, lastGangPayers, SourceSeat: source) })).ScoreChanges, "gang");
                        DrawAndDiscard(seat, true, out tile);
                        afterGang = true;
                    }
                    else
                    {
                        if (seat == state.SeatIndex) ownPengClaims++;
                        if (immediateSelfAction.Length > 0)
                        {
                            var gangTile = choice!.PlannedSelfActionTile;
                            var canConcealedGang = immediateSelfAction is "an_gang" or "concealed_gang"
                                && gangTile is >= 0 and < 27 && hands[seat][gangTile] == 4 && melds[seat].Count < 4;
                            if (canConcealedGang)
                            {
                                hands[seat][gangTile] -= 4;
                                publicVisible[gangTile] += 4;
                                melds[seat].Add(new SichuanMeldView(SichuanMeldType.ConcealedGang, gangTile, seat, 0));
                                lastGangType = SichuanMeldType.ConcealedGang;
                                lastGangScoreEligible = true;
                                Record(seat, SichuanPublicEventType.ConcealedGang, gangTile);
                                lastGangSource = seat;
                                lastGangPayers = ActiveSeats().Where(s => s != seat).ToArray();
                                Add(_settlement.ProjectScenario(new(GangEvents: new[] {
                                    new SichuanGangScoreEvent(seat, lastGangType, lastGangPayers,
                                        SourceSeat: seat, ScoreEligible: lastGangScoreEligible) })).ScoreChanges, "gang");
                                DrawAndDiscard(seat, true, out tile);
                                afterGang = true;
                            }
                            else
                            {
                                var fallbackView = Observe(seat, true);
                                tile = discardPolicy.DecideDiscard(fallbackView, false,
                                    policyBrains[seat].Observe(fallbackView)).Action.TileType;
                                if (tile < 0 || hands[seat][tile] <= 0)
                                {
                                    claimed = false;
                                    break;
                                }
                                hands[seat][tile]--;
                                publicVisible[tile]++;
                                Record(seat, SichuanPublicEventType.Discard, tile);
                                afterGang = false;
                            }
                        }
                        else
                        {
                            tile = discard;
                            hands[seat][tile]--;
                            publicVisible[tile]++;
                            Record(seat, SichuanPublicEventType.Discard, tile);
                            afterGang = false;
                        }
                    }
                    break;
                }
            }
            // Robbing an added gang consumes the tile but may leave the actor
            // active. Only a real emitted discard enters the reaction loop.
            if (claimed && active[current] && tile >= 0) continue;
            if (active.Count(x => x) <= 1 || wallIndex >= wall.Length) break;
            // Live GameState resumes after the last winner in actual turn order.
            var allWinners = winners.Concat(priorWinners).ToHashSet();
            var resumeFrom = OrderAfter(current).Where(allWinners.Contains).DefaultIfEmpty(current).Last();
            var next = OrderAfter(resumeFrom).First(s => active[s]);
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
            if (!replacement)
                melds[seat] = melds[seat].Select(m => m with { AddedGangBlockedUntilOwnDraw = false }).ToList();
            var draw = wall[wallIndex++];
            hands[seat][draw]++;
            lastDrawTiles[seat] = draw;
            drawReasons[seat] = replacement ? "gang_draw" : "normal_draw";
            Record(seat, SichuanPublicEventType.Draw, draw);
            locks[seat] = -1; // Every own draw (including replacement) clears 顺胡.
            if (seat == state.SeatIndex) ownDraws++;
            if (IsLegalWinning(seat, hands[seat]))
            {
                var pointGangFlower = replacement && lastGangType == SichuanMeldType.MeldedGang;
                var type = pointGangFlower ? SichuanWinType.DianGangHua
                    : replacement ? SichuanWinType.GangSelfDraw : SichuanWinType.SelfDraw;
                var fan = _fans.Project(hands[seat], melds[seat], type);
                if (seat == state.SeatIndex && !pointGangFlower)
                {
                    ownSelfDraw = true;
                    selfDrawPayers = ActiveSeats().Count(s => s != seat);
                }
                AddWin(seat, pointGangFlower ? lastGangSource : -1, fan, type, draw);
                active[seat] = false;
                won[seat] = fan.HandScore;
                return true;
            }
            var selfView = Observe(seat, true);
            var concealedOptions = Enumerable.Range(0,27).Where(t => hands[seat][t]==4 && t/9!=state.DingQueSuits[seat] && melds[seat].Count<4).ToArray();
            var addedOptions = melds[seat].Where(m=>m.Type==SichuanMeldType.Peng && hands[seat][m.TileType]>0 && m.TileType/9!=state.DingQueSuits[seat]).Select(m=>m.TileType).ToArray();
            var selfChoice = wallIndex<wall.Length && (concealedOptions.Length>0 || addedOptions.Length>0)
                ? selfPolicy.DecideSelfAction(selfView,false,concealedOptions,addedOptions,
                    roundBrain:policyBrains[seat].Observe(selfView)) : null;
            if (wallIndex < wall.Length && melds[seat].Count < 4)
            {
                for (var quad = 0; quad < 27; quad++)
                {
                    if (selfChoice?.Action.ActionType != SichuanActionType.Gang || selfChoice.GangSubtype != "an_gang" || selfChoice.Action.TileType != quad) continue;
                    hands[seat][quad] -= 4;

                    publicVisible[quad] += 4;
                    melds[seat].Add(new(SichuanMeldType.ConcealedGang, quad, seat, 0));
                    Record(seat, SichuanPublicEventType.ConcealedGang, quad);
                    lastGangPayers = ActiveSeats().Where(s => s != seat).ToArray();
                    lastGangType = SichuanMeldType.ConcealedGang;
                    lastGangScoreEligible = true;
                    lastGangSource = seat;
                    Add(_settlement.ProjectScenario(new(GangEvents: new[] {
                        new SichuanGangScoreEvent(seat, lastGangType, lastGangPayers) })).ScoreChanges, "gang");
                    return DrawAndDiscard(seat, true, out discard);
                }
            }
            // Added Gang is considered from own known tiles, before observing
            // the replacement. Rob-Gang winners take priority over payment.
            var added = selfChoice?.Action.ActionType == SichuanActionType.Gang && selfChoice.GangSubtype == "add_gang"
                ? melds[seat].FindIndex(m => m.Type == SichuanMeldType.Peng && m.TileType == selfChoice.Action.TileType) : -1;
            if (added >= 0 && wallIndex < wall.Length)
            {
                var addedTile=melds[seat][added].TileType;
                var robbers = OrderAfter(seat).Where(s => active[s] && CanWin(s, addedTile, SichuanWinType.RobAddedGang)
                    && !Refuse(s, addedTile, SichuanWinType.RobAddedGang)).ToArray();
                if (robbers.Length > 0)
                {
                    foreach (var robber in robbers)
                    {
                        hands[robber][addedTile]++;
                        var fan = _fans.Project(hands[robber], melds[robber], SichuanWinType.RobAddedGang);
                        AddWin(robber, seat, fan, SichuanWinType.RobAddedGang, addedTile);
                        hands[robber][addedTile]--;
                        active[robber] = false;
                        won[robber] = fan.HandScore;
                    }
                    hands[seat][addedTile]--;
                    publicVisible[addedTile]++;
                    // The robbed tile is consumed; resume after the final winner.
                    current = robbers.Last();
                    return true;
                }
                hands[seat][addedTile]--;
                publicVisible[addedTile]++;
                melds[seat][added] = melds[seat][added] with { Type = SichuanMeldType.AddedGang };
                var addedGangScoreEligible = selfView.CurrentSeat == seat
                    && selfView.LastDrawOrigin == SichuanTileOrigin.Draw
                    && selfView.LastDrawTileType == addedTile;
                Record(seat, SichuanPublicEventType.AddedGang, addedTile, gangScoreEligible: addedGangScoreEligible);
                lastGangPayers = ActiveSeats().Where(s => s != seat).ToArray();
                lastGangType = SichuanMeldType.AddedGang;
                lastGangScoreEligible = addedGangScoreEligible;
                Add(_settlement.ProjectScenario(new(GangEvents: new[] {
                    new SichuanGangScoreEvent(seat, lastGangType, lastGangPayers, ScoreEligible: addedGangScoreEligible) })).ScoreChanges, "gang");
                afterGang = true;
                return DrawAndDiscard(seat, true, out discard);
            }
            var discardView = Observe(seat, true);
            discard = discardPolicy.DecideDiscard(discardView,false,policyBrains[seat].Observe(discardView)).Action.TileType;
            if (discard < 0) return true;
            hands[seat][discard]--;
            publicVisible[discard]++;
            Record(seat, SichuanPublicEventType.Discard, discard);
            return false;
        }
        void Record(int seat, SichuanPublicEventType kind, int value, bool refused=false, int source=-1, bool gangScoreEligible=true)
        {
            if (kind is SichuanPublicEventType.Discard or SichuanPublicEventType.Peng)
                lastDrawTiles[seat] = -1;
            if (kind == SichuanPublicEventType.Discard) rivers[seat].Add(value);
            if (kind is SichuanPublicEventType.Peng or SichuanPublicEventType.MeldedGang && source >= 0)
            {
                var claimed = rivers[source].LastIndexOf(value);
                if (claimed >= 0) rivers[source].RemoveAt(claimed);
            }
            observedEvents.Add(new(++eventIndex,state.TurnIndex+(int)eventIndex,seat,kind,value,
                SourceSeat:source>=0?source:current,WallCountAfter:wall.Length-wallIndex,
                CanHu:refused, GangScoreEligible:gangScoreEligible));
        }
        SichuanStateView Observe(int seat, bool acting = false)
        {
            // This is the only policy view: no sampled opponent hand or future
            // wall order is exposed. Concealed draw identities remain private.
            var view=new SichuanStateView {
                SeatIndex=seat,CurrentSeat=acting?seat:current,DealerSeat=state.DealerSeat,
                RoundIndex=state.RoundIndex, TotalRounds=state.TotalRounds, RemainingRounds=state.RemainingRounds,
                EventVersion=eventIndex,VisibleVersion=(int)eventIndex,HandVersion=(int)eventIndex,
                StrategyContextVersion=(int)eventIndex,PolicyVariant=state.PolicyVariant,
                Scores=state.Scores.Select((score,i)=>score+changes[i]).ToArray(),
                Discards18=rivers.Select(r=>r.ToList()).ToArray(),
                WonScores=Enumerable.Range(0,4).Select(i=>won.GetValueOrDefault(i,-1)).ToArray(),
                WallCount=wall.Length-wallIndex,TurnIndex=state.TurnIndex,
                Hand18=(int[])hands[seat].Clone(),Visible18=(int[])publicVisible.Clone(),
                Remaining18=PublicRemaining(hands[seat],publicVisible),
                DingQueSuits=(int[])state.DingQueSuits.Clone(),ActiveSeats=(bool[])active.Clone(),
                HasHu=Enumerable.Range(0,4).Select(i=>won.ContainsKey(i)).ToArray(),
                HandCounts=hands.Select(h=>h.Sum()).ToArray(),
                LastDrawTileType=acting?lastDrawTiles[seat]:-1,
                LastDrawOrigin=acting && lastDrawTiles[seat]>=0?SichuanTileOrigin.Draw:SichuanTileOrigin.Unknown,
                OwnDrawReason=acting?drawReasons[seat]??string.Empty:string.Empty,
                LastGangSeat=afterGang?current:-1,LastGangType=afterGang?lastGangType switch {
                    SichuanMeldType.AddedGang=>"add_gang",SichuanMeldType.ConcealedGang=>"an_gang",_=>"melded_gang"}:string.Empty,
                LastGangSourceSeat=lastGangSource,LastGangScoreEligible=lastGangScoreEligible,
                LockedFans=Enumerable.Range(0,4).Select(i=>i==seat?locks[i]:-1).ToArray()
            };
            for(var i=0;i<4;i++) {
                view.MeldViews[i].AddRange(melds[i]);
                foreach(var m in melds[i])view.Melds18[i].AddRange(Enumerable.Repeat(m.TileType,m.Type==SichuanMeldType.Peng?3:4));
            }
            view.PublicEvents.AddRange(observedEvents.Where(e=>e.Seat==seat || e.Type!=SichuanPublicEventType.Pass).Select(e=>e.Seat==seat ? e : e with {CanHu=false,CanPeng=false,CanGang=false,
                TileType=e.Type==SichuanPublicEventType.Draw?-1:e.TileType}));
            return view;
        }
        bool Refuse(int seat,int offered,SichuanWinType type)
        {
            if(!development.ShouldRefuse(Observe(seat),offered,type))return false;
            refusedLocks[seat]=locks[seat];
            hands[seat][offered]++;
            locks[seat]=_fans.Project(hands[seat],melds[seat],type).CappedFan;
            hands[seat][offered]--;
            Record(seat,SichuanPublicEventType.Pass,offered,true);
            if(seat==state.SeatIndex)strategicRefusals++;
            return true;
        }
        int Distance(int[] h, int m) => structural?.Best(h, m) ?? Shanten(h, m);
        bool CanWin(int seat, int candidate, SichuanWinType winType)
        {
            if (candidate < 0 || state.DingQueSuits[seat] == candidate / 9 || hands[seat][candidate] >= 4) return false;
            hands[seat][candidate]++;
            var result = IsLegalWinning(seat, hands[seat]);
            if (result && locks[seat] >= 0 && _fans.Project(hands[seat], melds[seat], winType).CappedFan <= locks[seat])
            {
                if (seat == state.SeatIndex) lockedRonDenied++;
                result = false;
            }
            hands[seat][candidate]--;
            return result;
        }
        bool IsLegalWinning(int seat, int[] hand) => !HasMissing(hand, state.DingQueSuits[seat]) && _hands.IsWinning(hand, melds[seat].Count);
        int[] ActiveSeats() => Enumerable.Range(0, 4).Where(s => active[s]).ToArray();
        void Add(int[] value, string category = "")
        {
            for (var s = 0; s < 4; s++) changes[s] += value[s];
            if (category == "gang") gangNet += value[state.SeatIndex];
            if (category == "draw") drawSettlement += value[state.SeatIndex];
        }
        void AddWin(int winner, int source, SichuanFanProjection fan, SichuanWinType type, int winningTile = -1)
        {
            var payment = _settlement.ProjectWin(winner, source, ActiveSeats(), fan, type).ScoreChanges;
            var own = payment[state.SeatIndex];
            if (winner == state.SeatIndex) winGain += own;
            else if (source == state.SeatIndex) dealInLoss -= own;
            else opponentLoss -= own;
            Add(payment);
            Record(winner, SichuanPublicEventType.Hu, winningTile >= 0 ? winningTile : state.LastDrawTileType,
                source: type is SichuanWinType.SelfDraw or SichuanWinType.GangSelfDraw or SichuanWinType.DianGangHua ? winner : source);
        }
        IReadOnlyList<SichuanGangRefundEvent> BuildRefunds(IReadOnlyList<SichuanDrawAssessment> assessments)
            => SichuanPublicGangRefunds.Build(observedEvents,assessments);
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
                var settlement = _settlement.ProjectScenario(new(DrawAssessments: assessments, GangRefunds: BuildRefunds(assessments)));
                Add(settlement.ChaJiaoChanges.Zip(settlement.HuaZhuChanges, (a,b) => a+b).ToArray(), "draw");
                Add(settlement.RefundChanges, "gang");
            }
            if (initialDecisionPending)
            {
                immediateScore = changes[state.SeatIndex];
                initialDecisionPending = false;
            }
            var netScore = changes[state.SeatIndex];
            var ownWon = won.ContainsKey(state.SeatIndex);
            var ownReady = !ownWon && !HasMissing(hands[state.SeatIndex], state.OwnDingQueSuit)
                && Distance(hands[state.SeatIndex], melds[state.SeatIndex].Count) == 0;
            return new SimulationOutcome(netScore, immediateScore, netScore - immediateScore, initialDealIn, ownWon, ownReady, ownPengClaims) {
                WinGain = winGain, GangNet = gangNet, DrawSettlement = drawSettlement,
                DealInLoss = dealInLoss, OpponentLoss = opponentLoss,
                OwnDraws = ownDraws, SelfDrawPayers = selfDrawPayers, OwnSelfDraw = ownSelfDraw,
                OwnStrategicRefusals = strategicRefusals, LockedRonDenied = lockedRonDenied,
                Events = observedEvents.ToArray()
            };
        }
    }

    private bool TryPrepare(
        SichuanStateView state,
        IEnumerable<int> discardTiles,
        int maximumWall,
        out int[] seats,
        out int[] tiles,
        out int ownMeldCount,
        bool includeExitedSeats = false,
        bool includeUnready = false)
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
        // Exited winners' concealed cards stay allocated, but their historical
        // Hu price creates no future cha-jiao payment or eligibility gate.
        var readyMeldCount = ownMeldCount;
        var forced = HasMissing(state.Hand18, state.OwnDingQueSuit) ? state.OwnDingQueSuit : -1;
        tiles = discardTiles.Distinct().Where(t => t is >= 0 and < 27 && state.Hand18[t] > 0
            && (forced < 0 || t / 9 == forced)).Where(t =>
            {
                if (includeUnready) return true;
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

    private static int[] ShuffledWall(SichuanHiddenHandParticle particle, int seed, IReadOnlyList<int>? tileOrder = null)
    {
        var wall = (tileOrder ?? Enumerable.Range(0,27).ToArray()).SelectMany(t => Enumerable.Repeat(t, particle.Wall27[t])).ToArray();
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

    internal readonly record struct DiscardCacheKey(ulong HandLow, ulong HandHigh,
        ulong VisibleLow, ulong VisibleHigh, int Melds, int Missing, int Preferred,
        int Wall, int Active, bool FlushLegal);

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
    private static IEnumerable<int> OrderAfter(int seat) => Enumerable.Range(1, 3).Select(offset => (seat - offset + 4) % 4);
    private static List<SichuanMeldView> Melds(SichuanStateView state, int seat) => state.MeldViews[seat].Count > 0
        ? state.MeldViews[seat].ToList()
        : state.Melds18[seat].GroupBy(t => t).Select(g => new SichuanMeldView(g.Count() >= 4 ? SichuanMeldType.MeldedGang : SichuanMeldType.Peng, g.Key, -1, 0)).ToList();
}
