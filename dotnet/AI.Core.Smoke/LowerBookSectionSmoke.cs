using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using System.Text.Json;

internal static class LowerBookSectionSmoke
{
    public static int Run(string section)
    {
        try
        {
            void Check(bool ok,string reason) { if(!ok)throw new Exception(reason); }
            if(section=="6.1")
            {
                var input="research/technical_theory_lower_20261002/sections/6.1-fixtures.json";
                var exact=new SichuanExactHandAnalyzer();int checks=0;
                foreach(var row in JsonDocument.Parse(File.ReadAllText(input)).RootElement.EnumerateArray())
                {
                    var original=row.GetProperty("hand18").EnumerateArray().Select(x=>x.GetInt32()).ToArray();
                    foreach(var permutation in new int[][]{[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]})
                    {
                        var hand=new int[27];for(int t=0;t<27;t++)hand[permutation[t/9]*9+t%9]=original[t];
                        var suit=Enumerable.Range(0,3).Single(s=>hand.Skip(s*9).Take(9).Sum()==13);
                        var expected=Enumerable.Range(suit*9,9).Where(t=>hand[t]<4).ToArray();
                        var waits=exact.EnumerateWaits(hand).Select(w=>w.TileType).Order().ToArray();
                        Check(waits.SequenceEqual(expected),"source broad wait missed or impossible fifth copy included");
                        var remaining=Enumerable.Range(0,27).Select(t=>4-hand[t]).ToArray();
                        foreach(var tile in waits)
                        {
                            remaining[tile]=0;
                            Check(!exact.EnumerateWaits(hand,remaining).Any(w=>w.TileType==tile),"public dead wait retained");
                            remaining[tile]=4-hand[tile];
                        }
                        checks++;
                    }
                }
                Console.WriteLine($"LOWER_SECTION 6.1 PASS {checks} exact full-wait sets, six suit permutations, public dead-tile ablation; fifth copies excluded");return 0;
            }
            if(section=="4.2.1")
            {
                int[][] permutations=[[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]];
                foreach(var perm in permutations)
                foreach(var golden in new[]{false,true})
                {
                    int Map(int t)=>perm[t/9]*9+t%9;
                    var melds=new[]{new SichuanMeldView(SichuanMeldType.Peng,Map(21),1,0),new(SichuanMeldType.Peng,Map(25),2,0),new(SichuanMeldType.Peng,Map(9),3,0)};
                    if(golden)melds=melds.Append(new(SichuanMeldType.Peng,Map(15),1,0)).ToArray();
                    var tiles=golden?new[]{Map(26)}:new[]{Map(26),Map(15),Map(16),Map(17)};
                    var open=RepresentativeHuSmoke.Book(tiles,[perm[0],perm[0],perm[1],perm[2]],ownMelds:melds,offeredTile:Map(26));
                    var dead=RepresentativeHuSmoke.Book(tiles,[perm[0],perm[0],perm[1],perm[2]],ownMelds:melds,offeredTile:Map(26));
                    foreach(var m in melds){dead.Visible18[m.TileType]++;dead.Remaining18[m.TileType]--;}
                    var a=new SichuanDevelopmentPolicy().Evaluate(open);var b=new SichuanDevelopmentPolicy().Evaluate(dead);
                    Check(a.GangOpportunity==0 && b.GangOpportunity==0,"exposed Peng counted as greed opportunity");
                    var liveAction=new SichuanAiFacade().DecideReaction(open,Map(26),true,false,false,1,"discard");
                    var deadAction=new SichuanAiFacade().DecideReaction(dead,Map(26),true,false,false,1,"discard");
                    Check(liveAction.Action.ActionType==deadAction.Action.ActionType,"exposed fourth-copy supply changed Hu/Pass");
                    if(!golden)Check(liveAction.Action.ActionType==SichuanActionType.Hu,"three exposed Pungs induced refusal on narrow ordinary wait");
                    Console.WriteLine($"SECTION_4.2.1 perm={string.Join(',',perm)} golden={golden} action={liveAction.Action.ActionType} exposed_supply_ablation_same=True");
                }
                Console.WriteLine("LOWER_SECTION 4.2.1 PASS actual Hu/Pass entry, exposed supply ablation, golden-hook boundary, six suit transfers");return 0;
            }
            throw new ArgumentException("unimplemented section probe "+section);
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
}
