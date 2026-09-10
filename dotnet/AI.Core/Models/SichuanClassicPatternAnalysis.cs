namespace SichuanMahjong.AI.Core.Models;

public sealed record SichuanClassicPatternAnalysis(
    int Type,
    string Label,
    int Shanten,
    int EffectivePairCount,
    int RawPairCount,
    int TaatsuCount,
    int SingleCount,
    bool HasApparentPairOnly,
    bool HasTwoPairsAndHalf,
    IReadOnlyList<int> PairTiles,
    IReadOnlyList<int> SingleTiles);
