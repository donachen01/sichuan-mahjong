using System.Text.Json;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Strategy;

var dir=Path.GetFullPath(args[0]);
var rows=new List<object>();
var failures=new List<string>();
var checks=0;
void Check(bool ok,string why){checks++;if(!ok)failures.Add(why);}
int[] H(params int[] tiles){var h=new int[27];foreach(var t in tiles)h[t]++;return h;}
SichuanStateView State(int[] hand,int wall=40)
{
    var remaining=new int[27];var visible=new int[27];
    for(int t=0;t<27;t++)remaining[t]=4-hand[t];
    var toExpose=remaining.Sum()-wall-39;
    for(int t=0;t<27&&toExpose>0;t++){var n=Math.Min(toExpose,remaining[t]);visible[t]+=n;remaining[t]-=n;toExpose-=n;}
    return new SichuanStateView{SeatIndex=1,CurrentSeat=1,Phase=5,RoundIndex=1,
        RoundId="route-acceptance",WallCount=wall,Hand18=hand,Visible18=visible,
        Remaining18=remaining,HandCounts=[13,14,13,13],DingQueSuits=[1,2,2,2],
        ActiveSeats=[true,true,true,true],HasHu=[false,false,false,false],
        OwnDrawReason="normal_draw",InformationMode="public"};
}

var seven=State(H(0,0,3,3,6,6,9,10,11,12,14,15,16,17));
var brain=new SichuanRoundBrainEngine();
brain.Restore(seven,new(8,1,"暗七对","平胡",1,95,new(),[],[]));
var before=brain.Observe(seven);
var changedSeven=H(0,0,3,3,6,7,9,10,11,12,14,15,16,17);for(var t=0;t<27;t++)seven.Hand18[t]=changedSeven[t];seven.HandCounts[1]=14;seven.ViewVersion=2;
var after=brain.Observe(seven);
var plan=new SichuanRoutePlanEngine().Evaluate(seven,after);
Check(after.PrimaryRoute!="暗七对","ordinary Seven memory exits after pair prerequisite lost");
Check(!plan.ForbidsMelds&&!plan.ForbidsGangs,"ordinary route restores Peng/Gang exits after Seven loss");
rows.Add(new{id="seven_memory_loss",before=before.PrimaryRoute,after=after.PrimaryRoute,plan=plan.PrimaryRoute,constraints=plan.Constraints,reasons=after.Reasons.TakeLast(3)});

var flushHand=H(0,0,1,2,3,4,5,6,7,8,9,18,19,20,21);var flush=State(flushHand);
for(int t=0;t<9;t++){flush.Visible18[t]=4-flush.Hand18[t];flush.Remaining18[t]=0;}
flush.ViewVersion=3;
var flushBrain=new SichuanRoundBrainEngine();
flushBrain.Restore(flush,new(8,1,"清一色","平胡",0,90,new(),[],[]));
var flushBefore=flushBrain.Observe(flush);var flushAfter=flushBrain.Observe(flush);
var flushPlan=new SichuanRoutePlanEngine().Evaluate(flush,flushAfter);
var capacity=SichuanFlushCopyCapacity.Assess(flush,flush.Hand18,0);
Check(!capacity.Admissible,"flush target exits when public copies cannot complete");
Check(flushPlan.PrimaryRoute!="清一色"||flushPlan.Constraints.Count==0,"flush memory does not retain impossible target");
rows.Add(new{id="flush_capacity_loss",before=flushBefore.PrimaryRoute,after=flushAfter.PrimaryRoute,plan=flushPlan.PrimaryRoute,admissible=capacity.Admissible,reason=capacity.Reason});

var stable=State(H(0,0,0,1,2,3,4,5,6,7,8,9,10,11));
var stableBrain=new SichuanRoundBrainEngine();
stableBrain.Restore(stable,new(8,1,"清一色","平胡",0,90,new(),[],[]));
var stableOne=stableBrain.Observe(stable);var stableTwo=stableBrain.Observe(stable);
var stablePlan=new SichuanRoutePlanEngine().Evaluate(stable,stableTwo);
Check(stableTwo.PrimaryRoute=="清一色"||stablePlan.PrimaryRoute=="清一色","physically admissible committed flush is not forced out");
rows.Add(new{id="flush_stable",before=stableOne.PrimaryRoute,after=stableTwo.PrimaryRoute,plan=stablePlan.PrimaryRoute,revision=stableTwo.Revision});

File.WriteAllText(Path.Combine(dir,"route-results.json"),JsonSerializer.Serialize(new{checks,failures,rows},new JsonSerializerOptions{WriteIndented=true}));
Console.WriteLine($"ROUTE checks={checks} failures={failures.Count}");
foreach(var f in failures)Console.WriteLine("FAIL "+f);
return failures.Count==0?0:1;
