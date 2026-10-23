using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanSevenPairsEligibility(bool Applies,bool Early,bool Favorable,int DifficultPairs,bool Safe)
{public bool MayInvest=>Applies&&Early&&Favorable&&DifficultPairs>=2&&Safe;}

/// <summary>Public prerequisites for the ordinary Seven Pairs route.
/// Eligibility never substitutes for the shared action-value comparison.</summary>
public static class SichuanSevenPairsDevelopment
{
    public static SichuanSevenPairsEligibility Assess(SichuanStateView s,int[]? hand=null)
    {
        var h=hand??s.Hand18;
        var pairs=Enumerable.Range(0,27).Where(t=>h[t]>=2).ToArray();
        bool applies=s.InformationMode=="public"&&s.OwnMeldCount==0&&h.Sum() is 13 or 14
            &&!h.Any(x=>x>=4)&&pairs.Length>=4&&pairs.Select(t=>t/9).Distinct().Count()==2
            &&Enumerable.Range(0,3).Max(x=>h.Skip(x*9).Take(9).Sum())<10;
        if(!applies)return new(false,false,false,0,false);
        var active=Enumerable.Range(0,4).Where(x=>x!=s.SeatIndex&&s.ActiveSeats[x]&&!s.HasHu[x]).ToArray();
        int Missing(int suit)=>active.Count(x=>s.DingQueSuits[x]==suit);
        bool favorable=Enumerable.Range(0,3).Any(suit=>Missing(suit)>=2&&Enumerable.Range(suit*9,9).Count(t=>h[t]==1&&s.Remaining18[t]>0)>=2);
        int favorableSuppliers=Enumerable.Range(0,3).Where(suit=>Enumerable.Range(suit*9,9)
            .Count(t=>h[t]==1&&s.Remaining18[t]>0)>=2).Select(Missing).DefaultIfEmpty(0).Max();
        // Difficulty is relative to the favorable development suit. One
        // compulsory supplier is still scarcer than two; it is not "easy"
        // merely because its supply channel is nonzero.
        int difficult=pairs.Count(t=>Missing(t/9)<favorableSuppliers||s.Remaining18[t]<=1);
        var why=new List<string>();bool safe=SichuanDistinctDingQueHuPolicy.AssessDanger(s,why)==0;
        // First third of the original wall, not a literal 4/6/9-turn rule.
        bool early=s.WallCount*3>=(108-4*13-1)*2;
        return new(true,early,favorable,difficult,safe);
    }

}
