namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanEvidenceSnapshot
{
    public HashSet<int>[] SeatExactSafeTiles { get; init; } = Enumerable.Range(0, 4).Select(_ => new HashSet<int>()).ToArray();
    public double[][] SeatNoHuEvidence { get; init; } = Enumerable.Range(0, 4).Select(_ => new double[27]).ToArray();
    public double[][] SeatNoPengEvidence { get; init; } = Enumerable.Range(0, 4).Select(_ => new double[27]).ToArray();
    public double[][] SeatNoGangEvidence { get; init; } = Enumerable.Range(0, 4).Select(_ => new double[27]).ToArray();
    public double[][] SeatAbandonedSuitEvidence { get; init; } = Enumerable.Range(0, 4).Select(_ => new double[3]).ToArray();
    public IReadOnlyList<int>[] SeatRecentDiscardTrend { get; init; } = Enumerable.Range(0, 4).Select(_ => (IReadOnlyList<int>)Array.Empty<int>()).ToArray();
}
