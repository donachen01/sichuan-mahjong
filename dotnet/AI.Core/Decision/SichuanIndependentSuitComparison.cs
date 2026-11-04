using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Domain;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Compare with the complete executable policy on the SAME current
/// information and own brain. No stale command, private rival state or terminal
/// simulation is accepted. Conditional branches keep their own reference.</summary>
internal static class SichuanIndependentSuitComparison
{
    private sealed class Context
    {
        internal bool Reference;
        internal required SichuanStateView Root;
        internal int ExecutableRootDiscard=-1;
        internal SichuanReactionDecisionResult? ExecutableReaction;
        internal readonly Dictionary<string,SichuanDecisionResult> Discards=new();
        internal SichuanActionType? Reaction;
        internal string ReactionState="";
        internal readonly Dictionary<string,(int Tile,int[] Hand,string[] Melds)> Proofs=new();
    }
    private static readonly AsyncLocal<Context?> Current=new();
    internal static bool IsReference=>Current.Value?.Reference==true;
    internal static int ReferenceDiscard(SichuanStateView s)
    {
        if(Current.Value is not {Reference:false} c||c.Root.SeatIndex!=s.SeatIndex)return -1;
        var key=SichuanDecisionCommand.Fingerprint(s);
        if(c.ExecutableRootDiscard>=0&&key==SichuanDecisionCommand.Fingerprint(c.Root))return c.ExecutableRootDiscard;
        if(c.ExecutableReaction is { } r&&r.Action.ActionType==SichuanActionType.Peng
            &&r.PlannedSelfAction.Length==0&&r.PlannedDiscardTile>=0&&s.WallCount==c.Root.WallCount)
        {
            var hand=c.Root.Hand18.ToArray();hand[r.Action.TileType]-=2;
            var melds=Melds(c.Root).Append($"{(int)SichuanMeldType.Peng}:{r.Action.TileType}").Order(StringComparer.Ordinal);
            if(hand.SequenceEqual(s.Hand18)&&Melds(s).SequenceEqual(melds))return r.PlannedDiscardTile;
        }
        return c.Discards.GetValueOrDefault(key)?.Action.TileType??-1;
    }
    internal static SichuanActionType? ReferenceReaction(SichuanStateView s)=>Current.Value is {Reference:false} c
        &&c.ReactionState==SichuanDecisionCommand.Fingerprint(s)?c.Reaction:null;
    internal static bool Enabled(SichuanStateView s)=>Current.Value is null
        &&!SichuanDiscardPolicy.AtSearchLeaf
        &&SichuanReadyDevelopmentEvaluator.ShouldCompareIndependent(s);
    internal static void ConfirmDiscard(SichuanStateView s,int tile)
    {
        if(Current.Value is not {Reference:false} c||c.Root.SeatIndex!=s.SeatIndex)return;
        var key=SichuanDecisionCommand.Fingerprint(s);
        if(c.Discards.GetValueOrDefault(key)?.Arbitration.Any(a=>a.Accepted&&a.Priority>=SichuanDiscardArbiter.SafeTempo)==true)return;
        c.Proofs[key]=(tile,s.Hand18.ToArray(),Melds(s));
    }
    private static string[] Melds(SichuanStateView s)=>SichuanDevelopmentPolicy.Melds(s,s.SeatIndex)
        .Select(m=>$"{(int)m.Type}:{m.TileType}").Order(StringComparer.Ordinal).ToArray();
    private static bool Proven<T>(Context c,SichuanStateView s,T original,T proposed)
    {
        if(proposed is SichuanDecisionResult discard)
            return c.Proofs.TryGetValue(SichuanDecisionCommand.Fingerprint(s),out var d)&&d.Tile==discard.Action.TileType;
        if(proposed is SichuanSelfActionDecisionResult turn)
            return c.Proofs.TryGetValue(SichuanDecisionCommand.Fingerprint(s),out var t)&&t.Tile==turn.ContinuationDiscardTile;
        if(proposed is not SichuanReactionDecisionResult reaction||original is not SichuanReactionDecisionResult old)return false;
        if(reaction.Action.ActionType!=old.Action.ActionType)
            return reaction.ValueCandidates.Any(v=>v.Action.ActionType==reaction.Action.ActionType&&v.IsAdmissible
                &&v.ReasonCodes.Any(r=>r.StartsWith("PUBLIC_CLAIM_PAIRED_MEAN_",StringComparison.Ordinal)&&r.EndsWith("CONFIRMED_True",StringComparison.Ordinal)));
        if(reaction.Action.ActionType!=SichuanActionType.Peng)return false;
        var hand=s.Hand18.ToArray();hand[reaction.Action.TileType]-=2;
        var melds=Melds(s).Append($"{(int)SichuanMeldType.Peng}:{reaction.Action.TileType}").Order(StringComparer.Ordinal).ToArray();
        return c.Proofs.Values.Any(p=>p.Tile==reaction.PlannedDiscardTile&&p.Hand.SequenceEqual(hand)&&p.Melds.SequenceEqual(melds));
    }

    internal static SichuanDecisionResult Discard(SichuanStateView s,Func<SichuanDecisionResult> compute)
    {
        if(Current.Value is { } c)
        {
            if(c.Root.SeatIndex!=s.SeatIndex)return compute();
            var key=SichuanDecisionCommand.Fingerprint(s);
            if(!c.Reference&&!c.Discards.ContainsKey(key))
            {
                using var reference=Reference(c);
                c.Discards[key]=compute();
            }
            var r=compute();if(c.Reference)c.Discards[key]=r;return r;
        }
        if(!Enabled(s))return compute();
        return Compare(s,compute,r=>$"discard:{r.Action.TileType}",
            (r,reason)=>r.Reasons=r.Reasons.Prepend(reason).ToArray());
    }
    internal static SichuanSelfActionDecisionResult Turn(SichuanStateView s,Func<SichuanSelfActionDecisionResult> compute)
        =>Compare(s,compute,r=>$"{r.Action.ActionType}:{r.Action.TileType}:{r.GangSubtype}:{r.ContinuationDiscardTile}",
            (r,reason)=>r.Reasons=r.Reasons.Prepend(reason).ToArray());
    internal static SichuanReactionDecisionResult Reaction(SichuanStateView s,Func<SichuanReactionDecisionResult> compute)
        =>Compare(s,compute,r=>$"{r.Action.ActionType}:{r.Action.TileType}:{r.PlannedDiscardTile}:{r.PlannedSelfAction}:{r.PlannedSelfActionTile}",
            (r,reason)=>r.Reasons=r.Reasons.Prepend(reason).ToArray());

    private static T Compare<T>(SichuanStateView s,Func<T> compute,Func<T,string> key,Action<T,string> explain) where T:class
    {
        if(!Enabled(s))return compute();
        var context=new Context{Root=s};Current.Value=context;
        try
        {
            T original;
            using(Reference(context))original=compute();
            if(original is SichuanSelfActionDecisionResult own&&own.Action.ActionType==SichuanActionType.Pass)
                context.ExecutableRootDiscard=own.ContinuationDiscardTile;
            if(original is SichuanDecisionResult discard)context.ExecutableRootDiscard=discard.Action.TileType;
            if(original is SichuanReactionDecisionResult reaction)
            {context.Reaction=reaction.Action.ActionType;context.ReactionState=SichuanDecisionCommand.Fingerprint(s);context.ExecutableReaction=reaction;}
            T first;
            context.Proofs.Clear();
            using(SichuanReadyDevelopmentEvaluator.EnterComparisonNumerics(1024,20261107))first=compute();
            if(key(first)==key(original)){explain(first,"INDEPENDENT_SUIT_COMPLETE_REFERENCE_RETAINED");return first;}
            if(original is SichuanSelfActionDecisionResult oldTurn&&first is SichuanSelfActionDecisionResult newTurn
                &&(oldTurn.Action.ActionType!=SichuanActionType.Pass||newTurn.Action.ActionType!=SichuanActionType.Pass)
                ||original is SichuanReactionDecisionResult oldReaction&&first is SichuanReactionDecisionResult newReaction
                &&(oldReaction.Action.ActionType==SichuanActionType.Gang||newReaction.Action.ActionType==SichuanActionType.Gang
                    ||oldReaction.PlannedSelfAction.Length>0||newReaction.PlannedSelfAction.Length>0))
            {explain(original,"INDEPENDENT_SUIT_GANG_OUTSIDE_DEVELOPMENT_PROOF_RETAIN_REFERENCE");return original;}
            if(!Proven(context,s,original,first))
            {explain(original,"INDEPENDENT_SUIT_UNCONFIRMED_CHANGE_RETAIN_REFERENCE");return original;}
            if(SichuanReadyDevelopmentEvaluator.ResearchNumericalOverride)
            {explain(first,"INDEPENDENT_SUIT_RESEARCH_NUMERICS_SINGLE_OVERRIDE");return first;}
            T second;
            context.Proofs.Clear();
            using(SichuanReadyDevelopmentEvaluator.EnterComparisonNumerics(1024,20261109))second=compute();
            if(key(first)!=key(second)||!Proven(context,s,original,second))
            {explain(original,"INDEPENDENT_SUIT_SEED_DISAGREEMENT_RETAIN_REFERENCE");return original;}
            explain(first,"INDEPENDENT_SUIT_TWO_BATCH_COMPLETE_POLICY_COMPARISON");return first;
        }
        finally{Current.Value=null;}
    }
    private static IDisposable Reference(Context c)
    {
        bool old=c.Reference;c.Reference=true;
        var objective=SichuanIndependentSuitObjective.ReferencePolicy();
        var comparison=SichuanReadyDevelopmentEvaluator.SuspendComparison();
        return new Restore(()=>{comparison.Dispose();objective.Dispose();c.Reference=old;});
    }
    private sealed class Restore(Action end):IDisposable{public void Dispose()=>end();}
}
