using SichuanMahjong.AI.Core.Domain;

namespace SichuanMahjong.AI.Core.Rules;

/// <summary>Reconstructs refundable, already-paid Gang from public events only.</summary>
public static class SichuanPublicGangRefunds
{
    public static IReadOnlyList<SichuanGangRefundEvent> Build(
        IReadOnlyList<SichuanPublicEvent> observedEvents,IReadOnlyList<SichuanDrawAssessment> assessments)
    {
            var exited = new HashSet<int>();
            var gangs = new List<SichuanGangScoreEvent>();
            var transferred = new HashSet<int>();
            SichuanPublicEvent? preceding = null;
            var pendingGang = -1; var pendingSource = -1; var pendingTile = -1;
            foreach (var e in observedEvents)
            {
                if (e.Type is SichuanPublicEventType.Draw or SichuanPublicEventType.Pass) continue;
                if (e.Type == SichuanPublicEventType.Hu)
                {
                    exited.Add(e.Seat);
                    if (e.SourceSeat == pendingSource && e.TileType == pendingTile && pendingGang >= 0)
                        transferred.Add(pendingGang);
                    continue;
                }
                if (e.Type == SichuanPublicEventType.Discard)
                {
                    pendingGang = preceding?.Seat == e.Seat && preceding.Type is
                        SichuanPublicEventType.AddedGang or SichuanPublicEventType.ConcealedGang or SichuanPublicEventType.MeldedGang
                        ? gangs.Count - 1 : -1;
                    pendingSource = e.Seat; pendingTile = e.TileType;
                }
                if (e.Type is SichuanPublicEventType.AddedGang or SichuanPublicEventType.ConcealedGang or SichuanPublicEventType.MeldedGang)
                {
                    var kind = e.Type == SichuanPublicEventType.AddedGang ? SichuanMeldType.AddedGang
                        : e.Type == SichuanPublicEventType.ConcealedGang ? SichuanMeldType.ConcealedGang : SichuanMeldType.MeldedGang;
                    gangs.Add(new(e.Seat, kind, Enumerable.Range(0, 4).Where(s => s != e.Seat && !exited.Contains(s)).ToArray(),
                        SourceSeat: e.SourceSeat, ScoreEligible: e.GangScoreEligible));
                }
                preceding = e;
            }
            return gangs.Where((g, i) => g.ScoreEligible && !transferred.Contains(i)
                    && assessments.Any(a => a.Seat == g.ActorSeat && !a.HasWon && (!a.IsTing || a.IsHuaZhu)))
                .Select(g => new SichuanGangRefundEvent(g.ActorSeat, g.GangType, g.PayerSeats, g.SourceSeat)).ToArray();
    }
}
