namespace SichuanMahjong.AI.Core.Domain;

public enum SichuanMeldType { Peng, MeldedGang, ConcealedGang, AddedGang }

public sealed record SichuanMeldView(
    SichuanMeldType Type,
    int TileType,
    int SourceSeat,
    long EventIndex)
{
    // A new Peng cannot be upgraded until a later normal own draw.
    public bool AddedGangBlockedUntilOwnDraw { get; init; }
}
