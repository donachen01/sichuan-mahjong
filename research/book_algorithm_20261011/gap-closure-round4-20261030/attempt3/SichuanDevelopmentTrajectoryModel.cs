using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Domain;

namespace SichuanMahjong.AI.Core.Search;

/// <summary>Numerical trajectory, not a terminal policy rollout. Every hand,
/// legal wait, price and spare discard is fixed from public information before
/// a numerical wall is revealed. Alternative routes use the same walls.
/// New targets, voluntary supply and future Gang decisions are outside it.</summary>
public static class SichuanDevelopmentTrajectoryModel
{
    public sealed record Stage(double[] Ron,double[] Self,int[] OwnNext,int[] PengNext,
        int SpareDiscard,bool Ready,int[]? Hand=null,int[]? PengTiles=null)
    {
        public double ChaJiaoScore {get;init;}
        public int[]? OwnDiscards {get;init;}
        public int[]? PengDiscards {get;init;}
    }
    public sealed record Plan(string Id,Stage[] Stages,int Initial=0);
    public sealed record World(int[] Wall,double[] SelfUniform,double[] RonUniform,double[]? ClaimRonUniform=null)
    {public int[]? TerminalReadyScores {get;init;}public bool[]? TerminalFlowerPigs {get;init;}}
    public sealed record Environment(int OwnSeat,int[] Order,int[] Missing,double[] SelfHazard,
        double[][] RonHazard,double[] SelfPayment,double[] RonPayment,double[] UnreadyCharge,
        int FirstActor,bool[]? ForcedOffers=null)
    {
        public IReadOnlyList<SichuanPublicEvent>? GangHistory {get;init;}
        public int? InitialLiveMask {get;init;}
        public double[][]? RonPaymentByTile {get;init;}
    }
    public readonly record struct Outcome(double Gain,double Loss,double Cha,bool Win,bool Self,bool ReadyAtEnd,
        bool Peng,bool BattleEnd)
    {public double Refund {get;init;}public double Net=>Gain-Loss+Cha+Refund;public bool OpponentWin{get;init;}}
    public sealed record Estimate(SichuanActionTreeEvaluator.ChanceSearchResult Chance,
        double[] Nets,double ReadyProbability,double PengProbability)
    {public double[] Gains{get;init;}=[];public double[] Losses{get;init;}=[];public double[] ChaValues{get;init;}=[];}

    private static int[] Successors(Environment e)
    {
        var result=new int[64];
        for(int mask=0;mask<16;mask++)for(int seat=0;seat<4;seat++)
        {
            int next=e.OwnSeat,index=Array.IndexOf(e.Order,seat);
            for(int d=1;d<=e.Order.Length;d++)
            {int candidate=e.Order[(index+d)%e.Order.Length];if((mask&(1<<candidate))!=0){next=candidate;break;}}
            result[mask*4+seat]=next;
        }
        return result;
    }
    public static Outcome Run(Plan plan,World world,Environment e)=>Run(plan,world,e,null);
    private static Outcome Run(Plan plan,World world,Environment e,int[]? successors)
    {
        int own=e.OwnSeat,live=e.InitialLiveMask??e.Order.Aggregate(0,(a,s)=>a|(1<<s)),actor=e.FirstActor,stage=plan.Initial;
        double loss=0;bool peng=false,reached=plan.Stages[stage].Ready,opponentWin=false;
        Outcome Finish(double gain,double cost,double cha,bool win,bool self,bool ready,bool claim,bool battle)
            =>new(gain,cost,cha,win,self,ready,claim,battle){OpponentWin=opponentWin};
        int Next(int seat)
        {
            if(successors is not null)return successors[(live&15)*4+seat];
            int index=Array.IndexOf(e.Order,seat);
            for(int d=1;d<=e.Order.Length;d++)
            {int candidate=e.Order[(index+d)%e.Order.Length];if((live&(1<<candidate))!=0)return candidate;}
            return own;
        }
        int Payers()=>System.Numerics.BitOperations.PopCount((uint)live)-1;
        void Discard(int tile,int position,bool afterClaim=false)
        {
            var uniform=afterClaim?world.ClaimRonUniform??world.RonUniform:world.RonUniform;
            foreach(int seat in e.Order)if(seat!=own&&(live&(1<<seat))!=0
                &&e.Missing[seat]!=tile/9&&uniform[position*4+seat]<e.RonHazard[seat][tile])
            {loss+=e.RonPaymentByTile?[seat][tile]??e.RonPayment[seat];live&=~(1<<seat);opponentWin=true;}
        }
        bool RivalRon(int tile,int position,int source)
        {
            bool won=false;
            foreach(int seat in e.Order)if(seat!=own&&seat!=source&&(live&(1<<seat))!=0
                &&e.Missing[seat]!=tile/9&&world.RonUniform[position*4+seat]<e.RonHazard[seat][tile])
            {live&=~(1<<seat);won=true;opponentWin=true;}
            return won;
        }
        for(int position=0;position<world.Wall.Length;position++)
        {
            if(Payers()==0)return Finish(0,loss,0,false,false,reached,peng,true);
            int tile=world.Wall[position];var p=plan.Stages[stage];
            if(actor==own)
            {
                if(p.Self[tile]>0)return Finish(p.Self[tile]*Payers(),loss,0,true,true,true,peng,false);
                int next=p.OwnNext[tile];
                if(next>=0){stage=next;Discard(p.OwnDiscards?[tile]??p.SpareDiscard,position);reached|=plan.Stages[stage].Ready;}
                else Discard(tile,position);
                actor=Next(own);
            }
            else if(e.Missing[actor]==tile/9)
            {
                // An uncleared missing suit can contain other tiles. Its
                // owner need not release this particular drawn copy now.
                if(e.ForcedOffers is not null&&!e.ForcedOffers[actor]){actor=Next(actor);continue;}
                if(p.Ron[tile]>0){RivalRon(tile,position,actor);return Finish(p.Ron[tile],loss,0,true,false,true,peng,false);}
                // Hu consumes the discard before a lower-priority Peng.
                // Another player's Ron is paid by its source, not by us.
                if(RivalRon(tile,position,actor)){actor=Next(actor);continue;}
                int next=p.PengNext[tile];
                if(next>=0)
                {stage=next;peng=true;Discard(p.PengDiscards?[tile]??p.SpareDiscard,position,true);reached|=plan.Stages[stage].Ready;actor=Next(own);}
                else actor=Next(actor);
            }
            else
            {
                int before=actor;
                if(world.SelfUniform[position*4+actor]<e.SelfHazard[actor])
                {loss+=e.SelfPayment[actor];live&=~(1<<actor);opponentWin=true;}
                actor=Next(before);
            }
        }
        if(Payers()==0)return Finish(0,loss,0,false,false,reached,peng,true);
        double cha=0;
        if(world.TerminalReadyScores is not null)
        {
            // The wall and all terminal opponent assessments belong to the
            // SAME public hypothesis. No product of marginal ready rates.
            var assessments=e.Order.Where(seat=>(live&(1<<seat))!=0).Select(seat=>
                new SichuanDrawAssessment(seat,seat==own?plan.Stages[stage].Ready:world.TerminalReadyScores[seat]>0,
                    seat!=own&&(world.TerminalFlowerPigs?[seat]??false),
                    (int)(seat==own?plan.Stages[stage].ChaJiaoScore:world.TerminalReadyScores[seat]))).ToArray();
            var settlement=new SichuanSettlementProjectionEngine().ProjectScenario(new(DrawAssessments:assessments,
                GangRefunds:SichuanPublicGangRefunds.Build(e.GangHistory??[],assessments)));
            cha=settlement.ChaJiaoChanges[own]+settlement.HuaZhuChanges[own];
            return Finish(0,loss,cha,false,false,plan.Stages[stage].Ready,peng,false) with {Refund=settlement.RefundChanges[own]};
        }
        // No speculative future cha-jiao income. Charge the same public
        // current-readiness exposure to every unready terminal route.
        if(!plan.Stages[stage].Ready)foreach(int seat in e.Order)
            if(seat!=own&&(live&(1<<seat))!=0)cha-=e.UnreadyCharge[seat];
        return Finish(0,loss,cha,false,false,reached,peng,false);
    }

    // Discovery compares only this scalar. Keep the exact four sums and
    // arithmetic order used by Evaluate; confirmation still returns every
    // paired path array. All paths are simulated at unchanged precision.
    internal static double EvaluateMean(Plan plan,IReadOnlyList<World> worlds,Environment e)
    {
        using var timing=SichuanMahjong.AI.Core.Decision.SichuanPolicyTiming.Measure("development_trajectory_mean");
        var successors=Successors(e);double gain=0,loss=0,cha=0,refund=0;
        for(int i=0;i<worlds.Count;i++)
        {var v=Run(plan,worlds[i],e,successors);gain+=v.Gain;loss+=v.Loss;cha+=v.Cha;refund+=v.Refund;}
        return (gain-loss+cha+refund)/worlds.Count;
    }

    public static Estimate Evaluate(Plan plan,IReadOnlyList<World> worlds,Environment e)
    {
        using var timing=SichuanMahjong.AI.Core.Decision.SichuanPolicyTiming.Measure("development_trajectory_value");
        var successors=Successors(e);
        double refund=0,gain=0,loss=0,cha=0,win=0,self=0,ron=0,selfGain=0,ronGain=0,ready=0,peng=0,battle=0,opponent=0;
        var nets=new double[worlds.Count];
        var gains=new double[worlds.Count];var losses=new double[worlds.Count];var charges=new double[worlds.Count];
        for(int i=0;i<worlds.Count;i++)
        {
            var v=Run(plan,worlds[i],e,successors);nets[i]=v.Net;gains[i]=v.Gain;losses[i]=v.Loss;charges[i]=v.Cha;gain+=v.Gain;loss+=v.Loss;cha+=v.Cha;refund+=v.Refund;
            if(v.Win){win++;if(v.Self){self++;selfGain+=v.Gain;}else{ron++;ronGain+=v.Gain;}}
            if(v.ReadyAtEnd)ready++;if(v.Peng)peng++;if(v.BattleEnd)battle++;
            if(v.OpponentWin)opponent++;
        }
        double n=worlds.Count;
        return new(new((gain-loss+cha+refund)/n,win/n,opponent/n,(n-win-battle)/n,refund/n,worlds.Count,0,0)
            {ExpectedOwnWinGain=gain/n,ExpectedOpponentLoss=loss/n,ExpectedChaJiaoValue=cha/n,
                SelfDrawWinProbability=self/n,DiscardHuProbability=ron/n,ExpectedSelfDrawGain=selfGain/n,
                ExpectedDiscardHuGain=ronGain/n,BattleEndProbability=battle/n},nets,ready/n,peng/n)
            {Gains=gains,Losses=losses,ChaValues=charges};
    }
}
