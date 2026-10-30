using System.Numerics;

namespace SichuanMahjong.AI.Core.Search;

/// <summary>Public-observation fixed-hand stopping policy. Only own misses and
/// compulsory offers reveal a draw category. Unobserved rival retentions NEVER
/// enter the information state. Equal/lower Ron locks until our next own draw.
/// Requires a common compulsory-offer mask; other request types use the old
/// fixed-wait model. This solves a declared model, not empirical calibration.</summary>
internal static class SichuanReadyStoppingModel
{
    internal static SichuanBloodBattleChanceModel.Value Evaluate(SichuanActionTreeEvaluator.ChanceSearchRequest r)
    {
        var groups=r.ReadyGroups!;int players=Math.Clamp(r.ActivePlayers,2,4),wall=Math.Max(0,r.WallTiles);
        double hazard=Math.Clamp(r.OpponentWinProbabilityPerDraw,0,1);
        int forced=groups[0].ForcedDiscardMask;
        var expected=groups.Select(g=>Math.Max(0,g.ExpectedCopies)).ToArray();
        if(expected.Sum()>wall+1e-8)throw new ArgumentException("ready groups exceed wall");
        var cuts=new SortedSet<double>{0,1};double cumulative=0;
        foreach(double n in expected){cumulative+=n-Math.Floor(n);double f=cumulative-Math.Floor(cumulative);if(f>1e-12&&f<1-1e-12)cuts.Add(1-f);}
        var boundaries=cuts.ToArray();var allocations=new List<(int[] Counts,int Filler,double Weight)>();
        for(int i=1;i<boundaries.Length;i++)
        {
            double u=(boundaries[i]+boundaries[i-1])/2,prior=0;var counts=new int[expected.Length];
            for(int j=0;j<counts.Length;j++){double next=prior+expected[j];counts[j]=(int)(Math.Floor(next+u)-Math.Floor(prior+u));prior=next;}
            allocations.Add((counts,wall-counts.Sum(),boundaries[i]-boundaries[i-1]));
        }
        var posterior=new Dictionary<(ulong Observed,int Misses),double[]>();
        var cache=new Dictionary<(int W,ulong Observed,int Misses,int Mask,int Actor,double Lock,int Budget),SichuanBloodBattleChanceModel.Value>();
        int first=(players-Math.Clamp(r.OwnTurnOffset,0,players-1))%players;
        return Solve(wall,0,0,(1<<players)-1,first,r.InitialRonLockScore,Math.Max(0,r.MaxRonRefusals));

        double[] Probabilities(ulong observed,int misses)
        {
            if(posterior.TryGetValue((observed,misses),out var saved))return saved;
            var known=Enumerable.Range(0,groups.Count).Select(j=>(int)((observed>>(j*7))&127)).ToArray();
            int n=wall-known.Sum()-misses;var means=new double[groups.Count];double mass=0;
            foreach(var (counts,filler,weight) in allocations)
            {
                double likelihood=weight;int used=0;
                for(int j=0;j<known.Length&&likelihood>0;j++)for(int k=0;k<known[j];k++)
                    likelihood*=Math.Max(0,counts[j]-k)/(double)(wall-used++);
                for(int k=0;k<misses&&likelihood>0;k++)likelihood*=Math.Max(0,filler-k)/(double)(wall-used++);
                mass+=likelihood;for(int j=0;j<means.Length;j++)means[j]+=likelihood*(counts[j]-known[j]);
            }
            if(!(mass>0)||n<=0)throw new InvalidOperationException("unreachable public ready observation");
            for(int j=0;j<means.Length;j++)means[j]/=mass*n;
            return posterior[(observed,misses)]=means;
        }
        int Next(int mask,int actor)
        {for(int d=1;d<=players;d++){int s=(actor+d)%players;if((mask&(1<<s))!=0)return s;}return 0;}
        SichuanBloodBattleChanceModel.Value Solve(int w,ulong observed,int misses,int mask,int actor,double locked,int budget)
        {
            int payers=BitOperations.PopCount((uint)mask)-1;
            if(payers==0)return new(BattleEnd:1);
            if(w==0)return new(Draw:1,ChaJiao:r.ChaJiaoValue*payers/(players-1));
            if(actor==0)locked=0;
            var key=(w,observed,misses,mask,actor,locked,budget);if(cache.TryGetValue(key,out var known))return known;
            // Non-compulsory rival draws are not observed. Marginalize them
            // before any later decision; never optimize at their hidden counts.
            if(actor!=0&&(forced&(1<<actor))==0)return cache[key]=Advance(observed,misses,locked);
            var probabilities=Probabilities(observed,misses);
            var branches=new List<(SichuanBloodBattleChanceModel.Value,double)>();double target=0;
            for(int j=0;j<groups.Count;j++)
            {
                double p=probabilities[j];target+=p;if(p<=1e-14)continue;
                var g=groups[j];SichuanBloodBattleChanceModel.Value hit;
                if(actor==0)hit=new(Win:1,WinGain:g.SelfDrawPerPayer*payers){SelfDrawWin=1,SelfDrawGain=g.SelfDrawPerPayer*payers};
                else
                {
                    var pass=Solve(w-1,observed+(1UL<<(j*7)),misses,mask,Next(mask,actor),Math.Max(locked,g.DiscardScore),g.DiscardScore<=locked||budget==int.MaxValue?budget:Math.Max(0,budget-1));
                    var take=new SichuanBloodBattleChanceModel.Value(Win:1,WinGain:g.DiscardScore){RonWin=1,RonGain=g.DiscardScore};
                    hit=g.DiscardScore<=locked?pass:
                        budget>0&&pass.Net>=g.DiscardScore+Math.Max(.25,g.DiscardScore*.25)?pass:take;
                }
                branches.Add((hit,p));
            }
            if(target<1-1e-12)branches.Add((Advance(observed,misses+1,locked),1-target));
            var result=default(SichuanBloodBattleChanceModel.Value);double mass=0;
            foreach(var (v,p) in branches){result=mass==0?v:SichuanBloodBattleChanceModel.Value.Mix(v,result,p/(mass+p));mass+=p;}
            return cache[key]=result;
            SichuanBloodBattleChanceModel.Value Advance(ulong seen,int negative,double passLock)
            {
                var stay=Solve(w-1,seen,negative,mask,Next(mask,actor),passLock,budget);
                if(actor==0||hazard==0)return stay;
                int left=mask&~(1<<actor);var exit=Solve(w-1,seen,negative,left,Next(left,actor),passLock,budget);
                exit=exit with{OpponentWin=1,Loss=exit.Loss+Math.Max(0,r.OpponentWinLoss)};
                return SichuanBloodBattleChanceModel.Value.Mix(exit,stay,hazard);
            }
        }
    }
}
