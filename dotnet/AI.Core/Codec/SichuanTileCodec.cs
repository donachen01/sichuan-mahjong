namespace SichuanMahjong.AI.Core.Codec;

public static class SichuanTileCodec
{
    public static int EncodeTileType(int suitIndex, int rank)
    {
        if (suitIndex is < 0 or > 2 || rank is < 1 or > 9)
            return -1;
        return suitIndex * 9 + rank - 1;
    }

    public static (int suitIndex, int rank) DecodeTileType(int tileType)
    {
        if (tileType is < 0 or >= 27)
            return (-1, -1);
        return (tileType / 9, tileType % 9 + 1);
    }

    public static int[] BuildCount18(IEnumerable<int> tileTypes)
    {
        var counts = new int[27];
        foreach (var tileType in tileTypes)
        {
            if (tileType is >= 0 and < 27)
                counts[tileType]++;
        }
        return counts;
    }
}
