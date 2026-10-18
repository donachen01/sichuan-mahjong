using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Strategy;

public sealed record SichuanFlushCopyAssessment(bool Admissible, int AvailableCopies,
    int MinimumReadyCopies, string Reason);

/// <summary>Necessary public physical-copy bound, not a completion probability.
/// A legal ready hand has13 physical tiles plus one extra per own gang. Keep dead
/// waits admissible for cha-jiao; fourteen would wrongly require a live win.</summary>
public static class SichuanFlushCopyCapacity
{
    internal static (int Tile, int Copies)[] OwnMeldCopies(SichuanStateView state)
    {
        var typed=state.MeldViews[state.SeatIndex];
        return typed.Count>0
            ? typed.Select(m=>(Tile:m.TileType, Copies:m.Type==SichuanMeldType.Peng?3:4)).ToArray()
            : state.Melds18[state.SeatIndex].GroupBy(t=>t).Select(g=>(Tile:g.Key,Copies:g.Count())).ToArray();
    }

    public static SichuanFlushCopyAssessment Assess(SichuanStateView state,
        IReadOnlyList<int> concealed, int targetSuit)
    {
        if(targetSuit is <0 or >2 || targetSuit==state.OwnDingQueSuit)
            return new(false,0,13,"FLUSH_TARGET_MISSING_OR_INVALID");
        var groups=OwnMeldCopies(state);
        var required=13+groups.Count(g=>g.Copies==4);
        if(groups.Any(g=>g.Tile/9!=targetSuit))
            return new(false,0,required,"FLUSH_IRREVERSIBLE_OTHER_SUIT_MELD");
        var ownExposed=groups.Sum(g=>g.Copies);
        // Use the full root hand to count still-unseen copies. A candidate's
        // discarded card cannot re-enter its own hand, and fitted wall weights
        // must not be used as hard physical scarcity evidence.
        var unseen=Enumerable.Range(targetSuit*9,9)
            .Sum(t=>Math.Max(0,4-state.Visible18[t]-state.Hand18[t]));
        var available=concealed.Skip(targetSuit*9).Take(9).Sum()+ownExposed+unseen;
        // A reaction can acquire the already-visible offered tile. This bound
        // intentionally applies only outside that external-claim decision.
        var allowed=state.Phase!=5 || available>=required;
        return new(allowed,available,required,allowed?"":"FLUSH_READY_COPY_CAPACITY");
    }
}
