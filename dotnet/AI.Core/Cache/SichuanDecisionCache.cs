using System.Collections.Generic;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Cache;

public sealed class SichuanDecisionCache
{
    private readonly object _lock = new();
    private readonly int _capacity;
    private readonly Dictionary<string, LinkedListNode<CacheEntry>> _entries = new();
    private readonly LinkedList<CacheEntry> _lru = new();

    public SichuanDecisionCache(int capacity = 256)
    {
        _capacity = Math.Max(16, capacity);
    }

    public int Count => _entries.Count;
    public int Capacity => _capacity;
    public long Hits { get; private set; }
    public long Misses { get; private set; }

    public bool TryGet(string key, out SichuanDecisionResult result)
    {
        lock (_lock)
        {
            if (_entries.TryGetValue(key, out var node))
            {
                Hits++;
                _lru.Remove(node);
                _lru.AddLast(node);
                result = node.Value.Result;
                return true;
            }

            Misses++;
            result = new SichuanDecisionResult();
            return false;
        }
    }

    public void Put(string key, SichuanDecisionResult result)
    {
        lock (_lock)
        {
            if (_entries.TryGetValue(key, out var existing))
            {
                _lru.Remove(existing);
                existing.Value = new CacheEntry(key, result);
                _lru.AddLast(existing);
                return;
            }

            var node = new LinkedListNode<CacheEntry>(new CacheEntry(key, result));
            _lru.AddLast(node);
            _entries[key] = node;

            while (_entries.Count > _capacity && _lru.First is not null)
            {
                var oldest = _lru.First;
                _lru.RemoveFirst();
                _entries.Remove(oldest!.Value.Key);
            }
        }
    }

    public CacheSnapshot Snapshot()
    {
        lock (_lock)
        {
            return new CacheSnapshot
            {
                Count = Count,
                Capacity = Capacity,
                Hits = Hits,
                Misses = Misses
            };
        }
    }

    private readonly record struct CacheEntry(string Key, SichuanDecisionResult Result);
}

public sealed class CacheSnapshot
{
    public int Count { get; init; }
    public int Capacity { get; init; }
    public long Hits { get; init; }
    public long Misses { get; init; }
}
