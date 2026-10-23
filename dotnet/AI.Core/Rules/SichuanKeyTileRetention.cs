using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Rules;

public sealed record SichuanKeyTileEvidence(int TileType, int UnseenCopies, string Grade,
    bool CanBeInSequence, bool CanBePair, bool CanBeTriplet, bool CanBeDeadWait,
    int[] ForcedDiscardSeats)
{
    public string Meaning => "public_retention_constraints_not_guaranteed_wall_or_release_probability";
}

/// <summary>Chapter 7's retention classes from this seat's public copy limits.
/// Even S permits an opponent's singleton wait; A also permits a dead wait.
/// No class implies that the card is in the wall or will be discarded.</summary>
public static class SichuanKeyTileRetention
{
    public static SichuanKeyTileEvidence Assess(SichuanStateView s, int tile)
    {
        if (tile is < 0 or > 26 || s.Remaining18.Length != 27)
            throw new ArgumentException("Expected a tile and public copy counts.");
        int n=s.Remaining18[tile], rank=tile%9, start=tile/9*9;
        bool sequence=Enumerable.Range(Math.Max(0,rank-2),Math.Min(6,rank)-Math.Max(0,rank-2)+1)
            .Any(a=>Enumerable.Range(a,3).All(r=>r==rank||s.Remaining18[start+r]>0));
        bool partial=Enumerable.Range(Math.Max(0,rank-2),Math.Min(8,rank+2)-Math.Max(0,rank-2)+1)
            .Any(r=>r!=rank&&s.Remaining18[start+r]>0);
        string grade=n<=0?"EXHAUSTED":sequence?"UNCONSTRAINED":n==1?(partial?"A":"S"):"B";
        return new(tile,Math.Max(0,n),grade,sequence,n>=2,n>=3,!sequence&&partial,
            Enumerable.Range(0,4).Where(seat=>seat!=s.SeatIndex&&s.ActiveSeats[seat]&&!s.HasHu[seat]
                &&s.DingQueSuits[seat]==tile/9).ToArray());
    }
}
