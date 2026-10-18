namespace SichuanMahjong.AI.Core.Engines;

/// <summary>Incremental encoding of one mathematical hand. The supplied array
/// is borrowed; while this cursor is in use, all mutations must go through
/// Change. No public beliefs, player plans or action choices are cached here.</summary>
public sealed class SichuanHandDistanceCursor
{
    private static readonly int[] Powers={1,5,25,125,625,3125,15625,78125,390625};
    private readonly int[] _hand;
    private readonly int _melds;
    private readonly int[] _suits=new int[3];
    private ulong _low,_high;
    private int _quads,_pairs,_singles;
    private uint _quadTiles;

    public SichuanHandDistanceCursor(int[] hand,int melds)
    {
        if(hand.Length!=27||melds is <0 or >4||hand.Any(n=>n is <0 or >4))
            throw new ArgumentException("Expected physical hand and 0–4 melds.");
        _hand=hand;_melds=melds;
        for(int tile=0;tile<27;tile++)
        {
            int n=hand[tile];
            if(tile<21)_low|=(ulong)n<<(tile*3);else _high|=(ulong)n<<((tile-21)*3);
            _suits[tile/9]+=n*Powers[tile%9];
            _quads+=n==4?1:0;_pairs+=n/2;_singles+=n%2;
            if(n==4)_quadTiles|=1u<<tile;
        }
    }

    public void Change(int tile,int delta)
    {
        if(tile is <0 or >26)throw new ArgumentOutOfRangeException(nameof(tile));
        int before=_hand[tile],after=before+delta;
        if(after is <0 or >4)throw new InvalidOperationException("Incremental hand exceeds physical copy limits.");
        int shift=tile<21?tile*3:(tile-21)*3;
        if(tile<21)_low=(_low&~(7UL<<shift))|((ulong)after<<shift);
        else _high=(_high&~(7UL<<shift))|((ulong)after<<shift);
        _suits[tile/9]+=delta*Powers[tile%9];
        _quads+=(after==4?1:0)-(before==4?1:0);
        _pairs+=after/2-before/2;_singles+=after%2-before%2;
        if(after==4)_quadTiles|=1u<<tile;else _quadTiles&=~(1u<<tile);
        _hand[tile]=after;
    }

    public int Standard() => SichuanShantenEngine.CalcStandardCached(_hand,_melds,_low,_high,
        _suits[0],_suits[1],_suits[2],_quads);
    public int SevenPairs()
    {
        int missing=Math.Max(0,7-_pairs);
        return Math.Max(-1,missing*2-Math.Min(missing,_singles)-1);
    }
    public int Best(bool allowSevenPairs=true)
    {
        int standard=Standard();
        return !allowSevenPairs||_melds>0?standard:Math.Min(standard,SevenPairs());
    }

    /// <summary>Exact structural progress among the requested draw types.
    /// Supply, missing-suit legality and danger remain the caller's concerns.</summary>
    public uint ImprovingDrawMask(uint requested,bool allowSevenPairs=true)
        => SichuanStructuralProgressCache.Find(this,_low,_high,_melds,
            requested&((1u<<27)-1)&~_quadTiles,allowSevenPairs);
}
