using SichuanMahjong.AI.Core.Analysis;
using SichuanMahjong.AI.Core.Cache;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Strategy;
using SichuanMahjong.AI.Core.Domain;

namespace SichuanMahjong.AI.Core.Entry;

public sealed class SichuanAiFacade
{
    private readonly bool _seatWorker;
    private Agents.SichuanRoundAgentHost? _agents;
    public SichuanAiFacade() { }
    internal SichuanAiFacade(bool seatWorker) { _seatWorker = seatWorker; }
    public Agents.SichuanRoundAgentHost Agents => _agents ??= new();
    internal void RestorePlan(SichuanStateView state, Agents.AgentBrainMemory memory) => _roundBrain.Restore(state, memory);
    internal SichuanRoundBrainSnapshot ObservePlan(SichuanStateView state) => _roundBrain.Observe(state);
    internal void ConfirmObservedAction(SichuanStateView state, SichuanAction action) => _roundBrain.RecordReaction(state, action);

    // Explicit diagnostic entry, never an automatic policy override. The public
    // adapter rejects incomplete tile allocations and accepts no actual hidden wall.
    public Decision.SichuanPublicJointRouteReport AnalyzePublicJointRoutes(
        SichuanStateView state, int sampleCount, int seed)
        => new Decision.SichuanPublicJointRouteAnalysis().Analyze(state, sampleCount, seed);

    // Calibration-only entry. It exposes public posterior summaries and cannot
    // mutate candidate scores or accept post-decision hidden information.
    public Decision.SichuanPublicPosteriorReport AnalyzePublicPosterior(
        SichuanStateView state, int sampleCount, int seed)
        => new Decision.SichuanPublicPosteriorAnalysis().Analyze(state, sampleCount, seed);

    public Decision.SichuanPublicPosteriorEnsembleReport AnalyzePublicPosteriorSeedEnsemble(
        SichuanStateView state, int sampleCountPerSeed, int baseSeed, int seedCount = 6)
        => new Decision.SichuanPublicPosteriorAnalysis().AnalyzeSeedEnsemble(
            state, sampleCountPerSeed, baseSeed, seedCount);

    // Long-horizon blood-battle diagnostic. This is deliberately separate from
    // DecideDiscard: an uncalibrated video-derived mechanism cannot change play.
    public Decision.SichuanPublicContinuationReport AnalyzePublicContinuation(
        SichuanStateView state,
        IEnumerable<int> discardTiles,
        int maximumWall = 32,
        int sampleCount = 128,
        int seed = 20260909)
        => new Decision.SichuanPublicEndgameEvaluator().AnalyzeContinuation(
            state, discardTiles, maximumWall, sampleCount, seed);

    // Explicit test/research entry; live reaction decisions never call this.
    public Decision.SichuanHuContinuationReport AnalyzePublicHuContinuation(
        SichuanStateView state, int tile, int sourceSeat, string reactionType = "discard",
        int samples = 128, int seed = 20261002, int pengDiscard = -1, bool canGang = false)
        => new Decision.SichuanPublicEndgameEvaluator().AnalyzeHuContinuation(
            state, tile, sourceSeat, reactionType, samples, seed, pengDiscard, canGang);

    private readonly SichuanDecisionEngine _decisionEngine = new();
    private readonly SichuanReactionDecisionEngine _reactionDecisionEngine = new();
    private readonly SichuanSelfActionDecisionEngine _selfActionDecisionEngine = new();
    private readonly SichuanDingQueDecisionEngine _dingQueDecisionEngine = new();
    private readonly SichuanDecisionCache _turnCache = new();
    private readonly SichuanRoundStrategyBrain _roundBrain = new();

    public SichuanDecisionResult DecideDiscard(SichuanStateView state)
    {
        if (!_seatWorker && state.RoundId.Length > 0)
            return Agents.Run(state, "discard", engine => engine.DecideDiscard(state), r => r.Action);
        var brain = _roundBrain.Observe(state);
        using var planScope = Decision.SichuanPolicyExecutionScope.UseOwnPlan(brain);
        var result = _decisionEngine.DecideDiscard(state, false, brain);
        return result;
    }

    public SichuanDecisionResult DecideDiscardCached(SichuanStateView state, bool preferCsharp = true, bool forceLightweight = false)
    {
        if (!_seatWorker && state.RoundId.Length > 0)
            return Agents.Run(state, "discard", engine => engine.DecideDiscardCached(state, preferCsharp, forceLightweight), r => r.Action);
        var brain = _roundBrain.Observe(state);
        using var planScope = Decision.SichuanPolicyExecutionScope.UseOwnPlan(brain);
        var key = SichuanStateFingerprint.BuildTurnKey(state, preferCsharp, forceLightweight) + $"|brain={brain.Revision}";
        if (_turnCache.TryGet(key, out var cached))
        {
            return cached;
        }

        var result = _decisionEngine.DecideDiscard(state, forceLightweight, brain);
        _turnCache.Put(key, result);
        return result;
    }

    public SichuanReactionDecisionResult DecideReaction(
        SichuanStateView state,
        int reactionTileType,
        bool canHu,
        bool canPeng,
        bool canGang,
        int sourceSeat = -1,
        string reactionType = "discard",
        bool forceLightweight = false,
        bool mandatoryGang = false)
    {
        if (!_seatWorker && state.RoundId.Length > 0)
            return Agents.Run(state, "reaction", engine => engine.DecideReaction(state, reactionTileType, canHu, canPeng, canGang, sourceSeat, reactionType, forceLightweight, mandatoryGang), r => r.Action);
        var brain = _roundBrain.Observe(state);
        using var planScope = Decision.SichuanPolicyExecutionScope.UseOwnPlan(brain);
        var result = _reactionDecisionEngine.DecideReaction(state, reactionTileType, canHu, canPeng, canGang, sourceSeat, reactionType, forceLightweight, mandatoryGang, brain);
        return result;
    }

    public SichuanSelfActionDecisionResult DecideSelfAction(
        SichuanStateView state,
        bool canSelfHu,
        IReadOnlyList<int> anGangTileTypes,
        IReadOnlyList<int> addGangTileTypes,
        IReadOnlyDictionary<int, int>? addGangQiangGangCounts = null,
        IReadOnlyList<int>? mandatoryGangTileTypes = null)
    {
        if (!_seatWorker && state.RoundId.Length > 0)
            return Agents.Run(state, "self", engine => engine.DecideSelfAction(state, canSelfHu, anGangTileTypes, addGangTileTypes, addGangQiangGangCounts, mandatoryGangTileTypes), r => r.Action);
        var brain = _roundBrain.Observe(state);
        using var planScope = Decision.SichuanPolicyExecutionScope.UseOwnPlan(brain);
        var result = _selfActionDecisionEngine.DecideSelfAction(state, canSelfHu, anGangTileTypes, addGangTileTypes, addGangQiangGangCounts, mandatoryGangTileTypes, brain);
        return result;
    }

    public SichuanDingQueDecisionResult DecideDingQue(
        IReadOnlyDictionary<string, int> suitCounts,
        IReadOnlyList<string> activeSuits)
        => _dingQueDecisionEngine.DecideDingQue(suitCounts, activeSuits);

    public SichuanDingQueDecisionResult DecideDingQue(
        IReadOnlyList<int> hand18,
        IReadOnlyList<string> activeSuits)
        => _dingQueDecisionEngine.DecideDingQue(hand18, activeSuits);

    public SichuanDingQueDecisionResult DecideDingQue(SichuanStateView state, IReadOnlyList<string> suits)
        => Agents.DingQue(state, suits);

    public CacheSnapshot GetTurnCacheSnapshot() => _turnCache.Snapshot();
}
