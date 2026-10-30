// Reused physical-fixture and formal-entry harness from lower-completion-20261023.
// This run uses current source and a new declared witness seed; it is not blind evaluation.
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
if(name is "--reproduce-public" or "--reproduce-self")
{
 var state=JsonSerializer.Deserialize<SichuanStateView>(File.ReadAllText(Path.Combine(folder,name=="--reproduce-self"?"reproduce-self-state.json":"reproduce-state.json")),new JsonSerializerOptions{PropertyNameCaseInsensitive=true})!;
 using var input=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,name=="--reproduce-self"?"reproduce-self-state.json":"reproduce-state.json")));
 var options=new JsonSerializerOptions{PropertyNameCaseInsensitive=true};
 state.PublicEvents.Clear();state.PublicEvents.AddRange(JsonSerializer.Deserialize<List<SichuanPublicEvent>>(input.RootElement.GetProperty("publicEvents").GetRawText(),options)!);
 int seatNumber=0;foreach(var row in input.RootElement.GetProperty("meldViews").EnumerateArray())
 {state.MeldViews[seatNumber].Clear();state.MeldViews[seatNumber++].AddRange(JsonSerializer.Deserialize<List<SichuanMeldView>>(row.GetRawText(),options)!);}
 var facade=new SichuanAiFacade();facade.Agents.Begin([state]);
 var e=state.PublicEvents.Last(x=>x.Type==SichuanPublicEventType.Discard);
 try{object result;
 if(name=="--reproduce-self")result=facade.DecideSelfAction(state,
     analyzer.IsWinning(state.Hand18,state.OwnMeldCount,state.OwnMeldCount==0),
     Enumerable.Range(0,27).Where(t=>state.Hand18[t]==4&&t/9!=state.OwnDingQueSuit).ToArray(),
     state.MeldViews[state.SeatIndex].Where(m=>m.Type==SichuanMeldType.Peng&&state.Hand18[m.TileType]>0&&SichuanAddedGangRules.CanUpgrade(state,m.TileType)).Select(m=>m.TileType).ToArray());
 else result=facade.DecideReaction(state,e.TileType,false,true,false,state.CurrentSeat);
 Console.WriteLine(JsonSerializer.Serialize(result));return 0;}
 catch(Exception ex){File.WriteAllText(Path.Combine(folder,name=="--reproduce-self"?"native-self-failure-stack.txt":"native-failure-stack.txt"),ex.ToString());Console.WriteLine(ex.ToString());return 1;}
}

if(name=="--cash-before")
{
 var u=new SichuanMahjong.AI.Core.Search.SichuanMultiPlayerUtilityEngine();
 var old=u.Evaluate(new(0,0,0,0,2,0,0,0,4,1));
 Check(Math.Abs(old.NetUtility+2)<1e-12,"two actual own points must be charged as two, not discounted opponent growth");
 File.WriteAllText(Path.Combine(folder,"cash-before.json"),JsonSerializer.Serialize(new{checks,failures,actual=old.NetUtility,expected=-2.0,scope="Exact caller-channel arithmetic, confidence1; no game or strategy mock claim."}));
 Console.WriteLine($"OWNPAY before={old.NetUtility} expected=-2 failures={failures.Count}");return failures.Count==0?0:1;
}
if(name=="--cash-tests")
{
 var u=new SichuanMahjong.AI.Core.Search.SichuanMultiPlayerUtilityEngine();
 var state=new SichuanStateView();
 foreach(int players in new[]{2,3,4})foreach(double confidence in new[]{0,.78,1})foreach(double payment in new[]{0,1,2,8})
 {
  state.PolicyVariant="current";
  var input=SichuanLearningClosurePolicy.OwnCash(state,3,0,1,.4,payment,0,0,.18,players,confidence);
  var actual=u.Evaluate(input);
  double expected=4-.4-payment-.18-(1-confidence)*(4+.4+payment)*.35;
  Check(Math.Abs(actual.NetUtility-expected)<1e-12,"full own cash arithmetic");
  state.PolicyVariant="cash_cost_before_v1";
  var old=SichuanLearningClosurePolicy.OwnCash(state,3,0,1,.4,payment,0,0,.18,players,confidence);
  var legacy=u.Evaluate(new(3,0,1,.4,payment,0,0,.18,players,confidence));
  Check(u.Evaluate(old).NetUtility==legacy.NetUtility,"historical control arithmetic exact");
 }
 var growth=u.Evaluate(new(0,0,0,0,2,0,0,0,4,1));
 Check(Math.Abs(growth.NetUtility+1.16)<1e-12,"strategic opponent growth retains separate discount");
 foreach(bool full in new[]{false,true})foreach(int players in new[]{2,3,4})foreach(double confidence in new[]{0,.78,1})
 {
  state.PolicyVariant=full?"current":"cash_cost_before_v1";
  var input=SichuanLearningClosurePolicy.OwnCash(state,4,0,1,0,2,0,0,0,players,confidence);
  double[] gains=[2,4,6],losses=[1,2,3],cha=[.5,1,1.5];
  var series=SichuanMahjong.AI.Core.Search.SichuanMultiPlayerUtilityEngine.NumericalCenteredSeries(input,gains,losses,cha);
  for(int i=0;i<3;i++)
  {
   var row=SichuanLearningClosurePolicy.OwnCash(state,gains[i],0,cha[i],0,losses[i],0,0,0,players,confidence);
   Check(Math.Abs(series[i]-(u.Evaluate(row).NetUtility-u.Evaluate(input).NetUtility))<1e-12,"paired series uses same cash coefficients");
  }
 }
 File.WriteAllText(Path.Combine(folder,"cash-tests.json"),JsonSerializer.Serialize(new{checks,failures}));
 Console.WriteLine($"CASH checks={checks} failures={failures.Count}");return failures.Count==0?0:1;
}
if(name=="--ready-density")
{
 using var source=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"ready-density-oracle.json")));
 foreach(var c in source.RootElement.EnumerateArray())
 {
  var pool=Array(c,"pool");var h=Array(c,"hand");double expected=c.GetProperty("expected").GetDouble();
  var actual=SichuanMahjong.AI.Core.Inference.SichuanReadyHandProposal.Density(pool,Array(c,"exposed"),c.GetProperty("missing").GetInt32(),c.GetProperty("melds").GetInt32(),h,c.GetProperty("logs").EnumerateArray().Select(x=>x.GetDouble()).ToArray());
  Check(Math.Abs(actual-expected)<=2e-10*Math.Max(1e-6,expected),"ready density "+c.GetProperty("id"));
  double physical=c.GetProperty("physical").GetDouble();
  Check(Math.Abs(Math.Exp(SichuanMahjong.AI.Core.Inference.SichuanReadyHandProposal.LogPhysicalMass(pool,h))-physical)<1e-12,"unordered physical mass "+c.GetProperty("id"));
 }
 File.WriteAllText(Path.Combine(folder,"ready-density-current.json"),JsonSerializer.Serialize(new{checks,failures}));
 Console.WriteLine($"DENSITY checks={checks} failures={failures.Count}");return failures.Count==0?0:1;
}
if(name=="--shape-paths")
{
 using var source=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"shape-path-oracle.json")));
 foreach(var c in source.RootElement.EnumerateArray())
 {
  var actual=Math.Exp(FailedShapeProposal.ShapePathLogImportance(
      Array(c,"pool"),Array(c,"path"),c.GetProperty("forbidden").GetInt32(),c.GetProperty("excluded").GetUInt32()));
  Check(Math.Abs(actual-c.GetProperty("expected").GetDouble())<1e-11,"physical path "+c.GetProperty("id"));
 }
 File.WriteAllText(Path.Combine(folder,"shape-path-current.json"),JsonSerializer.Serialize(new{checks,failures}));
 Console.WriteLine($"PATH checks={checks} failures={failures.Count}");return failures.Count==0?0:1;
}
if(name=="--joint-fit")
{
 using var source=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"joint-fit-oracle.json")));
 foreach(var c in source.RootElement.EnumerateArray())
 {
  var pri=c.GetProperty("prior").EnumerateArray().Select(x=>x.GetDouble()).ToArray();
  var targets=c.GetProperty("targets").EnumerateObject().ToDictionary(x=>int.Parse(x.Name),x=>x.Value.GetDouble());
  var fit=SichuanMahjong.AI.Core.Inference.SichuanJointReadinessProjection.FitMasks(pri,targets);
  Check(fit.Supported==c.GetProperty("supported").GetBoolean(),"fit support "+c.GetProperty("id"));
  if(fit.Supported)foreach(var (x,i) in c.GetProperty("expected").EnumerateArray().Select((x,i)=>(x,i)))
   Check(Math.Abs(x.GetDouble()-fit.Mass[i])<1e-7,"analytic mass "+c.GetProperty("id")+"/"+i);
 }
 File.WriteAllText(Path.Combine(folder,"joint-fit-current.json"),JsonSerializer.Serialize(new{checks,failures}));
 Console.WriteLine($"JOINTFIT checks={checks} failures={failures.Count}");return failures.Count==0?0:1;
}
if(name=="--joint-acquisition")
{
 using var source=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"joint-acquisition-oracle.json")));
 foreach(var c in source.RootElement.EnumerateArray())
 {
  var p=SichuanMahjong.AI.Core.Search.SichuanJointAcquisition.AtLeast(Array(c,"supply"),Array(c,"required"),c.GetProperty("draws").GetInt32());
  Check(Math.Abs(p-c.GetProperty("expected").GetDouble())<1e-12,"joint requirement "+checks);
 }
 File.WriteAllText(Path.Combine(folder,"joint-acquisition-current.json"),JsonSerializer.Serialize(new{checks,failures}));
 Console.WriteLine($"JOINT checks={checks} failures={failures.Count}");return failures.Count==0?0:1;
}
if(name=="--stopping-oracle")
{
 using var source=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"stopping-oracle.json")));
 foreach(var c in source.RootElement.EnumerateArray())
 {
  var ns=c.GetProperty("counts").EnumerateArray().Select(x=>x.GetDouble()).ToArray();var ps=Array(c,"prices");int wall=c.GetProperty("wall").GetInt32();
  var gs=ns.Select((n,i)=>new SichuanMahjong.AI.Core.Search.SichuanReadyRaceGroup(n,ps[i]+1,ps[i],c.GetProperty("forced").GetInt32())).ToArray();
  var v=new SichuanMahjong.AI.Core.Search.SichuanActionTreeEvaluator().SearchChanceNodes(new(ns.Sum(),wall,c.GetProperty("players").GetInt32(),c.GetProperty("offset").GetInt32(),0,c.GetProperty("hazard").GetDouble(),2.4,ChaJiaoValue:1.25,MaxDraws:wall,ReadyGroups:gs,AllowRonRefusal:true,InitialRonLockScore:c.GetProperty("locked").GetDouble(),MaxRonRefusals:c.TryGetProperty("budget",out var budget)?budget.GetInt32():int.MaxValue));
  var actual=new[]{v.ExpectedOwnWinGain,v.SelfDrawWinProbability,v.DiscardHuProbability,v.ExpectedOpponentLoss,v.ExpectedChaJiaoValue,v.DrawProbability,v.BattleEndProbability};
  var expected=c.GetProperty("expected").EnumerateArray().Select(x=>x.GetDouble()).ToArray();
  for(int i=0;i<actual.Length;i++)Check(Math.Abs(actual[i]-expected[i])<1e-10,$"public stopping {checks} field{i}: {actual[i]} != {expected[i]}");
 }
 File.WriteAllText(Path.Combine(folder,"stopping-current.json"),JsonSerializer.Serialize(new{checks,failures}));
 Console.WriteLine($"STOPPING checks={checks} failures={failures.Count}");foreach(var f in failures.Take(5))Console.WriteLine(f);return failures.Count==0?0:1;
}
if(name=="--retention")
{
 using var oracle=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"retention-oracle.json")));
 foreach(var c in oracle.RootElement.EnumerateArray())
 {
  var v=new SichuanStateView{Remaining18=Array(c,"remaining")};var a=SichuanKeyTileRetention.Assess(v,c.GetProperty("tile").GetInt32());
  Check(a.Grade==c.GetProperty("grade").GetString(),"retention class "+checks);
  Check(a.CanBeInSequence==c.GetProperty("sequence").GetBoolean(),"retention sequence "+checks);
  Check(a.CanBePair==c.GetProperty("pair").GetBoolean(),"retention pair "+checks);
  Check(a.CanBeTriplet==c.GetProperty("triplet").GetBoolean(),"retention triplet "+checks);
 }
 File.WriteAllText(Path.Combine(folder,"retention-current.json"),JsonSerializer.Serialize(new{checks,failures}));
 Console.WriteLine($"RETENTION checks={checks} failures={failures.Count}");return failures.Count==0?0:1;
}
if(name=="--progress")
{
 using var oracle=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"progress-oracle.json")));
 foreach(var c in oracle.RootElement.EnumerateArray())
 {var actual=new SichuanShantenEngine().CalcStandardShanten(Array(c,"hand"),c.GetProperty("meld_count").GetInt32());Check(actual==c.GetProperty("expected").GetInt32(),"ordinary distance "+checks);}
 File.WriteAllText(Path.Combine(folder,"progress-current.json"),JsonSerializer.Serialize(new{checks,failures}));
 Console.WriteLine($"PROGRESS checks={checks} failures={failures.Count}");return failures.Count==0?0:1;
}
if(name=="--skeleton")
{
 using var oracle=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"skeleton-oracle.json")));
 foreach(var c in oracle.RootElement.EnumerateArray())
 {
  var v=new SichuanStateView{SeatIndex=1,Hand18=Array(c,"hand"),Remaining18=Array(c,"remaining")};v.DingQueSuits[1]=c.GetProperty("dq").GetInt32();
  foreach(var m in c.GetProperty("melds").EnumerateArray())
  {var ts=Array(m,"tiles");v.Melds18[1].AddRange(ts);v.MeldViews[1].Add(new(ts.Length==3?SichuanMeldType.Peng:SichuanMeldType.MeldedGang,ts[0],-1,0));}
  var a=SichuanFlushSkeletonEngine.Analyze(v,c.GetProperty("suit").GetInt32());var e=Array(c,"expected");
  Check(a.TwiceBlocks==e[0]&&a.PairBlocks==e[1]&&a.WeakestCompletionCopies==e[2],c.GetProperty("id")+" block packing proxy");
 }
 File.WriteAllText(Path.Combine(folder,"skeleton-current.json"),JsonSerializer.Serialize(new{checks,failures}));
 Console.WriteLine($"SKELETON checks={checks} failures={failures.Count}");return failures.Count==0?0:1;
}
if(name=="--shape")
{
 using var oracle=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"shape-oracle.json")));
 foreach(var c in oracle.RootElement.EnumerateArray())
 {
  int suit=c.GetProperty("suit").GetInt32();var h=Array(c,"hand");var ex=Array(c,"exposed");var rem=Array(c,"remaining");
  var a=new SichuanFlushStructureEngine().Analyze(h,rem,ex,suit,c.GetProperty("meld_count").GetInt32());
  var e=c.GetProperty("expected");
  Check(a.MinimumAdditionalTiles==e.GetProperty("minimum").GetInt32(),c.GetProperty("id")+" reachability distance");
  Check(a.UsefulDraws.Order().SequenceEqual(Array(e,"useful").Order()),c.GetProperty("id")+" useful union");
  Check(a.RequiredInEveryNearestPattern.Order().SequenceEqual(Array(e,"required").Order()),c.GetProperty("id")+" bottleneck intersection");
 }
 File.WriteAllText(Path.Combine(folder,"shape-current.json"),JsonSerializer.Serialize(new{checks,failures}));
 Console.WriteLine($"SHAPE checks={checks} failures={failures.Count}");return failures.Count==0?0:1;
}
if(name=="--exact")
{
 using var oracle=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"oracle.json")));
 foreach(var c in oracle.RootElement.EnumerateArray())
 {
  var hand=Array(c,"hand");var remain=Array(c,"remaining");int mc=c.GetProperty("meld_count").GetInt32();
  var actual=analyzer.EnumerateWaits(hand,remain,mc,mc==0);
  var expected=c.GetProperty("expected").EnumerateArray().ToArray();string id=c.GetProperty("id").GetString()!;
  Check(actual.Select(w=>w.TileType).Order().SequenceEqual(expected.Select(w=>w.GetProperty("tile").GetInt32()).Order()),id+" wait set");
  foreach(var w in actual)
  {
   var e=expected.FirstOrDefault(e=>e.GetProperty("tile").GetInt32()==w.TileType);
   if(e.ValueKind==JsonValueKind.Undefined)continue;
   Check(w.LiveCount==e.GetProperty("copies").GetInt32(),id+" copy upper bound");
   var keys=w.Decompositions.Select(d=>(d.IsSevenPairs?"S:":"N:")+string.Join("|",d.Groups.OrderBy(g=>(int)g.Type).ThenBy(g=>g.TileType).Select(g=>$"{(int)g.Type}:{g.TileType}"))).Order().ToArray();
   var ek=e.GetProperty("keys").EnumerateArray().Select(x=>x.GetString()!).Order().ToArray();
   Check(keys.SequenceEqual(ek),id+" all decompositions "+w.TileType);
   var comp=hand.ToArray();comp[w.TileType]++;
   var ex=Array(c,"exposed");var mv=Enumerable.Range(0,27).Where(t=>ex[t]>0).Select(t=>new SichuanMeldView(ex[t]==4?SichuanMeldType.MeldedGang:SichuanMeldType.Peng,t,-1,0)).ToArray();
   var fan=new SichuanFanProjectionEngine().Project(comp,mv,SichuanWinType.SelfDraw);
   // The first 6.1 artifact predates independent per-wait prices. Preserve
   // replay of its explicitly narrower wait/decomposition scope.
   if(e.TryGetProperty("score",out var es))Check(fan.BaseFan==es.GetProperty("base_fan").GetInt32()&&fan.GenCount==es.GetProperty("roots").GetInt32()
     &&fan.CappedFan==es.GetProperty("fan").GetInt32()&&fan.HandScore==es.GetProperty("hand_score").GetInt32()
     &&fan.PerPayerScore==es.GetProperty("self_per_payer").GetInt32(),id+" independent per-wait price "+w.TileType);
  }
 }
 File.WriteAllText(Path.Combine(folder,"exact-current.json"),JsonSerializer.Serialize(new{checks,failures}));
 Console.WriteLine($"EXACT checks={checks} failures={failures.Count}");
 foreach(var f in failures.Take(10))Console.WriteLine(f);
 return failures.Count==0?0:1;
}
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
  var s=Build(c);
  for(int seat=0;seat<4;seat++){s.IsCalled[seat]=s.MeldCount(seat)>0;s.UnlockOnOwnDraw[seat]=true;
   for(int m=0;m<s.MeldViews[seat].Count;m++)s.MeldViews[seat][m]=s.MeldViews[seat][m] with{EventIndex=m};}
  if(name=="cash_cost_before_v1")s.PolicyVariant=name;
  if(name=="pre-closure")s.PolicyVariant="pre_learning_closure_v1";
  if(name=="stopping")s.PolicyVariant="ready_stopping_candidate";if(name is "completion" or "graphs")s.PolicyVariant="completion_candidate";
  if(name=="retention")s.PolicyVariant="terminal_retention_candidate";if(name is "gap" or "profile")s.PolicyVariant="gap_candidate";
  if(name=="profile"){SichuanPolicyTiming.Enabled=true;SichuanPolicyTiming.Reset();}
  var facade=new SichuanAiFacade();facade.Agents.Begin([s]);
  var numeric=name.StartsWith("precision-")?name.Split('-'):null;
  using var numerical=numeric is null?null:SichuanReadyDevelopmentEvaluator.EnterNumericalResearch(int.Parse(numeric[1]),int.Parse(numeric[2]));
  var w=Stopwatch.StartNew();
  if(name=="joint-privacy")
  {
   if(!id.Contains("6-28"))continue;
   var model=new SichuanMahjong.AI.Core.Inference.SichuanJointReadinessProjection();var a=model.Analyze(s,4096,20261130);
   var alternate=SichuanBranchState.Copy(s,s.Hand18.ToArray());
   for(int seat=0;seat<4;seat++)if(seat!=s.SeatIndex)
   {
    alternate.IsReady[seat]=true;
    alternate.PublicEvents.Add(new(100000+seat,alternate.TurnIndex,seat,SichuanPublicEventType.Draw,7,SichuanTileOrigin.Draw));
   }
   alternate.VisibleVersion+=777;alternate.EventVersion+=444;
   var b=model.Analyze(alternate,4096,20261130);
   Check(a.Status==b.Status&&a.Target.SequenceEqual(b.Target)&&a.Ready.SequenceEqual(b.Ready)&&a.WallCopies.SequenceEqual(b.WallCopies),id+" private runtime flags/draw identities/transport versions ignored");
   bool blocked=false;using(var live=SichuanPolicyExecutionScope.EnterDecision())
   {try{model.Analyze(s,256,1);}catch(InvalidOperationException){blocked=true;}}
   Check(blocked,id+" joint terminal diagnostic cannot enter live decision");
   var invalid=SichuanBranchState.Copy(s,s.Hand18.ToArray(),wallCount:s.WallCount+1);
   Check(!model.Analyze(invalid,256,1).Supported,id+" contradictory public stock explicitly refused");
   rows.Add(new{id,status=a.Status,checks="privacy/live-boundary/stock"});continue;
  }
  if(name is "joint-audit" or "joint-audit-large" or "joint-profile")
  {
   foreach(int seed in new[]{20261130,20261209})
   {
    var r=new SichuanMahjong.AI.Core.Inference.SichuanJointReadinessProjection().Analyze(s,name=="joint-audit-large"?16384:name=="joint-profile"?256:4096,seed);
    rows.Add(new{id,seed,report=r,ms=w.Elapsed.TotalMilliseconds});
    if(r.Supported)
    {
     Check(r.Particles.All(p=>SichuanPublicInferenceBoundary.ParticleConserves(s,p)),id+" calibrated physical particles");
     Check(Math.Abs(r.Particles.Sum(p=>p.Weight)-1)<1e-9,id+" normalized calibrated weights");
     witnesses[id+"/joint-"+seed]=new{state=s,particles=r.Particles};
    }
   }
   continue;
  }
  if(name=="posterior-audit")
  {
   var b=new SichuanBeliefEngine().Build(s);var inf=new SichuanMahjong.AI.Core.Inference.SichuanHiddenHandInferenceEngine();
   foreach(int n in new[]{256,4096})foreach(int seed in new[]{20261130,20261209})
   {
    var posterior=inf.Infer(s,n,seed);rows.Add(new{id,n,seed,target=b.SeatReadyPosterior,posterior.ReadyProbabilities,posterior.EffectiveSampleSize,posterior.ParticleCount});
   }
   continue;
  }
  if(name=="cash-model")
  {
   int t=c.GetProperty("offered").GetInt32();var b=new SichuanBeliefEngine().Build(s);var ev=new SichuanMeldCounterfactualEvaluator();
   using var budget=SichuanSearchBudget.Enter(s);using var decision=SichuanPolicyExecutionScope.EnterDecision();
   using var ownPlan=SichuanPolicyExecutionScope.UseOwnPlan(new SichuanRoundBrainEngine().Observe(s));
   using var common=SichuanReadyDevelopmentEvaluator.EnterReactionComparison(s,true);
   foreach(string a in new[]{"pass","peng"})
   {
    var v=ev.Evaluate(s,a,t,a=="peng"?2:0,s.OwnMeldCount+(a=="peng"?1:0),0,0,0,b,gangSourceSeat:s.CurrentSeat);
    var cash=v.ReadyDevelopmentEstimate?.Chance;
    rows.Add(new{id,action=a,first=v.BestDiscardTile,utility=v.Value,ownReceipt=cash?.ExpectedOwnWinGain,
     ownPayment=cash?.ExpectedOpponentLoss,terminal=cash?.ExpectedChaJiaoValue,initialDiscardLoss=v.ExpectedDiscardRisk,
     rawExpectedCash=cash is null?(double?)null:cash.ExpectedOwnWinGain-cash.ExpectedOpponentLoss+cash.ExpectedChaJiaoValue
      -v.ExpectedDiscardRisk-v.ExpectedGangDiscardExtraLoss+v.ImmediateGangGain-v.ExpectedGangRefundLoss,
     scope="Bounded trajectory raw expected cash and risk-adjusted utility are different quantities; neither is actual terminal game score."});
   }
   continue;
  }
  if(name=="invariance")
  {
   int t=c.GetProperty("offered").GetInt32();var b=new SichuanBeliefEngine().Build(s);var ev=new SichuanMeldCounterfactualEvaluator();
   using var budget=SichuanSearchBudget.Enter(s);using var decision=SichuanPolicyExecutionScope.EnterDecision();
   using var ownPlan=SichuanPolicyExecutionScope.UseOwnPlan(new SichuanRoundBrainEngine().Observe(s));
   using var common=SichuanReadyDevelopmentEvaluator.EnterReactionComparison(s,true);
   var selected=ev.Evaluate(s,"peng",t,2,s.OwnMeldCount+1,0,0,0,b,gangSourceSeat:s.CurrentSeat);
   var explicitFirst=ev.Evaluate(s,"peng",t,2,s.OwnMeldCount+1,0,0,0,b,plannedDiscardTile:selected.BestDiscardTile,gangSourceSeat:s.CurrentSeat);
   rows.Add(new{id,first=selected.BestDiscardTile,selected,explicitFirst,difference=explicitFirst.Value-selected.Value});
   Check(Math.Abs(selected.Value-explicitFirst.Value)<1e-9,id+" same executable first discard must have one monetary value");continue;
  }
  if(name.StartsWith("worlds-"))
  {
   int samples=int.Parse(name.Split('-')[1]),seed=samples==8?20261107:20261119;
   if(!id.Contains("6-28-base-offer"))continue;
   var b=new SichuanBeliefEngine().Build(s);
   var brain=new SichuanRoundBrainEngine().Observe(s);
   int discard;
   using(var root=SichuanSearchBudget.Enter(s))using(var cache=SichuanPolicyExecutionScope.EnterDecision())
   using(var ownPlan=SichuanPolicyExecutionScope.UseOwnPlan(brain))
   using(var common=SichuanReadyDevelopmentEvaluator.EnterReactionComparison(s,true))
    discard=new SichuanMeldCounterfactualEvaluator().Evaluate(s,"peng",c.GetProperty("offered").GetInt32(),2,s.OwnMeldCount+1,0,0,0,b,gangSourceSeat:s.CurrentSeat).BestDiscardTile;
   var particles=new SichuanMahjong.AI.Core.Inference.SichuanHiddenHandInferenceEngine().SampleParticles(s,samples,seed,
      SichuanMahjong.AI.Core.Inference.SichuanHiddenHandProposal.PublicPriorThenLikelihood,minimumParticleCount:8);
   int index=0;
   foreach(var particle in particles)
   {
    if(!SichuanPublicInferenceBoundary.ParticleConserves(s,particle))throw new Exception("research particle stock failure");
    var wall=Enumerable.Range(0,27).SelectMany(t=>Enumerable.Repeat(t,particle.Wall27[t])).ToArray();var rng=new Random(seed+index*7919);
    for(int i=wall.Length-1;i>0;i--){int j=rng.Next(i+1);(wall[i],wall[j])=(wall[j],wall[i]);}
    var hands=particle.Hands27.Select(h=>h.ToArray()).ToArray();hands[s.SeatIndex]=s.Hand18.ToArray();
    rows.Add(new{id=id+"/world"+index,source=id,weight=particle.Weight,pengDiscard=discard,
     fixture=new{hands,state=s,wall_order=wall,winning=new Dictionary<int,int>(),offered=c.GetProperty("offered").GetInt32()}});index++;
   }
   continue;
  }
  if(name=="retention-diagnostic")
  {
   var b=new SichuanBeliefEngine().Build(s);
   if(c.TryGetProperty("readiness_prior",out var qp))
   {b=new SichuanBeliefSnapshot();int index=0;foreach(var q in qp.EnumerateArray())b.SeatReadyPosterior[index++]=q.GetDouble();}
   var report=new SichuanMahjong.AI.Core.Inference.SichuanTerminalRetentionModel().Evaluate(s,b,
       c.TryGetProperty("samples",out var ss)?ss.GetInt32():256,c.TryGetProperty("seed",out var se)?se.GetInt32():20261030);
   rows.Add(new{id,priors=b.SeatReadyPosterior,report});continue;
  }
  if(name=="graphs")
  {
   var b=new SichuanBeliefEngine().Build(s);var wall=new SichuanWallAvailabilityEngine().Build(s,b);var planner=new SichuanReadyDevelopmentEvaluator();
   var h=s.Hand18.ToArray();if(h.Sum()%3==2)h[c.GetProperty("draw").GetInt32()]--;
   var endpoints=planner.Endpoints(s,wall);var plan=planner.AdaptivePlan(s,h,endpoints,wall,Math.Max(2,s.ActiveSeats.Count(x=>x)));
   rows.Add(new{id,initial=h,missing=s.OwnDingQueSuit,exposed=Array(c,"exposed"),endpoints=endpoints.Count,plan});continue;
  }
  if(name=="detail")
  {
   var b=new SichuanBeliefEngine().Build(s);var ev=new SichuanMeldCounterfactualEvaluator();
   if(c.TryGetProperty("offered",out var offerDetail))
   {int t=offerDetail.GetInt32();rows.Add(new{id,pass=ev.Evaluate(s,"pass",-1,0,s.OwnMeldCount,0,0,0,b),peng=s.Hand18[t]>=2?ev.Evaluate(s,"peng",t,2,s.OwnMeldCount+1,0,0,0,b):null});}
   else rows.Add(new{id,common=new SichuanUnifiedDecisionEngine().RankDiscards(s,b),pass=ev.Evaluate(s,"continue",-1,0,s.OwnMeldCount,0,0,0,b)});
   continue;
  }
  string action;int tile,child=-1;object values;IReadOnlyList<string> reasons;SichuanDecisionCommand? command;
  if(c.TryGetProperty("offered",out var offered))
  {
   tile=offered.GetInt32();var h=s.Hand18.ToArray();h[tile]++;
   bool hu=analyzer.EnumerateWinningDecompositions(h,s.OwnMeldCount,s.OwnMeldCount==0).Count>0;
   var r=facade.DecideReaction(s,tile,hu,s.Hand18[tile]>=2,s.Hand18[tile]>=3&&s.WallCount>0,(s.SeatIndex+3)%4);
   action=r.Action.ActionType.ToString();tile=r.Action.TileType;child=r.PlannedDiscardTile;values=new {scores=r.ActionScores,candidates=r.ValueCandidates};reasons=r.Reasons;command=r.Command;
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

  rows.Add(new{id,section=c.GetProperty("section").GetString(),action,tile,child,ms=w.Elapsed.TotalMilliseconds,values,reasons,command,brain=facade.Agents.Capture(s).Brain,qing=new SichuanQingYiSePlanner().Evaluate(s),timing=name=="profile"?SichuanPolicyTiming.Snapshot():null,diagnostic=!c.TryGetProperty("offered",out _) ? facade.DecideDiscard(s).Candidates.Select(x=>new{x.TileType,x.Shanten,x.LiveUkeire,x.Danger,x.UnifiedActionValue,x.ExpectedValue,x.Reasons}).ToArray():null});
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
  AddOpponentMeld((own+entry.GetProperty("relative").GetInt32())%4,entry.GetProperty("tile").GetInt32(),entry.TryGetProperty("size",out var size)?size.GetInt32():3);
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
 var random=new Random(20261030);
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
 if(c.TryGetProperty("known_by_relative",out var rivers))
 {
  if(!known.Order().SequenceEqual(rivers.EnumerateArray().SelectMany(x=>x.EnumerateArray().Select(t=>t.GetInt32())).Order()))throw new Exception("exact public river totals changed");
  // The drawing fixes per-seat rivers, not complete interleaved event timing.
  // This deterministic interleave is declared reconstruction, not book history.
  for(int rel=0;rel<4;rel++)foreach(var entry in rivers[rel].EnumerateArray())
  {int t=entry.GetInt32(),seat=(own+rel)%4;s.Discards18[seat].Add(t);s.PublicEvents.Add(new(++eventIndex,++turn,seat,SichuanPublicEventType.Discard,t,SichuanTileOrigin.Unknown));}
 }
 else foreach(int t in known){int seat=turn++%4;s.Discards18[seat].Add(t);s.PublicEvents.Add(new(++eventIndex,turn,seat,SichuanPublicEventType.Discard,t,SichuanTileOrigin.Unknown));}
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
 void AddOpponentMeld(int seat,int t,int count=3)
 {
  if(count is not (3 or 4)||pool[t]<count)throw new Exception("opponent public meld capacity");pool[t]-=count;s.Melds18[seat].AddRange(Enumerable.Repeat(t,count));s.MeldViews[seat].Add(new(count==3?SichuanMeldType.Peng:SichuanMeldType.MeldedGang,t,own,++eventIndex));
  s.PublicEvents.Add(new(++eventIndex,0,seat,count==3?SichuanPublicEventType.Peng:SichuanPublicEventType.MeldedGang,t,SourceSeat:own));
 }
}
