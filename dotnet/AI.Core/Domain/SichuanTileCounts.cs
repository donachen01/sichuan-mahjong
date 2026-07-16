namespace SichuanMahjong.AI.Core.Domain;

public sealed class SichuanTileCounts
{
    public const int TileTypeCount = 27;
    private readonly int[] _counts;

    public SichuanTileCounts(IEnumerable<int> counts)
    {
        _counts = counts.Take(TileTypeCount).Concat(Enumerable.Repeat(0, TileTypeCount)).Take(TileTypeCount).ToArray();
        if (_counts.Any(value => value is < 0 or > 4))
            throw new ArgumentOutOfRangeException(nameof(counts), "每类牌张数必须在 0 到 4 之间。");
    }

    public int this[int tileType] => tileType is >= 0 and < TileTypeCount ? _counts[tileType] : 0;
    public int Total => _counts.Sum();
    public int[] ToArray() => (int[])_counts.Clone();
    public static int SuitOf(int tileType) => tileType is >= 0 and < TileTypeCount ? tileType / 9 : -1;
    public static int RankOf(int tileType) => tileType is >= 0 and < TileTypeCount ? tileType % 9 + 1 : -1;
}
