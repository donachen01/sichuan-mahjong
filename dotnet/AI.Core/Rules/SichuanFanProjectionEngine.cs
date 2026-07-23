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
        var concealedQuadCount = hand.Sum(count => count / 4);
        var isDragonSevenPairs = isSevenPairs && concealedQuadCount > 0;
        var genCount = Math.Max(0, concealedQuadCount - (isDragonSevenPairs ? 1 : 0));
        var isJiangDui = isDaDuiZi && Enumerable.Range(0, 27)
            .Where(tile => allTiles[tile] > 0)
            .All(tile => tile % 9 is 1 or 4 or 7);
        var isShiBaLuoHan = melds.Count == 4 && melds.All(item => item.Type != SichuanMeldType.Peng);

        var (handType, baseFan) = ResolveBaseHand(
            isQing,
            isSevenPairs,
            isDragonSevenPairs,
            isDaDuiZi,
            isJinGouDiao,
            isJiangDui,
            isShiBaLuoHan);
        var bonusFan = genCount;
        if (winType is SichuanWinType.GangSelfDraw or SichuanWinType.GangDiscard or SichuanWinType.RobAddedGang)
            bonusFan++;
        var uncapped = baseFan + bonusFan;
        var capped = rules.FanCap <= 0 ? uncapped : Math.Min(uncapped, rules.FanCap);
        var handScore = rules.BaseScore * (1 << Math.Max(0, capped));
        var selfDraw = winType is SichuanWinType.SelfDraw or SichuanWinType.GangSelfDraw;
        var labels = new List<string> { HandTypeLabel(handType) };
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
        if (isJiangDui) qualifyingPatterns.Add("jiang_dui");
        if (isShiBaLuoHan) qualifyingPatterns.Add("shi_ba_luo_han");
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

    private static (string HandType, int BaseFan) ResolveBaseHand(
        bool isQing,
        bool isSevenPairs,
        bool isDragonSevenPairs,
        bool isDaDuiZi,
        bool isJinGouDiao,
        bool isJiangDui,
        bool isShiBaLuoHan)
    {
        if (isShiBaLuoHan) return ("shi_ba_luo_han", 4);
        if (isQing && isSevenPairs) return ("qing_qi_dui", 4);
        if (isQing && isJinGouDiao) return ("qing_jin_gou_diao", 4);
        if (isJiangDui) return ("jiang_dui", 3);
        if (isQing && isDaDuiZi) return ("qing_dui", 3);
        if (isDragonSevenPairs) return ("long_qi_dui", 3);
        if (isQing) return ("qing_yi_se", 2);
        if (isSevenPairs) return ("qi_dui", 2);
        if (isJinGouDiao) return ("jin_gou_diao", 2);
        if (isDaDuiZi) return ("da_dui_zi", 1);
        return ("ping_hu", 0);
    }

    private static string HandTypeLabel(string handType) => handType switch
    {
        "shi_ba_luo_han" => "十八罗汉",
        "qing_qi_dui" => "清七对",
        "qing_jin_gou_diao" => "清金钩钓",
        "jiang_dui" => "将对",
        "qing_dui" => "清对",
        "long_qi_dui" => "龙七对",
        "qing_yi_se" => "清一色",
        "qi_dui" => "小七对",
        "jin_gou_diao" => "金钩钓",
        "da_dui_zi" => "大对子",
        _ => "平胡"
    };
}
