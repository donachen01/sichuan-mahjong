using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Inference;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanNaturalGangChance(double OwnDraw,double ForcedDiscard);

/// <summary>Exactly one fourth copy, conditional expected wall mass and fixed
/// current turn order. No unobserved hand is read; no Gang is possible without
/// a replacement tile. Exits, other Hu and competing Gang routes remain costs
/// in the caller's bounded continuation comparison.</summary>
public static class SichuanNaturalGangSupply
{
    public static SichuanNaturalGangChance FixedTurn(SichuanStateView s,int tile,
        double expectedWallCopies,bool concealedTriplet)
    {
        if(tile is <0 or >26 || s.WallCount<=1 || s.SeatIndex is <0 or >3
            || s.HasHu[s.SeatIndex] || !s.ActiveSeats[s.SeatIndex]
            || Enumerable.Range(0,4).Count(i=>s.ActiveSeats[i]&&!s.HasHu[i])<2)return new(0,0);
        var own=0;var forced=0;var actor=s.SeatIndex;
        for(int draw=0;draw<s.WallCount-1;draw++)
        {
            actor=Next(actor);
            if(actor==s.SeatIndex)own++;
            else if(concealedTriplet && SichuanOpponentTimeline.MustOfferDraw(s,actor,tile)
                && s.PassedGang18[s.SeatIndex][tile]==0)forced++;
        }
        var mass=Math.Clamp(expectedWallCopies,0,1);
        return new(mass*own/s.WallCount,mass*forced/s.WallCount);
        int Next(int seat)
        {
            for(int step=1;step<=4;step++)
            {var candidate=(seat-step+8)%4;if(s.ActiveSeats[candidate]&&!s.HasHu[candidate])return candidate;}
            return s.SeatIndex;
        }
    }
}
