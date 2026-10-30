using System.Collections.Concurrent;
using System.Diagnostics;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Explicit diagnostic counters; disabled during normal play.</summary>
public static class SichuanPolicyTiming
{
    public static bool Enabled { get; set; }
    private static readonly ConcurrentDictionary<string,(long Ticks,long Self,long Calls)> Values = new();
    private static readonly AsyncLocal<Timer?> Current = new();
    public sealed record Sample(string Name, double TotalMs, double SelfMs, long Calls);
    public static void Reset() => Values.Clear();
    public static IDisposable Measure(string name) => Enabled ? new Timer(name) : Empty.Instance;
    public static Sample[] Snapshot() => Values.Select(x=>new Sample(x.Key,
        x.Value.Ticks*1000.0/Stopwatch.Frequency,x.Value.Self*1000.0/Stopwatch.Frequency,x.Value.Calls))
        .OrderByDescending(x=>x.SelfMs).ToArray();
    public static string[] Report() => Snapshot()
        .Select(x=>$"{x.Name}: ms={x.TotalMs:F2} self_ms={x.SelfMs:F2} calls={x.Calls}").ToArray();
    private sealed class Timer : IDisposable
    {
        private readonly long _start=Stopwatch.GetTimestamp();
        private readonly string _name;
        private readonly Timer? _parent;
        private long _children;
        public Timer(string name) { _name=name; _parent=Current.Value; Current.Value=this; }
        public void Dispose() { var ticks=Stopwatch.GetTimestamp()-_start;
            Current.Value=_parent;
            if(_parent is not null) Interlocked.Add(ref _parent._children,ticks);
            long self=Math.Max(0,ticks-_children);
            Values.AddOrUpdate(_name,(ticks,self,1),(_,old)=>(old.Ticks+ticks,old.Self+self,old.Calls+1)); }
    }
    private sealed class Empty : IDisposable { public static readonly Empty Instance=new(); public void Dispose() {} }
}
