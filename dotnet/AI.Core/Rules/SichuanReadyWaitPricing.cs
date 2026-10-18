using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Rules;

public sealed record SichuanReadyWaitPrice(int TileType, int CappedFan, int HandScore,
    int SelfDrawPerPayer, double PublicWallWeight)
{
    // 4.3's source heuristic treats a winning tile that completes a root as
    // two effective waits and an ordinary winning tile as one.  Keep the
    // exact root count alongside the normal score so callers can compare the
    // source signal without replacing project scoring.
    public int GenCount { get; init; }
}

/// <summary>Exact ordinary-win price at each currently legal wait. Wall weights
/// remain an uncalibrated public allocation model, not a win probability.</summary>
public sealed record SichuanReadyPrice(IReadOnlyList<SichuanReadyWaitPrice> Waits,
    double PublicDrawableMass, double WeightedFan, double WeightedHandScore,
    double WeightedSelfDrawPerPayer)
{
    public bool HasDrawableWait => PublicDrawableMass > 1e-9;
    public double RootWeightedDrawableMass => Waits.Sum(wait =>
        Math.Max(0.0, wait.PublicWallWeight) * (wait.GenCount > 0 ? 2.0 : 1.0));
    public double RootDrawableMass => Waits.Where(wait => wait.GenCount > 0)
        .Sum(wait => Math.Max(0.0, wait.PublicWallWeight));
    public double NonRootDrawableMass => Waits.Where(wait => wait.GenCount <= 0)
        .Sum(wait => Math.Max(0.0, wait.PublicWallWeight));
}

public sealed class SichuanReadyWaitPricing
{
    private readonly SichuanExactHandAnalyzer _hands = new();
    private readonly SichuanFanProjectionEngine _fans = new();

    public SichuanReadyPrice? Build(SichuanStateView state, IReadOnlyList<int> hand,
        IReadOnlyList<double> publicWallCounts, IReadOnlyList<SichuanMeldView>? projectedMelds = null)
    {
        using var timing = SichuanMahjong.AI.Core.Decision.SichuanPolicyTiming.Measure("ready_pricing");
        if(hand.Count!=27 || publicWallCounts.Count!=27)throw new ArgumentException("Expected27 counts");
        if(state.OwnDingQueSuit>=0 && hand.Skip(state.OwnDingQueSuit*9).Take(9).Any(n=>n>0))return null;
        var melds=projectedMelds?.ToArray() ?? (state.MeldViews[state.SeatIndex].Count>0?state.MeldViews[state.SeatIndex].ToArray():
            state.Melds18[state.SeatIndex].GroupBy(t=>t).Select((g,i)=>new SichuanMeldView(g.Count()==4?SichuanMeldType.MeldedGang:SichuanMeldType.Peng,g.Key,-1,i)).ToArray());
        if(melds.Any(m=>m.TileType/9==state.OwnDingQueSuit))return null;
        var capacity=Enumerable.Range(0,27).Select(t=>4-hand[t]).ToArray();
        foreach(var m in melds)capacity[m.TileType]-=m.Type==SichuanMeldType.Peng?3:4;
        if(capacity.Any(n=>n<0))throw new InvalidOperationException("owned copies exceed4");
        var waits=new List<SichuanReadyWaitPrice>();
        foreach(var w in _hands.EnumerateWaits(hand,capacity,melds.Length,melds.Length==0))
        {
            if(w.TileType/9==state.OwnDingQueSuit)continue;
            var completed=hand.ToArray();completed[w.TileType]++;
            var fan=_fans.Project(completed,melds,SichuanWinType.SelfDraw);
            waits.Add(new(w.TileType,fan.CappedFan,fan.HandScore,fan.PerPayerScore,Math.Max(0,publicWallCounts[w.TileType]))
            {
                GenCount = fan.GenCount
            });
        }
        if(waits.Count==0)return null;
        double mass=waits.Sum(w=>w.PublicWallWeight);
        // Dead waits have no future-win revenue. Their unweighted legal price
        // can still be explained, without inventing a drawable probability.
        double Mean(Func<SichuanReadyWaitPrice,double> f)=>mass>1e-9?waits.Sum(w=>w.PublicWallWeight*f(w))/mass:waits.Average(f);
        return new(waits,mass,Mean(w=>w.CappedFan),Mean(w=>w.HandScore),Mean(w=>w.SelfDrawPerPayer));
    }

    internal static bool HasLegalOwnedContext(SichuanStateView state, IReadOnlyList<int> hand,
        IReadOnlyList<SichuanMeldView> melds)
    {
        if (hand.Count != 27 || hand.Any(n => n < 0 || n > 4)) return false;
        var owned = hand.ToArray();
        foreach (var meld in melds)
        {
            if (meld.TileType is < 0 or > 26) return false;
            owned[meld.TileType] += meld.Type == SichuanMeldType.Peng ? 3 : 4;
        }
        if (owned.Any(n => n > 4)) return false;
        return state.OwnDingQueSuit is < 0 or > 2
            || !owned.Skip(state.OwnDingQueSuit * 9).Take(9).Any(n => n > 0);
    }
}
