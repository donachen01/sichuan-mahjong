namespace SichuanMahjong.AI.Core.Domain;

public enum SichuanPublicEventType { Draw, Discard, Peng, MeldedGang, ConcealedGang, AddedGang, Hu, Pass }
public enum SichuanTileOrigin { Unknown, Hand, Draw }

public sealed record SichuanPublicEvent(
    long EventIndex,
    int TurnIndex,
    int Seat,
    SichuanPublicEventType Type,
    int TileType,
    SichuanTileOrigin Origin = SichuanTileOrigin.Unknown,
    int SourceSeat = -1,
    int WallCountAfter = -1,
    bool CanHu = false,
    bool CanPeng = false,
    bool CanGang = false);
