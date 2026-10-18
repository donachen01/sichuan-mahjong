using SichuanMahjong.AI.Core.Analysis;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Agents;

public sealed record AgentProposal(string Id, long ViewVersion, string Kind, string Action, int Tile, string Status);
public sealed record AgentOpponent(int Seat, int MissingSuit, bool Active, int[] Discards,
    SichuanOpeningObservation Opening, long[] EvidenceEvents)
{
    public double? ReadyEstimate { get; init; }
    public double? ThreatEstimate { get; init; }
    public double[] SuitDemand { get; init; } = Array.Empty<double>();
    public long InferenceViewVersion { get; init; }
}
public sealed record AgentPlan(int Revision, string PrimaryRoute, string FallbackRoute, int TargetSuit,
    int TablePhase, string HandPhase, int StandardDistance, int BestDistance, int MissingTiles,
    double RiskBudget, string Milestone, string[] SupportingEvidence, string[] SwitchConditions,
    long BasedOnViewVersion)
{
    public string StrategyVersion => SichuanStrategyContract.Version;
    public string Objective => SichuanStrategyContract.Objective;
    public bool? AllowsRonRefusal { get; init; }
    public SichuanDevelopmentPlan? DevelopmentPlan { get; init; }
    public SichuanDistinctDingQueHuAssessment? HuDiscipline { get; init; }
    public SichuanFlushPlanAssessment[] FlushRoutes { get; init; } = Array.Empty<SichuanFlushPlanAssessment>();
    public SichuanRouteContinuation[] RouteContinuations { get; init; } = Array.Empty<SichuanRouteContinuation>();
    public string RiskBudgetUnit => "heuristic_tolerance_0_1_not_probability";
    public bool EffectiveMetricsAvailable { get; init; }
    public int? SevenPairsDistance { get; init; }
    public int[] EffectiveTiles { get; init; } = Array.Empty<int>();
    public int UnseenEffectiveCopies { get; init; }
    public int ImprovementCopies { get; init; }
    public SichuanHandDevelopmentSummary? HandDevelopment { get; init; }
    public string[] CounterEvidence { get; init; } = Array.Empty<string>();
    public IReadOnlyDictionary<string, int> RouteWeights { get; init; } = new Dictionary<string, int>();
    public string ChangeReason { get; init; } = "initial";
}
public sealed record AgentSnapshot(string RoundId, long Generation, int Seat, string Status, long ViewVersion,
    int EventCount, AgentPlan? Plan, SichuanDingQueDecisionResult? OpeningDecision,
    AgentOpponent[] Opponents, AgentProposal? Proposal, string[] ConfirmedHistory)
{
    public AgentDecisionTrace[] Decisions { get; init; } = Array.Empty<AgentDecisionTrace>();
    public bool NeedsPlanRefresh => Plan?.BasedOnViewVersion != ViewVersion;
}

/// <summary>Round owner. Only filtered per-seat views enter the worker; no joint playing objective.</summary>
public sealed class SichuanRoundAgentHost
{
    public const string AlgorithmVersion = "round-agents-v29-flying-gang-route";
    private readonly object _gate = new();
    private Dictionary<int, SeatAgent> _seats = new();
    private string _roundId = "";
    private long _generation;
    private bool _active;

    private bool _researchRecording;
    /// <summary>Explicit research setting; fixed for the lifetime of a round.</summary>
    public bool ResearchRecordingEnabled
    {
        get { lock (_gate) return _researchRecording; }
        set { lock (_gate) { if (_active && value != _researchRecording) throw new InvalidOperationException("recording_mode_requires_round_boundary"); _researchRecording = value; } }
    }

    public void Begin(IReadOnlyList<SichuanStateView> views)
    {
        if (views.Count is < 1 or > 4 || views.Select(x => x.SeatIndex).Distinct().Count() != views.Count)
            throw new ArgumentException("invalid_agent_seats");
        var first = views[0];
        if (string.IsNullOrWhiteSpace(first.RoundId) || first.HostGeneration <= 0)
            throw new ArgumentException("missing_round_identity");
        if (views.Any(v => v.RoundId != first.RoundId || v.HostGeneration != first.HostGeneration))
            throw new ArgumentException("mixed_round_initialization");
        lock (_gate)
        {
            if (_active && _roundId == first.RoundId && _generation == first.HostGeneration)
            {
                if (!_seats.Keys.Order().SequenceEqual(views.Select(v => v.SeatIndex).Order()) ||
                    views.Any(v => !_seats[v.SeatIndex].SameInitial(v)))
                    throw new InvalidOperationException("conflicting_begin_round");
                return;
            }
            if (_active) throw new InvalidOperationException("end_previous_round_first");
            if (first.HostGeneration <= _generation) throw new InvalidOperationException("stale_generation");
            var prepared = new Dictionary<int, SeatAgent>();
            foreach (var view in views) { Validate(view); prepared.Add(view.SeatIndex, new SeatAgent(view, _researchRecording)); }
            _seats = prepared; _roundId = first.RoundId; _generation = first.HostGeneration; _active = true;
        }
    }

    public void End(string roundId, long generation)
    {
        lock (_gate)
        {
            if (roundId != _roundId || generation != _generation) throw new InvalidOperationException("stale_end_round");
            _active = false;
            foreach (var agent in _seats.Values) agent.Closed = true;
            _seats.Clear();
        }
    }

    private SeatAgent Resolve(SichuanStateView state)
    {
        lock (_gate)
        {
            if (!_active || state.RoundId != _roundId || state.HostGeneration != _generation)
                throw new InvalidOperationException("inactive_or_stale_round");
            if (!_seats.TryGetValue(state.SeatIndex, out var agent)) throw new InvalidOperationException("unregistered_agent_seat");
            return agent;
        }
    }

    public void Observe(SichuanStateView view)
    {
        var agent = Resolve(view);
        lock (agent.Gate) { agent.EnsureOpen(); agent.Observe(view); }
    }

    public T Run<T>(SichuanStateView view, string kind, Func<SichuanAiFacade, T> compute, Func<T, SichuanAction> action)
    {
        var agent = Resolve(view);
        lock (agent.Gate)
        {
            agent.EnsureOpen(); agent.Observe(view);
            if (view.HasHu[view.SeatIndex]) throw new InvalidOperationException("won_agent_cannot_act");
            using var cache = SichuanBeliefEngine.UseCache(agent.BeliefCache);
            agent.RefreshPlan(view);
            var result = compute(agent.Engine);
            agent.EnsureOpen(); // EndRound can invalidate an in-flight calculation without waiting for it.
            var selected = action(result);
            agent.Propose(kind, selected.ActionType.ToString(), selected.TileType);
            agent.RecordDecision(view, result!);
            return result;
        }
    }

    public SichuanDingQueDecisionResult DingQue(SichuanStateView view, IReadOnlyList<string> suits)
    {
        var agent = Resolve(view);
        lock (agent.Gate)
        {
            agent.EnsureOpen(); agent.Observe(view);
            using var cache = SichuanBeliefEngine.UseCache(agent.BeliefCache);
            var result = agent.Engine.DecideDingQue(view.Hand18, suits);
            agent.EnsureOpen(); agent.OpeningDecision = result;
            agent.RefreshPlan(view);
            agent.Propose("dingQue", result.Suit, -1);
            agent.RecordDecision(view, result);
            return result;
        }
    }

    public AgentSnapshot[] InspectAll()
    {
        SeatAgent[] agents;
        lock (_gate) agents = _seats.Values.ToArray();
        return agents.Select(agent => { lock (agent.Gate) return agent.Snapshot(); }).ToArray();
    }

    public AgentSnapshot Inspect(SichuanStateView identity)
    {
        var agent = Resolve(identity);
        lock (agent.Gate) return agent.Snapshot();
    }

    public SichuanAgentCheckpoint Capture(SichuanStateView view)
    {
        var agent = Resolve(view);
        lock (agent.Gate)
        {
            agent.EnsureOpen(); agent.Observe(view);
            using var cache = SichuanBeliefEngine.UseCache(agent.BeliefCache);
            agent.RefreshPlan(view);
            var brain = agent.Engine.ObservePlan(view);
            return new(1, SichuanRuleSnapshot.Version, AlgorithmVersion + ":" + view.PolicyVariant, view.RoundId, view.SeatIndex,
                view.ViewVersion, SichuanStateFingerprint.BuildTurnKey(view, true, false),
                new(brain.Revision, brain.Stage, brain.PrimaryRoute, brain.FallbackRoute, brain.TargetSuit,
                    brain.Commitment, new Dictionary<string, int>(brain.RouteWeights), brain.BrokenTriplets.ToArray(), brain.DecisionHistory.ToArray()),
                agent.Snapshot().OpeningDecision, agent.Snapshot().ConfirmedHistory) { Decisions = agent.Snapshot().Decisions };
        }
    }

    public void Restore(IReadOnlyList<SichuanStateView> views, IReadOnlyList<SichuanAgentCheckpoint> checkpoints)
    {
        if (checkpoints.Count != views.Count || checkpoints.Select(c => c.Seat).Distinct().Count() != views.Count)
            throw new ArgumentException("checkpoint_seats_mismatch");
        foreach (var view in views)
        {
            var checkpoint = checkpoints.SingleOrDefault(c => c.Seat == view.SeatIndex);
            if (checkpoint is null || checkpoint.SchemaVersion != 1 || checkpoint.RoundId != view.RoundId ||
                checkpoint.ViewVersion != view.ViewVersion || checkpoint.PolicyVersion != AlgorithmVersion + ":" + view.PolicyVariant ||
                checkpoint.RulesVersion != SichuanRuleSnapshot.Version ||
                checkpoint.ViewFingerprint != SichuanStateFingerprint.BuildTurnKey(view, true, false))
                throw new InvalidOperationException("incompatible_checkpoint_resync_required");
        }
        lock (_gate)
        {
            if (_active) throw new InvalidOperationException("end_previous_round_first");
            Begin(views);
            try
            {
                foreach (var view in views)
                {
                    var agent = _seats[view.SeatIndex];
                    var checkpoint = checkpoints.Single(c => c.Seat == view.SeatIndex);
                    using var cache = SichuanBeliefEngine.UseCache(agent.BeliefCache);
                    agent.Restore(view, checkpoint);
                }
            }
            catch { End(views[0].RoundId, views[0].HostGeneration); throw; }
        }
    }

    public int ActiveCount { get { lock (_gate) return _seats.Count; } }

    private static void Validate(SichuanStateView v)
    {
        if (v.SeatIndex is < 0 or > 3 || v.InformationMode != "public" || v.ViewVersion <= 0 ||
            v.Hand18.Length != 27 || v.Hand18.Any(n => n is < 0 or > 4)) throw new ArgumentException("invalid_public_agent_view");
        for (var seat = 0; seat < 4; seat++)
            if (seat != v.SeatIndex && (v.IsReady[seat] || v.PassedHu18[seat].Any(n => n != 0) ||
                v.PassedPeng18[seat].Any(n => n != 0) || v.PassedGang18[seat].Any(n => n != 0) || v.LockedFans[seat] >= 0))
                throw new ArgumentException("private_opponent_state_in_public_view");
        foreach (var e in v.PublicEvents)
            if (e.Seat != v.SeatIndex && ((e.Type == SichuanPublicEventType.Draw && e.TileType != -1) ||
                e.Type == SichuanPublicEventType.Pass || e.CanHu || e.CanPeng || e.CanGang))
                throw new ArgumentException("private_opponent_event_in_public_view");
    }

    private sealed class SeatAgent
    {
        public readonly object Gate = new();
        public readonly SichuanAiFacade Engine = new(true);
        public readonly SichuanBeliefEngine.ScopedCache BeliefCache = new();
        public volatile bool Closed;
        private readonly string _roundId;
        private readonly long _generation;
        private readonly int _seat;
        private readonly string _initial;
        private string _fingerprint = "";
        private long _viewVersion;
        private readonly List<SichuanPublicEvent> _events = new();
        private readonly List<string> _confirmed = new();
        private readonly List<AgentDecisionTrace> _decisions = new();
        private AgentOpponent[] _opponents = Array.Empty<AgentOpponent>();
        private AgentPlan? _plan;
        private AgentProposal? _proposal;
        private bool _won;
        private int _missing = -1;
        public SichuanDingQueDecisionResult? OpeningDecision;
        private readonly bool _recordResearch;
        public SeatAgent(SichuanStateView initial, bool recordResearch)
        {
            _recordResearch = recordResearch;
            _roundId = initial.RoundId; _generation = initial.HostGeneration; _seat = initial.SeatIndex;
            _initial = Fingerprint(initial); Observe(initial);
            using var cache = SichuanBeliefEngine.UseCache(BeliefCache);
            RefreshPlan(initial);
        }
        private static string Fingerprint(SichuanStateView v) => SichuanStateFingerprint.BuildTurnKey(v, true, false);
        public bool SameInitial(SichuanStateView v) => _initial == Fingerprint(v);
        public void EnsureOpen() { if (Closed) throw new InvalidOperationException("disposed_agent"); }
        public void Observe(SichuanStateView view)
        {
            Validate(view);
            var signature = Fingerprint(view);
            if (view.ViewVersion < _viewVersion) throw new InvalidOperationException("stale_observation");
            if (view.ViewVersion == _viewVersion)
            {
                if (signature != _fingerprint) throw new InvalidOperationException("conflicting_observation_version");
                return;
            }
            // Full filtered journal is the reliable resync path. No truncated journal is silently accepted.
            if (view.PublicEvents.Count < _events.Count) throw new InvalidOperationException("needs_resync_truncated_history");
            for (var i = 0; i < view.PublicEvents.Count; i++)
            {
                if (view.PublicEvents[i].EventIndex != i + 1) throw new InvalidOperationException("needs_resync_event_gap");
                if (i < _events.Count && view.PublicEvents[i] != _events[i]) throw new InvalidOperationException("conflicting_event_history");
            }
            foreach (var e in view.PublicEvents.Skip(_events.Count))
            {
                if (e.Seat == _seat)
                {
                    _confirmed.Add($"{e.EventIndex}:{e.Type}:{e.TileType}");
                    if (Enum.TryParse<SichuanActionType>(e.Type.ToString(), out var actionType))
                        Engine.ConfirmObservedAction(view, new SichuanAction(actionType, e.TileType));
                    else if (e.Type is SichuanPublicEventType.MeldedGang or SichuanPublicEventType.ConcealedGang or SichuanPublicEventType.AddedGang)
                        Engine.ConfirmObservedAction(view, new SichuanAction(SichuanActionType.Gang, e.TileType));
                    // A self-action Pass has no standalone game event. A later
                    // normal discard confirms that the offered gang was declined.
                    if (e.Type == SichuanPublicEventType.Discard)
                        for (var review = 0; review < _decisions.Count; review++)
                        {
                            var pending = _decisions[review];
                            if (pending.Kind == "self" && pending.Action == "Pass"
                                && pending.Status == "awaiting_discard_confirmation" && e.EventIndex > pending.EventIndex)
                                _decisions[review] = pending with { Status = "executed", ExecutionEvent = e.EventIndex,
                                    OutcomeViewVersion = view.ViewVersion, ObservedScoreDelta = view.Scores[_seat] - pending.PublicScores[_seat],
                                    OutcomeMeaning = "self_pass_confirmed_by_normal_discard" };
                        }
                    if (_proposal is { Status: "pending" } && Matches(_proposal, e))
                    {
                        CompleteTrace(view, "executed", e.EventIndex);
                        _proposal = _proposal with { Status = "executed" };
                    }
                    else if (_proposal is { Status: "pending" } && _proposal.Kind != "dingQue"
                        && e.Type != SichuanPublicEventType.Draw)
                    {
                        CompleteTrace(view, "different_action_observed", e.EventIndex);
                        _proposal = _proposal with { Status = "superseded" };
                    }
                }
            }
            if (_missing != view.OwnDingQueSuit && view.OwnDingQueSuit >= 0)
            {
                _confirmed.Add($"DingQueCommitted:{view.OwnDingQueSuit}");
                if (_proposal is { Kind: "dingQue", Status: "pending" })
                {
                    CompleteTrace(view, "executed", null);
                    _proposal = _proposal with { Status = "executed" };
                }
            }
            if (_proposal is { Status: "pending" } && signature != _fingerprint)
            {
                CompleteTrace(view, "superseded", null);
                _proposal = _proposal with { Status = "superseded" };
            }
            for (var review = 0; review < _decisions.Count; review++)
            {
                var trace = _decisions[review];
                if (trace.Status != "executed") continue;
                _decisions[review] = trace with { LatestReviewVersion = view.ViewVersion,
                    ScoreDeltaSinceDecision = view.Scores[_seat] - trace.PublicScores[_seat],
                    OwnWinObserved = view.HasHu[_seat] };
            }
            var openingChanged = _missing != view.OwnDingQueSuit;
            _missing = view.OwnDingQueSuit;
            _events.Clear(); _events.AddRange(view.PublicEvents);
            _viewVersion = view.ViewVersion; _fingerprint = signature; _won = view.HasHu[_seat];
            _opponents = Enumerable.Range(0, 4).Where(s => s != _seat).Select(s => new AgentOpponent(s,
                view.DingQueSuits[s], !view.HasHu[s], view.Discards18[s].ToArray(), SichuanOpeningObservation.Build(view, s),
                _events.Where(e => e.Seat == s).Select(e => e.EventIndex).ToArray())).ToArray();
            if (openingChanged && _plan is not null)
            {
                using var cache = SichuanBeliefEngine.UseCache(BeliefCache);
                RefreshPlan(view);
            }
        }
        private static bool Matches(AgentProposal p, SichuanPublicEvent e)
            => (string.Equals(p.Action, e.Type.ToString(), StringComparison.OrdinalIgnoreCase) ||
                (p.Action == "Gang" && e.Type is SichuanPublicEventType.MeldedGang or SichuanPublicEventType.ConcealedGang or SichuanPublicEventType.AddedGang))
                && (p.Tile < 0 || p.Tile == e.TileType);
        public void Propose(string kind, string action, int tile)
        {
            if (_proposal is { Status: "pending" } && _proposal.ViewVersion == _viewVersion && _proposal.Kind == kind &&
                _proposal.Action == action && _proposal.Tile == tile) return;
            if (_proposal is { Status: "pending" })
            {
                var previous = _decisions.FindLastIndex(d => d.Id == _proposal.Id);
                if (previous >= 0) _decisions[previous] = _decisions[previous] with {
                    Status = _proposal.Kind == "self" && _proposal.Action == "Pass" && kind == "discard"
                        ? "awaiting_discard_confirmation" : "replaced_proposal" };
            }
            _proposal = new($"{_roundId}:{_generation}:{_seat}:{_viewVersion}:{kind}:{action}:{tile}", _viewVersion, kind, action, tile, "pending");
        }
        public void RecordDecision(SichuanStateView view, object result)
        {
            if (!_recordResearch || _proposal is null || _decisions.Any(d => d.Id == _proposal.Id)) return;
            var evidence = SichuanDecisionJournal.Explain(result);
            _decisions.Add(new(_proposal.Id, view.ViewVersion, view.PublicEvents.LastOrDefault()?.EventIndex ?? 0,
                _proposal.Kind, _proposal.Action, _proposal.Tile, "pending", Fingerprint(view),
                SichuanStrategyContract.Version, _plan?.PrimaryRoute ?? "", _plan?.FallbackRoute ?? "",
                _plan?.SupportingEvidence.ToArray() ?? Array.Empty<string>(), evidence.Reasons, evidence.Candidates,
                view.Hand18.ToArray(), view.Scores.ToArray(), null, null, null, "pending_authoritative_execution")
            {
                ReviewFlags = evidence.Candidates.Length == 0 ? new[]{"candidate_evidence_unavailable"}
                    : evidence.Candidates.Any(c => c.Reasons.Length == 0)
                        ? new[]{"some_candidate_explanations_incomplete"} : Array.Empty<string>()
            });
        }
        private void CompleteTrace(SichuanStateView view, string status, long? eventIndex)
        {
            var index = _decisions.FindLastIndex(d => d.Id == _proposal?.Id);
            if (index < 0) return;
            var trace = _decisions[index];
            _decisions[index] = trace with { Status = status, ExecutionEvent = eventIndex,
                OutcomeViewVersion = view.ViewVersion, ObservedScoreDelta = view.Scores[_seat] - trace.PublicScores[_seat],
                OutcomeMeaning = "observed_until_view_not_causal_action_value_not_counterfactual" };
        }
        public void RefreshPlan(SichuanStateView view)
        {
            if (_plan?.BasedOnViewVersion == view.ViewVersion) return;
            var previous = _plan;
            var belief = new SichuanBeliefEngine().Build(view);
            var brain = Engine.ObservePlan(view);
            _opponents = _opponents.Select(o => o with {
                ReadyEstimate = belief.SeatReadyPosterior.GetValueOrDefault(o.Seat),
                ThreatEstimate = belief.SeatThreatScore.GetValueOrDefault(o.Seat),
                SuitDemand = Enumerable.Range(0, 3).Select(s => belief.SeatSuitDemand.GetValueOrDefault(o.Seat)?.GetValueOrDefault(s) ?? 0).ToArray(),
                InferenceViewVersion = view.ViewVersion
            }).ToArray();
            var clean = (int[])view.Hand18.Clone();
            var missing = view.OwnDingQueSuit;
            var missingCount = missing < 0 ? 0 : clean.Skip(missing * 9).Take(9).Sum();
            if (missing >= 0) Array.Clear(clean, missing * 9, 9);
            var shanten = new SichuanShantenEngine(); var melds = view.OwnMeldCount;
            var standard = shanten.CalcStandardShanten(clean, melds); var best = shanten.CalcBestShanten(clean, melds, melds == 0);
            var phase = missing < 0 ? "opening" : missingCount > 0 ? "clearing" : best <= 0 ? "ready" : best == 1 ? "one-away" : standard > 3 ? "building" : "improving";
            var development = new SichuanHandDevelopmentEngine().Analyze(view.Hand18, view.Remaining18,
                melds, missing, SichuanDevelopmentPolicy.Melds(view, view.SeatIndex), requireKnownMissingSuit: true);
            var effective = development.Summary.EffectiveTiles;
            var routeContinuations = missingCount == 0 && view.Hand18.Sum() + melds * 3 == 13
                ? new SichuanRouteContinuationEvaluator().Evaluate(view, (int[])view.Hand18.Clone(),
                    new SichuanWallAvailabilityEngine().Build(view, belief))
                : Array.Empty<SichuanRouteContinuation>();
            var strategy = phase == "ready" && view.Hand18.Sum() + melds * 3 == 13
                ? SichuanStrategyContract.Assess(view) : null;
            _plan = new(brain.Revision, brain.PrimaryRoute, brain.FallbackRoute, brain.TargetSuit, brain.Stage, phase,
                standard, best, missingCount, brain.RiskBudget,
                phase == "clearing" ? "清缺并保留合法发展空间" : phase == "ready" ? "比较听口收益与对手风险" : "减少结构距离并改善有效进张",
                brain.Reasons.ToArray(), new[] { "路线合法性失效时退出", "新路线优势超过连续策略切换门槛时换路", "摸牌机会与公开威胁变化时重估风险" }, view.ViewVersion)
            {
                AllowsRonRefusal = strategy?.AllowsRonRefusal,
                DevelopmentPlan = strategy?.Development,
                HuDiscipline = strategy?.Discipline,
                FlushRoutes = SichuanFlushPlanAssessment.Build(view),
                RouteContinuations = routeContinuations,
                EffectiveMetricsAvailable = missing >= 0 && missingCount == 0 && view.Hand18.Sum() + melds * 3 == 13,
                SevenPairsDistance = melds == 0 ? shanten.CalcSevenPairsShanten(clean) : null,
                EffectiveTiles = effective.ToArray(),
                UnseenEffectiveCopies = effective.Sum(t => view.Remaining18[t]),
                ImprovementCopies = development.Summary.ImprovementCopies,
                HandDevelopment = development.Summary,
                RouteWeights = new Dictionary<string, int>(brain.RouteWeights),
                CounterEvidence = brain.RouteWeights.Where(r => r.Key != brain.PrimaryRoute && r.Value > brain.RouteWeights.GetValueOrDefault(brain.PrimaryRoute)).Select(r => $"{r.Key}结构评分高于当前路线，待比较转换成本").ToArray(),
                ChangeReason = previous is null ? "initial" : previous.PrimaryRoute != brain.PrimaryRoute ? "route_changed_by_current_evidence" : "current_evidence_reassessed"
            };
            for (var review = 0; review < _decisions.Count; review++)
                if (_decisions[review].Status == "executed")
                    _decisions[review] = _decisions[review] with { LatestRoute = brain.PrimaryRoute,
                        LatestBestDistance = best, LatestReviewVersion = view.ViewVersion };
        }
        public void Restore(SichuanStateView view, SichuanAgentCheckpoint checkpoint)
        {
            Engine.RestorePlan(view, checkpoint.Brain);
            OpeningDecision = CopyOpening(checkpoint.OpeningDecision);
            _confirmed.Clear(); _confirmed.AddRange(checkpoint.ConfirmedHistory);
            _decisions.Clear();
            if (_recordResearch) _decisions.AddRange(checkpoint.Decisions.Select(d => d.Copy() with {
                Status = d.Status is "pending" or "awaiting_discard_confirmation" ? "invalidated_on_restore" : d.Status }));
            _proposal = null; // Pre-recovery proposals are never executable in the new generation.
            _plan = null;
            RefreshPlan(view);
        }
        private static SichuanDingQueDecisionResult? CopyOpening(SichuanDingQueDecisionResult? opening)
            => opening is null ? null : new() { Suit = opening.Suit, Score = opening.Score,
                KScoreBySuit = new Dictionary<string, int>(opening.KScoreBySuit),
                SuitCounts = new Dictionary<string, int>(opening.SuitCounts), Reasons = opening.Reasons.ToArray() };

        public AgentSnapshot Snapshot() => new(_roundId, _generation, _seat, Closed ? "disposed" : _won ? "won" : _missing < 0 ? "opening" : "playing",
            _viewVersion, _events.Count, _plan is null ? null : _plan with {
                DevelopmentPlan = _plan.DevelopmentPlan is null ? null : _plan.DevelopmentPlan with {
                    Reasons = (string[])_plan.DevelopmentPlan.Reasons.Clone(),
                    Representative = _plan.DevelopmentPlan.Representative is null ? null : _plan.DevelopmentPlan.Representative with {
                        WaitSuits = _plan.DevelopmentPlan.Representative.WaitSuits.ToArray(),
                        Reasons = _plan.DevelopmentPlan.Representative.Reasons.ToArray()
                    }
                },
                HuDiscipline = _plan.HuDiscipline is null ? null : _plan.HuDiscipline with { Reasons = _plan.HuDiscipline.Reasons.ToArray() },
                FlushRoutes = _plan.FlushRoutes.Select(f => f with {
                    EffectiveDraws = f.EffectiveDraws.ToArray(), BottleneckTiles = f.BottleneckTiles.ToArray(), Improvements = f.Improvements.ToArray()
                }).ToArray(),
                RouteContinuations = _plan.RouteContinuations.Select(r => r with { EffectiveDraws = r.EffectiveDraws.ToArray() }).ToArray(),
                HandDevelopment = _plan.HandDevelopment is null ? null : _plan.HandDevelopment with {
                    Routes = _plan.HandDevelopment.Routes.Select(r => r with { EffectiveTiles = r.EffectiveTiles.ToArray() }).ToArray(),
                    EffectiveTiles = _plan.HandDevelopment.EffectiveTiles.ToArray(),
                    StructuralImprovementTiles = _plan.HandDevelopment.StructuralImprovementTiles.ToArray(),
                    ValueImprovementTiles = _plan.HandDevelopment.ValueImprovementTiles.ToArray()
                },
                EffectiveTiles = _plan.EffectiveTiles.ToArray(), SupportingEvidence = _plan.SupportingEvidence.ToArray(),
                CounterEvidence = _plan.CounterEvidence.ToArray(), SwitchConditions = _plan.SwitchConditions.ToArray(),
                RouteWeights = new Dictionary<string, int>(_plan.RouteWeights)
            }, CopyOpening(OpeningDecision), _opponents.Select(o => o with {
                Discards = o.Discards.ToArray(), EvidenceEvents = o.EvidenceEvents.ToArray(), SuitDemand = o.SuitDemand.ToArray(),
                Opening = o.Opening with { RecentHandDiscards = o.Opening.RecentHandDiscards.ToArray(), RecentDrawDiscards = o.Opening.RecentDrawDiscards.ToArray() }
            }).ToArray(), _proposal, _confirmed.ToArray()) { Decisions = _decisions.Select(d => d.Copy()).ToArray() };
    }
}
