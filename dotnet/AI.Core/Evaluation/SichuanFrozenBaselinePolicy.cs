using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Evaluation;

/// <summary>Stable pre-ActionValue policy used only as an offline/benchmark opponent.</summary>
public sealed class SichuanFrozenBaselinePolicy
{
    private readonly SichuanExactHandAnalyzer _hands = new();
    private readonly SichuanShantenEngine _shanten = new();

    public int DecideDiscard(SichuanStateView state)
    {
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        var forcedSuit = state.OwnDingQueSuit is >= 0 and < 3
            && Enumerable.Range(state.OwnDingQueSuit * 9, 9).Any(tile => state.Hand18[tile] > 0)
            ? state.OwnDingQueSuit : -1;
        return _hands.AnalyzeDiscards(state.Hand18, state.Remaining18, meldCount, true, forcedSuit)
            .OrderBy(item => item.Shanten)
            .ThenByDescending(item => item.LiveUkeire)
            .ThenByDescending(item => item.WaitQuality)
            .ThenBy(item => item.StructuralLoss)
            .ThenBy(item => item.DiscardTileType)
            .Select(item => item.DiscardTileType)
            .DefaultIfEmpty(-1)
            .First();
    }

    public SichuanActionType DecideReaction(
        SichuanStateView state,
        int tileType,
        bool canHu,
        bool canPeng,
        bool canGang,
        bool mandatoryGang = false)
    {
        if (canHu) return SichuanActionType.Hu;
        if (!canPeng && !canGang) return SichuanActionType.Pass;
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        var current = _shanten.CalcBestShanten(state.Hand18, meldCount, meldCount == 0);
        var peng = 8;
        if (canPeng && state.Hand18[tileType] >= 2)
        {
            var pengHand = (int[])state.Hand18.Clone();
            pengHand[tileType] -= 2;
            peng = _hands.AnalyzeDiscards(pengHand, state.Remaining18, meldCount + 1, false)
                .Select(item => item.Shanten).DefaultIfEmpty(8).Min();
        }
        if (canGang && state.Hand18[tileType] >= 3 && (mandatoryGang || state.WallCount > 8))
        {
            var gangHand = (int[])state.Hand18.Clone();
            gangHand[tileType] -= 3;
            var oldPreReplacementGang = _shanten.CalcBestShanten(gangHand, meldCount + 1, false);
            if (mandatoryGang || oldPreReplacementGang <= peng) return SichuanActionType.Gang;
        }
        return canPeng && peng < current ? SichuanActionType.Peng : SichuanActionType.Pass;
    }
}
