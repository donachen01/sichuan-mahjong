using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanGoldenHookOpponent(int Seat, double ReadyNow,
    double ReadyByEnd, int ScheduledDraws, double TooFewChangesProbability,
    bool DifficultyEvidence, string Evidence);

/// <summary>Chapter 5.3, a specialized candidate inside the EXISTING flying
/// comparison, not a second action authority. Public posterior, exact prices,
/// existing finite-wall race, and the same production discard policy for a
/// bounded target-draw release estimate. No actual opponent hands are inputs.</summary>
public sealed class SichuanGoldenHookPolicy
{
    private sealed record World(double Weight,int WaitCopies,int GangCopies,SichuanReadyRaceOpponent[] Opponents);
    // The existing compact wire carries one reason. Preserve decisive chapter
    // evidence there without changing the protocol or dumping all diagnostics.
    public static string Summary(SichuanFlyingDecision d)
    {
        var codes=d.Reasons.Where(r=>r is "GOLDEN_HOOK_FIRST_HALF" or "GOLDEN_HOOK_SECOND_HALF"
            or "GOLDEN_HOOK_STAGE_ELIGIBLE" or "GOLDEN_HOOK_STAGE_TAKES_IMMEDIATE_HU"
            or "GOLDEN_HOOK_NET_SUPPORTS_FLIGHT" or "GOLDEN_HOOK_RETAIN_IMMEDIATE_HU").ToList();
        if(d.Reasons.Any(r=>r.Contains("_DIFFICULT_True_",StringComparison.Ordinal)))codes.Add("GOLDEN_HOOK_DIFFICULT_True");
        if(codes.Count==0)codes.Add(d.Reasons.FirstOrDefault()??"GOLDEN_HOOK_ASSESSMENT");
        return string.Join(";",codes);
    }

    public static bool Applies(SichuanStateView s,int offer) =>
        offer is >=0 and <27 && s.OwnMeldCount==3 && s.Hand18.Sum()==4
        && s.Hand18[offer]==2 && s.Hand18.Count(n=>n==2)==2;

    public SichuanFlyingDecision Decide(SichuanStateView source,int offer,int sourceSeat,
        SichuanHuRefusalAssessment evidence)
    {
        using var timing=SichuanPolicyTiming.Measure("golden_hook_candidate");
        using var budget=SichuanSearchBudget.Enter(source);
        var reasons=new List<string>{"GOLDEN_HOOK_TWO_PAIRS_HU_PENG_SPLIT_OTHER_PAIR"};
        SichuanFlyingDecision Reject(string why) => SichuanFlyingDecision.Rejected(why,evidence.ImmediateHuGain);
        if(!Applies(source,offer) || evidence.EffectiveWinType!=SichuanWinType.Discard)
            return Reject("GOLDEN_HOOK_NOT_ORDINARY_TWO_PAIR_OFFER");
        if(!SichuanPublicInferenceBoundary.TryProject(source,out var publicSource,out var failure,
            reaction:true,sourceSeat:sourceSeat))throw new InvalidOperationException("golden_hook_public_state_"+failure);
        var hand=source.Hand18.ToArray();hand[offer]-=2;
        var discard=Array.FindIndex(hand,n=>n==2);
        if(discard<0 || discard/9==source.OwnDingQueSuit)return Reject("GOLDEN_HOOK_NO_LEGAL_OTHER_PAIR");
        var peng=SichuanUnifiedDecisionEngine.ProjectPengContinuation(publicSource,hand,offer,sourceSeat);
        var after=SichuanBranchState.AfterDiscard(peng,discard);
        if(!SichuanPublicInferenceBoundary.TryProject(after,out var s,out failure,waiting:true))
            throw new InvalidOperationException("golden_hook_projected_public_state_"+failure);
        s.Scores=source.Scores.ToArray();
        var own=s.SeatIndex;
        var melds=SichuanDevelopmentPolicy.Melds(s,own);
        var fans=new SichuanFanProjectionEngine();
        var won=source.Hand18.ToArray();won[offer]++;
        var now=fans.Project(won,SichuanDevelopmentPolicy.Melds(source,own),SichuanWinType.Discard);
        var prices=new SichuanReadyWaitPricing().Build(s,s.Hand18,s.Remaining18.Select(n=>(double)n).ToArray(),melds);
        if(prices is not {HasDrawableWait:true} || prices.Waits.Count!=1)
            return Reject("GOLDEN_HOOK_NO_PUBLIC_LIVE_SINGLE_WAIT");
        var wait=prices.Waits[0];
        if(wait.HandScore<=now.HandScore)return Reject("GOLDEN_HOOK_NO_ACTUAL_PRICE_INCREASE");
        if(source.LockedFans[own]>=wait.CappedFan)
            return Reject("GOLDEN_HOOK_PRICE_DOES_NOT_CLEAR_PASSED_HU_LOCK");

        // 55 tiles remain after an ordinary four-player deal. Chapter halves
        // use wall progress, not the generic evaluator's last-two-draw gate.
        // This engineering boundary is reported explicitly, not quoted as an
        // author-specified turn number. Own opportunity/risk remain separate.
        var secondHalf=s.WallCount*2<=108-4*13-1;
        reasons.Add(secondHalf?"GOLDEN_HOOK_SECOND_HALF":"GOLDEN_HOOK_FIRST_HALF");
        var dangerReasons=new List<string>();
        var dangerClass=SichuanDistinctDingQueHuPolicy.AssessDanger(publicSource,dangerReasons);
        reasons.AddRange(dangerReasons);

        // Both alternatives start from the SAME pre-action public posterior.
        // Our own deterministic Peng/discard is not new evidence about hidden
        // hands. The post-Peng view is used only for future actor policy.
        var particles=SichuanHuWaitingModel.SharedPublicParticles(publicSource);
        if(particles.Any(p=>!SichuanPublicInferenceBoundary.ParticleConserves(s,p)))
            throw new InvalidOperationException("golden_hook_public_allocation_conservation_failed");
        if(particles.Count!=32)
            return Reject("GOLDEN_HOOK_PUBLIC_ALLOCATION_UNSUPPORTED");
        var mass=particles.Sum(p=>p.Weight);
        var ess=mass*mass/particles.Sum(p=>p.Weight*p.Weight);
        if(!double.IsFinite(ess) || ess<8)return Reject("GOLDEN_HOOK_PUBLIC_ALLOCATION_LOW_ESS");
        var order=new List<int>{own};
        for(int n=1;n<4;n++)
        {var seat=(own-n+4)%4;if(s.ActiveSeats[seat]&&!s.HasHu[seat])order.Add(seat);}
        var schedule=Enumerable.Range(0,s.WallCount).Select(i=>order[(i+1)%order.Count]).ToArray();
        var draws=order.ToDictionary(seat=>seat,seat=>schedule.Count(x=>x==seat));
        var readyNow=new double[4];var readyEnd=new double[4];var tooFew=new double[4];
        var worlds=new List<World>();
        var firstLoss=0.0;var wallCopies=0.0;var gangCopies=0.0;var originalOtherCopies=0.0;
        var safeGangTiles=melds.Where(m=>m.Type==SichuanMeldType.Peng).Select(m=>m.TileType).Where(t=>
        {
            if(s.Remaining18[t]<=0 || s.WallCount<=1)return false;
            var drawn=s.Hand18.ToArray();drawn[t]++;
            var view=SichuanBranchState.AfterOwnDraw(s,drawn,t,s.WallCount-1);
            return !SichuanPublicDiscardSafety.AnyMayRon(view,t);
        }).ToArray();
        var waiting=new SichuanHuWaitingModel();var shanten=new SichuanShantenEngine();
        foreach(var p in particles)
        {
            var worldProfiles=new List<SichuanReadyRaceOpponent>();
            var weight=p.Weight/mass;wallCopies+=weight*p.Wall27[wait.TileType];
            originalOtherCopies+=weight*p.Wall27[offer];
            gangCopies+=weight*safeGangTiles.Sum(t=>p.Wall27[t]);
            foreach(var seat in order.Skip(1))
            {
                var h=waiting.Hazard(s,p,seat);var isReady=h.SelfPrice.Any(v=>v>0);
                var distance=Math.Max(0,shanten.CalcLegalShanten(p.Hands27[seat],s.MeldCount(seat),s.DingQueSuits[seat]));
                // Current exact waits and the shared one-draw development
                // hypothesis. Multi-step rebuilding/claims are NOT silently
                // labelled a calibrated end-of-wall probability.
                var reach=isReady?1:1-Math.Pow(1-h.ReadyTransition,draws[seat]);
                readyNow[seat]+=weight*(isReady?1:0);readyEnd[seat]+=weight*reach;
                if(distance>draws[seat])tooFew[seat]+=weight;
                var developed=isReady?0:1-Math.Pow(1-h.ReadyTransition,draws[seat]/2.0);
                double zP=0,zMoney=0,rP=0,rMoney=0,gangCost=0,gangRonMoney=0;
                var missSize=Math.Max(1,s.WallCount-p.Wall27[wait.TileType]);
                for(int t=0;t<27;t++)
                {
                    var probability=p.Wall27[t]/(double)Math.Max(1,s.WallCount);
                    zP+=probability*((h.SelfPrice[t]>0?1:0)+developed*h.DevelopedSelfChance[t]);
                    zMoney+=probability*(h.SelfPrice[t]+developed*h.DevelopedSelfPrice[t]);
                    gangCost+=probability*h.DrawGangPrice[t];
                    if(t==wait.TileType)continue; // own hits Hu, never discard
                    var q=p.Wall27[t]/(double)missSize;
                    rP+=q*((h.RonPrice[t]>0?1:0)+developed*h.DevelopedRonChance[t]);
                    rMoney+=q*(h.RonPrice[t]+developed*h.DevelopedRonPrice[t]);
                    gangRonMoney+=q*(SichuanHuWaitingModel.GangDiscardPrice(h.RonPrice[t])+developed*h.DevelopedGangDiscardPrice[t]);
                }
                var firstPayment=SichuanPublicDiscardSafety.MayRon(publicSource,seat,discard)?h.RonPrice[discard]:0;
                firstLoss+=weight*firstPayment;
                worldProfiles.Add(new(order.IndexOf(seat),Math.Clamp(zP,0,1),Math.Clamp(rP,0,1),
                    zP>0?zMoney/zP:0,rP>0?rMoney/rP:0,gangCost,
                    FirstDiscardRonProbability:firstPayment>0?1:0,FirstDiscardPayment:firstPayment,
                    GangDiscardPayment:rP>0?gangRonMoney/rP:0));
            }
            worlds.Add(new(weight,p.Wall27[wait.TileType],safeGangTiles.Sum(t=>p.Wall27[t]),worldProfiles.ToArray()));
        }
        var outlook=new List<SichuanGoldenHookOpponent>();
        foreach(var seat in order.Skip(1))
        {
            var recent=s.PublicEvents.Where(e=>e.Seat==seat&&e.Type==SichuanPublicEventType.Discard).TakeLast(2).ToArray();
            var lateClear=recent.Length==2&&recent.All(e=>e.Origin==SichuanTileOrigin.Hand&&e.TileType/9==s.DingQueSuits[seat]);
            // These conservative support levels are engineering gates, not
            // textbook probabilities. A generic low ready prior alone cannot
            // certify difficulty; it needs observed late clearance or a strong
            // short-time structural posterior, with claims explicitly outside
            // that projection.
            var difficult=readyEnd[seat]<=0.25 && (lateClear||tooFew[seat]>=0.75);
            var why=lateClear?"recent_hand_discards_still_clear_missing":
                tooFew[seat]>=0.75?"public_short_time_structural_hypothesis":"no_supported_difficulty_evidence";
            outlook.Add(new(seat,readyNow[seat],readyEnd[seat],draws[seat],tooFew[seat],difficult,why));
            reasons.Add($"GOLDEN_HOOK_OPPONENT_{seat}_READY_{readyNow[seat]:F3}_LOCAL_END_{readyEnd[seat]:F3}_DRAWS_{draws[seat]}_DIFFICULT_{difficult}_{why}");
        }
        var existingRoot=now.GenCount>0;
        var difficulty=outlook.Any(o=>o.DifficultyEvidence);
        var eligible=draws[own]>0 && dangerClass==0 &&
            (!secondHalf || difficulty || existingRoot);
        if(order.Count==2)eligible=eligible&&difficulty;
        if(!eligible)
        {
            reasons.Add("GOLDEN_HOOK_STAGE_TAKES_IMMEDIATE_HU");
            reasons.Add("GOLDEN_HOOK_SKIPS_UNNEEDED_TARGET_POLICY_SEARCH");
            return new(false,discard,double.NegativeInfinity,evidence.ImmediateHuGain,[],reasons);
        }
        var release=new double[order.Count];var forced=0;
        for(int actor=1;actor<order.Count;actor++)if(SichuanOpponentTimeline.MustOfferDraw(s,order[actor],wait.TileType))forced|=1<<actor;
        var releases=EstimateReleases(s,particles,order,wait.TileType,forced,release);
        // Preserve joint allocation: a target held by a first-discard winner
        // cannot simultaneously remain in the wall. Likewise do not round two
        // fractional means into mutually exclusive Hu/Gang supplies: their
        // joint occurrence is exactly what gives a later root its value.
        SichuanActionTreeEvaluator.ChanceSearchResult EvaluateChance(double[] candidateRelease,bool optimisticBound=false)
        {
            var tree=new SichuanActionTreeEvaluator();
            var outcomes=worlds.Select(w=>
            {
                var group=new SichuanReadyRaceGroup(w.WaitCopies,wait.SelfDrawPerPayer,wait.HandScore,forced)
                    {ReleaseProbabilities=candidateRelease,OptimisticReleaseBound=optimisticBound};
                var value=tree.SearchChanceNodes(new(w.WaitCopies,s.WallCount,order.Count,order.Count-1,
                    wait.SelfDrawPerPayer*(order.Count-1),0,0,MaxDraws:s.WallCount,ReadyGroups:[group],
                    ReadyOpponents:w.Opponents,ReadyGang:new(w.GangCopies,
                        SichuanSettlementProjectionEngine.GangUnit(SichuanMeldType.AddedGang),
                        SichuanRuleSnapshot.Frozen.BaseScore*(1<<SichuanRuleSnapshot.Frozen.FanCap),
                        EnableHuJiaoTransfer:SichuanRuleSnapshot.Frozen.EnableHuJiaoTransfer)));
                return (value,w.Weight);
            }).ToArray();
            return SichuanActionTreeEvaluator.MixChanceResults(outcomes);
        }
        var chance=EvaluateChance(release);
        // Full concealed-hand supply is expensive and is only an ambiguity
        // resolver. First compute the cheap bounded result; if it is below
        // immediate Hu, compare against a deliberately optimistic release
        // envelope. Only when that envelope can cross Hu do we call the same
        // production discard policy on four <=13-tile sampled hands.
        var fullSupplyCalls=0;
        if(chance.ExpectedNetScore<=evidence.ImmediateHuGain+1e-9)
        {
            // All-release is not generally a net-value bound: retaining a
            // target can leave time for a later Gang. Maximize each target
            // event instead, within the declared local model only.
            var upper=EvaluateChance(release,optimisticBound:true);
            if(upper.ExpectedNetScore>evidence.ImmediateHuGain+1e-9)
            {
                fullSupplyCalls=EstimateReleases(s,particles,order,wait.TileType,forced,release,allowFullHands:true);
                chance=EvaluateChance(release);
            }
        }
        // No structural bonus, fabricated Gang premium or second estimate is
        // added to a monetary Hu comparison. Potential added Gang cannot by
        // itself unlock a refusal. Already scored Gang money is common/sunk.
        var value=chance.ExpectedNetScore;
        var admissible=eligible&&value>evidence.ImmediateHuGain+1e-9;
        reasons.AddRange(new[]{"GOLDEN_HOOK_EXACT_PRICE_SHARED_FINITE_WALL_RACE",
            "GOLDEN_HOOK_NARROWING_WAIT_ALLOWED_FOR_PRICE_GAIN",
            "GOLDEN_HOOK_FUTURE_ADDED_GANG_NOT_REFUSAL_PERMISSION",
            "GOLDEN_HOOK_LOCAL_MODEL_NOT_CALIBRATED_TERMINAL_EV",
            "GOLDEN_HOOK_ONE_DRAW_DEVELOPMENT_NO_LATER_HAND_REBUILD_OR_CLAIM_PROJECTION",
            "GOLDEN_HOOK_CROSS_OPPONENT_RON_AND_LATER_HELD_TILE_RELEASE_NOT_PROJECTED",
            "GOLDEN_HOOK_VOLUNTARY_RELEASE_CONDITIONAL_PRODUCTION_ACTOR_POLICY",
            "GOLDEN_HOOK_NATURAL_ADDED_GANG_REPLACEMENT_ROOT_AND_SURVIVAL_COUPLED",
            "GOLDEN_HOOK_GANG_FLOWER_GANG_DISCARD_AND_HUJIAO_TRANSFER_PRICED",
            "GOLDEN_HOOK_JOINT_PUBLIC_WALL_HOLDINGS_FIRST_RON_AND_GANG_ALLOCATION",
            "GOLDEN_HOOK_SHARED_PRE_ACTION_POSTERIOR_AND_SEAT_HAZARDS",
            $"GOLDEN_HOOK_TARGET_DRAW_RELEASE_POLICY_CALLS_{releases+fullSupplyCalls}",
            fullSupplyCalls>0?"GOLDEN_HOOK_FULL_HAND_SUPPLY_ESCALATION":"GOLDEN_HOOK_FULL_HAND_SUPPLY_NOT_NEEDED",
            $"GOLDEN_HOOK_PUBLIC_SAMPLES_32_ESS_{ess:F2}_WALL_COPIES_{wallCopies:F3}",
            $"GOLDEN_HOOK_VALUE_{value:F4}_HU_{evidence.ImmediateHuGain:F4}_FIRST_LOSS_{firstLoss:F4}_SELF_{chance.SelfDrawWinProbability:F4}_RON_{chance.DiscardHuProbability:F4}",
            eligible?"GOLDEN_HOOK_STAGE_ELIGIBLE":"GOLDEN_HOOK_STAGE_TAKES_IMMEDIATE_HU",
            admissible?"GOLDEN_HOOK_NET_SUPPORTS_FLIGHT":"GOLDEN_HOOK_RETAIN_IMMEDIATE_HU"});
        reasons.Add($"GOLDEN_HOOK_COUPLED_GANG_GAIN_{chance.ExpectedGangGain:F4}");
        var diagnosticRisk=new SichuanDangerEngine().Evaluate(discard,publicSource,new SichuanBeliefEngine().Build(publicSource));
        var branch=new SichuanFlyingBranch(discard,0,1,2,wallCopies,wallCopies+originalOtherCopies,
            -originalOtherCopies*(existingRoot?2:1),value,wait.CappedFan,
            wait.SelfDrawPerPayer,wait.HandScore,chance.ExpectedSelfDrawGain,chance.NaturalGangProbability,
            chance.ExpectedGangGain,safeGangTiles.Length,diagnosticRisk,false,admissible,reasons);
        return new(admissible,discard,value,evidence.ImmediateHuGain,[branch],reasons)
        {Financial=new(chance.ExpectedOwnWinGain,chance.ExpectedGangGain-chance.ExpectedGangPaymentLoss,
            chance.ExpectedChaJiaoValue,chance.ExpectedDealInLoss,chance.ExpectedOpponentSelfDrawLoss,
            chance.ExpectedContinuationValue,0)};
    }

    private static int EstimateReleases(SichuanStateView s,IReadOnlyList<SichuanHiddenHandParticle> particles,
        IReadOnlyList<int> order,int tile,int forced,double[] release,bool allowFullHands=false)
    {
        // Four equally spaced conditional posterior worlds. Only the target
        // draw is evaluated, never all future turns or all 27 draw branches.
        var worlds=particles.Where(p=>p.Wall27[tile]>0).ToArray();
        var total=worlds.Sum(p=>p.Weight*p.Wall27[tile]);
        if(total<=0)return 0;
        var selected=new List<SichuanHiddenHandParticle>();var index=0;var cumulative=worlds[0].Weight*worlds[0].Wall27[tile]/total;
        for(int i=0;i<4;i++)
        {var point=(i+0.5)/4;while(cumulative<point&&index<worlds.Length-1){index++;cumulative+=worlds[index].Weight*worlds[index].Wall27[tile]/total;}selected.Add(worlds[index]);}
        int calls=0;
        for(int actor=1;actor<order.Count;actor++)
        {
            if((forced&(1<<actor))!=0)continue;
            var seat=order[actor];double offers=0;
            if(!allowFullHands && s.HandCounts[seat]>7)continue;
            foreach(var p in selected)
            {
                var hand=p.Hands27[seat].ToArray();hand[tile]++;
                var view=SichuanOpponentSupplyStep.ActorView(s,seat,hand,tile);
                if(SichuanOwnTurnActions.FromState(view).CanHu)continue;
                var actorBrain=new SichuanRoundBrainEngine().Observe(view);
                using var isolated=SichuanPolicyExecutionScope.UseOwnPlan(actorBrain);
                var chosen=SichuanDiscardPolicy.Select(view,actorBrain,searchLeaf:true);calls++;
                if(chosen.Action.TileType==tile)offers++;
            }
            release[actor]=offers/selected.Count;
        }
        return calls;
    }
}
