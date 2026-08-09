namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanHandShapeSummary
{
    public int GoodShapeCount { get; init; }
    public int BadShapeCount { get; init; }
    public int PairPressure { get; init; }
    public int TaatsuOverflow { get; init; }
    public int SameShantenImprovementCount { get; init; }
    public int MiddleTileFlexibility { get; init; }
    public int BestBlockCount { get; init; }
    public int AlternativeDecompositionCount { get; init; }
    public double ShapeScore { get; init; }
    public IReadOnlyList<string> Reasons { get; init; } = Array.Empty<string>();
}
