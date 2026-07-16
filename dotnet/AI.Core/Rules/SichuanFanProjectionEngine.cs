using SichuanMahjong.AI.Core.Domain;

namespace SichuanMahjong.AI.Core.Rules;

public enum SichuanWinType { Discard, SelfDraw, GangSelfDraw, GangDiscard, RobAddedGang }

public sealed record SichuanFanProjection(
    string HandType,
    int BaseFan,
    int GenCount,
    int UncappedFan,
    int CappedFan,
    int HandScore,
    int PerPayerScore,
    IReadOnlyList<string> Labels,
    IReadOnlyList<string> QualifyingPatterns,
    bool IsQingYiSe,
    bool IsSevenPairs,
    bool IsDragonSevenPairs,
    bool IsDaDuiZi,
    bool IsJinGouDiao);

public sealed class SichuanFanProjectionEngine
{
    private readonly SichuanExactHandAnalyzer _analyzer = new();

    public SichuanFanProjection Project(
        IReadOnlyList<int> concealed27,
        IReadOnlyList<SichuanMeldView> melds,
        SichuanWinType winType,
        SichuanRuleSnapshot? rules = null)
    {
        rules ??= SichuanRuleSnapshot.Frozen;
        var hand = Normalize(concealed27);
        var decompositions = _analyzer.EnumerateWinningDecompositions(hand, melds.Count, rules.AllowSevenPairs);
        var isSevenPairs = decompositions.Any(item => item.IsSevenPairs);
        var allTiles = (int[])hand.Clone();
        foreach (var meld in melds)
            allTiles[meld.TileType] += meld.Type == SichuanMeldType.Peng ? 3 : 4;
        var suits = Enumerable.Range(0, 27).Where(tile => allTiles[tile] > 0).Select(tile => tile / 9).Distinct().ToArray();
        var isQing = suits.Length == 1;
        var isDaDuiZi = decompositions.Any(item => !item.IsSevenPairs && item.Groups.All(group => group.Type != SichuanGroupType.Sequence));
        var isJinGouDiao = melds.Count == 4 && hand.Sum() == 2;
        var genCount = allTiles.Sum(count => count / 4);
        var isDragonSevenPairs = isSevenPairs && genCount > 0;

        var handType = isQing ? "qing_yi_se" : isSevenPairs ? "qi_dui" : isDaDuiZi ? "da_dui_zi" : "ping_hu";
        var baseFan = handType switch { "qing_yi_se" => 4, "qi_dui" => 4, "da_dui_zi" => 2, _ => 1 };
        var multiplier = 1;
        if (winType is SichuanWinType.GangSelfDraw or SichuanWinType.GangDiscard or SichuanWinType.RobAddedGang) multiplier *= 2;
        if (isJinGouDiao) multiplier *= 2;
        multiplier *= 1 << Math.Min(genCount, 20);
        var uncapped = baseFan * multiplier;
        var capped = rules.FanCap <= 0 ? uncapped : Math.Min(uncapped, rules.FanCap);
        var handScore = capped <= 0 ? rules.BaseScore : rules.BaseScore * (1 << Math.Max(0, capped - 1));
        var selfDraw = winType is SichuanWinType.SelfDraw or SichuanWinType.GangSelfDraw;
        var labels = new List<string> { handType switch { "qing_yi_se" => "清一色", "qi_dui" => "暗七对", "da_dui_zi" => "大对子", _ => "平胡" } };
        if (isJinGouDiao) labels.Add("金钩钓");
        for (var i = 0; i < genCount; i++) labels.Add("带根");
        if (winType == SichuanWinType.GangSelfDraw) labels.Add("杠上花");
        if (winType == SichuanWinType.GangDiscard) labels.Add("杠上炮");
        if (winType == SichuanWinType.RobAddedGang) labels.Add("抢杠胡");
        if (selfDraw) labels.Add("自摸");
        var qualifyingPatterns = new List<string>();
        if (isQing) qualifyingPatterns.Add("qing_yi_se");
        if (isSevenPairs) qualifyingPatterns.Add(isDragonSevenPairs ? "long_qi_dui" : "qi_dui");
        if (isDaDuiZi) qualifyingPatterns.Add("da_dui_zi");
        if (isJinGouDiao) qualifyingPatterns.Add("jin_gou_diao");
        if (genCount > 0) qualifyingPatterns.Add("dai_gen");
        return new SichuanFanProjection(
            handType,
            baseFan,
            genCount,
            uncapped,
            capped,
            handScore,
            handScore + (selfDraw ? rules.SelfDrawBottomBonus : 0),
            labels,
            qualifyingPatterns,
            isQing,
            isSevenPairs,
            isDragonSevenPairs,
            isDaDuiZi,
            isJinGouDiao);
    }

    private static int[] Normalize(IReadOnlyList<int> source)
        => Enumerable.Range(0, 27).Select(index => index < source.Count ? Math.Clamp(source[index], 0, 4) : 0).ToArray();
}
