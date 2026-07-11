namespace SichuanMahjong.AI.Core.Models;

public enum SichuanActionType
{
    Pass,
    Discard,
    Peng,
    Gang,
    Hu
}

public sealed record SichuanAction(
    SichuanActionType ActionType,
    int TileType = -1,
    int Score = 0,
    string Reason = ""
);
