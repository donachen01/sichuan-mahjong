using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

internal static class PublicMeldAccountingSmoke
{
    public static int Run()
    {
        try
        {
            int checks=0;
            void Check(bool value,string why){checks++;if(!value)throw new Exception(why);}
            foreach(int observer in Enumerable.Range(0,4))
            foreach(int suit in Enumerable.Range(0,3))
            foreach(int groups in Enumerable.Range(0,5))
            foreach(int mask in Enumerable.Range(0,1<<groups))
            {
                int target=(observer+1)%4;
                SichuanStateView State(bool typed)
                {
                    int Map(int t)=>(t+suit*9)%27;
                    var h=new int[27];foreach(int t in new[]{9,9,10,10,11,11,12,12,13,13,14,15,16,17})h[Map(t)]++;
                    var visible=new int[27];int gangs=0;
                    for(int g=0;g<groups;g++){bool gang=(mask&(1<<g))!=0;visible[Map(g)]=gang?4:3;gangs+=gang?1:0;}
                    var counts=Enumerable.Repeat(13,4).ToArray();counts[observer]=14;counts[target]=13-3*groups;
                    var s=SichuanStateCodec.FromRaw(observer,0,observer,55-gangs,h,visible,dingQueSuits:Enumerable.Repeat((suit+2)%3,4).ToArray(),handCounts:counts);
                    for(int g=0;g<groups;g++)
                    {
                        bool gang=(mask&(1<<g))!=0;
                        s.Melds18[target].AddRange(Enumerable.Repeat(Map(g),gang?4:3));
                        if(typed)s.MeldViews[target].Add(new(gang?SichuanMeldType.ConcealedGang:SichuanMeldType.Peng,Map(g),target,g));
                    }
                    return s;
                }
                var typed=State(true);var flat=State(false);
                double pressure=.14+groups*.14;
                double ready=.04+pressure*.32+groups*.10;
                foreach(var s in new[]{typed,flat})
                {
                    var range=new SichuanOpponentRangeEngine().BuildSeatRange(s,new SichuanEvidenceEngine().Build(s),target);
                    Check(Math.Abs(range.ReadyProbability-ready)<1e-9,$"range uses tile count instead of actual groups: groups={groups} mask={mask}");
                }
                var bt=new SichuanBeliefEngine().Build(typed);var bf=new SichuanBeliefEngine().Build(flat);
                Check(Math.Abs(bt.SeatPressure[target]-pressure)<1e-9,"typed public pressure overcounts quad groups");
                Check(Math.Abs(bf.SeatPressure[target]-pressure)<1e-9,"flat public pressure overcounts quad groups");
                Check(Math.Abs(bt.SeatReadyPosterior[target]-bf.SeatReadyPosterior[target])<1e-9,$"typed/flat actual ready calibration differs: groups={groups} mask={mask}");
                Check(Math.Abs(bt.PublicReadFeatures[$"seat:{target}:根潜力"]-groups/6.0)<1e-9,"public root-potential explanation overcounts quad groups");
            }
            Console.WriteLine($"PUBLIC_MELD_ACCOUNTING PASS checks={checks}; four observer seats, three suits, all 0..4 mixed melds, independent range/pressure formula and typed-flat readiness parity; no fitted weights changed");
            return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
}
