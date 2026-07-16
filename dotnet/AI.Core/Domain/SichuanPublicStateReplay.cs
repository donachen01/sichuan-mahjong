namespace SichuanMahjong.AI.Core.Domain;

public sealed record SichuanReplayedPublicState(
    int[] Visible27,
    List<int>[] Discards,
    List<SichuanMeldView>[] Melds,
    int[] HandCounts,
    bool[] ActiveSeats,
    int[][] PassedHu27,
    int[][] PassedPeng27,
    int[][] PassedGang27,
    int WallCount,
    long EventVersion);

public sealed class SichuanPublicStateReplay
{
    public SichuanReplayedPublicState Replay(IReadOnlyList<int> initialHandCounts, IEnumerable<SichuanPublicEvent> events)
    {
        var visible = new int[27];
        var discards = Enumerable.Range(0, 4).Select(_ => new List<int>()).ToArray();
        var melds = Enumerable.Range(0, 4).Select(_ => new List<SichuanMeldView>()).ToArray();
        var handCounts = initialHandCounts.Take(4).Concat(Enumerable.Repeat(13, 4)).Take(4).ToArray();
        var active = Enumerable.Repeat(true, 4).ToArray();
        var passedHu = CountMatrix();
        var passedPeng = CountMatrix();
        var passedGang = CountMatrix();
        var wallCount = -1;
        long eventVersion = 0;

        foreach (var item in events.OrderBy(item => item.EventIndex))
        {
            if (item.Seat is < 0 or >= 4) continue;
            eventVersion = Math.Max(eventVersion, item.EventIndex);
            if (item.WallCountAfter >= 0) wallCount = item.WallCountAfter;
            var tile = item.TileType;
            switch (item.Type)
            {
                case SichuanPublicEventType.Draw:
                    handCounts[item.Seat]++;
                    break;
                case SichuanPublicEventType.Discard:
                    handCounts[item.Seat]--;
                    AddVisible(visible, tile, 1);
                    if (tile is >= 0 and < 27) discards[item.Seat].Add(tile);
                    break;
                case SichuanPublicEventType.Peng:
                    handCounts[item.Seat] -= 2;
                    AddVisible(visible, tile, 2);
                    ConsumeDiscard(discards, item.SourceSeat, tile);
                    AddMeld(melds, item, SichuanMeldType.Peng);
                    break;
                case SichuanPublicEventType.MeldedGang:
                    handCounts[item.Seat] -= 3;
                    AddVisible(visible, tile, 3);
                    ConsumeDiscard(discards, item.SourceSeat, tile);
                    AddMeld(melds, item, SichuanMeldType.MeldedGang);
                    break;
                case SichuanPublicEventType.ConcealedGang:
                    handCounts[item.Seat] -= 4;
                    AddVisible(visible, tile, 4);
                    AddMeld(melds, item, SichuanMeldType.ConcealedGang);
                    break;
                case SichuanPublicEventType.AddedGang:
                    handCounts[item.Seat]--;
                    AddVisible(visible, tile, 1);
                    UpgradeMeld(melds[item.Seat], item);
                    break;
                case SichuanPublicEventType.Hu:
                    active[item.Seat] = false;
                    break;
                case SichuanPublicEventType.Pass:
                    if (tile is >= 0 and < 27)
                    {
                        if (item.CanHu) passedHu[item.Seat][tile]++;
                        if (item.CanPeng) passedPeng[item.Seat][tile]++;
                        if (item.CanGang) passedGang[item.Seat][tile]++;
                    }
                    break;
            }
            handCounts[item.Seat] = Math.Max(0, handCounts[item.Seat]);
        }

        return new SichuanReplayedPublicState(
            visible, discards, melds, handCounts, active,
            passedHu, passedPeng, passedGang, wallCount, eventVersion);
    }

    private static int[][] CountMatrix() => Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();

    private static void AddVisible(int[] visible, int tile, int count)
    {
        if (tile is >= 0 and < 27) visible[tile] = Math.Min(4, visible[tile] + count);
    }

    private static void ConsumeDiscard(IReadOnlyList<List<int>> discards, int sourceSeat, int tile)
    {
        if (sourceSeat is < 0 or >= 4 || tile is < 0 or >= 27) return;
        var index = discards[sourceSeat].LastIndexOf(tile);
        if (index >= 0) discards[sourceSeat].RemoveAt(index);
    }

    private static void AddMeld(IReadOnlyList<List<SichuanMeldView>> melds, SichuanPublicEvent item, SichuanMeldType type)
    {
        if (item.TileType is >= 0 and < 27)
            melds[item.Seat].Add(new SichuanMeldView(type, item.TileType, item.SourceSeat, item.EventIndex));
    }

    private static void UpgradeMeld(List<SichuanMeldView> melds, SichuanPublicEvent item)
    {
        var index = melds.FindLastIndex(meld => meld.TileType == item.TileType && meld.Type == SichuanMeldType.Peng);
        if (index >= 0)
            melds[index] = new SichuanMeldView(SichuanMeldType.AddedGang, item.TileType, melds[index].SourceSeat, item.EventIndex);
        else
            melds.Add(new SichuanMeldView(SichuanMeldType.AddedGang, item.TileType, item.SourceSeat, item.EventIndex));
    }
}
