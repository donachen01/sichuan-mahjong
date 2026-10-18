namespace SichuanMahjong.AI.Core.Models;

using SichuanMahjong.AI.Core.Domain;

public sealed class SichuanStateView
{
    public string RoundId { get; set; } = string.Empty;
    public long HostGeneration { get; set; }
    public long ViewVersion { get; set; }
    public int SeatIndex { get; init; }
    public int DealerSeat { get; init; }
    public int CurrentSeat { get; init; }
    public int WallCount { get; init; }
    public int TurnIndex { get; set; }
    public int Phase { get; set; }
    public int RoundIndex { get; set; }
    public int TotalRounds { get; set; }
    public int RemainingRounds { get; set; }
    public int VisibleVersion { get; set; }
    public int HandVersion { get; set; }
    public int StrategyContextVersion { get; set; }
    public int[] Scores { get; set; } = new int[4];
    public int[] DingQueSuits { get; set; } = Enumerable.Repeat(-1, 4).ToArray();
	public int[] HandCounts { get; set; } = new[] { 13, 13, 13, 13 };
    // Historical public Hu price; it creates no later cha-jiao entitlement.
    // -1 means the transport did not supply this public fact.
    public int[] WonScores { get; set; } = Enumerable.Repeat(-1, 4).ToArray();
	public int[] LockedFans { get; set; } = Enumerable.Repeat(-1, 4).ToArray();
	public int[] LockTurns { get; set; } = Enumerable.Repeat(-1, 4).ToArray();
	public bool[] UnlockOnOwnDraw { get; set; } = new bool[4];
	public bool[] ActiveSeats { get; set; } = Enumerable.Repeat(true, 4).ToArray();
	public long EventVersion { get; set; }
	public string InformationMode { get; set; } = "public";
	public string PolicyVariant { get; set; } = "current";
	public bool ExchangeThreeEnabled { get; set; }
	public List<SichuanPublicEvent> PublicEvents { get; } = new();
	public List<SichuanMeldView>[] MeldViews { get; } = Enumerable.Range(0, 4).Select(_ => new List<SichuanMeldView>()).ToArray();

    public int MeldCount(int seat) => MeldViews[seat].Count > 0 ? MeldViews[seat].Count
        : Melds18[seat].GroupBy(t => t).Sum(g => g.Count() / 3);

    public int OwnMeldCount => MeldCount(SeatIndex);

    public int OwnDingQueSuit => SeatIndex is >= 0 and < 4 ? DingQueSuits[SeatIndex] : -1;

    public int[] Hand18 { get; init; } = new int[27];
    public int[] Visible18 { get; init; } = new int[27];
    public int[] Remaining18 { get; init; } = Enumerable.Repeat(4, 27).ToArray();

    public List<int>[] Discards18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new List<int>()).ToArray();
    public List<int>[] Melds18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new List<int>()).ToArray();

    public bool[] IsCalled { get; init; } = new bool[4];
    public bool[] IsReady { get; init; } = new bool[4];
    public bool[] HasHu { get; init; } = new bool[4];
    public string OwnDrawReason { get; set; } = string.Empty;
    public int LastGangSourceSeat { get; set; } = -1;
    public int LastDrawTileType { get; set; } = -1;
	public SichuanTileOrigin LastDrawOrigin { get; set; } = SichuanTileOrigin.Unknown;
	public int LastGangSeat { get; set; } = -1;
	public int LastGangTileType { get; set; } = -1;
	public string LastGangType { get; set; } = string.Empty;
	public bool LastGangScoreEligible { get; set; } = true;
    public bool? PendingAddedGangScoreEligible { get; set; }
    public int[][] PassedHu18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    public int[][] PassedPeng18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
    public int[][] PassedGang18 { get; init; } = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
}
