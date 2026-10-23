using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>One owner for one round and seat. Never called by hypothetical analysis.</summary>
internal sealed class SichuanDecisionAuthority
{
    private readonly object _gate = new();
    private string _turnKey = "";
    private SichuanSelfActionDecisionResult? _turn;
    private string _reactionKey = "";
    private SichuanReactionDecisionResult? _reaction;
    private (SichuanStateView Source, SichuanDecisionCommand Command)? _pendingPeng;

    internal bool IsIssuedFor(SichuanStateView state, SichuanDecisionCommand command)
    {
        lock (_gate)
        {
            var issued = command.Window == "turn" ? _turn?.Command
                : command.Window == "reaction" ? _reaction?.Command : null;
            return issued is not null && issued == command
                && command.StateKey == SichuanDecisionCommand.Fingerprint(state);
        }
    }

    internal SichuanSelfActionDecisionResult Turn(SichuanStateView state, SichuanRoundBrainSnapshot brain,
        bool canHu, IReadOnlyList<int> concealed, IReadOnlyList<int> added,
        IReadOnlyDictionary<int,int>? robCounts, IReadOnlyList<int>? mandatory)
    {
        lock (_gate)
        {
            var an = concealed.Distinct().Order().ToArray(); var add = added.Distinct().Order().ToArray();
            var required = (mandatory ?? Array.Empty<int>()).Distinct().Order().ToArray();
            var key = SichuanDecisionCommand.Fingerprint(state) + $"/{brain.Revision}/{canHu}/" + string.Join(',',an) + "/" + string.Join(',',add) + "/" + string.Join(',',required);
            if (_turnKey == key && _turn is not null) return _turn;
            using var scope = SichuanPolicyExecutionScope.UseOwnPlan(brain);
            SichuanSelfActionDecisionResult result;
            var parent = "";
            var pending = _pendingPeng;
            _pendingPeng = null;
            if (pending.HasValue && MatchesPeng(pending.Value.Source, state, pending.Value.Command))
            {
                var c = pending.Value.Command;
                result = new() { Action = new(c.ContinuationAction == "discard" ? SichuanActionType.Pass : SichuanActionType.Gang,
                    c.ContinuationAction == "discard" ? -1 : c.ContinuationTile, 0, "执行本家已评价的碰后计划"),
                    GangSubtype = c.ContinuationAction == "discard" ? "" : c.ContinuationAction,
                    ContinuationDiscardTile = c.ContinuationAction == "discard" ? c.ContinuationTile : -1,
                    Reasons = new[] { "PENG_PRICED_CONTINUATION_COMMITTED", c.Id } };
                parent = c.Id;
                if (!Legal(state, result, canHu, an, add))
                {
                    parent = "";
                    result = Compute();
                    result.Reasons = result.Reasons.Prepend("PENG_PLAN_INVALIDATED_RECOMPUTE").ToArray();
                }
            }
            else
            {
                result = Compute();
                if (pending.HasValue) result.Reasons = result.Reasons.Prepend("PENG_STATE_CHANGED_RECOMPUTE").ToArray();
            }
            if (!Legal(state, result, canHu, an, add)) throw new InvalidOperationException("unified_turn_selected_illegal_action");
            var actual = Executable(result);
            result.Command = Issue(state, brain, "turn", key, actual.ActionType.ToString().ToLowerInvariant(), actual.TileType, result.GangSubtype, parent);
            _turnKey = key; _turn = result; return result;

            SichuanSelfActionDecisionResult Compute() => new SichuanSelfActionDecisionEngine().DecideSelfAction(state,canHu,an,add,robCounts,required,brain);
        }
    }

    internal SichuanReactionDecisionResult Reaction(SichuanStateView state, SichuanRoundBrainSnapshot brain,
        int tile, bool hu, bool peng, bool gang, int source, string type, bool mandatory)
    {
        lock (_gate)
        {
            if (type != "discard" || SichuanMahjong.AI.Core.Rules.SichuanDiscardClaimWindow.HuAlreadyClaimed(state, source, tile))
            {
                peng = false;
                gang = false;
                mandatory = false;
            }
            var key = SichuanDecisionCommand.Fingerprint(state) + $"/{brain.Revision}/{tile}/{hu}/{peng}/{gang}/{source}/{type}/{mandatory}";
            if (_reactionKey == key && _reaction is not null) return _reaction;
            using var scope = SichuanPolicyExecutionScope.UseOwnPlan(brain);
            var r = new SichuanReactionDecisionEngine().DecideReaction(state,tile,hu,peng,gang,source,type,false,mandatory,brain);
            var validTile = tile is >= 0 and < 27;
            var missingTile = validTile && tile / 9 == state.OwnDingQueSuit;
            // Caller option flags may be stale. The authority cannot sign a
            // meld forbidden by the current hand, missing suit or empty wall.
            if (r.Action.ActionType switch { SichuanActionType.Pass => false,
                SichuanActionType.Hu => !hu || !validTile || missingTile,
                SichuanActionType.Peng => !peng || !validTile || missingTile || state.Hand18[tile] < 2,
                SichuanActionType.Gang => !gang || !validTile || missingTile || state.Hand18[tile] < 3 || state.WallCount <= 0,
                _ => true })
                throw new InvalidOperationException("unified_reaction_selected_illegal_action");
            var childAction = ""; var childTile = -1; var shape = "";
            if (r.Action.ActionType == SichuanActionType.Peng)
            {
                var hand = (int[])state.Hand18.Clone(); hand[tile] -= 2;
                var projected = SichuanUnifiedDecisionEngine.ProjectPengContinuation(state,hand,tile,source);
                childAction = string.IsNullOrEmpty(r.PlannedSelfAction) ? "discard" : r.PlannedSelfAction;
                childTile = childAction == "discard" ? r.PlannedDiscardTile : r.PlannedSelfActionTile;
                if (childTile < 0) throw new InvalidOperationException("peng_missing_executable_continuation");
                shape = PengShape(projected);
            }
            r.Command = Issue(state,brain,"reaction",key,r.Action.ActionType.ToString().ToLowerInvariant(),r.Action.TileType,"",
                continuationAction:childAction,continuationTile:childTile,continuationState:shape);
            _pendingPeng = r.Action.ActionType == SichuanActionType.Peng ? (SichuanBranchState.Copy(state),r.Command) : null;
            _reactionKey=key; _reaction=r; return r;
        }
    }

    private static SichuanDecisionCommand Issue(SichuanStateView s, SichuanRoundBrainSnapshot b, string window,
        string key, string action, int tile, string subtype, string parent="", string continuationAction="",
        int continuationTile=-1, string continuationState="") => new(
        SichuanDecisionCommand.Hash(key + "/" + action + "/" + tile + "/" + subtype + "/" + parent), window,
        s.RoundId,s.HostGeneration,s.ViewVersion,s.SeatIndex,SichuanDecisionCommand.Fingerprint(s),
        SichuanDecisionCommand.PolicyVersion,b.Revision,action,tile,subtype,parent,continuationAction,continuationTile,continuationState);

    internal static SichuanAction Executable(SichuanSelfActionDecisionResult r) => r.Action.ActionType == SichuanActionType.Pass
        ? r.Action with { ActionType=SichuanActionType.Discard, TileType=r.ContinuationDiscardTile } : r.Action;

    private static bool Legal(SichuanStateView s, SichuanSelfActionDecisionResult r, bool hu, int[] an, int[] add)
    {
        var a=Executable(r); var t=a.TileType;
        if(a.ActionType==SichuanActionType.Hu) return hu;
        if(t is <0 or >=27 || s.Hand18[t]<=0) return false;
        var hasMissing = Enumerable.Range(0,27).Any(i=>i/9==s.OwnDingQueSuit && s.Hand18[i]>0);
        if(a.ActionType==SichuanActionType.Discard) return !hasMissing || t/9==s.OwnDingQueSuit;
        if(a.ActionType!=SichuanActionType.Gang || s.WallCount<=0 || t/9==s.OwnDingQueSuit) return false;
        return r.GangSubtype == "an_gang" ? an.Contains(t)&&s.Hand18[t]==4
            : r.GangSubtype=="add_gang" && add.Contains(t)&&SichuanAddedGangRules.CanUpgrade(s,t);
    }

    private static bool MatchesPeng(SichuanStateView source, SichuanStateView actual, SichuanDecisionCommand c)
    {
        if(actual.RoundId!=c.RoundId || actual.HostGeneration!=c.Generation || actual.SeatIndex!=c.Seat || actual.CurrentSeat!=c.Seat
            || actual.ViewVersion<c.ViewVersion || actual.WallCount!=source.WallCount) return false;
        // EventVersion is a content/cache stamp on the Godot bridge, not an
        // event ordinal. Require the unchanged journal plus exactly one new
        // Peng; comparing event indexes with that stamp rejects every live plan.
        if (actual.PublicEvents.Count != source.PublicEvents.Count + 1
            || !actual.PublicEvents.Take(source.PublicEvents.Count).SequenceEqual(source.PublicEvents)) return false;
        var later=actual.PublicEvents.Skip(source.PublicEvents.Count).ToArray();
        // No new draw or other public fact may be concealed behind an old plan.
        if(later.Length!=1 || later[0].Type!=SichuanPublicEventType.Peng || later[0].Seat!=c.Seat || later[0].TileType!=c.Tile
            || later[0].SourceSeat!=source.CurrentSeat || later[0].WallCountAfter!=actual.WallCount) return false;
        return PengShape(actual)==c.ContinuationState;
    }

    // Versions and the expected new Peng event differ. All strategic facts and
    // legality are retained; differences cause a fresh decision, never substitution.
    private static string PengShape(SichuanStateView s)
    {
        var c=SichuanBranchState.Copy(s); c.RoundId=""; c.HostGeneration=0;c.ViewVersion=0;
        c.VisibleVersion=0;c.HandVersion=0;c.StrategyContextVersion=0;c.EventVersion=0;
        c.PublicEvents.Clear();
        // Meld event indexes are bookkeeping, while added-Gang blocking is a rule.
        for(var seat=0;seat<4;seat++)
            for(var i=0;i<c.MeldViews[seat].Count;i++) c.MeldViews[seat][i]=c.MeldViews[seat][i] with { EventIndex=0 };
        return SichuanDecisionCommand.Fingerprint(c);
    }
}
