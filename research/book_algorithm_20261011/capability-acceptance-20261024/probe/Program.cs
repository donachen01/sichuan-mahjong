using System.Text.Json;
using System.Diagnostics;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Rules;
var folder=Path.GetFullPath(args[0]);var label=args.Length>1?args[1]:"before";
int checks=0;var failures=new List<string>();var rows=new List<object>();
void Check(bool pass,string why){checks++;if(!pass)failures.Add(why);}
int[] H(params int[] tiles){var h=new int[27];foreach(var t in tiles)h[t]++;return h;}
for(int rotation=0;rotation<3;rotation++)for(int own=1;own<=3;own++)foreach(string evidence in new[]{"uncleared","missing_only","public_river","ordered_event"}){
 int Map(int t)=>((t/9+rotation)%3)*9+t%9;
 int actor=(own+3)%4;var h=H(new[]{0,1,2,3,4,5,6,7,8,9,10,11,13}.Select(Map).ToArray());
 var s=new SichuanStateView{SeatIndex=own,CurrentSeat=own,Phase=5,WallCount=12,Hand18=h,DingQueSuits=Enumerable.Repeat(rotation,4).ToArray(),HandCounts=[13,13,13,13]};
 s.DingQueSuits[own]=(rotation+2)%3;s.DingQueSuits[actor]=(rotation+1)%3;
 int missing=Map(13), other=Map(0);s.Remaining18[missing]=1;
 if(evidence=="missing_only")s.Discards18[actor].Add(Map(9));
 if(evidence=="public_river")s.Discards18[actor].Add(other);
 if(evidence=="ordered_event")s.PublicEvents.Add(new(1,1,actor,SichuanPublicEventType.Discard,other));
 var price=new SichuanReadyWaitPricing().Build(s,h,Enumerable.Repeat(1.0,27).ToArray())!;
 Check(price is not null&&price.Waits.Any(w=>w.TileType==missing),"generated legal whole-hand wait");
 var group=SichuanReadyRaceSupply.Build(s,price!).Single(g=>g.ForcedDiscardMask!=0||g.ExpectedCopies>0);
 bool clear=evidence is "public_river" or "ordered_event";
 Check(((group.ForcedDiscardMask&2)!=0)==clear,$"forced offer requires public clearance r{rotation}/seat{own}/{evidence}");
 var gang=SichuanNaturalGangSupply.FixedTurn(s,missing,1,true);
 double expected=clear?Enumerable.Range(0,s.WallCount-1).Count(i=>i%4==0)/(double)s.WallCount:0;
 Check(Math.Abs(gang.ForcedDiscard-expected)<1e-12,$"natural Gang same release premise r{rotation}/seat{own}/{evidence}");
 rows.Add(new{id=$"supply/r{rotation}/seat{own}/{evidence}",mask=group.ForcedDiscardMask,gang.ForcedDiscard,expected});
}
foreach(var pairCount in new[]{2,3}){
 var tiles=pairCount==3?new[]{0,0,3,3,6,6,9,10,11,12,14,15,16,17}:new[]{0,0,3,3,6,7,9,10,11,12,14,15,16,17};
 var h=H(tiles);var s=new SichuanStateView{SeatIndex=1,CurrentSeat=1,Phase=5,RoundId="new-pairs-"+pairCount,RoundIndex=1,HostGeneration=1,ViewVersion=1,WallCount=24,Hand18=h};s.DingQueSuits[1]=2;s.HandCounts[1]=14;
 for(int t=0;t<27;t++)s.Remaining18[t]=4-h[t];
 var memory=new SichuanRoundBrainSnapshot{PrimaryRoute="暗七对",Commitment=95,TargetSuit=1};
 var direct=new SichuanRoutePlanEngine().Evaluate(s,memory);
 var brain=new SichuanRoundBrainEngine();brain.Restore(s,new(8,1,"暗七对","平胡",1,95,new(),[],[]));var restored=brain.Observe(s);
 var effective=new SichuanRoutePlanEngine().Evaluate(s,restored);
 Check(direct.PrimaryRoute!="暗七对"&&!direct.ForbidsMelds&&!direct.ForbidsGangs,"insufficient pairs exits direct ordinary Seven main route "+pairCount);
 Check(restored.PrimaryRoute!="暗七对"&&!effective.ForbidsMelds&&!effective.ForbidsGangs,"restored memory revalidates ordinary Seven eligibility "+pairCount);
 rows.Add(new{id="dynamic/pairs"+pairCount,direct,restored=restored.PrimaryRoute,effective});
}
// Protected endpoint controls: an already legal Seven wait and Dragon route
// are not invalidated by the ordinary two/three-pair memory correction.
foreach(var control in new[]{(Name:"ready",Route:"暗七对",Tiles:new[]{0,0,2,2,4,4,9,9,11,11,13,13,16}),
 (Name:"dragon",Route:"龙七对",Tiles:new[]{0,0,0,0,3,3,5,5,9,9,12,12,17}),
 (Name:"pure",Route:"清七对",Tiles:new[]{0,0,1,1,2,2,4,4,6,6,8,8,7})}){
 var h=H(control.Tiles);var s=new SichuanStateView{SeatIndex=1,CurrentSeat=1,RoundIndex=1,WallCount=40,Hand18=h,Phase=5};s.DingQueSuits[1]=2;
 for(int t=0;t<27;t++)s.Remaining18[t]=4-h[t];s.HandCounts[1]=h.Sum();
 var b=new SichuanRoundBrainEngine();b.Restore(s,new(8,1,control.Route,"平胡",0,95,new(),[],[]));var brain=b.Observe(s);var p=new SichuanRoutePlanEngine().Evaluate(s,brain);
 Check(brain.PrimaryRoute==control.Route&&p.PrimaryRoute==control.Route,"protected route retained "+control.Name);
 rows.Add(new{id="protected/"+control.Name,brain=brain.PrimaryRoute,p.PrimaryRoute,p.ForbidsMelds});
}
// Seed-free exact supply upper/lower boundary: one unknown target copy can be
// in an uncleared opponent hand, so public unseen count is not known wall mass.
using(var oracle=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"independent-allocation-oracle.json")))){
 var neutral=new List<object>();
 foreach(var c in oracle.RootElement.EnumerateArray())foreach(int seed in new[]{2026102407,2026102419,2026102431}){
  int w=c.GetProperty("wall").GetInt32(),hidden=c.GetProperty("hidden").GetInt32(),copies=c.GetProperty("copies").GetInt32();
  int total=w+hidden;var pool=new int[27];pool[0]=copies;int left=total-copies;
  for(int t=1;t<18&&left>0;t++){pool[t]=Math.Min(4,left);left-=pool[t];}
  var k=new SichuanStateView{SeatIndex=1,WallCount=w,Remaining18=pool,HandCounts=[hidden,0,0,0],DingQueSuits=[2,2,2,2]};
  var particles=new SichuanHiddenHandInferenceEngine().SampleParticles(k,256,seed,SichuanHiddenHandProposal.PublicPriorThenLikelihood);
  double mean=particles.Sum(p=>p.Weight*p.Wall27[0]),prob=particles.Where(p=>p.Wall27[0]>0).Sum(p=>p.Weight);
  double expected=c.GetProperty("expected_wall").GetDouble(),expectedProb=c.GetProperty("p_in_wall").GetDouble();
  double variance=w*(copies/(double)total)*(1-copies/(double)total)*hidden/(total-1.0);
  Check(Math.Abs(mean-expected)<=6*Math.Sqrt(variance/256)+1e-10,"independent neutral posterior wall-copy mean "+w+"/"+hidden+"/"+copies+"/"+seed);
  Check(Math.Abs(prob-expectedProb)<=6*Math.Sqrt(expectedProb*(1-expectedProb)/256)+1e-10,"independent neutral posterior in-wall probability "+w+"/"+hidden+"/"+copies+"/"+seed);
  Check(particles.Count==256&&particles.All(p=>p.Wall27.Sum()==w&&Enumerable.Range(0,27).All(t=>p.Wall27[t]+p.Hands27[0][t]==pool[t])),"neutral posterior finite allocation conservation");
  neutral.Add(new{w,hidden,copies,seed,mean,prob,expected,expectedProb});
 }
 rows.Add(new{id="neutral_posterior_independent_enumeration",hypotheses=neutral.Count*256,comparisons=neutral});
}
foreach(int count in new[]{0,12}){
 var s=Tail(count,true);var other=Tail(count,false);var engine=new SichuanUnifiedDecisionEngine();
 var watch=Stopwatch.StartNew();var a=engine.RankDiscards(s);var b=engine.RankDiscards(other);
 var aa=a.Candidates.Single(c=>c.Action.TileType==3);var bb=b.Candidates.Single(c=>c.Action.TileType==3);
 Check(Math.Abs(aa.ChaJiaoValue-bb.ChaJiaoValue)<1e-10,"exited Hu cannot become cha payer via active bitmap "+count);
 if(count>0)Check(bb.WinGain>0,"nonzero live win channel in payer comparison");
 Check(Math.Abs(aa.WinGain-bb.WinGain)<1e-10,"exited Hu cannot become future Hu payer via active bitmap "+count);
 rows.Add(new{id="net/exited-wall"+count,ms=watch.Elapsed.TotalMilliseconds,activeWon=new{aa.ChaJiaoValue,aa.WinGain,aa.ExpectedNetScore},inactiveWon=new{bb.ChaJiaoValue,bb.WinGain,bb.ExpectedNetScore}});
}
using(var raw=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"unseen-inputs.json")))){
 var fixtures=new Dictionary<string,object>();
 foreach(var entry in raw.RootElement.EnumerateObject()){
  var f=entry.Value;int[][] hands=f.GetProperty("hands").EnumerateArray().Select(a=>H(a.EnumerateArray().Select(v=>v.GetInt32()).ToArray())).ToArray();
  var rivers=f.GetProperty("rivers").EnumerateArray().Select(a=>a.EnumerateArray().Select(v=>v.GetInt32()).ToList()).ToArray();
  var actualWall=H(f.GetProperty("wall").EnumerateArray().Select(v=>v.GetInt32()).ToArray());
  var remaining=Enumerable.Range(0,27).Select(t=>actualWall[t]+hands[0][t]+hands[2][t]+hands[3][t]).ToArray();
  var s=new SichuanStateView{SeatIndex=1,CurrentSeat=1,Phase=5,RoundIndex=1,RoundId=entry.Name,HostGeneration=1,ViewVersion=1,Hand18=hands[1],
   Remaining18=remaining,Visible18=Enumerable.Range(0,27).Select(t=>rivers.Sum(r=>r.Count(v=>v==t))).ToArray(),Discards18=rivers,
   WallCount=actualWall.Sum(),DingQueSuits=[1,2,2,2],HandCounts=[13,14,13,13],OwnDrawReason="normal_draw",LastDrawOrigin=SichuanTileOrigin.Draw,LastDrawTileType=f.GetProperty("draw").GetInt32()};
  long index=0;for(int seat=0;seat<4;seat++)foreach(int t in rivers[seat])s.PublicEvents.Add(new(++index,(int)index,seat,SichuanPublicEventType.Discard,t,SourceSeat:seat));
  var facade=new SichuanAiFacade();facade.Agents.Begin([s]);var watch=Stopwatch.StartNew();var turn=facade.DecideTurn(s);var analysis=facade.DecideDiscard(s);
  Check(turn.Command is not null&&facade.ValidateDecisionCommand(s,turn.Command),entry.Name+" formal latest-state authority");
  Check(turn.ContinuationDiscardTile==analysis.Action.TileType,entry.Name+" signed turn equals shared discard");
  Check(s.Hand18[turn.ContinuationDiscardTile]>0,entry.Name+" actual owned candidate");
  Check(analysis.Candidates.All(c=>double.IsFinite(c.UnifiedActionValue)),entry.Name+" finite common values");
  if(f.GetProperty("kind").GetString()!="ready_choice")Check(analysis.RoundBrain?.PrimaryRoute!="暗七对",entry.Name+" ordinary Seven not primary under four pairs");
  var belief=new SichuanBeliefEngine().Build(s);var alloc=new SichuanHiddenHandInferenceEngine().SampleParticles(s,64,20261024,SichuanHiddenHandProposal.PublicPriorThenLikelihood);
  Check(alloc.All(p=>Enumerable.Range(0,27).All(t=>p.Wall27[t]+Enumerable.Range(0,4).Sum(seat=>p.Hands27[seat][t])==remaining[t])),entry.Name+" all posterior hypotheses conserve copy pool");
  var priced=new SichuanReadyWaitPricing().Build(s,Enumerable.Range(0,27).Select(t=>s.Hand18[t]-(t==17?1:0)).ToArray(),new SichuanWallAvailabilityEngine().Build(s,belief).ExpectedCounts18);
  if(f.GetProperty("kind").GetString()=="ready_choice"){
   var groups=SichuanReadyRaceSupply.Build(s,priced!);
   if(groups.Count==0){Console.WriteLine("EMPTY "+entry.Name+" mass="+priced!.PublicDrawableMass+" lock="+s.LockedFans[1]+" remaining13="+remaining[13]);}
   var forced=groups.FirstOrDefault()?.ForcedDiscardMask??0;
   Check(((forced&2)!=0)==(f.GetProperty("cleared").GetBoolean()&&priced!.PublicDrawableMass>0),entry.Name+" real ready profile uses clearance evidence and live supply");
   if(remaining[13]==0)Check(priced!.Waits.Any(w=>w.TileType==13)&&groups.Count==0,entry.Name+" publicly dead legal wait remains legal without live race group");
  }
  fixtures[entry.Name]=new{state=s,hands,winning=new Dictionary<int,int>(),offered=-1};
  rows.Add(new{id="formal/"+entry.Name,ms=watch.Elapsed.TotalMilliseconds,command=turn.Command,selected=turn.ContinuationDiscardTile,brain=analysis.RoundBrain?.PrimaryRoute,reasons=analysis.Reasons});
 }
 File.WriteAllText(Path.Combine(folder,"unseen-fixtures.json"),JsonSerializer.Serialize(fixtures));
}
File.WriteAllText(Path.Combine(folder,label+".json"),JsonSerializer.Serialize(new{checks,failures,rows},new JsonSerializerOptions{WriteIndented=true}));
Console.WriteLine($"{label} checks={checks} failures={failures.Count}");foreach(var f in failures)Console.WriteLine("FAIL "+f);return failures.Count==0?0:1;
SichuanStateView Tail(int wall,bool activeWon){
 var h=H(18,18,20,21,22,1,1,3);var remaining=H(0,1,1,2);for(int i=0;i<wall;i++)remaining[9+i%9]++;
 if(wall>0){remaining[9]--;remaining[18]++;}
 var s=new SichuanStateView{SeatIndex=1,CurrentSeat=1,Phase=5,WallCount=wall,Hand18=h,Remaining18=remaining,Visible18=Enumerable.Range(0,27).Select(t=>4-h[t]-remaining[t]).ToArray(),HandCounts=[4,8,0,0],HasHu=[false,false,true,true],ActiveSeats=[true,true,activeWon,activeWon],DingQueSuits=[1,1,0,0],OwnDrawReason="normal_draw"};
 foreach(var (seat,t,gang) in new[]{(1,2,false),(1,4,true),(0,6,true),(0,3,false),(0,5,false)}){s.MeldViews[seat].Add(new(gang?SichuanMeldType.ConcealedGang:SichuanMeldType.Peng,t,2,1));s.Melds18[seat].AddRange(Enumerable.Repeat(t,gang?4:3));}
 s.PublicEvents.Add(new(1,1,0,SichuanPublicEventType.Discard,18));return s;
}
