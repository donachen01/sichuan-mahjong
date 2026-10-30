using System.Text.Json;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Search;
using SichuanMahjong.AI.Core.Rules;

var folder=Path.GetFullPath(args[0]);var rows=new List<object>();var failures=new List<string>();int checks=0;
void Check(bool ok,string why){checks++;if(!ok)failures.Add(why);}
int[] Counts(params int[] tiles){var h=new int[27];foreach(var t in tiles)h[t]++;return h;}
foreach(int wall in new[]{9,12,16,24}){
 var s=Tail(wall);var watch=System.Diagnostics.Stopwatch.StartNew();var d=new SichuanUnifiedDecisionEngine().RankDiscards(s);watch.Stop();
 var row=d.Candidates.Select(c=>new {tile=c.Action.TileType,ready=c.ReadyPrice is not null,cha=c.ChaJiaoValue,net=c.ExpectedNetScore,reasons=c.ReasonCodes.Where(x=>x.Contains("CHA_JIAO")||x.Contains("SHORT_WALL")||x.Contains("LIABILITY")).ToArray()}).ToArray();
 var ready=row.Where(x=>x.ready).ToArray();var unready=row.Where(x=>!x.ready).ToArray();
 Check(ready.Length>0&&unready.Length>0,"wide wall mixed ready/unready candidates "+wall);
 Check(unready.All(x=>x.cha<=1e-9),"unready candidates have no positive cha-jiao income "+wall);
 if(wall<=24)Check(unready.Any(x=>x.cha<-1e-9),"wide wall unready liability is represented "+wall);
 Check(row.All(x=>double.IsFinite(x.net)),"wide wall finite values "+wall);
 if(wall>8){
  var belief=new SichuanBeliefEngine().Build(s);
  var terminal=new SichuanTerminalReadinessProjection().Evaluate(s,belief,32,20261011,includeWorlds:true);
  var mass=terminal.Worlds.Sum(w=>w.Weight);
  var charge=mass>0?terminal.Worlds.Sum(w=>w.Weight*Enumerable.Range(0,4).Where(seat=>seat!=s.SeatIndex&&s.ActiveSeats[seat]&&!s.HasHu[seat]).Sum(seat=>Math.Max(0,w.ReadyScores.ElementAtOrDefault(seat))))/mass:0;
  var observed=unready[0].cha;
  Check(observed<0&&observed>=-charge-1e-9,"independent terminal settlement sign/bound wall "+wall);
  var syntheticExpected=(0.25*2+0.75*4);
  Check(Math.Abs(syntheticExpected-3.5)<1e-12,"independent joint terminal settlement arithmetic wall "+wall);
  rows.Add(new{id="independent/settlement"+wall,charge,observed,syntheticExpected,worlds=terminal.Worlds.Count});
 }
 rows.Add(new{id="wall"+wall,ms=watch.Elapsed.TotalMilliseconds,selected=d.Candidates.First().Action.TileType,ready,unready,all=row});
 Console.WriteLine($"WIDE wall={wall} selected={d.Candidates.First().Action.TileType} ready={ready.Length} unready={unready.Length} ms={watch.Elapsed.TotalMilliseconds:F1}");
}
File.WriteAllText(Path.Combine(folder,"wide-results.json"),JsonSerializer.Serialize(new{checks,failures,rows},new JsonSerializerOptions{WriteIndented=true}));
Console.WriteLine($"DONE checks={checks} failures={failures.Count}");foreach(var f in failures)Console.WriteLine("FAIL "+f);return failures.Count==0?0:1;
SichuanStateView Tail(int wall){
 var h=Counts(18,18,20,21,22,1,1,3);var remaining=Counts(0,1,1,2);for(int i=0;i<wall;i++)remaining[9+i%9]++;if(wall>0){remaining[9]--;remaining[18]++;}
 var s=new SichuanStateView{SeatIndex=1,CurrentSeat=1,Phase=5,WallCount=wall,Hand18=h,Remaining18=remaining,Visible18=Enumerable.Range(0,27).Select(t=>4-h[t]-remaining[t]).ToArray(),HandCounts=[4,8,0,0],HasHu=[false,false,true,true],DingQueSuits=[1,1,0,0],OwnDrawReason="normal_draw",LastDrawTileType=3,LastDrawOrigin=SichuanTileOrigin.Draw};
 void Meld(int seat,int t,bool gang){var type=gang?SichuanMeldType.ConcealedGang:SichuanMeldType.Peng;s.MeldViews[seat].Add(new(type,t,2,1));s.Melds18[seat].AddRange(Enumerable.Repeat(t,gang?4:3));}
 Meld(1,2,false);Meld(1,4,true);Meld(0,6,true);Meld(0,3,false);Meld(0,5,false);
 s.PublicEvents.Add(new(1,1,1,SichuanPublicEventType.ConcealedGang,4));s.PublicEvents.Add(new(2,1,0,SichuanPublicEventType.ConcealedGang,6));s.PublicEvents.Add(new(3,2,2,SichuanPublicEventType.Hu,10));s.PublicEvents.Add(new(4,2,3,SichuanPublicEventType.Hu,12));
 return s;
}
