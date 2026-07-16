namespace SichuanMahjong.AI.Core.Domain;

public sealed record SichuanRuleSnapshot(
    int TileTypeCount = 27,
    int CopiesPerTile = 4,
    int FanCap = 3,
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
    public const string Version = "sichuan-v2-frozen-20260713";
    public static SichuanRuleSnapshot Frozen { get; } = new();
}
