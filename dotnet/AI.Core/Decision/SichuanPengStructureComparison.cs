using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanPengStructureProfile(int StandardShanten, int BestShanten, int MissingTiles,
    int[] ImprovingTiles, int LiveCopies, int ImprovementCopies, int ClaimedTileCopies,
    int? SevenPairsShanten, bool FlushPossible);

public sealed record SichuanPengStructureComparison(SichuanPengStructureProfile Pass,
    SichuanPengStructureProfile Peng, int PlannedDiscard)
{
    public static SichuanPengStructureComparison Build(SichuanStateView state, int tile, int discard)
    {
        var melds = state.MeldCount(state.SeatIndex);
        var shanten = new SichuanShantenEngine();
        SichuanPengStructureProfile Profile(int[] hand, int count, bool claimed)
        {
            var missing = state.OwnDingQueSuit;
            var missingCount = missing is >= 0 and < 3 ? hand.Skip(missing*9).Take(9).Sum() : 0;
            var clean = (int[])hand.Clone();
            if (missing is >= 0 and < 3) Array.Clear(clean, missing*9,9);
            var distance = shanten.CalcLegalShanten(hand,count,missing,count==0);
            var improving = new List<int>();
            for(var t=0;t<27;t++)
            {
                if(t/9==missing || state.Remaining18[t]<=0)continue;
                hand[t]++;
                if(shanten.CalcLegalShanten(hand,count,missing,count==0)<distance)improving.Add(t);
                hand[t]--;
            }
            var improvement = missingCount==0 ? new SichuanHandImprovementEngine()
                .Enumerate(hand,state.Remaining18,count,missing).Sum(x=>x.Copies) : 0;
            var exposedSuits = state.Melds18[state.SeatIndex].Select(t=>t/9)
                .Concat(claimed?new[]{tile/9}:Array.Empty<int>()).Distinct().ToArray();
            return new(shanten.CalcLegalShanten(hand,count,missing,false),distance,missingCount,improving.ToArray(),
                improving.Sum(t=>state.Remaining18[t]),improvement,state.Remaining18[tile],
                count==0?shanten.CalcSevenPairsShanten(clean):null,
                exposedSuits.Length<=1 && !exposedSuits.Contains(missing));
        }
        var after = (int[])state.Hand18.Clone();
        if(tile is <0 or >=27 || discard is <0 or >=27 || after[tile]<2)throw new ArgumentException("Invalid Peng continuation");
        after[tile]-=2;
        if(after[discard]<=0)throw new ArgumentException("Invalid Peng discard");
        after[discard]--;
        return new(Profile(state.Hand18,melds,false),Profile(after,melds+1,true),discard);
    }
}
