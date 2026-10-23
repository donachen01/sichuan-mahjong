using System.Numerics;

namespace SichuanMahjong.AI.Core.Search;

/// <summary>A fixed-wait group in a single suit. Prices are conditional means;
/// the mask identifies only opponents legally forced to discard that suit.</summary>
public sealed record SichuanReadyRaceGroup(double ExpectedCopies, double SelfDrawPerPayer,
    double DiscardScore, int ForcedDiscardMask)
{
    // Optional conditional release model. Missing-suit releases remain certain.
    // An absent estimate never becomes an invented voluntary offer.
    public IReadOnlyList<double>? ReleaseProbabilities { get; init; }
    // Compute-allocation bound only: on each non-forced target draw allow
    // whichever of release/retain benefits us more. This is not an opponent
    // policy and must never be used as a candidate's estimated net value.
    public bool OptimisticReleaseBound { get; init; }
}

/// <summary>Conditional public estimates for ONE particular opponent in draw
/// order (actor 1..3). These are local hypotheses, not known hidden hands.</summary>
public sealed record SichuanReadyRaceOpponent(int Actor, double SelfDrawProbability,
    double OwnDiscardRonProbability, double SelfDrawPayment, double OwnDiscardPayment,
    double GangPaymentPerDraw, double CrossRonProbability = 0,
    double FirstDiscardRonProbability = 0, double FirstDiscardPayment = 0,
    double GangDiscardPayment = 0);

/// <summary>Drawn fourth copies for existing Peng melds. On an own draw they
/// produce one legal paid added Gang, one root and an immediate replacement.</summary>
public sealed record SichuanReadyRaceGang(double ExpectedCopies,double PerPayerGain,int HandScoreCap,
    bool EnableHuJiaoTransfer=true);

/// <summary>Small finite-wall race, with separate self draw and forced-discard
/// wins. Other opponents retaining a target consume it. It does not predict
/// voluntary discards, hand changes, Gang, or a fully calibrated wall posterior.</summary>
internal static class SichuanReadyRaceModel
{
    internal static SichuanBloodBattleChanceModel.Value Evaluate(
        SichuanActionTreeEvaluator.ChanceSearchRequest r)
    {
        var groups = r.ReadyGroups!;
        var players = Math.Clamp(r.ActivePlayers,2,4);
        var wall = Math.Max(0,r.WallTiles);
        var hazard = Math.Clamp(r.OpponentWinProbabilityPerDraw,0,1);
        var first = (players-Math.Clamp(r.OwnTurnOffset,0,players-1))%players;
        var a = Math.Clamp(groups[0].ExpectedCopies,0,wall);
        var hasGang=r.ReadyGang is not null && groups.Count==1;
        var b = hasGang?Math.Clamp(r.ReadyGang!.ExpectedCopies,0,wall-a):
            groups.Count>1 ? Math.Clamp(groups[1].ExpectedCopies,0,wall-a) : 0;
        var loA=(int)Math.Floor(a);var loB=(int)Math.Floor(b);
        var fa=a-loA;var fb=b-loB;
        // Dependent rounding retains both expected supplies, and totals are
        // floor/ceil of the total; impossible walls are never assigned mass.
        var both=Math.Max(0,fa+fb-1);
        var allocations=new[]{(loA,loB,1-fa-fb+both),(loA+1,loB,fa-both),
            (loA,loB+1,fb-both),(loA+1,loB+1,both)};
        var cache=new Dictionary<(int W,int A,int B,int G,int Roots,int Mask,int Next,int Left,bool Replacement),SichuanBloodBattleChanceModel.Value>();
        var total=default(SichuanBloodBattleChanceModel.Value);
        var accumulated=0.0;
        foreach(var (aa,bb,weight) in allocations)
        {
            if(weight<=1e-12)continue;
            var v=Start(0,(1<<players)-1,0);
            total=accumulated==0?v:SichuanBloodBattleChanceModel.Value.Mix(v,total,weight/(weight+accumulated));
            accumulated+=weight;
            SichuanBloodBattleChanceModel.Value Start(int index,int mask,double loss)
            {
                if(r.ReadyOpponents is not { } profiles || index==profiles.Count)
                {
                    var actor=Next(mask,(first+players-1)%players);
                    var value=Solve(wall,aa,hasGang?0:bb,hasGang?bb:0,0,mask,actor,Math.Min(wall,Math.Max(0,r.MaxDraws)));
                    return value with {Loss=value.Loss+loss,RonLoss=value.RonLoss+loss};
                }
                var p=profiles[index];var stay=Start(index+1,mask,loss);
                if(p.FirstDiscardRonProbability<=0)return stay;
                var leave=Start(index+1,mask&~(1<<p.Actor),loss+Math.Max(0,p.FirstDiscardPayment));
                leave=leave with {OpponentWin=1};
                return SichuanBloodBattleChanceModel.Value.Mix(leave,stay,Math.Clamp(p.FirstDiscardRonProbability,0,1));
            }
        }
        return total;

        SichuanBloodBattleChanceModel.Value Solve(int w,int aa,int bb,int gg,int roots,int mask,int actor,int left,bool replacement=false)
        {
            var opponents=BitOperations.PopCount((uint)mask)-1;
            if(opponents==0)return new(BattleEnd:1);
            if(w==0)return new(Draw:1,ChaJiao:r.ChaJiaoValue*opponents/(players-1));
            var key=(w,aa,bb,gg,roots,mask,actor,left,replacement);
            if(left==0){var tail=Solve(w,aa,bb,gg,roots,mask,actor,w,replacement);return new(Horizon:1,Continuation:tail.Net);}
            if(cache.TryGetValue(key,out var saved))return saved;
            var branches=new List<(SichuanBloodBattleChanceModel.Value,double)>();
            if(w>aa+bb+gg)branches.Add((AfterDraw(aa,bb,gg), (w-aa-bb-gg)/(double)w));
            if(aa>0)branches.Add((Hit(0,aa-1,bb),aa/(double)w));
            if(bb>0)branches.Add((Hit(1,aa,bb-1),bb/(double)w));
            if(gg>0)
            {
                var gang=actor==0&&w>1
                    ? Solve(w-1,aa,bb,gg-1,roots+1,mask,0,left-1,replacement:true)
                    : AfterDraw(aa,bb,gg-1);
                if(actor==0&&w>1)gang=gang with{Gang=gang.Gang+opponents*r.ReadyGang!.PerPayerGain,NaturalGang=1};
                branches.Add((gang,gg/(double)w));
            }
            var value=default(SichuanBloodBattleChanceModel.Value);var mass=0.0;
            foreach(var (v,p) in branches)
            {value=mass==0?v:SichuanBloodBattleChanceModel.Value.Mix(v,value,p/(mass+p));mass+=p;}
            return cache[key]=value;

            SichuanBloodBattleChanceModel.Value Hit(int group,int nextA,int nextB)
            {
                var g=groups[group];
                var score=roots==0?g.DiscardScore:Math.Min(r.ReadyGang!.HandScoreCap,g.DiscardScore*Math.Pow(2,roots));
                var self=(replacement?Math.Min(r.ReadyGang!.HandScoreCap,score*2):score)
                    +g.SelfDrawPerPayer-g.DiscardScore;
                if(actor==0)return new(Win:1,WinGain:self*opponents){SelfDrawWin=1,SelfDrawGain=self*opponents};
                // A missing-suit draw cannot be kept or Hu'd. It is discarded
                // before an opponent may win, so this branch is our Ron.
                if((g.ForcedDiscardMask&(1<<actor))!=0)return new(Win:1,WinGain:score){RonWin=1,RonGain=score};
                if(g.OptimisticReleaseBound)
                {
                    var ron=new SichuanBloodBattleChanceModel.Value(Win:1,WinGain:score){RonWin=1,RonGain=score};
                    var retain=AfterDraw(nextA,nextB,gg);
                    return ron.Net>=retain.Net?ron:retain;
                }
                if(g.ReleaseProbabilities is { } release && actor<release.Count && release[actor]>0)
                {
                    var ron=new SichuanBloodBattleChanceModel.Value(Win:1,WinGain:score){RonWin=1,RonGain=score};
                    return SichuanBloodBattleChanceModel.Value.Mix(ron,AfterDraw(nextA,nextB,gg),Math.Clamp(release[actor],0,1));
                }
                return AfterDraw(nextA,nextB,gg);
            }
            SichuanBloodBattleChanceModel.Value AfterDraw(int nextA,int nextB,int nextG)
            {
                if(r.ReadyOpponents is {Count:>0} profiles)
                {
                    // Own misses can feed several opponents on the same tile.
                    // Opponents' mutual Ron removes payers without charging us.
                    return Exits(0,mask,0,0,0);
                    SichuanBloodBattleChanceModel.Value Exits(int index,int live,double loss,double ron,double self)
                    {
                        if(index==profiles.Count)
                        {
                            var value=Solve(w-1,nextA,nextB,nextG,roots,live,Next(live,actor),left-1);
                            var gang=actor>0 && (live&(1<<actor))!=0
                                ? profiles.Where(p=>p.Actor==actor).Sum(p=>Math.Max(0,p.GangPaymentPerDraw)):0;
                            return value with {Loss=value.Loss+loss+gang,RonLoss=value.RonLoss+ron,
                                SelfLoss=value.SelfLoss+self,GangLoss=value.GangLoss+gang};
                        }
                        var p=profiles[index];var bit=1<<p.Actor;
                        if((live&bit)==0)return Exits(index+1,live,loss,ron,self);
                        var probability=actor==0?p.OwnDiscardRonProbability:
                            actor==p.Actor?p.SelfDrawProbability:p.CrossRonProbability;
                        var payment=actor==0?p.OwnDiscardPayment:actor==p.Actor?p.SelfDrawPayment:0;
                        if(actor==0 && replacement)
                        {
                            payment=p.GangDiscardPayment>0?p.GangDiscardPayment:
                                Math.Min(r.ReadyGang!.HandScoreCap,2*p.OwnDiscardPayment);
                            if(r.ReadyGang!.EnableHuJiaoTransfer)payment+=opponents*r.ReadyGang.PerPayerGain;
                        }
                        var stay=Exits(index+1,live,loss,ron,self);
                        if(probability<=0)return stay;
                        var leave=Exits(index+1,live&~bit,loss+Math.Max(0,payment),
                            ron+(actor==0?Math.Max(0,payment):0),self+(actor==p.Actor?Math.Max(0,payment):0));
                        leave=leave with {OpponentWin=1};
                        return SichuanBloodBattleChanceModel.Value.Mix(leave,stay,Math.Clamp(probability,0,1));
                    }
                }
                var stay=Solve(w-1,nextA,nextB,nextG,roots,mask,Next(mask,actor),left-1);
                if(actor==0 || hazard==0)return stay;
                var exited=mask&~(1<<actor);
                var leave=Solve(w-1,nextA,nextB,nextG,roots,exited,Next(exited,actor),left-1);
                leave=leave with{OpponentWin=1,Loss=leave.Loss+Math.Max(0,r.OpponentWinLoss)};
                return SichuanBloodBattleChanceModel.Value.Mix(leave,stay,hazard);
            }
        }
        int Next(int mask,int actor)
        {
            for(int step=1;step<=players;step++)if((mask&(1<<((actor+step)%players)))!=0)return (actor+step)%players;
            return 0;
        }
    }
}
