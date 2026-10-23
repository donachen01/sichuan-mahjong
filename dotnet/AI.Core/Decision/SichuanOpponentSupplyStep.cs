using System.Diagnostics;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanOpponentSupplyReport(string Status, int Samples, double MinimumEffectiveSamples,
    double ElapsedMs, IReadOnlyDictionary<int, SichuanActionTreeEvaluator.ChanceSearchResult> Chances,
    int HeldTileOffers = 0, int DrawnTileOffers = 0)
{
    public IReadOnlyDictionary<int, int> HeldOffersByDiscard { get; init; } = new Dictionary<int, int>();
    public IReadOnlyDictionary<int, int> DrawnOffersByDiscard { get; init; } = new Dictionary<int, int>();
}

/// <summary>A bounded first-opponent transition, followed by the existing fixed
/// wait race. Latent allocations come only from the public posterior; the actor
/// sees its own sampled hand, public events and wall SIZE, never another hand or
/// the sampled wall. This is not a calibrated full-game probability or terminal
/// rollout. Later voluntary releases, claims and Gang remain outside this step.</summary>
public sealed class SichuanOpponentSupplyStep
{
    internal static SichuanOpponentSupplyReport? RootReport(SichuanStateView state)
        => SichuanSearchBudget.IsRoot(state) && !SichuanDiscardPolicy.AtSearchLeaf
            ? SichuanPolicyExecutionScope.ReadMemoized<SichuanOpponentSupplyReport>(
                "opponent-supply-root", SichuanDecisionCommand.Fingerprint(state)) : null;

    internal static string Reason(SichuanOpponentSupplyReport r, int discard)
        => $"PUBLIC_SUPPLY_{r.Status}_N{r.Samples}_ESS{r.MinimumEffectiveSamples:F1}_MS{r.ElapsedMs:F1}_HELD{r.HeldOffersByDiscard.GetValueOrDefault(discard)}_DRAWN{r.DrawnOffersByDiscard.GetValueOrDefault(discard)}";

    internal static string[] RootReasons(SichuanStateView state, int discard)
        => RootReport(state) is { } r && r.Status != "outside_conditional_supply_scope"
            ? [Reason(r, discard)] : [];

    public SichuanOpponentSupplyReport Refine(SichuanStateView state,
        IReadOnlyDictionary<int, SichuanReadyPrice> ready,
        IReadOnlyDictionary<int, SichuanActionTreeEvaluator.ChanceSearchRequest> requests)
    {
        // Self-action pricing and the committed discard revisit this SAME root.
        // Keep the single budgeted estimate, rather than spend its budget and
        // then silently replace it with the old race on the second visit.
        if (SichuanDiscardPolicy.AtSearchLeaf || !SichuanSearchBudget.IsRoot(state))
            return new("outside_conditional_supply_scope", 0, 0, 0,
                new Dictionary<int, SichuanActionTreeEvaluator.ChanceSearchResult>());
        return SichuanPolicyExecutionScope.Memoize("opponent-supply-root",
            SichuanDecisionCommand.Fingerprint(state), () => Compute(state, ready, requests));
    }

    private SichuanOpponentSupplyReport Compute(SichuanStateView state,
        IReadOnlyDictionary<int, SichuanReadyPrice> ready,
        IReadOnlyDictionary<int, SichuanActionTreeEvaluator.ChanceSearchRequest> requests)
    {
        var watch = Stopwatch.StartNew();
        SichuanOpponentSupplyReport No(string status, int samples = 0, double ess = 0) =>
            new(status, samples, ess, watch.Elapsed.TotalMilliseconds,
                new Dictionary<int, SichuanActionTreeEvaluator.ChanceSearchResult>());
        if (state.InformationMode != "public" || state.WallCount is < 2 or > 20
            || ready.Count != 2 || state.LockedFans[state.SeatIndex] >= 0
            || SichuanDiscardPolicy.AtSearchLeaf || !SichuanSearchBudget.IsRoot(state)
            || !ready.Values.Any(p => p.Waits.Any(w => state.Remaining18[w.TileType] is > 0 and <= 2
                && SichuanKeyTileRetention.Assess(state, w.TileType).Grade is "S" or "A" or "B")))
            return No("outside_conditional_supply_scope");
        if (!SichuanPublicInferenceBoundary.TryProject(state, out var projection, out var reason))
            return No("public_projection_" + reason);
        // This step starts at the next draw; a possible Peng/Gang on our
        // discard would change that turn order and needs a reaction model.
        if (ready.Keys.Any(t => state.Remaining18[t] >= 2
            && Enumerable.Range(0, 4).Any(s => s != state.SeatIndex && state.ActiveSeats[s]
                && !state.HasHu[s] && state.DingQueSuits[s] != t / 9)))
            return No("root_claim_outside_step");
        var actor = Enumerable.Range(1, 3).Select(o => (state.SeatIndex - o + 4) % 4)
            .First(s => state.ActiveSeats[s] && !state.HasHu[s]);
        // The same production policy on 32 thirteen-tile actor branches was
        // measured at 1-2 seconds, often only to reject an unstable estimate.
        // Bound work using public hand size, before spending the root budget.
        // Two exposed melds leave at most seven concealed tiles before draw.
        if (state.HandCounts[actor] > 7) return No("actor_hand_outside_bounded_step");
        using var allocation = SichuanSearchBudget.TryDeep(state, "SEARCH_DEEP_PUBLIC_OPPONENT_SUPPLY");
        if (allocation is null) return No("budget_not_allocated");
        using var timing = SichuanPolicyTiming.Measure("public_opponent_supply_step");
        var batches = new List<Dictionary<int, SichuanActionTreeEvaluator.ChanceSearchResult>>();
        double minimumEss = double.PositiveInfinity;
        int count = 0, heldOffers = 0, drawnOffers = 0;
        var heldByDiscard = ready.Keys.ToDictionary(t => t, _ => 0);
        var drawnByDiscard = ready.Keys.ToDictionary(t => t, _ => 0);
        for (var batch = 0; batch < 2; batch++)
        {
            var seed = 20261020 ^ state.RoundIndex ^ (state.SeatIndex << 8) ^ state.TurnIndex ^ (batch * 7919);
            var particles = new SichuanHiddenHandInferenceEngine().SampleParticles(projection, 32, seed,
                SichuanHiddenHandProposal.PublicPriorThenLikelihood);
            if (particles.Count != 32 || particles.Any(p => !SichuanPublicInferenceBoundary.ParticleConserves(state, p)))
                return No("public_sample_conservation_rejected", count);
            var mass = particles.Sum(p => p.Weight);
            var ess = mass * mass / particles.Sum(p => p.Weight * p.Weight);
            if (!double.IsFinite(ess) || ess < 8) return No("insufficient_effective_samples", count, ess);
            var random = new Random(seed ^ 104729);
            // Systematic weighted resampling bounds policy calls to eight
            // worlds per seed while keeping the posterior, rather than taking
            // an unrepresentative prefix or evaluating all 32 expensive hands.
            var selected = new List<int>();
            var offset = random.NextDouble() / 8;
            var cumulative = particles[0].Weight / mass; var index = 0;
            for (var i = 0; i < 8; i++)
            {
                var position = offset + i / 8.0;
                while (position > cumulative && index < particles.Count - 1)
                    cumulative += particles[++index].Weight / mass;
                selected.Add(index);
            }
            var resampledEss = 64.0 / selected.GroupBy(i => i).Sum(g => g.Count() * g.Count());
            minimumEss = Math.Min(minimumEss, Math.Min(ess, resampledEss));
            if (resampledEss < 4) return No("insufficient_resampled_worlds", count, minimumEss);
            var outcomes = ready.Keys.ToDictionary(t => t,
                _ => new List<(SichuanActionTreeEvaluator.ChanceSearchResult Value, double Weight)>());
            foreach (var selectedIndex in selected)
            {
                var particle = particles[selectedIndex];
                var draw = Draw(particle.Wall27, random.Next(state.WallCount));
                foreach (var (discard, price) in ready)
                {
                    var result = Evaluate(state, particle, actor, draw, discard, price, requests[discard],
                        out var held, out var drawn);
                    // A Gang changes the replacement draw/rob window. Do not
                    // silently replace that event with a discard, or renormalize
                    // away difficult samples: retain the existing model for ALL
                    // candidates when this bounded transition cannot model it.
                    if (result is null) return No("gang_transition_outside_step", count, minimumEss);
                    heldOffers += held ? 1 : 0; drawnOffers += drawn ? 1 : 0;
                    heldByDiscard[discard] += held ? 1 : 0; drawnByDiscard[discard] += drawn ? 1 : 0;
                    outcomes[discard].Add((result, 1.0 / selected.Count));
                    count++;
                }
            }
            batches.Add(outcomes.ToDictionary(p => p.Key, p => Mix(p.Value)));
        }
        var keys = ready.Keys.Order().ToArray();
        // A seed-agreement filter, not a confidence interval or calibration
        // certificate. Avoid changing a root comparison on opposing samples.
        double Difference(int b) => batches[b][keys[0]].ExpectedNetScore - batches[b][keys[1]].ExpectedNetScore;
        double WinDifference(int b) => batches[b][keys[0]].OwnWinProbability - batches[b][keys[1]].OwnWinProbability;
        if (Math.Sign(Difference(0)) != Math.Sign(Difference(1))
            || Math.Sign(WinDifference(0)) != Math.Sign(WinDifference(1)))
            return No("seed_comparison_unstable", count, minimumEss);
        var chances = keys.ToDictionary(k => k, k => Mix(batches.Select(b => (b[k], .5))));
        return new("public_first_opponent_step", count, minimumEss, watch.Elapsed.TotalMilliseconds,
            chances, heldOffers, drawnOffers)
        { HeldOffersByDiscard = heldByDiscard, DrawnOffersByDiscard = drawnByDiscard };
    }

    private static SichuanActionTreeEvaluator.ChanceSearchResult? Evaluate(SichuanStateView source,
        SichuanHiddenHandParticle particle, int actor, int draw, int discard, SichuanReadyPrice ready,
        SichuanActionTreeEvaluator.ChanceSearchRequest original, out bool held, out bool drawn)
    {
        held = drawn = false;
        var after = SichuanBranchState.AfterDiscard(source, discard);
        // Transport EventVersion is a content stamp, not an event ordinal.
        var ordinal = source.PublicEvents.Select(e => e.EventIndex).DefaultIfEmpty(0).Max() + 1;
        after.PublicEvents[^1] = after.PublicEvents[^1] with { EventIndex = ordinal };
        after.EventVersion = ordinal;
        var hand = (int[])particle.Hands27[actor].Clone(); hand[draw]++;
        var view = ActorView(after, actor, hand, draw);
        var legal = SichuanOwnTurnActions.FromState(view);
        if (legal.Concealed.Length > 0 || legal.Added.Length > 0) return null;
        var wall = (int[])particle.Wall27.Clone(); wall[draw]--;
        if (legal.CanHu)
        {
            var loss = new SichuanFanProjectionEngine().Project(hand,
                SichuanDevelopmentPolicy.Melds(view, actor), SichuanWinType.SelfDraw).PerPayerScore;
            after.ActiveSeats[actor] = false; after.HasHu[actor] = true;
            var tail = Tail(after, ready, original, wall);
            return tail with { OpponentWinProbability = 1, ExpectedOpponentLoss = tail.ExpectedOpponentLoss + loss,
                ExpectedNetScore = tail.ExpectedNetScore - loss };
        }
        SichuanDecisionResult decision;
        var beforeView = SichuanBranchState.Copy(view, particle.Hands27[actor], source.WallCount, source.SeatIndex);
        beforeView.HandCounts[actor] = particle.Hands27[actor].Sum();
        beforeView.LastDrawTileType = -1; beforeView.LastDrawOrigin = SichuanTileOrigin.Unknown;
        beforeView.OwnDrawReason = ""; beforeView.PublicEvents.RemoveAt(beforeView.PublicEvents.Count - 1);
        for (var t = 0; t < 27; t++) beforeView.Remaining18[t] = 4 - beforeView.Visible18[t] - beforeView.Hand18[t];
        var brain = new SichuanRoundBrainEngine(); brain.Observe(beforeView);
        var actorPlan = brain.Observe(view);
        using (SichuanPolicyExecutionScope.UseOwnPlan(null))
            decision = SichuanDiscardPolicy.Select(view, actorPlan, searchLeaf: true);
        var offered = decision.Action.TileType;
        if (offered is < 0 or > 26 || hand[offered] <= 0)
            throw new InvalidOperationException("opponent_supply_selected_illegal_discard");
        var win = ready.Waits.FirstOrDefault(w => w.TileType == offered);
        if (win is not null)
        {
            drawn = offered == draw; held = !drawn;
            return new(win.HandScore, 1, 0, 0, 0, 0, 0, 0)
            { ExpectedOwnWinGain = win.HandScore, DiscardHuProbability = 1, ExpectedDiscardHuGain = win.HandScore };
        }
        return Tail(after, ready, original, wall);
    }

    private static SichuanActionTreeEvaluator.ChanceSearchResult Tail(SichuanStateView after,
        SichuanReadyPrice ready, SichuanActionTreeEvaluator.ChanceSearchRequest original, int[] wall)
    {
        var active = after.ActiveSeats.Count(a => a);
        if (active == 1) return new(0, 0, 1, 0, 0, 0, 0, 0) { BattleEndProbability = 1 };
        var waits = ready.Waits.Select(w => w with { PublicWallWeight = wall[w.TileType] }).ToArray();
        var mass = waits.Sum(w => w.PublicWallWeight);
        var priced = new SichuanReadyPrice(waits, mass, ready.WeightedFan, ready.WeightedHandScore,
            mass > 0 ? waits.Sum(w => w.PublicWallWeight * w.SelfDrawPerPayer) / mass : 0);
        // All originally later actors still precede us even if the first
        // opponent just Hu'd and exited the turn order.
        var beforeOwn = Math.Max(0, original.ActivePlayers - 2);
        return new SichuanActionTreeEvaluator().SearchChanceNodes(original with {
            LiveTiles = mass, WallTiles = wall.Sum(), ActivePlayers = active,
            OwnTurnOffset = beforeOwn, MaxDraws = wall.Sum(),
            WinScore = priced.WeightedSelfDrawPerPayer * (active - 1),
            ChaJiaoValue = original.ChaJiaoValue * (active - 1) / (original.ActivePlayers - 1),
            ReadyGroups = SichuanReadyRaceSupply.Build(after, priced)
        });
    }

    internal static SichuanStateView ActorView(SichuanStateView after, int actor, int[] hand, int draw)
    {
        var v = SichuanBranchState.Copy(after, hand, after.WallCount - 1, actor, actor);
        v.RoundId = ""; v.Phase = 5; v.HandCounts[actor] = hand.Sum();
        v.LastDrawTileType = draw; v.LastDrawOrigin = SichuanTileOrigin.Draw; v.OwnDrawReason = "normal_draw";
        Array.Fill(v.LockedFans, -1); Array.Fill(v.LockTurns, -1); Array.Clear(v.UnlockOnOwnDraw);
        Array.Clear(v.IsReady);
        for (var seat = 0; seat < 4; seat++)
        {
            Array.Clear(v.PassedHu18[seat]); Array.Clear(v.PassedPeng18[seat]); Array.Clear(v.PassedGang18[seat]);
            v.IsCalled[seat] = v.MeldCount(seat) > 0;
        }
        for (var t = 0; t < 27; t++) v.Remaining18[t] = 4 - v.Visible18[t] - hand[t];
        v.PublicEvents.Clear();
        v.PublicEvents.AddRange(after.PublicEvents.Where(e => e.Type != SichuanPublicEventType.Pass)
            .Select(e => e with { TileType = e.Type == SichuanPublicEventType.Draw ? -1 : e.TileType,
                CanHu = false, CanPeng = false, CanGang = false }));
        var index = v.PublicEvents.Select(e => e.EventIndex).DefaultIfEmpty(0).Max() + 1;
        v.PublicEvents.Add(new(index, after.TurnIndex, actor, SichuanPublicEventType.Draw, draw,
            SichuanTileOrigin.Draw, WallCountAfter: v.WallCount));
        v.EventVersion = index;
        // A later own draw ends the immediate-Peng added-Gang prohibition.
        for (var i = 0; i < v.MeldViews[actor].Count; i++)
            v.MeldViews[actor][i] = v.MeldViews[actor][i] with { AddedGangBlockedUntilOwnDraw = false };
        return v;
    }

    private static int Draw(int[] wall, int position)
    {
        for (var t = 0; t < 27; t++) { if (position < wall[t]) return t; position -= wall[t]; }
        throw new InvalidOperationException("public_supply_draw_outside_wall");
    }

    private static SichuanActionTreeEvaluator.ChanceSearchResult Mix(
        IEnumerable<(SichuanActionTreeEvaluator.ChanceSearchResult Value, double Weight)> source)
    {
        var a = source.ToArray(); var total = a.Sum(x => x.Weight);
        double M(Func<SichuanActionTreeEvaluator.ChanceSearchResult, double> f) => a.Sum(x => x.Weight * f(x.Value)) / total;
        return new(M(x => x.ExpectedNetScore), M(x => x.OwnWinProbability), M(x => x.OpponentWinProbability),
            M(x => x.DrawProbability), M(x => x.ExpectedGangGain), 0, M(x => x.ElapsedMilliseconds), M(x => x.HorizonProbability))
        {
            ExpectedOwnWinGain = M(x => x.ExpectedOwnWinGain), SelfDrawWinProbability = M(x => x.SelfDrawWinProbability),
            DiscardHuProbability = M(x => x.DiscardHuProbability), ExpectedSelfDrawGain = M(x => x.ExpectedSelfDrawGain),
            ExpectedDiscardHuGain = M(x => x.ExpectedDiscardHuGain), ExpectedOpponentLoss = M(x => x.ExpectedOpponentLoss),
            ExpectedChaJiaoValue = M(x => x.ExpectedChaJiaoValue), ExpectedContinuationValue = M(x => x.ExpectedContinuationValue),
            BattleEndProbability = M(x => x.BattleEndProbability)
        };
    }
}
