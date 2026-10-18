using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Domain;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Owned branch snapshots only. No live seat brain or other agent is mutated.</summary>
public static class SichuanBranchState
{
    public static SichuanStateView Copy(SichuanStateView source, int[]? hand = null, int? wallCount = null, int? currentSeat = null)
    {
        var result = new SichuanStateView
        {
            RoundId = source.RoundId,
            HostGeneration = source.HostGeneration,
            ViewVersion = source.ViewVersion,
            SeatIndex = source.SeatIndex,
            DealerSeat = source.DealerSeat,
            CurrentSeat = currentSeat ?? source.CurrentSeat,
            WallCount = wallCount ?? source.WallCount,
            TurnIndex = source.TurnIndex,
            Phase = source.Phase,
            RoundIndex = source.RoundIndex,
            TotalRounds = source.TotalRounds,
            RemainingRounds = source.RemainingRounds,
            VisibleVersion = source.VisibleVersion,
            HandVersion = source.HandVersion,
            StrategyContextVersion = source.StrategyContextVersion,
            Scores = (int[])source.Scores.Clone(),
            DingQueSuits = (int[])source.DingQueSuits.Clone(),
            HandCounts = (int[])source.HandCounts.Clone(),
            WonScores = (int[])source.WonScores.Clone(),
            LockedFans = (int[])source.LockedFans.Clone(),
            LockTurns = (int[])source.LockTurns.Clone(),
            UnlockOnOwnDraw = (bool[])source.UnlockOnOwnDraw.Clone(),
            ActiveSeats = (bool[])source.ActiveSeats.Clone(),
            EventVersion = source.EventVersion,
            InformationMode = source.InformationMode,
            PolicyVariant = source.PolicyVariant,
            ExchangeThreeEnabled = source.ExchangeThreeEnabled,
            Hand18 = (int[])(hand ?? source.Hand18).Clone(),
            Visible18 = (int[])source.Visible18.Clone(),
            Remaining18 = (int[])source.Remaining18.Clone(),
            Discards18 = source.Discards18.Select(a => new List<int>(a)).ToArray(),
            Melds18 = source.Melds18.Select(a => new List<int>(a)).ToArray(),
            IsCalled = (bool[])source.IsCalled.Clone(),
            IsReady = (bool[])source.IsReady.Clone(),
            HasHu = (bool[])source.HasHu.Clone(),
            OwnDrawReason = source.OwnDrawReason,
            LastGangSourceSeat = source.LastGangSourceSeat,
            LastDrawTileType = source.LastDrawTileType,
            LastDrawOrigin = source.LastDrawOrigin,
            LastGangSeat = source.LastGangSeat,
            LastGangTileType = source.LastGangTileType,
            LastGangType = source.LastGangType,
            LastGangScoreEligible = source.LastGangScoreEligible,
            PendingAddedGangScoreEligible = source.PendingAddedGangScoreEligible,
            PassedHu18 = source.PassedHu18.Select(a => (int[])a.Clone()).ToArray(),
            PassedPeng18 = source.PassedPeng18.Select(a => (int[])a.Clone()).ToArray(),
            PassedGang18 = source.PassedGang18.Select(a => (int[])a.Clone()).ToArray(),
        };
        result.PublicEvents.AddRange(source.PublicEvents);
        for (var seat = 0; seat < 4; seat++) result.MeldViews[seat].AddRange(source.MeldViews[seat]);
        return result;
    }

    public static SichuanStateView Continuation(SichuanStateView source, int[] hand,
        IReadOnlyList<SichuanMeldView> melds, int wallCount, double? gangCash = null)
    {
        if(hand.SequenceEqual(source.Hand18) && wallCount==source.WallCount
            && melds.SequenceEqual(source.MeldViews[source.SeatIndex])) return Copy(source);
        var result = Copy(source, hand, wallCount, source.SeatIndex);
        var own = source.SeatIndex;
        var oldExposed = new int[27];
        foreach (var t in source.Melds18[own]) oldExposed[t]++;
        if (source.MeldViews[own].Count > 0)
        {
            Array.Clear(oldExposed);
            foreach (var m in source.MeldViews[own]) oldExposed[m.TileType] += m.Type == SichuanMeldType.Peng ? 3 : 4;
        }
        var newExposed = new int[27];
        foreach (var m in melds) newExposed[m.TileType] += m.Type == SichuanMeldType.Peng ? 3 : 4;
        var claimed=melds.FirstOrDefault(m=>m.SourceSeat is >=0 and <4 && m.SourceSeat!=own
            && m.Type is SichuanMeldType.Peng or SichuanMeldType.MeldedGang
            && !source.MeldViews[own].Any(old=>old.Type==m.Type && old.TileType==m.TileType));
        if(claimed is not null)
        {
            var index=result.Discards18[claimed.SourceSeat].LastIndexOf(claimed.TileType);
            if(index>=0) result.Discards18[claimed.SourceSeat].RemoveAt(index);
        }
        var draw = -1;
        for (var t = 0; t < 27; t++)
        {
            var incoming=claimed?.TileType==t?1:0;
            result.Visible18[t] += newExposed[t] - oldExposed[t] - incoming;
            var newlyKnown = Math.Max(0, hand[t] + newExposed[t] - source.Hand18[t] - oldExposed[t] - incoming);
            result.Remaining18[t] = Math.Max(0, source.Remaining18[t] - newlyKnown);
            if (newlyKnown > 0) draw = t;
        }
        result.MeldViews[own].Clear(); result.MeldViews[own].AddRange(melds);
        result.Melds18[own].Clear();
        foreach (var m in melds) result.Melds18[own].AddRange(Enumerable.Repeat(m.TileType, m.Type == SichuanMeldType.Peng ? 3 : 4));
        result.HandCounts[own] = hand.Sum(); result.Phase = 5;
        if (draw >= 0)
        {
            result.LastDrawTileType = draw; result.LastDrawOrigin = SichuanTileOrigin.Draw;
            result.OwnDrawReason = gangCash.HasValue ? "gang_draw" : "normal_draw";
        }
        if (gangCash.HasValue)
        {
            var changed = melds.FirstOrDefault(m => !source.MeldViews[own].Any(old => old.Type == m.Type && old.TileType == m.TileType));
            if (changed is not null)
            {
                result.LastGangSeat = own; result.LastGangTileType = changed.TileType;
                result.LastGangSourceSeat = changed.SourceSeat;
                result.LastGangType = changed.Type == SichuanMeldType.ConcealedGang ? "an_gang" : changed.Type == SichuanMeldType.AddedGang ? "add_gang" : "melded_gang";
                result.LastGangScoreEligible = gangCash.Value > 0;
                var payers=Enumerable.Range(0,4).Where(seat=>seat!=own && source.ActiveSeats[seat] && !source.HasHu[seat]).ToArray();
                var deltas=new Rules.SichuanSettlementProjectionEngine().ProjectScenario(new(
                    GangEvents:new[]{new Rules.SichuanGangScoreEvent(own,changed.Type,payers,
                        SourceSeat:changed.SourceSeat,ScoreEligible:result.LastGangScoreEligible)},IsRoundResolved:false)).ScoreChanges;
                for(var seat=0;seat<4;seat++) result.Scores[seat]+=deltas[seat];
                result.EventVersion++;
                var eventType=changed.Type==SichuanMeldType.ConcealedGang?SichuanPublicEventType.ConcealedGang
                    :changed.Type==SichuanMeldType.AddedGang?SichuanPublicEventType.AddedGang:SichuanPublicEventType.MeldedGang;
                result.PublicEvents.Add(new(result.EventVersion,source.TurnIndex,own,eventType,changed.TileType,
                    SourceSeat:changed.SourceSeat,WallCountAfter:source.WallCount,GangScoreEligible:result.LastGangScoreEligible));
            }
        }
        if(draw>=0)
        {
            result.EventVersion++;
            result.PublicEvents.Add(new(result.EventVersion,source.TurnIndex,own,SichuanPublicEventType.Draw,draw,
                SichuanTileOrigin.Draw,WallCountAfter:wallCount));
        }
        return result;
    }

    public static SichuanStateView AfterDiscard(SichuanStateView source, int tile)
    {
        var hand=(int[])source.Hand18.Clone(); hand[tile]--;
        var result=Copy(source,hand); result.Visible18[tile]++;
        result.Discards18[source.SeatIndex].Add(tile); result.HandCounts[source.SeatIndex]=hand.Sum();
        result.TurnIndex++; result.EventVersion++;
        result.PublicEvents.Add(new(result.EventVersion,result.TurnIndex,source.SeatIndex,SichuanPublicEventType.Discard,tile,
            tile==source.LastDrawTileType?SichuanTileOrigin.Draw:SichuanTileOrigin.Hand,WallCountAfter:source.WallCount));
        return result;
    }

    public static SichuanStateView AfterOwnDraw(SichuanStateView source, int[] hand, int draw, int wallCount)
    {
        var result=Copy(source,hand,Math.Max(0,wallCount),source.SeatIndex);
        result.Remaining18[draw]=Math.Max(0,result.Remaining18[draw]-1);
        result.LastDrawTileType=draw;result.LastDrawOrigin=SichuanTileOrigin.Draw;result.OwnDrawReason="normal_draw";
        result.Phase=5;result.HandCounts[source.SeatIndex]=hand.Sum();result.EventVersion++;
        result.LockedFans[source.SeatIndex]=-1;result.LockTurns[source.SeatIndex]=-1;result.UnlockOnOwnDraw[source.SeatIndex]=false;
        Array.Clear(result.PassedHu18[source.SeatIndex]); Array.Clear(result.PassedPeng18[source.SeatIndex]);Array.Clear(result.PassedGang18[source.SeatIndex]);
        for(var i=0;i<result.MeldViews[source.SeatIndex].Count;i++) result.MeldViews[source.SeatIndex][i]=result.MeldViews[source.SeatIndex][i] with {AddedGangBlockedUntilOwnDraw=false};
        result.PublicEvents.Add(new(result.EventVersion,source.TurnIndex,source.SeatIndex,SichuanPublicEventType.Draw,draw,
            SichuanTileOrigin.Draw,WallCountAfter:result.WallCount));
        return result;
    }
}
