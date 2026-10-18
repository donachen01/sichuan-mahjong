using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanRootWeightedWaitComparison(
    double BeforeWeightedCopies,
    double AfterWeightedCopies,
    double Delta,
    double BeforeRootCopies,
    double AfterRootCopies,
    double BeforeNonRootCopies,
    double AfterNonRootCopies)
{
    public bool Improves => Delta > 1e-9;
    public bool AddsRootWait => AfterRootCopies > BeforeRootCopies + 1e-9;
}

/// <summary>
/// Source-derived 4.3 signal for a ready-hand wait swap.  It is deliberately
/// separate from exact fan/settlement pricing: root=2 and ordinary=1 is a
/// structural heuristic, while project action ranking still keeps real score,
/// cap, safety and payer effects.
/// </summary>
public static class SichuanRootWeightedWaitPolicy
{
    public static SichuanRootWeightedWaitComparison Compare(
        SichuanReadyPrice? before, SichuanReadyPrice? after)
    {
        var beforeWeighted = before?.RootWeightedDrawableMass ?? 0.0;
        var afterWeighted = after?.RootWeightedDrawableMass ?? 0.0;
        return new(
            beforeWeighted,
            afterWeighted,
            afterWeighted - beforeWeighted,
            before?.RootDrawableMass ?? 0.0,
            after?.RootDrawableMass ?? 0.0,
            before?.NonRootDrawableMass ?? 0.0,
            after?.NonRootDrawableMass ?? 0.0);
    }
}
