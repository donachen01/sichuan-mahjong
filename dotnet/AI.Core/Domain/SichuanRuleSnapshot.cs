namespace SichuanMahjong.AI.Core.Domain;

public sealed record SichuanRuleSnapshot(
    int TileTypeCount = 27,
    int CopiesPerTile = 4,
    int FanCap = 4,
    int BaseScore = 1,
    int SelfDrawBottomBonus = 1,
    bool AllowChi = false,
    bool AllowSevenPairs = true,
    bool RequireDingQue = true,
    bool BattleToEnd = true,
    bool MultipleWinners = true,
    bool EnableChaJiao = true,
    bool EnableHuaZhu = true,
    bool EnableGangRefund = true,
    bool EnableHuJiaoTransfer = true,
    bool EnableRobAddedGang = true)
{
    public const string Version = "sichuan-v2-rule-20261018-deferred-added-gang";
    public static SichuanRuleSnapshot Frozen { get; } = new();
}
