#nullable enable
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Reflection;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Search;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Entry;
var folder=args[0];var errors=new List<string>();int checks=0;
void Check(bool ok,string id){checks++;if(!ok)errors.Add(id);}
void Near(double a,double b,string id)=>Check(Math.Abs(a-b)<1e-9,$"{id}: {a:R} vs {b:R}");
var json=new JsonSerializerOptions{PropertyNameCaseInsensitive=true,Converters={new JsonStringEnumConverter()}};
SichuanStateView State(JsonElement raw)
{
 var s=new SichuanStateView();
 foreach(var p in typeof(SichuanStateView).GetProperties().Where(x=>x.CanWrite))
  foreach(var v in raw.EnumerateObject())if(string.Equals(p.Name,v.Name,StringComparison.OrdinalIgnoreCase))p.SetValue(s,JsonSerializer.Deserialize(v.Value.GetRawText(),p.PropertyType,json));
 s.PublicEvents.AddRange(JsonSerializer.Deserialize<List<SichuanPublicEvent>>(raw.GetProperty("publicEvents").GetRawText(),json)!);
 var melds=JsonSerializer.Deserialize<List<SichuanMeldView>[]>(raw.GetProperty("meldViews").GetRawText(),json)!;
 for(int seat=0;seat<4;seat++)s.MeldViews[seat].AddRange(melds[seat]);s.RoundId="";return s;
}
using var input=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"game-results.json")));
var rawRows=input.RootElement.GetProperty("rows").EnumerateArray().ToArray();var rows=new List<object>();
var engines=new Dictionary<string,SichuanDecisionExplanation>();
foreach(var row in rawRows.Where(r=>!r.GetProperty("compact").GetBoolean()))
{
 var id=row.GetProperty("id").GetString()!;var s=State(row.GetProperty("payload"));
 SichuanDecisionExplanation baseline;
 using(SichuanSearchBudget.Enter(s))using(SichuanSearchBudget.EnterBranch())
  baseline=new SichuanUnifiedDecisionEngine().RankDiscards(s);
 var refined=new SichuanUnifiedDecisionEngine().RankDiscards(s);engines[id]=refined;
 var formal=new SichuanAiFacade().DecideDiscard(s);
 foreach(var c in refined.Candidates.Where(c=>c.ModeledOwnWinProbability is not null))
 {
  var d=formal.Candidates.Single(c2=>c2.TileType==c.Action.TileType);
  Near(c.ModeledOwnWinProbability!.Value,d.WinProbability,"facade/common Hu");
  if (c.ModeledSelfDrawProbability is { } selfDraw)
   Near(selfDraw,d.SelfDrawProbability,"facade/common self-draw");
  else
   Check(double.IsFinite(d.SelfDrawProbability),"facade/common self-draw availability");
  Check(d.WinProbability>=0&&d.WinProbability<=1
   && d.SelfDrawProbability>=0&&d.SelfDrawProbability<=1,"probability bounds");
 }
 var compact=rawRows.Single(r=>r.GetProperty("compact").GetBoolean()&&r.GetProperty("id").GetString()==id);
 Check(compact.GetProperty("actual").GetInt32()==row.GetProperty("actual").GetInt32(),"normal/compact execution");
 foreach(var c in row.GetProperty("diagnostic").GetProperty("candidates").EnumerateArray())
 {
  var other=compact.GetProperty("diagnostic").GetProperty("candidates").EnumerateArray().Single(t=>t.GetProperty("tileType").GetDouble()==c.GetProperty("tileType").GetDouble());
  Near(c.GetProperty("winProbability").GetDouble(),other.GetProperty("winProbability").GetDouble(),"normal/compact probability");
 }
 rows.Add(new{id,selected=formal.Action.TileType,root=row.GetProperty("actual").GetInt32(),baseline=baseline.Candidates.Where(c=>c.ReadyPrice is not null).Select(c=>new{tile=c.Action.TileType,c.ModeledOwnWinProbability,c.ModeledSelfDrawProbability,c.WinGain}),
  refined=refined.Candidates.Where(c=>c.ReadyPrice is not null).Select(c=>new{tile=c.Action.TileType,c.ModeledOwnWinProbability,c.ModeledSelfDrawProbability,c.WinGain,status=c.ReasonCodes.FirstOrDefault(r=>r.StartsWith("PUBLIC_SUPPLY_"))})});
}
foreach(var tile in new[]{0,4})
 Near(engines["supply2"].Candidates.Single(c=>c.Action.TileType==tile).ModeledOwnWinProbability!.Value,
  engines["supply2-hidden-swap"].Candidates.Single(c=>c.Action.TileType==tile).ModeledOwnWinProbability!.Value,"hidden swap cannot change observer estimate");
var memoState=State(rawRows[0].GetProperty("payload"));
using(SichuanSearchBudget.Enter(memoState))using(SichuanPolicyExecutionScope.EnterDecision())
{
 var belief=new SichuanBeliefEngine().Build(memoState);
 var ranked=new SichuanUnifiedDecisionEngine().RankDiscards(memoState,belief);
 var rootReader=typeof(SichuanOpponentSupplyStep).GetMethod("RootReport",BindingFlags.NonPublic|BindingFlags.Static)!;
 var first=rootReader.Invoke(null,new object[]{memoState});
 var current=new SichuanMeldCounterfactualEvaluator().Evaluate(memoState,"continue",-1,0,memoState.OwnMeldCount,0,0,0,belief);
 var priced=ranked.Candidates.Single(c=>c.Action.TileType==current.BestDiscardTile);
 Check(current.ContinuationModel is "shared_public_first_opponent_step_then_fixed_wait" or "shared_executable_ready_action_value"
   || current.ContinuationModel.StartsWith("common_"),"own-turn continuation uses a shared executable chance model");
 if (priced.ModeledSelfDrawProbability is { } pricedSelfDraw)
  Check(double.IsFinite(current.FutureSelfDrawProbability)&&double.IsFinite(pricedSelfDraw),"own-turn continuation/common probability is finite");
 var second=rootReader.Invoke(null,new object[]{memoState});
 Check(first is not null&&ReferenceEquals(first,second),"pricing and discard reuse exactly one root report");
 var selfAction=new SichuanSelfActionDecisionEngine().DecideSelfAction(memoState,false,[],[]);
 Check(selfAction.Reasons.Any(r=>r.StartsWith("PUBLIC_SUPPLY_public_first_opponent_step_")),"issued own-turn path reports shared supply estimate");
 Check(ReferenceEquals(first,rootReader.Invoke(null,new object[]{memoState})),"issuing self action does not resample root");
}
// Contract checks are deliberately synthetic candidate values, not alleged
// recovered hands or calibrated probabilities.
var basis=engines["safe_current"].Candidates.First(c=>c.ReadyPrice is not null);
// A uniform price is part of the contract's premise. The physical fixture
// also has a legal dead root-producing wait, so do not pretend it is uniform.
basis=basis with{ReadyPrice=basis.ReadyPrice! with{Waits=[basis.ReadyPrice!.Waits[0]]}};
var a=basis with{Action=new(SichuanActionType.Discard,0),ModeledOwnWinProbability=.2,DealInLoss=0,OpponentFutureLoss=0,ChaJiaoValue=0,GangGain=0};
var b=a with{Action=new(SichuanActionType.Discard,4),ModeledOwnWinProbability=.7};
var contract=new Dictionary<int,SichuanDecisionCandidate>{{0,a},{4,b}};
int Pick(SichuanDecisionCandidate other,int priority=SichuanDiscardArbiter.GlobalPlan)
{var arbiter=new SichuanDiscardArbiter(new[]{0,4},0);arbiter.Propose(0,priority,"structure");return arbiter.Resolve(readyValues:new Dictionary<int,SichuanDecisionCandidate>{{0,a},{4,other}});}
Check(Pick(b)==4,"higher Hu beats structure with same price/cost");
Check(Pick(b with{DealInLoss=.01})==0,"higher deal-in cost prevents probability-only choice");
Check(Pick(b with{OpponentFutureLoss=.01})==0,"higher future payment prevents probability-only choice");
Check(Pick(b with{ChaJiaoValue=-.01})==4,"winning first can remove a same-price cha-jiao payment event");
Check(Pick(b,SichuanDiscardArbiter.ExtremeSafety)==0,"hard safety retains authority");
var different=b.ReadyPrice! with{Waits=b.ReadyPrice!.Waits.Select(w=>w with{HandScore=w.HandScore*2,CappedFan=w.CappedFan+1}).ToArray()};
Check(Pick(b with{ReadyPrice=different})==0,"different fan uses existing common value comparison");
// Independent finite-wall oracle. Production policy supplies only the first
// actor's choice. The expected probabilities/revenue are independently
// enumerated over every physical permutation of the remaining tiny wall.
var tiny=rawRows.First(r=>r.GetProperty("id").GetString()=="tiny");var source=State(tiny.GetProperty("payload"));
var hands=JsonSerializer.Deserialize<int[][]>(tiny.GetProperty("research_world").GetProperty("hands").GetRawText())!;
hands[source.SeatIndex]=new int[27]; // particle convention excludes observer hand
var wall=JsonSerializer.Deserialize<int[]>(tiny.GetProperty("research_world").GetProperty("wall").GetRawText())!;
var particle=new SichuanHiddenHandParticle(hands,wall,1);
var eval=typeof(SichuanOpponentSupplyStep).GetMethod("Evaluate",BindingFlags.NonPublic|BindingFlags.Static)!;
var actorView=typeof(SichuanOpponentSupplyStep).GetMethod("ActorView",BindingFlags.NonPublic|BindingFlags.Static)!;
IEnumerable<int[]> Permute(int[] tiles)
{
 if(tiles.Length==0){yield return [];yield break;}
 for(int i=0;i<tiles.Length;i++)foreach(var rest in Permute(tiles.Where((_,j)=>j!=i).ToArray()))yield return new[]{tiles[i]}.Concat(rest).ToArray();
}
var oracle=new List<object>();
foreach(var discard in new[]{0,4})foreach(var draw in Enumerable.Range(0,27).Where(t=>wall[t]>0))
{
 var after=SichuanBranchState.AfterDiscard(source,discard);
 after.PublicEvents[^1]=after.PublicEvents[^1] with{EventIndex=source.PublicEvents.Max(e=>e.EventIndex)+1};
 after.EventVersion=after.PublicEvents[^1].EventIndex;
 var hand=(int[])hands[2].Clone();hand[draw]++;
 var v=(SichuanStateView)actorView.Invoke(null,new object[]{after,2,hand,draw})!;
 Check(v.SeatIndex==2&&v.CurrentSeat==2&&v.Hand18.SequenceEqual(hand),"actor owns its own view");
 Check(v.RoundId==""&&v.IsReady.All(x=>!x)&&v.PassedHu18.All(x=>x.All(t=>t==0)),"actor no observer private flags");
 Check(v.PublicEvents.Where(e=>e.Type==SichuanPublicEventType.Draw&&e.Seat!=2).All(e=>e.TileType==-1),"actor no private draw identities");
 Check(v.PublicEvents.All(e=>e.Type!=SichuanPublicEventType.Pass),"actor no private pass alternatives");
 Check(Enumerable.Range(0,27).All(t=>v.Remaining18[t]==4-v.Visible18[t]-hand[t]),"actor availability uses own hand");
 var legal=SichuanOwnTurnActions.FromState(v);Check(!legal.CanHu&&legal.Concealed.Length==0&&legal.Added.Length==0,"tiny oracle first step is discard only");
 var before=SichuanBranchState.Copy(v,hands[2],source.WallCount,source.SeatIndex);
 before.HandCounts[2]=hands[2].Sum();before.LastDrawTileType=-1;before.LastDrawOrigin=SichuanTileOrigin.Unknown;before.OwnDrawReason="";before.PublicEvents.RemoveAt(before.PublicEvents.Count-1);
 for(int t=0;t<27;t++)before.Remaining18[t]=4-before.Visible18[t]-before.Hand18[t];
 var brain=new SichuanRoundBrainEngine();brain.Observe(before);var plan=brain.Observe(v);
 var offered=SichuanDiscardPolicy.Select(v,plan,searchLeaf:true).Action.TileType;
 var own=(int[])source.Hand18.Clone();own[discard]--;
 var price=new SichuanReadyWaitPricing().Build(source,own,wall.Select(x=>(double)x).ToArray())!;
 var request=new SichuanActionTreeEvaluator.ChanceSearchRequest(price.PublicDrawableMass,4,2,1,price.WeightedSelfDrawPerPayer,0,0,MaxDraws:4,ReadyGroups:SichuanReadyRaceSupply.Build(source,price));
 var call=new object?[]{source,particle,2,draw,discard,price,request,false,false};
 var actual=(SichuanActionTreeEvaluator.ChanceSearchResult)eval.Invoke(null,call)!;
 var residual=(int[])wall.Clone();residual[draw]--;
 double wins=0,self=0,gain=0;int permutations=0;
 foreach(var order in Permute(Enumerable.Range(0,27).SelectMany(t=>Enumerable.Repeat(t,residual[t])).ToArray()))
 {
  permutations++;var immediate=price.Waits.FirstOrDefault(w=>w.TileType==offered);
  if(immediate is not null){wins++;gain+=immediate.HandScore;continue;}
  for(int pos=0;pos<order.Length;pos++)
  {
   var w=price.Waits.FirstOrDefault(w=>w.TileType==order[pos]);if(w is null)continue;
   bool ownDraw=pos%2==0;
   if(!ownDraw&&source.DingQueSuits[2]!=order[pos]/9)continue;
   wins++;if(ownDraw)self++;gain+=ownDraw?w.SelfDrawPerPayer:w.HandScore;break;
  }
 }
 Near(actual.OwnWinProbability,wins/permutations,"independent first-step+tail Hu");
 Near(actual.SelfDrawWinProbability,self/permutations,"independent first-step+tail self-draw");
 Near(actual.ExpectedOwnWinGain,gain/permutations,"independent first-step+tail revenue");
 Near(actual.DiscardHuProbability,(wins-self)/permutations,"independent first-step+tail Ron");
 oracle.Add(new{discard,draw,offered,permutations,actual.OwnWinProbability,actual.SelfDrawWinProbability,actual.ExpectedOwnWinGain});
}
foreach(var (id,actor,draw,expectGang) in new[]{("opponent_selfhu",2,26,false),("active_peng2",0,1,true)})
{
 var row=rawRows.First(r=>r.GetProperty("id").GetString()==id);
 var s=State(row.GetProperty("payload"));
 var h=JsonSerializer.Deserialize<int[][]>(row.GetProperty("research_world").GetProperty("hands").GetRawText())!;h[s.SeatIndex]=new int[27];
 var w=JsonSerializer.Deserialize<int[]>(row.GetProperty("research_world").GetProperty("wall").GetRawText())!;
 var p=new SichuanHiddenHandParticle(h,w,1);var own=(int[])s.Hand18.Clone();own[0]--;
 var price=new SichuanReadyWaitPricing().Build(s,own,w.Select(n=>(double)n).ToArray())!;
 var request=new SichuanActionTreeEvaluator.ChanceSearchRequest(price.PublicDrawableMass,w.Sum(),2,1,price.WeightedSelfDrawPerPayer,0,0);
 var call=new object?[]{s,p,actor,draw,0,price,request,false,false};
 var result=(SichuanActionTreeEvaluator.ChanceSearchResult?)eval.Invoke(null,call);
 if(expectGang){Check(result is null,"legal added Gang is not replaced with a discard");continue;}
 Check(result is not null,"modeled first-opponent self-Hu transition");
 Near(result!.OwnWinProbability,0,"last opponent Hu ends own winning opportunity");
 Near(result.BattleEndProbability,1,"last opponent Hu ends blood battle");
 var completed=(int[])h[actor].Clone();completed[draw]++;
 var loss=new SichuanFanProjectionEngine().Project(completed,s.MeldViews[actor],SichuanWinType.SelfDraw).PerPayerScore;
 Near(result.ExpectedOpponentLoss,loss,"first-opponent self-Hu charges rule score");
}
File.WriteAllText(Path.Combine(folder,"audit-results.json"),JsonSerializer.Serialize(new{checks,errors,rows,oracle},new JsonSerializerOptions{WriteIndented=true}));
Console.WriteLine($"SUPPLY_AUDIT checks={checks} errors={errors.Count}");foreach(var e in errors.Take(12))Console.WriteLine(e);
return errors.Count==0?0:1;
