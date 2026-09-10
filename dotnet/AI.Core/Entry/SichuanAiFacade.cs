using SichuanMahjong.AI.Core.Analysis;
using SichuanMahjong.AI.Core.Cache;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Strategy;

namespace SichuanMahjong.AI.Core.Entry;

public sealed class SichuanAiFacade
{
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

    private readonly SichuanDecisionEngine _decisionEngine = new();
    private readonly SichuanReactionDecisionEngine _reactionDecisionEngine = new();
    private readonly SichuanSelfActionDecisionEngine _selfActionDecisionEngine = new();
    private readonly SichuanDingQueDecisionEngine _dingQueDecisionEngine = new();
    private readonly SichuanDecisionCache _turnCache = new();
    private readonly SichuanRoundStrategyBrain _roundBrain = new();

    public SichuanDecisionResult DecideDiscard(SichuanStateView state)
    {
        var brain = _roundBrain.Observe(state);
        var result = _decisionEngine.DecideDiscard(state, false, brain);
        _roundBrain.RecordDiscard(state, result.Action.TileType, result.RoutePlan);
        return result;
    }

    public SichuanDecisionResult DecideDiscardCached(SichuanStateView state, bool preferCsharp = true, bool forceLightweight = false)
    {
        var brain = _roundBrain.Observe(state);
        var key = SichuanStateFingerprint.BuildTurnKey(state, preferCsharp, forceLightweight) + $"|brain={brain.Revision}";
        if (_turnCache.TryGet(key, out var cached))
        {
            return cached;
        }

        var result = _decisionEngine.DecideDiscard(state, forceLightweight, brain);
        _turnCache.Put(key, result);
        _roundBrain.RecordDiscard(state, result.Action.TileType, result.RoutePlan);
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
        var brain = _roundBrain.Observe(state);
        var result = _reactionDecisionEngine.DecideReaction(state, reactionTileType, canHu, canPeng, canGang, sourceSeat, reactionType, forceLightweight, mandatoryGang, brain);
        _roundBrain.RecordReaction(state, result.Action);
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
        var brain = _roundBrain.Observe(state);
        var result = _selfActionDecisionEngine.DecideSelfAction(state, canSelfHu, anGangTileTypes, addGangTileTypes, addGangQiangGangCounts, mandatoryGangTileTypes, brain);
        _roundBrain.RecordReaction(state, result.Action);
        return result;
    }

    public SichuanDingQueDecisionResult DecideDingQue(
        IReadOnlyDictionary<string, int> suitCounts,
        IReadOnlyList<string> activeSuits)
        => _dingQueDecisionEngine.DecideDingQue(suitCounts, activeSuits);

    public CacheSnapshot GetTurnCacheSnapshot() => _turnCache.Snapshot();
}
