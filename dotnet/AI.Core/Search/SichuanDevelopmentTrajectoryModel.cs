using SichuanMahjong.AI.Core.Decision;

namespace SichuanMahjong.AI.Core.Search;

/// <summary>Numerical trajectory, not a terminal policy rollout. Every hand,
/// legal wait, price and spare discard is fixed from public information before
/// a numerical wall is revealed. Alternative routes use the same walls.
/// New targets, voluntary supply and future Gang decisions are outside it.</summary>
public static class SichuanDevelopmentTrajectoryModel
{
    public sealed record Stage(double[] Ron,double[] Self,int[] OwnNext,int[] PengNext,
        int SpareDiscard,bool Ready,int[]? Hand=null,int[]? PengTiles=null);
    public sealed record Plan(string Id,Stage[] Stages,int Initial=0);
    public sealed record World(int[] Wall,double[] SelfUniform,double[] RonUniform,double[]? ClaimRonUniform=null);
    public sealed record Environment(int OwnSeat,int[] Order,int[] Missing,double[] SelfHazard,
        double[][] RonHazard,double[] SelfPayment,double[] RonPayment,double[] UnreadyCharge,
        int FirstActor,bool[]? ForcedOffers=null);
    public readonly record struct Outcome(double Gain,double Loss,double Cha,bool Win,bool Self,bool ReadyAtEnd,
        bool Peng,bool BattleEnd)
    {public double Net=>Gain-Loss+Cha;public bool OpponentWin{get;init;}}
    public sealed record Estimate(SichuanActionTreeEvaluator.ChanceSearchResult Chance,
        double[] Nets,double ReadyProbability,double PengProbability)
    {public double[] Gains{get;init;}=[];public double[] Losses{get;init;}=[];public double[] ChaValues{get;init;}=[];}

    public static Outcome Run(Plan plan,World world,Environment e)
    {
        int own=e.OwnSeat,live=e.Order.Aggregate(0,(a,s)=>a|(1<<s)),actor=e.FirstActor,stage=plan.Initial;
        double loss=0;bool peng=false,reached=plan.Stages[stage].Ready,opponentWin=false;
        Outcome Finish(double gain,double cost,double cha,bool win,bool self,bool ready,bool claim,bool battle)
            =>new(gain,cost,cha,win,self,ready,claim,battle){OpponentWin=opponentWin};
        int Next(int seat){int i=Array.IndexOf(e.Order,seat);for(int d=1;d<=e.Order.Length;d++)
            {int s=e.Order[(i+d)%e.Order.Length];if((live&(1<<s))!=0)return s;}return own;}
        int Payers()=>System.Numerics.BitOperations.PopCount((uint)live)-1;
        void Discard(int tile,int position,bool afterClaim=false)
        {
            var uniform=afterClaim?world.ClaimRonUniform??world.RonUniform:world.RonUniform;
            foreach(int seat in e.Order)if(seat!=own&&(live&(1<<seat))!=0
                &&e.Missing[seat]!=tile/9&&uniform[position*4+seat]<e.RonHazard[seat][tile])
            {loss+=e.RonPayment[seat];live&=~(1<<seat);opponentWin=true;}
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
                if(next>=0){stage=next;Discard(p.SpareDiscard,position);reached|=plan.Stages[stage].Ready;}
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
                {stage=next;peng=true;Discard(p.SpareDiscard,position,true);reached|=plan.Stages[stage].Ready;actor=Next(own);}
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
        // No speculative future cha-jiao income. Charge the same public
        // current-readiness exposure to every unready terminal route.
        if(!plan.Stages[stage].Ready)foreach(int seat in e.Order)
            if(seat!=own&&(live&(1<<seat))!=0)cha-=e.UnreadyCharge[seat];
        return Finish(0,loss,cha,false,false,reached,peng,false);
    }

    public static Estimate Evaluate(Plan plan,IReadOnlyList<World> worlds,Environment e)
    {
        double gain=0,loss=0,cha=0,win=0,self=0,ron=0,selfGain=0,ronGain=0,ready=0,peng=0,battle=0,opponent=0;
        var nets=new double[worlds.Count];
        var gains=new double[worlds.Count];var losses=new double[worlds.Count];var charges=new double[worlds.Count];
        for(int i=0;i<worlds.Count;i++)
        {
            var v=Run(plan,worlds[i],e);nets[i]=v.Net;gains[i]=v.Gain;losses[i]=v.Loss;charges[i]=v.Cha;gain+=v.Gain;loss+=v.Loss;cha+=v.Cha;
            if(v.Win){win++;if(v.Self){self++;selfGain+=v.Gain;}else{ron++;ronGain+=v.Gain;}}
            if(v.ReadyAtEnd)ready++;if(v.Peng)peng++;if(v.BattleEnd)battle++;
            if(v.OpponentWin)opponent++;
        }
        double n=worlds.Count;
        return new(new((gain-loss+cha)/n,win/n,opponent/n,(n-win-battle)/n,0,worlds.Count,0,0)
            {ExpectedOwnWinGain=gain/n,ExpectedOpponentLoss=loss/n,ExpectedChaJiaoValue=cha/n,
                SelfDrawWinProbability=self/n,DiscardHuProbability=ron/n,ExpectedSelfDrawGain=selfGain/n,
                ExpectedDiscardHuGain=ronGain/n,BattleEndProbability=battle/n},nets,ready/n,peng/n)
            {Gains=gains,Losses=losses,ChaValues=charges};
    }
}
