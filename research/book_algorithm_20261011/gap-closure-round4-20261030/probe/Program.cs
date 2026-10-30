using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;
using System.Text.Json;
using System.Diagnostics;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Decision;
using M=SichuanMahjong.AI.Core.Search.SichuanDevelopmentTrajectoryModel;
using Round4;

if(args.Length>1&&args[1]=="--identities")
{
 var map=new Dictionary<string,string>();
 foreach(var path in args.Skip(2))
 {
  using var stream=File.OpenRead(path);using var pe=new PEReader(stream);
  var metadata=pe.GetMetadataReader();map[path]=metadata.GetGuid(metadata.GetModuleDefinition().Mvid).ToString("D");
 }
 File.WriteAllText(Path.Combine(args[0],"binary-identities.json"),JsonSerializer.Serialize(map,new JsonSerializerOptions{WriteIndented=true}));
 return 0;
}
string folder=Path.GetFullPath(args[0]);var failures=new List<string>();int checks=0,walls=0,paths=0;
void Check(bool ok,string id){checks++;if(!ok)failures.Add(id);}
var rng=new Random(2026103104);var wallEngine=new SichuanWallAvailabilityEngine();var watch=Stopwatch.StartNew();
foreach(int k in Enumerable.Range(0,180))
{
 var state=new SichuanStateView{SeatIndex=1,WallCount=k%12==0?0:rng.Next(1,65),Remaining18=Enumerable.Range(0,27).Select(_=>rng.Next(5)).ToArray(),HandCounts=[13,14,13,13],DingQueSuits=[0,1,0,0],ActiveSeats=[true,true,true,true],HasHu=new bool[4]};
 var belief=new SichuanBeliefSnapshot();for(int t=0;t<27;t++)belief.TileWallPosterior[t]=k%13==0?double.NaN:rng.NextDouble()*1.2-.1;
 // Make guaranteed-wall evidence explicit. Some invalid bounds deliberately
 // check identical rejection; these are numerical toys, not natural games.
 if(k%3==0)foreach(int seat in new[]{0,2,3})
 {state.PublicEvents.Add(new(seat,1,seat,SichuanPublicEventType.Discard,10,SichuanTileOrigin.Hand));state.Discards18[seat].Add(10);}
 foreach(int suit in new[]{0,1,2})foreach(int seed in new[]{int.MinValue,-7,0,1,20261030,int.MaxValue})
 {
  int[]? before=null,after=null;Exception? be=null,ae=null;
  try{before=OldWallSampler.SampleWallOrder(state,belief,seed,suit);}catch(Exception ex){be=ex;}
  try{after=wallEngine.SampleWallOrder(state,belief,seed,suit);}catch(Exception ex){ae=ex;}
  Check(be?.GetType()==ae?.GetType(),$"wall rejection {k}/{suit}/{seed}");
  if(be is null){Check(before!.SequenceEqual(after!),$"wall bit identity {k}/{suit}/{seed}");walls++;}
 }
 try
 {
  var prepared=wallEngine.PrepareWallOrders(state,belief);var expected=OldWallSampler.SampleWallOrder(state,belief,17);
  var signature=prepared.Signature;
  Check(prepared.Sample(17).SequenceEqual(expected),"prepared exact law");
  belief.TileWallPosterior[0]=.3125;state.Remaining18[0]=(state.Remaining18[0]+1)%5;state=SichuanBranchState.Copy(state,wallCount:state.WallCount+1);
  Check(prepared.Sample(17).SequenceEqual(expected),"prepared snapshot unaffected by later mutations");
  var changed=wallEngine.PrepareWallOrders(state,belief);Check(changed.Signature!=signature,"changed actual sampling inputs invalidate key");
 }catch(InvalidOperationException){}
}
// Exercise the actual decision-local reuse key, not just the sampler helper.
var cachedState=new SichuanStateView{SeatIndex=1,WallCount=20,Remaining18=Enumerable.Repeat(2,27).ToArray(),HandCounts=[13,14,13,13],DingQueSuits=[0,1,2,0],ActiveSeats=[true,true,true,true],HasHu=new bool[4]};
var cachedBelief=new SichuanBeliefSnapshot();for(int t=0;t<27;t++)cachedBelief.TileWallPosterior[t]=.4;
var planner=new SichuanReadyDevelopmentEvaluator();M.World[]? firstBatch=null;
using(SichuanPolicyExecutionScope.EnterDecision())
{
 firstBatch=planner.SharedWorlds(cachedState,cachedBelief,12);
 Check(ReferenceEquals(firstBatch,planner.SharedWorlds(cachedState,cachedBelief,12)),"identical numeric law reused within one decision");
 for(int i=0;i<12;i++)
 {
  int seed=20261022+i*7919;var random=new Random(seed^104729);
  Check(firstBatch[i].Wall.SequenceEqual(OldWallSampler.SampleWallOrder(cachedState,cachedBelief,seed)),"cached exact per-seed wall");
  Check(firstBatch[i].SelfUniform.SequenceEqual(Enumerable.Range(0,80).Select(_=>random.NextDouble())),"cached exact self stream");
  Check(firstBatch[i].RonUniform.SequenceEqual(Enumerable.Range(0,80).Select(_=>random.NextDouble())),"cached exact Ron stream");
  Check(firstBatch[i].ClaimRonUniform!.SequenceEqual(Enumerable.Range(0,80).Select(_=>random.NextDouble())),"cached exact post-claim stream");
 }
 cachedState.VisibleVersion++;
 Check(ReferenceEquals(firstBatch,planner.SharedWorlds(cachedState,cachedBelief,12)),"transport version alone not a draw-law input");
 cachedBelief.TileWallPosterior[3]=.7;
 var changedBatch=planner.SharedWorlds(cachedState,cachedBelief,12);
 Check(!ReferenceEquals(firstBatch,changedBatch),"changed wall evidence requires fresh worlds");
 Check(ReferenceEquals(firstBatch[0].SelfUniform,changedBatch[0].SelfUniform)&&ReferenceEquals(firstBatch[0].RonUniform,changedBatch[0].RonUniform)&&ReferenceEquals(firstBatch[0].ClaimRonUniform,changedBatch[0].ClaimRonUniform),"different wall laws reuse only identical fixed uniform streams");
 cachedBelief.TileWallPosterior[3]=.4;cachedState=SichuanBranchState.Copy(cachedState,wallCount:55);
 var oversized=planner.SharedWorlds(cachedState,cachedBelief,12);cachedState=SichuanBranchState.Copy(cachedState,wallCount:56);
 Check(!ReferenceEquals(oversized,planner.SharedWorlds(cachedState,cachedBelief,12)),"uniform-stream length keyed even if effective wall target is same");
 cachedState=SichuanBranchState.Copy(cachedState,wallCount:20);
}
using(SichuanPolicyExecutionScope.EnterDecision())Check(!ReferenceEquals(firstBatch,planner.SharedWorlds(cachedState,cachedBelief,12)),"no world cache survives decision boundary");
using(SichuanPolicyExecutionScope.EnterDecision())
{
 var large=planner.SharedWorlds(cachedState,cachedBelief,2048);
 for(int i=0;i<large.Length;i++)Check(large[i].Wall.SequenceEqual(OldWallSampler.SampleWallOrder(cachedState,cachedBelief,20261022+i*7919)),"parallel wall generation exact seed "+i);
}
foreach(int k in Enumerable.Range(0,240))
{
 int own=k%4;var order=Enumerable.Range(0,4).OrderBy(_=>rng.Next()).Take(2+k%3).ToArray();
 if(!order.Contains(own))order[0]=own;
 int live=order.Aggregate(0,(a,s)=>a|(1<<s));
 if(k%5==0&&order.Length>2)live&=~(1<<order.Last(s=>s!=own));
 int first=order.First(s=>(live&(1<<s))!=0);
 var stages=new List<M.Stage>();int n=2+k%5;
 for(int i=0;i<n;i++)
 {
  bool ready=i==n-1||rng.Next(4)==0;var ron=new double[27];var self=new double[27];var next=Enumerable.Repeat(-1,27).ToArray();var peng=next.ToArray();
  for(int t=0;t<27;t++)
  {if(ready&&rng.Next(5)==0){ron[t]=1<<rng.Next(4);self[t]=ron[t]+1;}
   if(!ready&&i+1<n){if(rng.Next(4)==0)next[t]=i+1;if(rng.Next(6)==0)peng[t]=i+1;}}
  stages.Add(new(ron,self,next,peng,rng.Next(27),ready){ChaJiaoScore=1<<rng.Next(4),OwnDiscards=Enumerable.Range(0,27).Select(_=>rng.Next(27)).ToArray(),PengDiscards=Enumerable.Range(0,27).Select(_=>rng.Next(27)).ToArray()});
 }
 var plan=new M.Plan("synthetic-semantic-parity",stages.ToArray());
 var env=new M.Environment(own,order,Enumerable.Range(0,4).Select(_=>rng.Next(3)).ToArray(),Enumerable.Range(0,4).Select(_=>rng.NextDouble()*.4).ToArray(),Enumerable.Range(0,4).Select(_=>Enumerable.Range(0,27).Select(_=>rng.NextDouble()*.5).ToArray()).ToArray(),Enumerable.Range(0,4).Select(_=>(double)(1<<rng.Next(4))).ToArray(),Enumerable.Range(0,4).Select(_=>(double)(1<<rng.Next(4))).ToArray(),Enumerable.Range(0,4).Select(_=>rng.NextDouble()*2).ToArray(),first,k%2==0?Enumerable.Range(0,4).Select(_=>rng.Next(2)==0).ToArray():null){InitialLiveMask=live,RonPaymentByTile=k%3==0?Enumerable.Range(0,4).Select(_=>Enumerable.Range(0,27).Select(_=>(double)rng.Next(1,9)).ToArray()).ToArray():null};
 var worlds=new M.World[64];
 for(int j=0;j<worlds.Length;j++)
 {
  int length=(j+k)%56;var deck=Enumerable.Range(0,108).OrderBy(_=>rng.Next()).Take(length).Select(t=>t/4).ToArray();
  var world=new M.World(deck,Enumerable.Range(0,length*4).Select(_=>rng.NextDouble()).ToArray(),Enumerable.Range(0,length*4).Select(_=>rng.NextDouble()).ToArray(),j%2==0?Enumerable.Range(0,length*4).Select(_=>rng.NextDouble()).ToArray():null){TerminalReadyScores=j%3==0?Enumerable.Range(0,4).Select(_=>rng.Next(5)).ToArray():null,TerminalFlowerPigs=j%3==0?Enumerable.Range(0,4).Select(_=>rng.Next(9)==0).ToArray():null};
  worlds[j]=world;
  var a=OldTrajectory.Run(plan,world,env);var b=M.Run(plan,world,env);
  Check(JsonSerializer.Serialize(a)==JsonSerializer.Serialize(b),$"trajectory exact outcome {k}/{j}");paths++;
 }
 Check(BitConverter.DoubleToInt64Bits(M.EvaluateMean(plan,worlds,env))==BitConverter.DoubleToInt64Bits(OldTrajectory.Evaluate(plan,worlds,env).Chance.ExpectedNetScore),"discovery scalar exact four-sum mean "+k);
 if(k<16)
 {
  var large=Enumerable.Range(0,2048).Select(i=>worlds[i%worlds.Length]).ToArray();
  long expected=BitConverter.DoubleToInt64Bits(OldTrajectory.Evaluate(plan,large,env).Chance.ExpectedNetScore);
  for(int repeat=0;repeat<3;repeat++)Check(BitConverter.DoubleToInt64Bits(M.EvaluateMean(plan,large,env))==expected,"parallel paths and ordered cash reduction bit exact "+k+"/"+repeat);
 }
 Check(JsonSerializer.Serialize(OldTrajectory.Evaluate(plan,worlds,env))==JsonSerializer.Serialize(M.Evaluate(plan,worlds,env)),"trajectory aggregate and paired arrays bit identity "+k);
}
File.WriteAllText(Path.Combine(folder,"kernel-parity.json"),JsonSerializer.Serialize(new{checks,walls,paths,failures,ms=watch.Elapsed.TotalMilliseconds,processors=System.Environment.ProcessorCount,scope="Exact semantic parity to archived original kernels; numerical toy cases, not strength or natural game claims."},new JsonSerializerOptions{WriteIndented=true}));
Console.WriteLine($"KERNEL checks={checks} walls={walls} paths={paths} failures={failures.Count}");return failures.Count==0?0:1;
