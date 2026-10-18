using System.Collections.Concurrent;
using System.Diagnostics;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Explicit diagnostic counters; disabled during normal play.</summary>
public static class SichuanPolicyTiming
{
    public static bool Enabled { get; set; }
    private static readonly ConcurrentDictionary<string,(long Ticks,long Calls)> Values = new();
    public static void Reset() => Values.Clear();
    public static IDisposable Measure(string name) => Enabled ? new Timer(name) : Empty.Instance;
    public static string[] Report() => Values.OrderByDescending(x=>x.Value.Ticks)
        .Select(x=>$"{x.Key}: ms={x.Value.Ticks*1000.0/Stopwatch.Frequency:F2} calls={x.Value.Calls}").ToArray();
    private sealed class Timer(string name) : IDisposable
    {
        private readonly long _start=Stopwatch.GetTimestamp();
        public void Dispose() { var ticks=Stopwatch.GetTimestamp()-_start;
            Values.AddOrUpdate(name,(ticks,1),(_,old)=>(old.Ticks+ticks,old.Calls+1)); }
    }
    private sealed class Empty : IDisposable { public static readonly Empty Instance=new(); public void Dispose() {} }
}
