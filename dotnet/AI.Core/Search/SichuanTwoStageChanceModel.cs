using System.Numerics;

namespace SichuanMahjong.AI.Core.Search;

public sealed record SichuanReadyTransition(double DrawMass, double WaitMass, double SelfDrawGain);
public sealed record SichuanTwoStageEstimate(double ReadyProbability, double SelfDrawProbability,
    double ExpectedSelfDrawGain, double ExpectedOpponentLoss)
{
    public double DiscardHuProbability { get; init; }
    public double ExpectedDiscardHuGain { get; init; }
    public double Net => ExpectedSelfDrawGain + ExpectedDiscardHuGain - ExpectedOpponentLoss;
}

/// <summary>Conditional public model: keep the non-ready hand on misses, enter
/// one of the explicitly enumerated ready hands on a useful own draw, then use
/// the shared fixed-wait blood-battle model. Opponent wins remove a payer and
/// do not stop the whole hand. Unknown future reorganizations/claims are not
/// modeled. Posterior inputs are estimates, never calibrated real-world odds.</summary>
public sealed class SichuanTwoStageChanceModel
{
    public SichuanTwoStageEstimate Evaluate(int wall, int players, int ownOffset,
        IReadOnlyList<SichuanReadyTransition> transitions, double opponentHazard, double opponentLoss)
    {
        using var timing = SichuanMahjong.AI.Core.Decision.SichuanPolicyTiming.Measure("two_stage_dp");
        wall=Math.Max(0,wall);players=Math.Clamp(players,2,4);
        if(wall==0)return new(0,0,0,0);
        var valid=transitions.Where(t=>t.DrawMass>0&&t.WaitMass>0&&t.SelfDrawGain>0).ToArray();
        var mass=Math.Clamp(valid.Sum(t=>t.DrawMass),0,wall);
        var hazard=Math.Clamp(opponentHazard,0,1);
        var cache=new Dictionary<(int,int,int,int),SichuanTwoStageEstimate>();
        var readyCache=new Dictionary<(int,int),SichuanTwoStageEstimate>();
        // Reuse the ready-stage DP across all possible times and paths of
        // reaching ready. Rebuilding a full solver at every chance node was
        // needlessly multiplying the same fixed-wait calculation.
        var readyStates=new Dictionary<(int,int,int,int),(double Win,double Payers,double Loss)>();
        int Next(int mask,int seat){for(int n=1;n<=players;n++){int s=(seat+n)%players;if((mask&(1<<s))!=0)return s;}return 0;}
        SichuanTwoStageEstimate Mix(SichuanTwoStageEstimate a,SichuanTwoStageEstimate b,double p)
            =>new(p*a.ReadyProbability+(1-p)*b.ReadyProbability,p*a.SelfDrawProbability+(1-p)*b.SelfDrawProbability,
                p*a.ExpectedSelfDrawGain+(1-p)*b.ExpectedSelfDrawGain,p*a.ExpectedOpponentLoss+(1-p)*b.ExpectedOpponentLoss);
        (double Win,double Payers,double Loss) Ready(int left,int targets,int mask,int next)
        {
            int opponents=BitOperations.PopCount((uint)mask)-1;
            if(left==0||opponents==0)return (0,0,0);
            var key=(left,targets,mask,next);if(readyStates.TryGetValue(key,out var known))return known;
            (double Win,double Payers,double Loss) Blend((double Win,double Payers,double Loss) a,
                (double Win,double Payers,double Loss) b,double p)
                =>(p*a.Win+(1-p)*b.Win,p*a.Payers+(1-p)*b.Payers,p*a.Loss+(1-p)*b.Loss);
            double hit=targets/(double)left;
            (double Win,double Payers,double Loss) value;
            if(next==0)value=Blend((1,opponents,0),targets<left?Ready(left-1,targets,mask,Next(mask,next)):(0,0,0),hit);
            else
            {
                (double Win,double Payers,double Loss) After(int n)
                {
                    var stay=Ready(left-1,n,mask,Next(mask,next));
                    if(hazard==0)return stay;
                    int exited=mask&~(1<<next);var exit=Ready(left-1,n,exited,Next(exited,next));
                    return Blend((exit.Win,exit.Payers,exit.Loss+1),stay,hazard);
                }
                value=Blend(targets>0?After(targets-1):(0,0,0),targets<left?After(targets):(0,0,0),hit);
            }
            return readyStates[key]=value;
        }
        SichuanTwoStageEstimate Solve(int left,int targets,int mask,int next)
        {
            int opponents=BitOperations.PopCount((uint)mask)-1;
            if(left==0||opponents==0)return new(0,0,0,0);
            var key=(left,targets,mask,next);if(cache.TryGetValue(key,out var known))return known;
            double hit=targets/(double)left;
            SichuanTwoStageEstimate value;
            if(next==0)
            {
                if(!readyCache.TryGetValue((left,opponents),out var madeReady))
                {
                double win=0,gain=0,loss=0;
                foreach(var t in valid)
                {
                    // Conditional first-hit model thins the unknown later wait
                    // supply uniformly. It does not invent hidden opponent hands.
                    double weight=t.DrawMass/Math.Max(1e-12,valid.Sum(t=>t.DrawMass));
                    double live=t.WaitMass*Math.Max(0,left-1)/Math.Max(1,wall-1);
                    live=Math.Clamp(live,0,left-1);int readyTargets=(int)Math.Floor(live);
                    var lo=Ready(left-1,readyTargets,mask,Next(mask,0));
                    var hi=live==readyTargets?lo:Ready(left-1,readyTargets+1,mask,Next(mask,0));double f=live-readyTargets;
                    win+=weight*((1-f)*lo.Win+f*hi.Win);
                    gain+=weight*((1-f)*lo.Payers+f*hi.Payers)*t.SelfDrawGain/(players-1);
                    loss+=weight*((1-f)*lo.Loss+f*hi.Loss)*opponentLoss;
                }
                madeReady=new SichuanTwoStageEstimate(1,win,gain,loss);
                readyCache[(left,opponents)]=madeReady;
                }
                var miss=targets<left?Solve(left-1,targets,mask,Next(mask,next)):new(0,0,0,0);
                value=Mix(madeReady,miss,hit);
            }
            else
            {
                SichuanTwoStageEstimate After(int n)
                {
                    var stay=Solve(left-1,n,mask,Next(mask,next));
                    if(hazard==0)return stay;
                    int exited=mask&~(1<<next);
                    var exit=Solve(left-1,n,exited,Next(exited,next));
                    exit=exit with{ExpectedOpponentLoss=exit.ExpectedOpponentLoss+Math.Max(0,opponentLoss)};
                    return Mix(exit,stay,hazard);
                }
                value=Mix(targets>0?After(targets-1):new(0,0,0,0),targets<left?After(targets):new(0,0,0,0),hit);
            }
            return cache[key]=value;
        }
        int floor=(int)Math.Floor(mass),first=(players-Math.Clamp(ownOffset,0,players-1))%players;
        var lo=Solve(wall,floor,(1<<players)-1,first);
        return mass==floor?lo:Mix(Solve(wall,floor+1,(1<<players)-1,first),lo,mass-floor);
    }
}
