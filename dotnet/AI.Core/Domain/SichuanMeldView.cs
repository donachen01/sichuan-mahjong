namespace SichuanMahjong.AI.Core.Domain;

public enum SichuanMeldType { Peng, MeldedGang, ConcealedGang, AddedGang }

public sealed record SichuanMeldView(
    SichuanMeldType Type,
    int TileType,
    int SourceSeat,
    long EventIndex);
