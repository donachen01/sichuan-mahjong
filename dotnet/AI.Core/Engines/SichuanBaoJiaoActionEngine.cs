using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanBaoJiaoActionEngine
{
    public SichuanDecisionResult? TryDecideDiscard(SichuanStateView state) => null;

    public SichuanSelfActionDecisionResult? TryDecideSelfAction(
        SichuanStateView state,
        bool canSelfHu,
        IReadOnlyList<int> anGangTileTypes,
        IReadOnlyList<int> addGangTileTypes,
        IReadOnlyList<int>? mandatoryGangTileTypes = null) => null;

    public SichuanReactionDecisionResult? TryDecideReaction(
        SichuanStateView state,
        int reactionTileType,
        bool canHu,
        bool canPeng,
        bool canGang,
        bool mandatoryGang = false) => null;
}
