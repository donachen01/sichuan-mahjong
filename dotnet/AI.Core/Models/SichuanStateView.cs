namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanStateView
{
    public int SeatIndex { get; init; }
    public int DealerSeat { get; init; }
    public int CurrentSeat { get; init; }
    public int WallCount { get; init; }
    public int TurnIndex { get; init; }
    public int Phase { get; init; }
    public int RoundIndex { get; set; }
    public int TotalRounds { get; set; }
    public int RemainingRounds { get; set; }
    public int VisibleVersion { get; set; }
    public int HandVersion { get; set; }
    public int StrategyContextVersion { get; set; }
    public int[] Scores { get; set; } = new int[4];
    public int[] DingQueSuits { get; set; } = Enumerable.Repeat(-1, 4).ToArray();

    public int OwnDingQueSuit => SeatIndex is >= 0 and < 4 ? DingQueSuits[SeatIndex] : -1;

    public int[] Hand18 { get; init; } = new int[27];
    public int[] Visible18 { get; init; } = new int[27];
    public int[] Remaining18 { get; init; } = Enumerable.Repeat(4, 27).ToArray();

    public List<int>[] Discards18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new List<int>()).ToArray();
    public List<int>[] Melds18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new List<int>()).ToArray();

    public bool[] IsCalled { get; init; } = new bool[4];
    public bool[] IsReady { get; init; } = new bool[4];
    public bool[] HasHu { get; init; } = new bool[4];
    public int LastDrawTileType { get; set; } = -1;
    public int[][] PassedHu18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    public int[][] PassedPeng18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    public int[][] PassedGang18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
}
