namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanHellOracleResult
{
    public string DecisionType { get; init; } = "discard";
    public SichuanAction Action { get; init; } = new(SichuanActionType.Pass);
    public string Category { get; init; } = "same_action";
    public string Severity { get; init; } = "none";
    public bool ExactDealIn { get; init; }
    public bool FairExactDealIn { get; init; }
    public bool OracleExactDealIn { get; init; }
    public bool FairFeedsHumanHu { get; init; }
    public bool OracleFeedsHumanHu { get; init; }
    public bool FairFeedsHumanPeng { get; init; }
    public bool OracleFeedsHumanPeng { get; init; }
    public bool FairFeedsHumanGang { get; init; }
    public bool OracleFeedsHumanGang { get; init; }
    public int HumanPressureLevel { get; init; } = 1;
    public IReadOnlyList<int> FairDealInTargetSeats { get; init; } = Array.Empty<int>();
    public IReadOnlyList<int> OracleDealInTargetSeats { get; init; } = Array.Empty<int>();
    public bool ExactKeepsReady { get; init; }
    public int ExactWallRemaining { get; init; }
    public int SelectedShanten { get; init; }
    public int SelectedLiveUkeire { get; init; }
    public int SelectedWaitCount { get; init; }
    public string SelectedTier { get; init; } = "";
    public int FairTileType { get; init; } = -1;
    public int ActualTileType { get; init; } = -1;
    public string TeamRole { get; init; } = "";
    public int TeamPressureBonus { get; init; }
    public IReadOnlyList<string> TeamPlanSummary { get; init; } = Array.Empty<string>();
    public IReadOnlyList<SichuanHellChallengeCandidate> Candidates { get; init; } = Array.Empty<SichuanHellChallengeCandidate>();
    public IReadOnlyList<string> Reasons { get; init; } = Array.Empty<string>();
}

public sealed class SichuanHellChallengeCandidate
{
    public int TileType { get; init; }
    public int Score { get; init; }
    public int Shanten { get; init; }
    public int LiveUkeire { get; init; }
    public int WaitCount { get; init; }
    public bool ExactDealIn { get; init; }
    public bool FeedsHumanHu { get; init; }
    public bool FeedsHumanPeng { get; init; }
    public bool FeedsHumanGang { get; init; }
    public int HumanPengThreat { get; init; }
    public int HumanPengPenalty { get; init; }
    public int TempoPengAllowanceBonus { get; init; }
    public int PengOnlyInteractionBonus { get; init; }
    public bool KeepsReady { get; init; }
    public int ExactWallRemaining { get; init; }
    public string Tier { get; init; } = "";
    public int TierRank { get; init; }
    public int TierAdjustment { get; init; }
    public IReadOnlyList<int> DealInTargetSeats { get; init; } = Array.Empty<int>();
    public IReadOnlyList<string> Reasons { get; init; } = Array.Empty<string>();
}
