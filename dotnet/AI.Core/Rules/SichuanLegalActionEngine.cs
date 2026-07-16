using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Rules;

public sealed class SichuanLegalActionEngine
{
    public IReadOnlyList<SichuanAction> BuildDiscardActions(SichuanStateView state)
    {
        var ownDingQue = state.OwnDingQueSuit;
        var hasDingQueTiles = ownDingQue is >= 0 and < 3
            && Enumerable.Range(ownDingQue * 9, 9).Any(tile => state.Hand18[tile] > 0);
        var actions = new List<SichuanAction>();
        for (var tile = 0; tile < 27; tile++)
        {
            if (state.Hand18[tile] <= 0) continue;
            if (hasDingQueTiles && tile / 9 != ownDingQue) continue;
            actions.Add(new SichuanAction(SichuanActionType.Discard, tile, Reason: hasDingQueTiles ? "DING_QUE_FIRST" : "LEGAL_DISCARD"));
        }
        return actions;
    }

    public IReadOnlyList<SichuanAction> BuildReactionActions(int tileType, bool canHu, bool canGang, bool canPeng)
    {
        var actions = new List<SichuanAction> { new(SichuanActionType.Pass, tileType, Reason: "LEGAL_PASS") };
        if (canHu) actions.Add(new SichuanAction(SichuanActionType.Hu, tileType, Reason: "LEGAL_DISCARD_HU"));
        if (canGang) actions.Add(new SichuanAction(SichuanActionType.Gang, tileType, Reason: "LEGAL_MELDED_GANG"));
        if (canPeng) actions.Add(new SichuanAction(SichuanActionType.Peng, tileType, Reason: "LEGAL_PENG"));
        return actions;
    }

    public IReadOnlyList<SichuanAction> BuildSelfActions(bool canSelfHu, IEnumerable<int> concealedGangTiles, IEnumerable<int> addedGangTiles)
    {
        var actions = new List<SichuanAction> { new(SichuanActionType.Pass, Reason: "LEGAL_CONTINUE_TO_DISCARD") };
        if (canSelfHu) actions.Add(new SichuanAction(SichuanActionType.Hu, Reason: "LEGAL_SELF_DRAW_HU"));
        actions.AddRange(concealedGangTiles.Distinct().Select(tile => new SichuanAction(SichuanActionType.Gang, tile, Reason: "LEGAL_CONCEALED_GANG")));
        actions.AddRange(addedGangTiles.Distinct().Select(tile => new SichuanAction(SichuanActionType.Gang, tile, Reason: "LEGAL_ADDED_GANG")));
        return actions;
    }
}
