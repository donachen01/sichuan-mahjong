namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanAiContext
{
    public SichuanStageContext Stage { get; set; } = new();
    public SichuanRoundGoalContext RoundGoal { get; set; } = new();
    public SichuanStrategyModeContext StrategyMode { get; set; } = new();
    public SichuanHandAnalysis HandAnalysis { get; set; } = new();
    public SichuanAttackEligibility AttackEligibility { get; set; } = new();
    public IReadOnlyDictionary<int, SichuanOpponentDangerProfile> OpponentDangerProfiles { get; set; }
        = new Dictionary<int, SichuanOpponentDangerProfile>();
    public IReadOnlyDictionary<int, SichuanTileDangerProfile> TileDangerMap { get; set; }
        = new Dictionary<int, SichuanTileDangerProfile>();
    public SichuanScoreSituation ScoreSituation { get; set; } = new();
    public SichuanRiskTolerance RiskTolerance { get; set; } = new();
    public int UpdatedAtTurn { get; set; }
    public SichuanAiContextDirtyFlags DirtyFlags { get; set; } = new();
    public IReadOnlyList<SichuanModulePerfSample> ModulePerf { get; set; } = Array.Empty<SichuanModulePerfSample>();
    public IReadOnlyList<string> ReasonCodes { get; set; } = Array.Empty<string>();
}

public sealed class SichuanStageContext
{
    public string Stage { get; set; } = "early";
    public int StageIndex { get; set; }
    public string ReasonCode { get; set; } = "STAGE_EARLY_DEFAULT";
    public int WallCount { get; set; }
    public int MaxDiscardCount { get; set; }
    public int ExposedMeldCount { get; set; }
    public bool HasLikelyReadyOpponent { get; set; }
    public bool RiskRaised { get; set; }
}

public sealed class SichuanRoundGoalContext
{
    public string Goal { get; set; } = "balanced";
    public string ReasonCode { get; set; } = "ROUND_GOAL_BALANCED";
}

public sealed class SichuanStrategyModeContext
{
    public string Mode { get; set; } = "balanced";
    public string PreviousMode { get; set; } = "";
    public string ReasonCode { get; set; } = "MODE_BALANCED_DEFAULT";
    public bool Changed { get; set; }
}

public sealed class SichuanHandAnalysis
{
    public string HandKey { get; set; } = "";
    public int Shanten { get; set; } = 8;
    public int TaatsuCount { get; set; }
    public int PairCount { get; set; }
    public int IsolatedCount { get; set; }
    public int UkeireCount { get; set; }
    public int LiveUkeireCount { get; set; }
    public bool DingQueClear { get; set; } = true;
    public int BigHandPotential { get; set; }
    public int HighRiskWasteCount { get; set; }
    public int HandQuality { get; set; }
    public string ReasonCode { get; set; } = "HAND_UNKNOWN";
    public double ElapsedMs { get; set; }
}

public sealed class SichuanAttackEligibility
{
    public string Level { get; set; } = "balanced";
    public string ReasonCode { get; set; } = "ATTACK_BALANCED_DEFAULT";
    public int Score { get; set; }
}

public sealed class SichuanOpponentDangerProfile
{
    public int Seat { get; set; }
    public int DangerLevel { get; set; }
    public bool LikelyReady { get; set; }
    public int LikelyMissingSuit { get; set; } = -1;
    public int BigHandRisk { get; set; }
    public int ExposedMeldCount { get; set; }
    public IReadOnlyList<string> DangerReasonCodes { get; set; } = Array.Empty<string>();
}

public sealed class SichuanTileDangerProfile
{
    public int TileType { get; set; }
    public string Level { get; set; } = "low";
    public int MaxDangerScore { get; set; }
    public int TopThreatSeat { get; set; } = -1;
    public IReadOnlyDictionary<int, SichuanSeatTileDanger> ByOpponent { get; set; }
        = new Dictionary<int, SichuanSeatTileDanger>();
    public IReadOnlyList<string> ReasonCodes { get; set; } = Array.Empty<string>();
}

public sealed class SichuanSeatTileDanger
{
    public int Seat { get; set; }
    public int Score { get; set; }
    public string Level { get; set; } = "low";
    public IReadOnlyList<string> ReasonCodes { get; set; } = Array.Empty<string>();
}

public sealed class SichuanScoreSituation
{
    public int SelfScore { get; set; }
    public int LeaderScore { get; set; }
    public int Rank { get; set; } = 1;
    public int GapToLeader { get; set; }
    public int GapToNext { get; set; }
    public string Situation { get; set; } = "close";
}

public sealed class SichuanRiskTolerance
{
    public int Value { get; set; } = 50;
    public string ReasonCode { get; set; } = "RISK_BALANCED";
}

public sealed class SichuanAiContextDirtyFlags
{
    public bool Stage { get; set; }
    public bool RoundGoal { get; set; }
    public bool StrategyMode { get; set; }
    public bool HandAnalysis { get; set; }
    public bool OpponentDanger { get; set; }
    public bool TileDanger { get; set; }
    public bool ScoreSituation { get; set; }
}

public sealed class SichuanDealInPolicy
{
    public int TileType { get; set; }
    public int AdjustmentScore { get; set; }
    public bool AllowSmallDealInRisk { get; set; }
    public bool BlockBigHandDealIn { get; set; }
    public string ReasonCode { get; set; } = "DEAL_IN_NEUTRAL";
}

public sealed class SichuanDecisionExplain
{
    public string Mode { get; set; } = "normal";
    public string Action { get; set; } = "discard";
    public int TileType { get; set; } = -1;
    public int Score { get; set; }
    public string StrategyMode { get; set; } = "balanced";
    public IReadOnlyList<string> ReasonCodes { get; set; } = Array.Empty<string>();
}

public sealed class SichuanDecisionPerformanceReport
{
    public double TotalMs { get; set; }
    public double MaxModuleMs { get; set; }
    public bool Warning { get; set; }
    public IReadOnlyList<string> WarningCodes { get; set; } = Array.Empty<string>();
    public IReadOnlyList<SichuanModulePerfSample> Modules { get; set; } = Array.Empty<SichuanModulePerfSample>();
}

public sealed class SichuanModulePerfSample
{
    public string Module { get; set; } = "";
    public double ElapsedMs { get; set; }
    public bool Warning { get; set; }
}
