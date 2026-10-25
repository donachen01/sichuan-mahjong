using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;
using M=SichuanMahjong.AI.Core.Search.SichuanDevelopmentTrajectoryModel;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Common finite-wall price for bounded legal ready-endpoint plans.
/// The endpoint and spare-discard order are chosen before any numerical wall
/// is revealed. This supplies values to the existing ranker, never actions.</summary>
public sealed class SichuanReadyDevelopmentEvaluator
{
    internal static bool SuppressForResearch;
    public sealed record Value(M.Estimate Estimate,string Endpoint,int Plans,double StandardError);
    public sealed record Report(string Status,IReadOnlyDictionary<int,Value> Values,double Ms,int Endpoints,int Samples)
    {public double EndpointMs{get;init;}public double WallMs{get;init;}public double PlansMs{get;init;}}
    private readonly SichuanShantenEngine _distance=new();
    private readonly SichuanReadyWaitPricing _prices=new();
    private readonly SichuanWallAvailabilityEngine _walls=new();
    private readonly Dictionary<string,SichuanReadyPrice?> _priceCache=new();
    private SichuanReadyPrice? Price(SichuanStateView s,int[] hand,SichuanWallAvailability wall,IReadOnlyList<SichuanMeldView>? melds=null)
    {
        melds??=SichuanDevelopmentPolicy.Melds(s,s.SeatIndex);
        var key=Key(hand)+"/"+string.Join(',',melds.Select(m=>$"{m.Type}:{m.TileType}"));
        if(_priceCache.TryGetValue(key,out var saved))return saved;
        return _priceCache[key]=_prices.Build(s,hand,wall.ExpectedCounts18,melds);
    }
    internal sealed record Endpoint(int[] Hand,SichuanReadyPrice Price,bool SevenOnly);
    private sealed record Comparison(SichuanStateView Root,SichuanBeliefSnapshot Belief,SichuanWallAvailability Wall);
    private static readonly AsyncLocal<Comparison?> CurrentComparison=new();
    private sealed class Scope(Action end):IDisposable{public void Dispose()=>end();}
    internal static IDisposable EnterReactionComparison(SichuanStateView s,bool allowed)
    {
        if(!allowed||SuppressForResearch||!Qualifies(s)||s.Hand18.Sum()!=13||s.OwnMeldCount!=0
            ||new SichuanShantenEngine().CalcLegalShanten(s.Hand18,0,s.OwnDingQueSuit)<=0)
            return new Scope(()=>{});
        var allocation=SichuanSearchBudget.TryDeep(s,"SEARCH_DEEP_ORDINARY_SEVEN_PAIRS_DEVELOPMENT");
        if(allocation is null)return new Scope(()=>{});
        var b=new SichuanBeliefEngine().Build(s);var w=new SichuanWallAvailabilityEngine().Build(s,b);
        var previous=CurrentComparison.Value;CurrentComparison.Value=new(s,b,w);
        return new Scope(()=>{CurrentComparison.Value=previous;allocation.Dispose();});
    }
    private static bool Qualifies(SichuanStateView s)
    {
        if(s.InformationMode!="public"||s.WallCount<28||s.LockedFans[s.SeatIndex]>=0
            ||s.OwnDingQueSuit is <0 or >2||s.DingQueSuits.Any(x=>x is <0 or >2)
            ||s.Hand18.Skip(s.OwnDingQueSuit*9).Take(9).Any(n=>n>0)
            ||!Enumerable.Range(0,4).Any(x=>x!=s.SeatIndex&&s.ActiveSeats[x]&&!s.HasHu[x])
            ||SichuanGangDiscardLiability.CurrentGangCash(s) is not null)return false;
        var gate=SichuanSevenPairsDevelopment.Assess(s);
        if(gate.Applies)return gate.Favorable&&gate.Safe;
        return s.OwnMeldCount==1&&SichuanDevelopmentPolicy.Melds(s,s.SeatIndex).All(m=>m.Type==SichuanMeldType.Peng)
            &&SichuanDevelopmentPolicy.Melds(s,s.SeatIndex).All(m=>s.Hand18[m.TileType]==0)
            &&s.Hand18.Count(n=>n>=2)>=3&&!s.Hand18.Any(n=>n>=4)
            &&Enumerable.Range(0,3).Any(suit=>Enumerable.Range(0,4).Count(x=>x!=s.SeatIndex&&s.ActiveSeats[x]&&!s.HasHu[x]&&s.DingQueSuits[x]==suit)>=2)
            &&SichuanDistinctDingQueHuPolicy.AssessDanger(s,new())==0;
    }

    internal Report Refine(SichuanStateView s,SichuanBeliefSnapshot belief,SichuanWallAvailability wall,
        IReadOnlyList<SichuanDiscardAnalysis> analyses)
    {
        Report No(string why)=>new(why,new Dictionary<int,Value>(),0,0,0);
        var context=CurrentComparison.Value;
        bool ownedComparison=context is not null&&context.Root.SeatIndex==s.SeatIndex;
        if(SuppressForResearch||(!ownedComparison&&(!SichuanSearchBudget.IsRoot(s)||SichuanDiscardPolicy.AtSearchLeaf))
            ||!Qualifies(s)||s.Hand18.Sum()!=14-3*s.OwnMeldCount)return No("outside_scope");
        var gate=SichuanSevenPairsDevelopment.Assess(s);
        return SichuanPolicyExecutionScope.Memoize("common_ready_development",SichuanDecisionCommand.Fingerprint(s),()=>
        {
            if(ownedComparison)return Compute(s,context!.Belief,context.Wall,analyses,gate,context.Root);
            using var allocation=SichuanSearchBudget.TryDeep(s,"SEARCH_DEEP_ORDINARY_SEVEN_PAIRS_DEVELOPMENT");
            return allocation is null?No("budget_not_allocated"):Compute(s,belief,wall,analyses,gate);
        });
    }

    private Report Compute(SichuanStateView s,SichuanBeliefSnapshot belief,SichuanWallAvailability wall,
        IReadOnlyList<SichuanDiscardAnalysis> analyses,SichuanSevenPairsEligibility gate,SichuanStateView? numericalSource=null)
    {
        var watch=System.Diagnostics.Stopwatch.StartNew();
        var endpoints=Endpoints(s,wall);
        double endpointMs=watch.Elapsed.TotalMilliseconds;
        var order=new List<int>{s.SeatIndex};for(int d=1;d<4;d++)
        {int seat=(s.SeatIndex-d+4)%4;if(s.ActiveSeats[seat]&&!s.HasHu[seat])order.Add(seat);}
        numericalSource??=s;
        var env=Environment(numericalSource,belief,wall,order.ToArray());
        const int count=1024;
        var worlds=new M.World[count];
        for(int i=0;i<count;i++)
        {
            int seed=20261022+i*7919;
            var random=new Random(seed^104729);
            worlds[i]=new(_walls.SampleWallOrder(numericalSource,belief,seed),
                Enumerable.Range(0,s.WallCount*4).Select(_=>random.NextDouble()).ToArray(),
                Enumerable.Range(0,s.WallCount*4).Select(_=>random.NextDouble()).ToArray(),
                Enumerable.Range(0,s.WallCount*4).Select(_=>random.NextDouble()).ToArray());
        }
        double wallMs=watch.Elapsed.TotalMilliseconds-endpointMs;
        var discovery=worlds.Take(count/2).ToArray();var confirmation=worlds.Skip(count/2).ToArray();
        var result=new Dictionary<int,Value>();
        int minimum=analyses.Min(a=>{var h=s.Hand18.ToArray();h[a.DiscardTileType]--;return _distance.CalcStandardShanten(h,s.OwnMeldCount);});
        foreach(var a in analyses)
        {
            var h=s.Hand18.ToArray();h[a.DiscardTileType]--;
            result[a.DiscardTileType]=EvaluateOne(s,h,endpoints,wall,belief,env,discovery,confirmation,
                gate.MayInvest||_distance.CalcStandardShanten(h,s.OwnMeldCount)<=minimum);
        }
        return new("bounded_legal_ready_endpoint_trajectories",result,watch.Elapsed.TotalMilliseconds,endpoints.Count,count)
            {EndpointMs=endpointMs,WallMs=wallMs,PlansMs=watch.Elapsed.TotalMilliseconds-endpointMs-wallMs};
    }

    private Value EvaluateOne(SichuanStateView s,int[] h,List<Endpoint> endpoints,SichuanWallAvailability wall,
        SichuanBeliefSnapshot belief,M.Environment env,M.World[] discovery,M.World[] confirmation,bool allowSeven)
    {
            var ready=Price(s,h,wall);
            var options=ready is not null?new[]{new Endpoint(h,ready,_distance.CalcStandardShanten(h,s.OwnMeldCount)>0)}:
                endpoints.Where(e=>Missing(h,e.Hand)<=2&&(allowSeven||!e.SevenOnly))
                .Select(e=>(e,score:Priority(s,h,e,wall,env.Order.Length))).Where(x=>x.score>0)
                .GroupBy(x=>x.e.SevenOnly).SelectMany(g=>g.OrderByDescending(x=>x.score).ThenBy(x=>Key(x.e.Hand),StringComparer.Ordinal).Take(6))
                .Select(x=>x.e).ToArray();
            M.Estimate? best=null;M.Plan? bestPlan=null;string id="";int n=0;
            foreach(var e in options)
            {
                if(Enumerable.Range(0,27).Any(t=>Math.Max(0,e.Hand[t]-h[t])>s.Remaining18[t]))continue;
                var plan=Plan(s,h,e.Hand,wall,belief);if(plan is null)continue;
                n++;var value=M.Evaluate(plan,discovery,env);
                // One public plan for all worlds, never a wall-aware maximum.
                if(best is null||value.Chance.ExpectedNetScore>best.Chance.ExpectedNetScore+1e-9)
                {best=value;id=plan.Id;bestPlan=plan;}
            }
            if(best is null)
            {bestPlan=Plan(s,h,h,wall,belief)!;id=Key(h);}
            best=M.Evaluate(bestPlan!,confirmation,env);
            if(best is not null)
            {
                double mean=best.Nets.Average();double se=Math.Sqrt(best.Nets.Sum(x=>(x-mean)*(x-mean))/(confirmation.Length*(confirmation.Length-1)));
                return new(best,id,n,se);
            }
            throw new InvalidOperationException("development_missing_holding_value");
    }

    internal Value? Holding(SichuanStateView root,SichuanStateView holding,int offset)
    {
        var context=CurrentComparison.Value;
        if(context is null||context.Root.SeatIndex!=root.SeatIndex)return null;
        return SichuanPolicyExecutionScope.Memoize("common_development_holding",(SichuanDecisionCommand.Fingerprint(holding),offset),()=>
        {
            var endpoints=Endpoints(holding,context.Wall);var source=context.Root;
            var order=new List<int>{root.SeatIndex};for(int d=1;d<4;d++){int seat=(root.SeatIndex-d+4)%4;if(root.ActiveSeats[seat]&&!root.HasHu[seat])order.Add(seat);}
            var env=Environment(source,context.Belief,context.Wall,order.ToArray()) with{FirstActor=order[(order.Count-Math.Clamp(offset,0,order.Count-1))%order.Count]};
            var worlds=SichuanPolicyExecutionScope.Memoize("development_reaction_worlds",SichuanDecisionCommand.Fingerprint(source),()=>
            {
                var w=new M.World[1024];for(int i=0;i<w.Length;i++){int seed=20261022+i*7919;var random=new Random(seed^104729);
                    w[i]=new(_walls.SampleWallOrder(source,context.Belief,seed),Enumerable.Range(0,source.WallCount*4).Select(_=>random.NextDouble()).ToArray(),Enumerable.Range(0,source.WallCount*4).Select(_=>random.NextDouble()).ToArray(),Enumerable.Range(0,source.WallCount*4).Select(_=>random.NextDouble()).ToArray());}return w;
            });
            return EvaluateOne(holding,holding.Hand18,endpoints,context.Wall,context.Belief,env,worlds.Take(512).ToArray(),worlds.Skip(512).ToArray(),true);
        });
    }

    private static int Missing(int[] source,int[] target)=>Enumerable.Range(0,27).Sum(t=>Math.Max(0,target[t]-source[t]));
    private static string Key(int[] h)=>string.Concat(h.Select(x=>(char)('0'+x)));
    internal List<Endpoint> Endpoints(SichuanStateView s,SichuanWallAvailability wall,bool includeDead=false)
    {
        var h=new int[27];var found=new Dictionary<string,int[]>();
        var exposed=new int[27];foreach(var m in SichuanDevelopmentPolicy.Melds(s,s.SeatIndex))exposed[m.TileType]+=m.Type==SichuanMeldType.Peng?3:4;
        var legal=Enumerable.Range(0,27).Where(t=>t/9!=s.OwnDingQueSuit).ToArray();
        bool Add(int t,int n)
        {
            h[t]+=n;
            // A complete shape may use one hypothetical winning copy even
            // when that wait is publicly dead. The retained 13-tile endpoint
            // itself must still be physically obtainable.
            bool supply=includeDead
                ?Enumerable.Range(0,27).Sum(x=>Math.Max(0,h[x]-s.Hand18[x]-s.Remaining18[x]))<=1
                :h[t]<=s.Hand18[t]+s.Remaining18[t];
            bool valid=h[t]+exposed[t]<=4&&supply&&Missing(s.Hand18,h)<=3;
            if(!valid)h[t]-=n;return valid;
        }
        void Save()
        {if(Missing(s.Hand18,h)<=2&&Enumerable.Range(0,27).All(t=>h[t]<=s.Hand18[t]+s.Remaining18[t]))
            found.TryAdd(Key(h),h.ToArray());}
        var melds=new List<int[]>();
        foreach(int t in legal){melds.Add([t,t,t]);if(t%9<=6)melds.Add([t,t+1,t+2]);}
        void Ordinary(int start,int left)
        {
            if(left==0)
            {foreach(int t in legal)if(h[t]>0){h[t]--;Save();h[t]++;}return;}
            for(int i=start;i<melds.Count;i++)
            {
                int added=0;foreach(int t in melds[i]){if(!Add(t,1))break;added++;}
                if(added==3)Ordinary(i,left-1);
                for(int j=0;j<added;j++)h[melds[i][j]]--;
            }
        }
        foreach(int pair in legal)if(Add(pair,2)){Ordinary(0,4-s.OwnMeldCount);h[pair]-=2;}
        void Seven(int start,int left)
        {
            if(left==0)
            {foreach(int t in legal)if(Add(t,1)){Save();h[t]--;}return;}
            for(int i=start;i<=legal.Length-left;i++)if(Add(legal[i],2))
            {Seven(i+1,left-1);h[legal[i]]-=2;}
        }
        if(s.OwnMeldCount==0)Seven(0,6);
        var result=new List<Endpoint>();
        foreach(var hand in found.Values)
        {
            var price=Price(s,hand,wall);
            if(price is not null&&(includeDead||price.HasDrawableWait))result.Add(new(hand,price,s.OwnMeldCount==0&&_distance.CalcStandardShanten(hand,0)>0));
        }
        return result;
    }

    internal static double Priority(SichuanStateView s,int[] source,Endpoint e,SichuanWallAvailability wall,int players)
    {
        double reach=1;int missing=Missing(source,e.Hand);if(missing==0)return double.PositiveInfinity;
        double draws=wall.WallCount/(double)players;
        for(int t=0;t<27;t++)if(e.Hand[t]>source[t])
        {
            int need=e.Hand[t]-source[t];double p=Math.Clamp(wall.ExpectedCounts18[t]/wall.WallCount,0,1);
            int suppliers=e.Hand[t]==3&&source[t]==2?Enumerable.Range(0,4).Count(x=>x!=s.SeatIndex&&s.ActiveSeats[x]&&!s.HasHu[x]&&s.DingQueSuits[x]==t/9):0;
            double k=draws*(1+suppliers),miss=Math.Pow(1-p,k);
            reach*=Math.Max(0,need==1?1-miss:1-miss-k*p*Math.Pow(1-p,Math.Max(0,k-1)));
        }
        double win=0;
        foreach(var w in e.Price.Waits)
        {
            int suppliers=Enumerable.Range(0,4).Count(x=>x!=s.SeatIndex&&s.ActiveSeats[x]&&!s.HasHu[x]&&s.DingQueSuits[x]==w.TileType/9);
            win+=w.PublicWallWeight/wall.WallCount*draws/(missing+1)*(w.SelfDrawPerPayer*(players-1)+suppliers*w.HandScore);
        }
        return reach*win;
    }

    internal M.Plan? Plan(SichuanStateView s,int[] initial,int[] endpoint,SichuanWallAvailability wall,SichuanBeliefSnapshot belief)
    {
        var types=Enumerable.Range(0,27).Where(t=>endpoint[t]>initial[t]).ToArray();
        var required=types.Select(t=>endpoint[t]-initial[t]).ToArray();
        var spare=Enumerable.Range(0,27).SelectMany(t=>Enumerable.Repeat(t,Math.Max(0,initial[t]-endpoint[t])))
            .OrderBy(t=>Enumerable.Range(0,4).Where(x=>x!=s.SeatIndex&&s.ActiveSeats[x]&&!s.HasHu[x])
                .Sum(x=>belief.SeatTileWaitProbability.GetValueOrDefault(x)?.GetValueOrDefault(t)??0)).ThenBy(t=>t).ToArray();
        if(types.Length>2||required.Sum()>2||spare.Length!=required.Sum())return null;
        var states=new List<M.Stage>();var cache=new Dictionary<string,int>();
        int Build(int[] got,int claims)
        {
            var key=string.Join(',',got)+"/"+claims;if(cache.TryGetValue(key,out int known))return known;
            var hand=initial.ToArray();int total=got.Sum();
            for(int i=0;i<types.Length;i++)hand[types[i]]+=got[i];
            for(int i=0;i<total;i++)hand[spare[i]]--;
            var melds=SichuanDevelopmentPolicy.Melds(s,s.SeatIndex);
            for(int i=0;i<types.Length;i++)if((claims&(1<<i))!=0)
            {hand[types[i]]-=3;melds.Add(new(SichuanMeldType.Peng,types[i],-1,0));}
            if(hand.Any(n=>n<0||n>4))throw new InvalidOperationException("development_plan_illegal_hand");
            var price=_distance.CalcLegalShanten(hand,melds.Count,s.OwnDingQueSuit,melds.Count==0)==0
                ?Price(s,hand,wall,melds):null;
            var ron=new double[27];var self=new double[27];
            if(price is not null)foreach(var w in price.Waits){ron[w.TileType]=w.HandScore;self[w.TileType]=w.SelfDrawPerPayer;}
            var own=Enumerable.Repeat(-1,27).ToArray();var peng=Enumerable.Repeat(-1,27).ToArray();
            int index=states.Count;cache[key]=index;
            states.Add(new(ron,self,own,peng,total<spare.Length?spare[total]:-1,price is not null,hand,melds.Select(m=>m.TileType).ToArray())
                {ChaJiaoScore=price?.Waits.Max(w=>w.HandScore)??0});
            for(int i=0;i<types.Length;i++)if(got[i]<required[i])
            {
                int t=types[i];var next=got.ToArray();next[i]++;
                own[t]=Build(next,claims);
                if(hand[t]==2&&endpoint[t]==3&&(claims&(1<<i))==0)
                {
                    var complete=endpoint.ToArray();var finalMelds=melds.ToList();complete[t]-=3;
                    foreach(int j in Enumerable.Range(0,types.Length).Where(j=>(claims&(1<<j))!=0))complete[types[j]]-=3;
                    finalMelds.Add(new(SichuanMeldType.Peng,t,-1,0));
                    if(Price(s,complete,wall,finalMelds) is not null)peng[t]=Build(next,claims|(1<<i));
                }
            }
            return index;
        }
        Build(new int[types.Length],0);
        return new(Key(endpoint),states.ToArray());
    }

    internal M.Plan PlanForCheck(SichuanStateView s,int[] initial,int[] endpoint,SichuanWallAvailability wall,SichuanBeliefSnapshot belief)
        =>Plan(s,initial,endpoint,wall,belief)!;

    internal static M.Environment Environment(SichuanStateView s,SichuanBeliefSnapshot belief,SichuanWallAvailability wall,int[] order)
    {
        var hazard=new double[4];var ron=new double[4][];var selfPay=new double[4];var ronPay=new double[4];var charge=new double[4];
        for(int seat=0;seat<4;seat++)
        {
            ron[seat]=Enumerable.Range(0,27).Select(t=>SichuanPublicDiscardSafety.MayRon(s,seat,t)
                ?Math.Clamp(belief.SeatTileWaitProbability.GetValueOrDefault(seat)?.GetValueOrDefault(t)??0,0,1):0).ToArray();
            double mass=Enumerable.Range(0,27).Where(t=>t/9!=s.DingQueSuits[seat]).Sum(t=>wall.ExpectedCounts18[t]);
            hazard[seat]=mass>0?Math.Clamp(Enumerable.Range(0,27).Sum(t=>wall.ExpectedCounts18[t]*ron[seat][t])/mass,0,.35):0;
            selfPay[seat]=2.5;ronPay[seat]=2+Math.Min(4,s.MeldCount(seat))*.75;
            charge[seat]=belief.SeatReadyPosterior.GetValueOrDefault(seat)*ronPay[seat];
        }
        return new(s.SeatIndex,order,s.DingQueSuits,hazard,ron,selfPay,ronPay,charge,order[1],
            Enumerable.Range(0,4).Select(x=>x==s.SeatIndex||SichuanOpponentTimeline.MustHaveClearedMissing(s,x)).ToArray());
    }
}
