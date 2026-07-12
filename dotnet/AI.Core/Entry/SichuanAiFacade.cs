using SichuanMahjong.AI.Core.Analysis;
using SichuanMahjong.AI.Core.Cache;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Entry;

public sealed class SichuanAiFacade
{
    private readonly SichuanDecisionEngine _decisionEngine = new();
    private readonly SichuanReactionDecisionEngine _reactionDecisionEngine = new();
    private readonly SichuanSelfActionDecisionEngine _selfActionDecisionEngine = new();
    private readonly SichuanDingQueDecisionEngine _dingQueDecisionEngine = new();
    private readonly SichuanDecisionCache _turnCache = new();

    public SichuanDecisionResult DecideDiscard(SichuanStateView state) => _decisionEngine.DecideDiscard(state);

    public SichuanDecisionResult DecideDiscardCached(SichuanStateView state, bool preferCsharp = true, bool forceLightweight = false)
    {
        var key = SichuanStateFingerprint.BuildTurnKey(state, preferCsharp, forceLightweight);
        if (_turnCache.TryGet(key, out var cached))
        {
            return cached;
        }

        var result = _decisionEngine.DecideDiscard(state, forceLightweight);
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
        => _reactionDecisionEngine.DecideReaction(state, reactionTileType, canHu, canPeng, canGang, sourceSeat, reactionType, forceLightweight, mandatoryGang);

    public SichuanSelfActionDecisionResult DecideSelfAction(
        SichuanStateView state,
        bool canSelfHu,
        IReadOnlyList<int> anGangTileTypes,
        IReadOnlyList<int> addGangTileTypes,
        IReadOnlyDictionary<int, int>? addGangQiangGangCounts = null,
        IReadOnlyList<int>? mandatoryGangTileTypes = null)
        => _selfActionDecisionEngine.DecideSelfAction(state, canSelfHu, anGangTileTypes, addGangTileTypes, addGangQiangGangCounts, mandatoryGangTileTypes);

    public SichuanDingQueDecisionResult DecideDingQue(
        IReadOnlyDictionary<string, int> suitCounts,
        IReadOnlyList<string> activeSuits)
        => _dingQueDecisionEngine.DecideDingQue(suitCounts, activeSuits);

    public CacheSnapshot GetTurnCacheSnapshot() => _turnCache.Snapshot();
}
