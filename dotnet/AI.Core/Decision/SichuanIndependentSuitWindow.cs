using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Agents;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanIndependentSuitWindowPath(int Discard,int Particle,int Draws,
    string Boundary,int OwnActionTile,string OwnAction,bool Ready,bool IndependentWait,
    int ForcedOffers,int AuxiliaryOffers,bool HeldOffer,int OfferTile,int OfferSource,string OwnPolicyEvidence="")
{
    public int[]? PostHand {get;init;}
    public IReadOnlyList<SichuanMeldView> PostMelds {get;init;}=[];
    public int[] LegalWaits {get;init;}=[];
}
public sealed record SichuanIndependentSuitWindowBounds(int Discard,int KnownPaths,int UnresolvedPaths,
    double HuLower,double HuUpper,double ReadyOrHuLower,double ReadyOrHuUpper);
public sealed record SichuanIndependentSuitWindowReport(string Status,int Samples,double EffectiveSamples,
    string ConditionalScope,IReadOnlyList<SichuanIndependentSuitWindowPath> Paths)
{public IReadOnlyList<SichuanIndependentSuitWindowBounds> EmpiricalModelBounds {get;init;}=[];}

/// <summary>Public-posterior experiment through the next OWN decision/claim.
/// Actual shared policies see only their own hypothetical hand and public
/// observations, never a sampled future wall. No terminal value or live score
/// is manufactured from these paths. Unimplemented claim/Gang branches remain
/// explicit boundaries in the denominator, not silently renormalized away.</summary>
public sealed class SichuanIndependentSuitWindow
{
    public SichuanIndependentSuitWindowReport Analyze(SichuanStateView source,IEnumerable<int> discards,
        int samples=32,int seed=20261111)
    {
        SichuanPolicyExecutionScope.RequireResearchContext();
        if(samples is <8 or >128)throw new ArgumentOutOfRangeException(nameof(samples));
        int lane=SichuanIndependentSuitObjective.Suit(source),own=source.SeatIndex;
        if(lane<0||source.Hand18.Sum()!=14-3*source.OwnMeldCount||source.LockedFans[own]>=0
            ||source.HasHu[own]||!source.ActiveSeats[own]||source.ActiveSeats.Count(x=>x)<2)
            return new("outside_scope",0,0,"next_own_decision",[]);
        if(!SichuanPublicInferenceBoundary.TryProject(source,out var projection,out var why))
            return new("public_projection_"+why,0,0,"next_own_decision",[]);
        // Restore public game context and OWN private restrictions only.
        // Rival private pass/ready/lock flags never enter a hypothetical policy.
        projection.Phase=source.Phase;projection.RoundId=source.RoundId;projection.HostGeneration=source.HostGeneration;
        projection.ViewVersion=source.ViewVersion;projection.PolicyVariant=source.PolicyVariant;
        projection.Scores=source.Scores.ToArray();projection.TotalRounds=source.TotalRounds;projection.RemainingRounds=source.RemainingRounds;
        projection.LockedFans[own]=source.LockedFans[own];projection.LockTurns[own]=source.LockTurns[own];
        projection.UnlockOnOwnDraw[own]=source.UnlockOnOwnDraw[own];
        projection.PassedHu18[own]=source.PassedHu18[own].ToArray();projection.PassedPeng18[own]=source.PassedPeng18[own].ToArray();
        projection.PassedGang18[own]=source.PassedGang18[own].ToArray();
        var choices=discards.Distinct().Order().ToArray();
        if(choices.Length==0)throw new ArgumentException("independent_window_empty_choices");
        if(choices.Any(t=>t is <0 or >26||source.Hand18[t]<=0||t/9==source.OwnDingQueSuit))
            throw new InvalidOperationException("independent_window_illegal_discard");
        var particles=new SichuanHiddenHandInferenceEngine().SampleParticles(projection,Math.Max(32,samples),seed,
            SichuanHiddenHandProposal.PublicPriorThenLikelihood);
        if(particles.Count==0||particles.Any(p=>!SichuanPublicInferenceBoundary.ParticleConserves(source,p)))
            return new("public_sample_conservation_rejected",0,0,"next_own_decision",[]);
        double total=particles.Sum(p=>p.Weight),ess=total*total/particles.Sum(p=>p.Weight*p.Weight);
        if(!double.IsFinite(total)||total<=0)return new("zero_posterior_mass",0,0,"next_own_decision",[]);
        // The inference likelihood uses its own evidence projection. The
        // executable policies also need public draw/claim timing and own facts.
        SichuanPublicInferenceBoundary.RestorePolicyHistory(source,projection);
        for(int i=0;i<projection.PublicEvents.Count;i++)projection.PublicEvents[i]=projection.PublicEvents[i] with{EventIndex=i+1};
        projection.EventVersion=projection.PublicEvents.Count;
        var random=new Random(seed);double offset=random.NextDouble()/samples,cumulative=particles[0].Weight/total;
        int selected=0;var paths=new List<SichuanIndependentSuitWindowPath>();
        for(int i=0;i<samples;i++)
        {
            double position=offset+i/(double)samples;
            while(position>cumulative&&selected<particles.Count-1)cumulative+=particles[++selected].Weight/total;
            // One joint allocation and draw order, shared by every root choice.
            var p=particles[selected];var wall=Enumerable.Range(0,27).SelectMany(t=>Enumerable.Repeat(t,p.Wall27[t])).ToArray();
            var shuffle=new Random(seed+i*7919);for(int j=wall.Length-1;j>0;j--){int k=shuffle.Next(j+1);(wall[j],wall[k])=(wall[k],wall[j]);}
            foreach(int discard in choices)paths.Add(Run(projection,p,wall,discard,i,lane));
        }
        static bool Known(SichuanIndependentSuitWindowPath p)=>p.Boundary is "own_decision" or "own_claim" or "own_reaction_pass" or "wall_empty" or "battle_end";
        string status=paths.All(Known)?"bounded_window_complete":"bounded_window_with_unresolved_branches";
        var bounds=paths.GroupBy(p=>p.Discard).Select(g=>
        {
            int unknown=g.Count(p=>!Known(p)),hu=g.Count(p=>p.OwnAction=="hu"),ready=g.Count(p=>p.Ready);
            return new SichuanIndependentSuitWindowBounds(g.Key,g.Count()-unknown,unknown,
                hu/(double)samples,(hu+unknown)/(double)samples,ready/(double)samples,(ready+unknown)/(double)samples);
        }).ToArray();
        return new(status,samples,ess,"next_actual_own_policy_action; rivals_use_reference_policy_and_public_reconstructed_memory; selected_gang_and_rival_claims_are_boundaries; empirical_bounds_are_not_confidence_intervals_or_full_game_value",paths)
            {EmpiricalModelBounds=bounds};
    }

    private static SichuanIndependentSuitWindowPath Run(SichuanStateView source,SichuanHiddenHandParticle particle,
        int[] wall,int discard,int index,int lane)
    {
        int own=source.SeatIndex,forced=0,auxiliary=0,draws=0,offer=-1,offerSource=-1;bool held=false;
        var state=SichuanBranchState.AfterDiscard(source,discard);
        state.Phase=6;
        state.LastDrawTileType=-1;state.LastDrawOrigin=SichuanTileOrigin.Unknown;state.OwnDrawReason="";
        var hands=particle.Hands27.Select(h=>h.ToArray()).ToArray();hands[own]=state.Hand18.ToArray();
        void Conserve(int consumed)
        {
            var counts=state.Visible18.ToArray();foreach(var hand in hands)for(int t=0;t<27;t++)counts[t]+=hand[t];
            foreach(int t in wall.Skip(consumed))counts[t]++;
            if(counts.Any(n=>n!=4))throw new InvalidOperationException("independent_window_physical_inventory_not_conserved");
        }
        Conserve(0);
        var shanten=new SichuanShantenEngine();
        SichuanIndependentSuitWindowPath Finish(string boundary,string action="",int tile=-1,SichuanStateView? post=null,string policyEvidence="")
        {
            bool ready=false,goal=false;
            int[] waits=[];
            if(post is not null&&post.Hand18.Sum()==13-3*post.OwnMeldCount)
            {
                var belief=new SichuanBeliefEngine().Build(post);var availability=new SichuanWallAvailabilityEngine().Build(post,belief);
                var price=new SichuanReadyWaitPricing().Build(post,post.Hand18,availability.ExpectedCounts18);
                ready=price is not null;goal=price is not null&&price.Waits.Any(w=>w.TileType/9==lane&&w.PublicWallWeight>0);
                waits=price?.Waits.Select(w=>w.TileType).Order().ToArray()??[];
            }
            if(action=="hu"){ready=true;goal=tile/9==lane;}
            return new(discard,index,draws,boundary,tile,action,ready,goal,forced,auxiliary,held,offer,offerSource,policyEvidence)
                {PostHand=post?.Hand18.ToArray(),PostMelds=SichuanDevelopmentPolicy.Melds(post??state,own).ToArray(),LegalWaits=waits};
        }
        bool RivalMayClaim(int sourceSeat,int tile)
        {
            for(int seat=0;seat<4;seat++)if(seat!=own&&seat!=sourceSeat&&state.ActiveSeats[seat]&&!state.HasHu[seat]
                &&state.DingQueSuits[seat]!=tile/9)
            {
                var h=hands[seat].ToArray();h[tile]++;
                if(hands[seat][tile]>=2||shanten.CalcLegalShanten(h,state.MeldCount(seat),state.DingQueSuits[seat])<0)return true;
            }
            return false;
        }
        if(RivalMayClaim(own,discard))return Finish("rival_claim_on_root_discard");
        int Next(int from)=>Enumerable.Range(1,4).Select(d=>(from-d+8)%4).First(s=>state.ActiveSeats[s]&&!state.HasHu[s]);
        int actor=Next(own);
        var ownPlan=SichuanPolicyExecutionScope.OwnPlan;var ownBrain=new SichuanRoundBrainEngine();
        if(ownPlan is not null)ownBrain.Restore(source,new AgentBrainMemory(ownPlan.Revision,ownPlan.Stage,
            ownPlan.PrimaryRoute,ownPlan.FallbackRoute,ownPlan.TargetSuit,ownPlan.Commitment,
            new(ownPlan.RouteWeights),ownPlan.BrokenTriplets.ToArray(),ownPlan.DecisionHistory.ToArray()));
        else ownBrain.Observe(source);
        ownBrain.RecordReaction(source,new SichuanAction(SichuanActionType.Discard,discard));ownBrain.Observe(state);
        for(int position=0;position<wall.Length;position++)
        {
            int draw=wall[position];draws++;
            if(actor==own)
            {
                var hand=hands[own].ToArray();hand[draw]++;
                hands[own]=hand;Conserve(position+1);
                var view=SichuanBranchState.AfterOwnDraw(state,hand,draw,wall.Length-position-1);
                var legal=SichuanOwnTurnActions.FromState(view);
                var brain=ownBrain.Observe(view);using var plan=SichuanPolicyExecutionScope.UseOwnPlan(brain);
                var decision=new SichuanSelfActionDecisionEngine().DecideSelfAction(view,legal.CanHu,legal.Concealed,legal.Added,roundBrain:brain);
                string evidence=decision.Reasons.FirstOrDefault()??"";
                if(decision.Action.ActionType==SichuanActionType.Gang)return Finish("own_gang_window","gang",decision.Action.TileType,policyEvidence:evidence);
                if(decision.Action.ActionType==SichuanActionType.Hu)return Finish("own_decision","hu",draw,view,evidence);
                if(decision.ContinuationDiscardTile<0)throw new InvalidOperationException("independent_window_missing_actual_own_discard");
                return Finish("own_decision","discard",decision.ContinuationDiscardTile,
                    SichuanBranchState.AfterDiscard(view,decision.ContinuationDiscardTile),evidence);
            }
            hands[actor][draw]++;
            Conserve(position+1);
            var rival=SichuanOpponentSupplyStep.ActorView(state,actor,hands[actor],draw);
            long drawOrdinal=state.PublicEvents.Select(e=>e.EventIndex).DefaultIfEmpty(0).Max()+1;
            state.PublicEvents.Add(new(drawOrdinal,state.TurnIndex,actor,SichuanPublicEventType.Draw,-1,
                SichuanTileOrigin.Draw,actor,wall.Length-position-1));
            var rivalLegal=SichuanOwnTurnActions.FromState(rival);
            SichuanSelfActionDecisionResult rivalDecision;
            using(SichuanIndependentSuitObjective.ReferencePolicy())
            using(SichuanPolicyExecutionScope.UseOwnPlan(null))
            {
                var before=SichuanBranchState.Copy(rival,particle.Hands27[actor],rival.WallCount+1);
                before.HandCounts[actor]=particle.Hands27[actor].Sum();before.LastDrawTileType=-1;
                before.LastDrawOrigin=SichuanTileOrigin.Unknown;before.OwnDrawReason="";before.PublicEvents.RemoveAt(before.PublicEvents.Count-1);
                for(int t=0;t<27;t++)before.Remaining18[t]=4-before.Visible18[t]-before.Hand18[t];
                var rivalBrain=new SichuanRoundBrainEngine();rivalBrain.Observe(before);var hypothesis=rivalBrain.Observe(rival);
                using var plan=SichuanPolicyExecutionScope.UseOwnPlan(hypothesis);
                rivalDecision=new SichuanSelfActionDecisionEngine().DecideSelfAction(rival,rivalLegal.CanHu,rivalLegal.Concealed,rivalLegal.Added,roundBrain:hypothesis);
            }
            if(rivalDecision.Action.ActionType==SichuanActionType.Gang)return Finish("rival_gang_window");
            if(rivalDecision.Action.ActionType==SichuanActionType.Hu)
            {
                var price=new SichuanFanProjectionEngine().Project(hands[actor],SichuanDevelopmentPolicy.Melds(state,actor),SichuanWinType.SelfDraw);
                var settlement=new SichuanSettlementProjectionEngine().ProjectWin(actor,actor,
                    Enumerable.Range(0,4).Where(s=>state.ActiveSeats[s]&&!state.HasHu[s]).ToArray(),price,SichuanWinType.SelfDraw);
                for(int s=0;s<4;s++)state.Scores[s]+=settlement.ScoreChanges[s];state.WonScores[actor]=price.HandScore;
                state.ActiveSeats[actor]=false;state.HasHu[actor]=true;state.HandCounts[actor]=hands[actor].Sum();
                state=SichuanBranchState.Copy(state,wallCount:wall.Length-position-1,currentSeat:actor);
                long huOrdinal=state.PublicEvents.Select(e=>e.EventIndex).DefaultIfEmpty(0).Max()+1;
                state.PublicEvents.Add(new(huOrdinal,state.TurnIndex,actor,SichuanPublicEventType.Hu,draw,
                    SichuanTileOrigin.Draw,actor,state.WallCount));state.EventVersion=huOrdinal;ownBrain.Observe(state);
                if(state.ActiveSeats.Count(x=>x)<=1)return Finish("battle_end");actor=Next(actor);continue;
            }
            var discarded=rivalDecision.ContinuationDiscardTile;
            if(discarded is <0 or >26||hands[actor][discarded]<=0)throw new InvalidOperationException("independent_window_illegal_rival_discard");
            held=discarded!=draw;offer=discarded;offerSource=actor;
            bool forcedOffer=discarded/9==state.DingQueSuits[actor];
            if(forcedOffer)forced++;
            else if(discarded/9!=state.OwnDingQueSuit)auxiliary++;
            hands[actor][discarded]--;
            state=SichuanBranchState.Copy(state,wallCount:wall.Length-position-1,currentSeat:actor);
            state.HandCounts[actor]=hands[actor].Sum();state.Visible18[discarded]++;state.Remaining18[discarded]--;
            state.Discards18[actor].Add(discarded);state.TurnIndex++;
            Conserve(position+1);
            long ordinal=state.PublicEvents.Select(e=>e.EventIndex).DefaultIfEmpty(0).Max()+1;
            state.PublicEvents.Add(new(ordinal,state.TurnIndex,actor,SichuanPublicEventType.Discard,discarded,
                held?SichuanTileOrigin.Hand:SichuanTileOrigin.Draw,actor,state.WallCount));state.EventVersion=ordinal;
            if(RivalMayClaim(actor,discarded))return Finish("rival_claim_on_intermediate_discard");
            bool allowed=discarded/9!=state.OwnDingQueSuit;
            var winning=state.Hand18.ToArray();winning[discarded]++;
            bool hu=allowed&&state.PassedHu18[own][discarded]==0&&shanten.CalcLegalShanten(winning,state.OwnMeldCount,state.OwnDingQueSuit)<0;
            bool peng=allowed&&state.PassedPeng18[own][discarded]==0&&state.Hand18[discarded]>=2;
            bool gang=allowed&&state.PassedGang18[own][discarded]==0&&state.Hand18[discarded]>=3&&state.WallCount>0;
            if(hu||peng||gang)
            {
                var brain=ownBrain.Observe(state);using var plan=SichuanPolicyExecutionScope.UseOwnPlan(brain);
                var reaction=new SichuanReactionDecisionEngine().DecideReaction(state,discarded,hu,peng,gang,actor,roundBrain:brain);
                string evidence=reaction.Reasons.FirstOrDefault()??"";
                if(reaction.Action.ActionType==SichuanActionType.Hu)return Finish("own_claim","hu",discarded,SichuanBranchState.Copy(state,winning),evidence);
                if(reaction.Action.ActionType==SichuanActionType.Gang)return Finish("own_gang_window","gang",discarded,policyEvidence:evidence);
                if(reaction.Action.ActionType==SichuanActionType.Peng)
                {
                    var hand=state.Hand18.ToArray();hand[discarded]-=2;
                    var post=SichuanUnifiedDecisionEngine.ProjectPengContinuation(state,hand,discarded,actor);
                    if(reaction.PlannedSelfAction.Length>0)return Finish("own_gang_window");
                    return Finish("own_claim","peng",reaction.PlannedDiscardTile,SichuanBranchState.AfterDiscard(post,reaction.PlannedDiscardTile),evidence);
                }
                // This is the next actual own decision as well. Continuing
                // past it would also require the new passed-Hu lock state.
                return Finish("own_reaction_pass","pass",discarded,state,evidence);
            }
            ownBrain.Observe(state);
            actor=Next(actor);
        }
        return Finish("wall_empty",post:state);
    }
}
