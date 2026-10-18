using System.Collections.Concurrent;
using System.Numerics;
using SichuanMahjong.AI.Core.Decision;

namespace SichuanMahjong.AI.Core.Engines;

/// <summary>Bounded mathematical facts only: which one-tile additions improve
/// this exact hand. A partial entry records which tiles were actually tested.
/// It never stores public supply, posterior, plan, risk or an action.</summary>
internal static class SichuanStructuralProgressCache
{
    private readonly record struct Key(ulong Low,ulong High,int Melds,bool SevenPairs);
    private readonly record struct Masks(uint Tested,uint Improving);
    private const int Capacity=8192;
    private static readonly ConcurrentDictionary<Key,Masks> Values=new();
    private static readonly Queue<Key> Order=new();
    private static readonly object Gate=new();
    private static long _lookups,_fullHits,_computedTiles;
    public static object Diagnostics()=>new{lookups=_lookups,fullHits=_fullHits,
        computedTiles=_computedTiles,entries=Values.Count,capacity=Capacity};

    internal static uint Find(SichuanHandDistanceCursor cursor,ulong low,ulong high,
        int melds,uint requested,bool sevenPairs)
    {
        if(requested==0)return 0;
        bool diagnostic=SichuanPolicyTiming.Enabled;
        if(diagnostic)Interlocked.Increment(ref _lookups);
        var key=new Key(low,high,melds,sevenPairs);
        Values.TryGetValue(key,out var known);
        uint missing=requested&~known.Tested;
        if(missing==0)
        {
            if(diagnostic)Interlocked.Increment(ref _fullHits);
            return requested&known.Improving;
        }
        int before=cursor.Best(sevenPairs);
        uint improved=known.Improving;
        for(uint bits=missing;bits!=0;bits&=bits-1)
        {
            int tile=BitOperations.TrailingZeroCount(bits);
            cursor.Change(tile,1);
            try{if(cursor.Best(sevenPairs)<before)improved|=1u<<tile;}
            finally{cursor.Change(tile,-1);}
        }
        if(diagnostic)Interlocked.Add(ref _computedTiles,BitOperations.PopCount(missing));
        var computed=new Masks(known.Tested|missing,improved);
        lock(Gate)
        {
            if(Values.TryGetValue(key,out var newer))
                Values[key]=new(newer.Tested|computed.Tested,newer.Improving|computed.Improving);
            else
            {
                Values[key]=computed;Order.Enqueue(key);
                while(Order.Count>Capacity)Values.TryRemove(Order.Dequeue(),out _);
            }
        }
        return improved&requested;
    }
}
