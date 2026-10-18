using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Strategy;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Entry;

internal static class MeldGroupCountSmoke
{
    public static int Run()
    {
        try
        {
            void Check(bool ok,string why){if(!ok)throw new Exception(why);}
            int checks=0;
            foreach(var seat in Enumerable.Range(0,4))
            foreach(var count in Enumerable.Range(0,5))
            foreach(var mask in Enumerable.Range(0,1<<count))
            {
                var state=SichuanStateCodec.FromRaw(seat,0,seat,40,new int[27],new int[27],dingQueSuits:[0,0,0,0]);
                for(int i=0;i<count;i++)
                {
                    bool gang=(mask&(1<<i))!=0;state.MeldViews[seat].Add(new(gang?SichuanMeldType.ConcealedGang:SichuanMeldType.Peng,9+i,seat,i));
                    state.Melds18[seat].AddRange(Enumerable.Repeat(9+i,gang?4:3));
                }
                state.HandCounts[seat]=13-3*count;state.Discards18[seat].Add(17);
                Check(state.MeldCount(seat)==count && state.OwnMeldCount==count,"quad counted as an extra meld group");
                Check(SichuanOpponentTimeline.MustHaveClearedMissing(state,seat),"post-discard clearing boundary rejected actual group count");
                state.HandCounts[seat]++;Check(!SichuanOpponentTimeline.MustHaveClearedMissing(state,seat),"between draw/discard treated as cleared");state.HandCounts[seat]--;
                state.MeldViews[seat].Clear();Check(state.MeldCount(seat)==count && SichuanOpponentTimeline.MustHaveClearedMissing(state,seat),"flat legacy three/four-tile meld grouping changed count");checks++;
            }
            foreach(var suit in Enumerable.Range(0,3))
            {
                int Map(int t)=>(t+suit*9)%27;
                var own=new int[27];foreach(var t in new[]{3,4,5,6,6})own[Map(t)]++;
                var pool=Enumerable.Repeat(4,27).ToArray();for(int t=0;t<27;t++)pool[t]-=own[t];
                var visible=new int[27];foreach(var t in new[]{Map(0),Map(1),Map(2)}){visible[t]=4;pool[t]-=4;}
                // Complete 108-copy world with each opponent's 13 concealed tiles.
                for(int s=1;s<4;s++)for(int i=0;i<13;i++){int t=Array.FindIndex(pool,n=>n>0);pool[t]--;}
                var state=SichuanStateCodec.FromRaw(0,0,0,pool.Sum(),own,visible,dingQueSuits:[(suit+2)%3,suit,suit,suit],handCounts:[5,13,13,13]);
                foreach(var t in new[]{Map(0),Map(1),Map(2)}){state.MeldViews[0].Add(new(SichuanMeldType.ConcealedGang,t,0,0));state.Melds18[0].AddRange(Enumerable.Repeat(t,4));}
                state.LastDrawTileType=Map(6);state.LastDrawOrigin=SichuanTileOrigin.Draw;state.OwnDrawReason="normal_draw";
                var belief=new SichuanBeliefEngine().Build(state);var wall=new SichuanWallAvailabilityEngine().Build(state,belief);
                var lane=new SichuanSingleLaneEvaluator().EvaluateDiscards(state,belief,wall);
                Check(lane.ContainsKey(Map(6)) && lane[Map(6)].TargetShanten==0,"actual three-gang flush discard lost ready shape");
                var hu=new SichuanAiFacade().DecideSelfAction(state,true,[],[]);Check(hu.Action.ActionType==SichuanActionType.Hu && hu.ActionScores["hu"]==51000,"three-gang actual facade fan cap/root settlement failed");
            }
            Console.WriteLine($"MELD_GROUP_COUNT PASS mixtures={checks}; all seats 0..4 groups, flat and typed, waiting versus drawn boundary, three-suit actual three-gang single-lane ready and self-Hu pricing");return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
}
