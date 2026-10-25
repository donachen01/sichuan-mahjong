using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using M=SichuanMahjong.AI.Core.Search.SichuanDevelopmentTrajectoryModel;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Short-wall comparison of fixed, public-information endpoint plans.
/// Plans are chosen on discovery hypotheses BEFORE independent confirmation.
/// This does not run the production policy against a sampled or actual wall.
/// Opponent development is the existing structural terminal forecast, not a
/// calibrated model of voluntary claims, adaptive defense or future Gang.</summary>
internal sealed class SichuanLateWallDiscardEvaluator
{
    internal const string Applied="SHORT_WALL_COMMON_SETTLEMENT_VALUE";
    internal const int MaximumWall=8;
    internal const int MaximumWiderWall=40;
    internal sealed record Value(double Gain,double InitialLoss,double FutureLoss,double Cha,double Refund,
        double RiskUncertainty,double WinProbability,double ReadyProbability,double StandardError,string Plan)
    {
        public double Net=>Gain-InitialLoss-FutureLoss+Cha+Refund-RiskUncertainty;
        // Total-win and self-draw probabilities must come from the same
        // terminal trajectories. The unified root replaces its old fixed-wait
        // value with this report at short walls.
        public double SelfDrawProbability { get; init; }
    }
    internal sealed record Report(IReadOnlyDictionary<int,Value> Values,int Samples,string Status);

    internal static bool Qualifies(SichuanStateView s,IReadOnlyList<SichuanDecisionCandidate> candidates)
        =>s.InformationMode=="public"&&s.WallCount is >=0 and <=MaximumWall
        &&s.CurrentSeat==s.SeatIndex&&s.OwnDingQueSuit is >=0 and <3
        &&s.Hand18.Sum()==14-3*s.OwnMeldCount
        &&!s.Hand18.Skip(s.OwnDingQueSuit*9).Take(9).Any(n=>n>0)
        &&SichuanGangDiscardLiability.CurrentGangCash(s) is null
        &&Enumerable.Range(0,4).All(x=>!s.ActiveSeats[x]||s.HasHu[x]||s.LockedFans[x]<0)
        &&candidates.Any(c=>c.ReadyPrice is not null)&&candidates.Any(c=>c.ReadyPrice is null);

    internal Report Evaluate(SichuanStateView s,SichuanBeliefSnapshot belief,SichuanWallAvailability wall,
        IReadOnlyList<SichuanDecisionCandidate> candidates,SichuanTerminalReadinessEstimate? terminal)
    {
        Report No(string why)=>new(new Dictionary<int,Value>(),0,why);
        if(!Qualifies(s,candidates)||terminal is not {Supported:true,Worlds.Count:>=32})return No("outside_supported_short_wall");
        var hypotheses=terminal.Worlds.ToArray();
        var order=new List<int>{s.SeatIndex};for(int d=1;d<4;d++)
        {int seat=(s.SeatIndex-d+4)%4;if(s.ActiveSeats[seat]&&!s.HasHu[seat])order.Add(seat);}
        if(order.Count<2)return No("no_opponents");
        var environment=SichuanReadyDevelopmentEvaluator.Environment(s,belief,wall,order.ToArray()) with {GangHistory=s.PublicEvents};
        var planner=new SichuanReadyDevelopmentEvaluator();
        var endpoints=planner.Endpoints(s,wall,includeDead:true);
        // Rival exits or claims can advance our turn. Do not prune by a fixed seat count.
        int maximumOwnDraws=s.WallCount;
        var worlds=hypotheses.Select((w,i)=>
        {
            var r=new Random(20261023+i*7919);
            return new M.World(w.Wall,Enumerable.Range(0,w.Wall.Length*4).Select(_=>r.NextDouble()).ToArray(),
                Enumerable.Range(0,w.Wall.Length*4).Select(_=>r.NextDouble()).ToArray(),
                Enumerable.Range(0,w.Wall.Length*4).Select(_=>r.NextDouble()).ToArray())
                {TerminalReadyScores=w.ReadyScores,TerminalFlowerPigs=w.FlowerPigs};
        }).ToArray();
        var discovery=Enumerable.Range(0,hypotheses.Length/2).ToArray();
        var confirmation=Enumerable.Range(hypotheses.Length/2,hypotheses.Length-hypotheses.Length/2).ToArray();
        var result=new Dictionary<int,Value>();
        foreach(var candidate in candidates)
        {
            int tile=candidate.Action.TileType;
            var hand=s.Hand18.ToArray();hand[tile]--;
            var holding=planner.Plan(s,hand,hand,wall,belief)!;
            var plans=new List<M.Plan>{holding};
            if(maximumOwnDraws>0)
            foreach(var e in endpoints.Where(e=>Missing(hand,e.Hand)<=Math.Min(2,maximumOwnDraws))
                .Where(e=>Enumerable.Range(0,27).All(t=>Math.Max(0,e.Hand[t]-hand[t])<=s.Remaining18[t]))
                .OrderByDescending(e=>SichuanReadyDevelopmentEvaluator.Priority(s,hand,e,wall,order.Count))
                .ThenBy(e=>string.Join(',',e.Hand),StringComparer.Ordinal).Take(12))
            {
                var plan=planner.Plan(s,hand,e.Hand,wall,belief);
                if(plan is not null&&plan.Id!=holding.Id)plans.Add(plan);
            }
            // Select one plan on discovery; do not take a wall-aware maximum
            // over alternatives inside an individual numerical hypothesis.
            var selected=plans.OrderByDescending(p=>Measure(p,discovery,candidate).Net).ThenBy(p=>p.Id,StringComparer.Ordinal).First();
            result[tile]=Measure(selected,confirmation,candidate);
        }
        return new(result,confirmation.Length,"paired_public_fixed_endpoint_confirmation");

        Value Measure(M.Plan plan,int[] indices,SichuanDecisionCandidate candidate)
        {
            double mass=indices.Sum(i=>hypotheses[i].Weight),gain=0,initial=0,loss=0,cha=0,refund=0,win=0,selfDraw=0,ready=0;
            var values=new List<(double Net,double Weight)>();
            foreach(int i in indices)
            {
                var h=hypotheses[i];double w=h.Weight/mass;
                int mask=order.Aggregate(0,(m,seat)=>m|(1<<seat));double immediate=0;
                foreach(int seat in order.Where(x=>x!=s.SeatIndex))
                {
                    double price=h.CurrentRonScores[seat][candidate.Action.TileType];
                    if(price>0&&SichuanPublicDiscardSafety.MayRon(s,seat,candidate.Action.TileType))
                    {immediate+=price;mask&=~(1<<seat);}
                }
                // Continue blood battle after the initial discard's winners
                // exit. Already exited seats cannot later collect cha-jiao.
                int next=order.Skip(1).FirstOrDefault(seat=>(mask&(1<<seat))!=0,s.SeatIndex);
                // Prices come from this same public hypothesis and project
                // rules. If it is not currently ready, the terminal structural
                // price is an explicit approximation of its later win price.
                var ronPrices=Enumerable.Range(0,4).Select(seat=>Enumerable.Range(0,27).Select(t=>
                    h.CurrentRonScores[seat][t]>0?h.CurrentRonScores[seat][t]:
                    Math.Max(SichuanRuleSnapshot.Frozen.BaseScore,h.ReadyScores[seat])).ToArray()).ToArray();
                var selfPrices=Enumerable.Range(0,4).Select(seat=>h.CurrentSelfScores[seat]>0?h.CurrentSelfScores[seat]:
                    Math.Max(SichuanRuleSnapshot.Frozen.BaseScore,h.ReadyScores[seat])+SichuanRuleSnapshot.Frozen.SelfDrawBottomBonus).ToArray();
                var env=environment with {InitialLiveMask=mask,FirstActor=next,RonPaymentByTile=ronPrices,SelfPayment=selfPrices};
                var outcome=M.Run(plan,worlds[i],env);
                gain+=outcome.Gain*w;initial+=immediate*w;loss+=outcome.Loss*w;cha+=outcome.Cha*w;refund+=outcome.Refund*w;
                if(outcome.Win)
                {
                    win+=w;
                    if(outcome.Self)selfDraw+=w;
                }
                if(outcome.ReadyAtEnd)ready+=w;
                values.Add((outcome.Net-immediate,w));
            }
            // A statistical zero is not a safety proof. Retain the existing
            // public risk estimate as an explicit uncertainty floor, counted
            // ONCE; physical impossibility is handled by MayRon above.
            double floor=Math.Max(0,candidate.DealInLoss-initial);
            double mean=gain-initial-loss+cha+refund;
            double ess=1/values.Sum(v=>v.Weight*v.Weight);
            double error=Math.Sqrt(values.Sum(v=>v.Weight*Math.Pow(v.Net-mean,2))/Math.Max(1,ess-1));
            return new(gain,initial,loss,cha,refund,floor,win,ready,error,plan.Id)
            {
                SelfDrawProbability = selfDraw
            };
        }
    }

    private static int Missing(int[] a,int[] b)=>Enumerable.Range(0,27).Sum(t=>Math.Max(0,b[t]-a[t]));
}
