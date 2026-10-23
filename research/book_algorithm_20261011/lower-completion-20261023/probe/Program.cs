using System.Text.Json;
using System.Diagnostics;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Strategy;

var folder=Path.GetFullPath(args[0]);var name=args.Length>1?args[1]:"baseline";var section=args.Length>2?args[2]:"";
var failures=new List<string>();int checks=0;var rows=new List<object>();var witnesses=new Dictionary<string,object>();
var analyzer=new SichuanExactHandAnalyzer();
if(name=="--models")
{
 using var ordered=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"ordered-oracle.json")));
 foreach(var c in ordered.RootElement.EnumerateArray())
 {
  var a=Array(c,"args");Check(Math.Abs(SichuanFlushSelfDrawInvestment.OrderedEvent(a[0],a[1],a[2],a[3],a[4],a[5],a[6])-c.GetProperty("expected").GetDouble())<1e-11,"independent ordered-wall enumeration "+checks);
 }

 using var claimOrdered=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"claim-ordered-oracle.json")));
 foreach(var c in claimOrdered.RootElement.EnumerateArray())
 {
  var a=Array(c,"args");Check(Math.Abs(SichuanFlushSelfDrawInvestment.OrderedClaimEvent(a[0],a[1],a[2],a[3],a[4],a[5],a[6],a[7],a[8],a[9])-c.GetProperty("expected").GetDouble())<1e-11,"independent first-claim event "+checks);
 }
 using var retention=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"retention-oracle.json")));
 foreach(var c in retention.RootElement.EnumerateArray())
 {
  var state=new SichuanStateView{Remaining18=Array(c,"remaining")};
  var e=SichuanKeyTileRetention.Assess(state,c.GetProperty("tile").GetInt32());
  Check(e.Grade==c.GetProperty("grade").GetString(),"retention class "+checks);
  Check(e.CanBeInSequence==c.GetProperty("sequence").GetBoolean(),"retention sequence "+checks);
  Check(e.CanBePair==c.GetProperty("pair").GetBoolean(),"retention pair "+checks);
  Check(e.CanBeTriplet==c.GetProperty("triplet").GetBoolean(),"retention triplet "+checks);
 }

 using var skeleton=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"skeleton-oracle.json")));
 foreach(var c in skeleton.RootElement.EnumerateArray())
 {
  var v=new SichuanStateView{SeatIndex=1,Hand18=Array(c,"hand"),Remaining18=Array(c,"remaining")};v.DingQueSuits[1]=c.GetProperty("dq").GetInt32();
  foreach(var m in c.GetProperty("melds").EnumerateArray())
  {
   var tiles=Array(m,"tiles");v.Melds18[1].AddRange(tiles);v.MeldViews[1].Add(new(tiles.Length==3?SichuanMeldType.Peng:SichuanMeldType.MeldedGang,tiles[0],0,0));
  }
  var e=SichuanFlushSkeletonEngine.Analyze(v,c.GetProperty("suit").GetInt32());var expected=Array(c,"expected");
  Check(e.TwiceBlocks==expected[0]&&e.PairBlocks==expected[1]&&e.WeakestCompletionCopies==expected[2],"independent block packing "+c.GetProperty("id"));
 }
 File.WriteAllText(Path.Combine(folder,"model-validation.json"),JsonSerializer.Serialize(new{checks,failures}));
 Console.WriteLine($"MODELS checks={checks} failures={failures.Count}");return failures.Count==0?0:1;
}

using var geo=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"structures.json")));
foreach(var c in geo.RootElement.EnumerateArray())
{
 if(section!=""&&c.GetProperty("section").GetString()!=section)continue;
 var h=Array(c,"hand");var ex=Array(c,"exposed");int dq=c.GetProperty("dq").GetInt32(),melds=c.GetProperty("melds").GetArrayLength();
 foreach(var row in c.GetProperty("rows").EnumerateArray())
 {
  int d=row.GetProperty("discard").GetInt32();if(d>=0)h[d]--;
  var remain=Enumerable.Range(0,27).Select(t=>4-h[t]-ex[t]).ToArray();
  var actual=analyzer.EnumerateWaits(h,remain,melds,melds==0).Where(w=>w.TileType/9!=dq).Select(w=>w.TileType).Order().ToArray();
  Check(actual.SequenceEqual(Array(row,"waits")),c.GetProperty("id")+" exact all-waits discard "+d);
  if(d>=0)h[d]++;
 }
}
using var cases=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"cases.json")));
foreach(var c in cases.RootElement.EnumerateArray())
{
 if(section!=""&&c.GetProperty("section").GetString()!=section)continue;
 string id=c.GetProperty("id").GetString()!;
 if(name=="inspect"&&!new[]{"lower-47-6-9-base","lower-50-6-13-C","lower-55-6-17-B","lower-72-6-24-A-offer-p3","lower-75-6-26-base-offer-p4","lower-76-6-28-base-offer-m2","lower-85-7-6-base-offer-p9"}.Contains(id))continue;
 try
 {
  var s=Build(c);var facade=new SichuanAiFacade();facade.Agents.Begin([s]);var w=Stopwatch.StartNew();
  string action;int tile,child=-1;object values;IReadOnlyList<string> reasons;SichuanDecisionCommand? command;
  if(c.TryGetProperty("offered",out var offered))
  {
   tile=offered.GetInt32();var h=s.Hand18.ToArray();h[tile]++;
   bool hu=analyzer.EnumerateWinningDecompositions(h,s.OwnMeldCount,s.OwnMeldCount==0).Count>0;
   var r=facade.DecideReaction(s,tile,hu,s.Hand18[tile]>=2,s.Hand18[tile]>=3&&s.WallCount>0,(s.SeatIndex+3)%4);
   action=r.Action.ActionType.ToString();tile=r.Action.TileType;child=r.PlannedDiscardTile;values=r.ActionScores;reasons=r.Reasons;command=r.Command;
  }
  else
  {
   var r=facade.DecideTurn(s);action=r.Action.ActionType==SichuanActionType.Pass?"Discard":r.Action.ActionType.ToString();
   tile=action=="Discard"?r.ContinuationDiscardTile:r.Action.TileType;if(action=="Gang")action=r.GangSubtype;
   child=r.ContinuationDiscardTile;values=r.ActionScores;reasons=r.Reasons;command=r.Command;
  }
  Check(command is not null&&facade.ValidateDecisionCommand(s,command),id+" authority issues latest-state command");
  if(name=="inspect")
  {
   var b=new SichuanBeliefEngine().Build(s);
   if(!c.TryGetProperty("offered",out var off))
   {
    var d=facade.DecideDiscard(s);var q=new SichuanQingYiSePlanner().Evaluate(s);
    var invest=SichuanFlushSelfDrawInvestment.Evaluate(s,6,b,false);
    rows.Add(new{id,action,tile,mode=d.AiContext?.StrategyMode.Mode,skeleton=Enumerable.Range(0,3).Select(t=>SichuanFlushSkeletonEngine.Analyze(s,t)).ToArray(),
      proposal=SichuanFlushDevelopmentPolicy.Select(s,d.Candidates,d.Action.TileType),singleLane=SichuanSingleLaneSupply.HasKnownWallSuit(s,0),invest,
      details=d.Candidates.Select(x=>new{x.TileType,x.Shanten,x.LiveUkeire,x.ExpectedDealInLoss,x.Danger,x.UnifiedActionValue}),arbitration=d.Arbitration,q});
   }
   else
   {
    int t=off.GetInt32();var e=new SichuanDevelopmentPolicy().AssessRefusal(s,t,SichuanWinType.Discard);
    var f=new SichuanFlyingDecisionPolicy().Decide(s,t,0,e,b);
    rows.Add(new{id,action,tile,f,e,values,reasons});
   }
   continue;
  }

  rows.Add(new{id,section=c.GetProperty("section").GetString(),action,tile,child,ms=w.Elapsed.TotalMilliseconds,values,reasons,command,diagnostic=c.GetProperty("section").GetString()=="5.5"&& !c.TryGetProperty("offered",out _) ? facade.DecideDiscard(s).Candidates.Select(x=>new{x.TileType,x.Shanten,x.LiveUkeire,x.Danger,x.UnifiedActionValue,x.ExpectedValue,x.Reasons}).ToArray():null});
  Console.WriteLine($"LOWER {id} {action} tile={tile} child={child} ms={w.Elapsed.TotalMilliseconds:F1}");
 }
 catch(Exception e){failures.Add(id+" "+e.ToString());Console.WriteLine("FAIL "+id+" "+e.Message);}
}
File.WriteAllText(Path.Combine(folder,name+".json"),JsonSerializer.Serialize(new{checks,failures,rows},new JsonSerializerOptions{WriteIndented=true,NumberHandling=System.Text.Json.Serialization.JsonNumberHandling.AllowNamedFloatingPointLiterals}));
File.WriteAllText(Path.Combine(folder,name+"-fixtures.json"),JsonSerializer.Serialize(witnesses));
Console.WriteLine($"DONE {name} geometry-and-authority={checks} rows={rows.Count} failures={failures.Count}");return failures.Count==0?0:1;
void Check(bool b,string why){checks++;if(!b)failures.Add(why);}
int[] Array(JsonElement c,string k)=>c.GetProperty(k).EnumerateArray().Select(x=>x.GetInt32()).ToArray();
SichuanStateView Build(JsonElement c)
{
 var h=Array(c,"hand");int own=1,wall=c.GetProperty("wall").GetInt32();var pool=Enumerable.Range(0,27).Select(t=>4-h[t]).ToArray();
 bool react=c.TryGetProperty("offered",out var offer);int offered=react?offer.GetInt32():-1;
 var s=new SichuanStateView{SeatIndex=own,CurrentSeat=react?0:own,HostGeneration=1,ViewVersion=1,RoundIndex=1,RoundId=c.GetProperty("id").GetString()!,Phase=react?6:5,WallCount=wall,Hand18=h,
 LastDrawTileType=react?-1:c.GetProperty("draw").GetInt32(),LastDrawOrigin=SichuanTileOrigin.Draw,OwnDrawReason=react?"":"normal_draw"};
 s.DingQueSuits[own]=c.GetProperty("dq").GetInt32();var op=Array(c,"opponent_dq");
 for(int r=1;r<4;r++)s.DingQueSuits[(own+r)%4]=op[r-1];s.HandCounts[own]=h.Sum();
 long eventIndex=0;
 foreach(var m in c.GetProperty("melds").EnumerateArray())
 {
  var tiles=Array(m,"tiles");int t=tiles[0];var kind=tiles.Length==4?SichuanMeldType.MeldedGang:SichuanMeldType.Peng;
  foreach(var _ in tiles){pool[t]--;s.Melds18[own].Add(t);}s.MeldViews[own].Add(new(kind,t,0,++eventIndex));
 }
 if(c.TryGetProperty("op_meld",out var om))AddOpponentMeld((own+om.GetProperty("relative").GetInt32())%4,om.GetProperty("tile").GetInt32());
 if(c.TryGetProperty("op_melds",out var oms))foreach(var entry in oms.EnumerateArray())
  AddOpponentMeld((own+entry.GetProperty("relative").GetInt32())%4,entry.GetProperty("tile").GetInt32());
 if(c.TryGetProperty("danger_suit",out var ds))
 {
  int seat=3,suit=ds.GetInt32();if(s.DingQueSuits[seat]==suit)s.DingQueSuits[seat]=(suit+1)%3;
  foreach(var t in Enumerable.Range(suit*9,9).Where(t=>pool[t]>=3).Take(2).ToArray())AddOpponentMeld(seat,t);
 }
 var known=Array(c,"known").ToList();foreach(var t in known)pool[t]--;
 if(react)pool[offered]--;
 var hidden=new int[4][];hidden[own]=h;var completed=new Dictionary<int,int>();
 foreach(var rel in Array(c,"winners"))
 {
  int seat=(own+rel)%4;var hh=new int[27];int need=4-s.MeldCount(seat);
  foreach(int t in Enumerable.Range(0,27).Where(t=>t/9!=s.DingQueSuits[seat]&&pool[t]>=3).Take(need).ToArray()){hh[t]+=3;pool[t]-=3;need--;}
  if(need!=0)throw new Exception("winner witness unavailable");
  int pair=Enumerable.Range(0,27).First(t=>t/9!=s.DingQueSuits[seat]&&pool[t]>=2);hh[pair]++;pool[pair]-=2;hidden[seat]=hh;completed[seat]=pair;
  s.HasHu[seat]=true;s.ActiveSeats[seat]=false;s.HandCounts[seat]=hh.Sum();
 }
 int protectedSuit=Enumerable.Range(0,3).OrderByDescending(suit=>h.Skip(suit*9).Take(9).Sum()+s.Melds18[own].Count(t=>t/9==suit)).First();
 var random=new Random(20261023);
 for(int seat=0;seat<4;seat++)
 {
  if(hidden[seat] is not null)continue;var hh=new int[27];int size=13-s.MeldCount(seat)*3;
  for(int i=0;i<size;i++)
  {
   var available=Enumerable.Range(0,27).Where(t=>pool[t]>0&&t/9!=s.DingQueSuits[seat]).ToArray();
   if(available.Length==0)throw new Exception("hidden witness unavailable");int t=available[random.Next(available.Length)];pool[t]--;hh[t]++;
  }
  hidden[seat]=hh;s.HandCounts[seat]=size;
 }
 if(pool.Any(n=>n<0)||pool.Sum()<wall)throw new Exception("physical capacity "+pool.Sum()+" wall "+wall);
 while(pool.Sum()>wall)
 {
  var available=Enumerable.Range(0,27).Where(t=>pool[t]>0&&t/9!=protectedSuit&&h[t]==0).ToArray();
  if(available.Length==0)available=Enumerable.Range(0,27).Where(t=>pool[t]>0&&t/9!=protectedSuit).ToArray();
  if(available.Length==0)available=Enumerable.Range(0,27).Where(t=>pool[t]>0).ToArray();
  int t=available[random.Next(available.Length)];pool[t]--;known.Add(t);
 }
 int turn=0;
 foreach(int t in known){int seat=turn++%4;s.Discards18[seat].Add(t);s.PublicEvents.Add(new(++eventIndex,turn,seat,SichuanPublicEventType.Discard,t,SichuanTileOrigin.Unknown));}
 foreach(var (seat,t) in completed)s.PublicEvents.Add(new(++eventIndex,turn,seat,SichuanPublicEventType.Hu,t,SourceSeat:own));
 if(react){s.Discards18[0].Add(offered);s.PublicEvents.Add(new(++eventIndex,turn,0,SichuanPublicEventType.Discard,offered,SichuanTileOrigin.Hand));}
 else s.PublicEvents.Add(new(++eventIndex,turn,own,SichuanPublicEventType.Draw,s.LastDrawTileType,SichuanTileOrigin.Draw));
 for(int seat=0;seat<4;seat++)foreach(var t in s.Discards18[seat].Concat(s.Melds18[seat]))s.Visible18[t]++;
 foreach(var t in completed.Values)s.Visible18[t]++;
 for(int t=0;t<27;t++)s.Remaining18[t]=4-h[t]-s.Visible18[t];
 for(int i=0;i<s.PublicEvents.Count;i++)s.PublicEvents[i]=s.PublicEvents[i] with{EventIndex=i+1};
 s.TurnIndex=turn;s.EventVersion=s.PublicEvents.Count;
 if(!SichuanPublicInferenceBoundary.TryProject(s,out _,out var failure,reaction:react,sourceSeat:0))throw new Exception("public boundary "+failure);
 witnesses[c.GetProperty("id").GetString()!]=new{hands=hidden,wall=pool,winning=completed,state=s,offered};return s;
 void AddOpponentMeld(int seat,int t)
 {
  if(pool[t]<3)throw new Exception("opponent public meld capacity");pool[t]-=3;s.Melds18[seat].AddRange([t,t,t]);s.MeldViews[seat].Add(new(SichuanMeldType.Peng,t,own,++eventIndex));
  s.PublicEvents.Add(new(++eventIndex,0,seat,SichuanPublicEventType.Peng,t,SourceSeat:own));
 }
}
