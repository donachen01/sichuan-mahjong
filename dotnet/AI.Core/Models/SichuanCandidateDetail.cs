namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanCandidateDetail
{
    public int TileType { get; init; }
    public int FastTingDiscardRank { get; init; }
    public int Score { get; init; }
    public int Shanten { get; init; }
    public int Ukeire { get; init; }
    public int LiveUkeire { get; init; }
    public int Danger { get; init; }
    public int WaitCount { get; init; }
    public int WaitQualityScore { get; init; }
    public IReadOnlyList<int> ImprovingTiles { get; init; } = Array.Empty<int>();
    public string RiskLabel { get; init; } = string.Empty;
    public string StrategyTag { get; init; } = string.Empty;
    public string StrategyMode { get; init; } = string.Empty;
    public string ExplanationHint { get; init; } = string.Empty;
    public string RoutePlanPrimary { get; init; } = string.Empty;
    public int RoutePlanScore { get; init; }
    public IReadOnlyList<string> RoutesAfter { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> RouteLoss { get; init; } = Array.Empty<string>();
    public double TenpaiProbability { get; init; }
    public double SelfDrawProbability { get; init; }
    public double WinProbability { get; init; }
    public double ExpectedFan { get; init; }
    public double DealInProbability { get; init; }
    public double ExpectedValue { get; init; }
    public double ExpectedNetScore { get; init; }
    public double ExpectedWinGain { get; init; }
    public double ExpectedDealInLoss { get; init; }
    public double ExpectedDrawRiskLoss { get; init; }
    public double ExpectedReadyValue { get; init; }
    public double PosteriorAdjustment { get; init; }
    public double DefenseAdjustment { get; init; }
    public int GoodShapeCount { get; init; }
    public int BadShapeCount { get; init; }
    public int PairPressure { get; init; }
    public int TaatsuOverflow { get; init; }
    public int SameShantenImprovementCount { get; init; }
    public int MiddleTileFlexibility { get; init; }
    public double ShapeScore { get; init; }
    public bool BreaksPair { get; init; }
    public bool BreaksTriplet { get; init; }
    public double SetPreservationScore { get; init; }
    public string WaitShapeLabel { get; init; } = string.Empty;
    public double WaitShapeScore { get; init; }
    public int RyanmenWaitCount { get; init; }
    public int KanchanWaitCount { get; init; }
    public int PenchanWaitCount { get; init; }
    public int TankiWaitCount { get; init; }
    public int ShanponWaitCount { get; init; }
    public double LimitedLookaheadScore { get; init; }
    public int LimitedLookaheadSamples { get; init; }
    public int LimitedLookaheadBestShanten { get; init; }
    public int LimitedLookaheadBestLiveUkeire { get; init; }
    public double SearchBonus { get; init; }
    public int SearchSimulations { get; init; }
    public bool SearchUsed { get; init; }
    public IReadOnlyList<string> PosteriorReasons { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> RiskReasons { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> Reasons { get; init; } = Array.Empty<string>();
}
