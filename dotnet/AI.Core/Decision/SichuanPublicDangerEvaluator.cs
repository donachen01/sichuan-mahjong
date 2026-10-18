using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanPublicDangerSignal(int Level, int Seat, int TargetSuit,
    string Code, long[] EventIndices, string Explanation);

public sealed record SichuanPublicDangerAssessment(int Level, SichuanPublicDangerSignal[] Signals)
{
    public string[] Reasons => Signals.Select(s => s.Code + ": " + s.Explanation).ToArray();
}

/// <summary>Observable danger patterns, never private readiness or a claim to
/// know the opponent's waits. Melds describe completed structures; pending or
/// robbed upgrades do not add a second group. Zero-cash Gangs still add roots.</summary>
public sealed class SichuanPublicDangerEvaluator
{
    public SichuanPublicDangerAssessment Evaluate(SichuanStateView state)
    {
        var signals = new List<SichuanPublicDangerSignal>();
        var active = Enumerable.Range(0,4).Where(s => s != state.SeatIndex
            && state.ActiveSeats[s] && !state.HasHu[s]).ToArray();
        var melds = active.ToDictionary(s => s, s => SichuanDevelopmentPolicy.Melds(state,s)
            .GroupBy(m => m.TileType).Select(g => g.OrderByDescending(m => m.Type != SichuanMeldType.Peng)
                .ThenByDescending(m => m.EventIndex).First()).ToArray());
        void Add(int level, int seat, int target, string code, IEnumerable<long> events, string text)
            => signals.Add(new(level,seat,target,code,events.ToArray(),text));
        var gangs = melds.Values.SelectMany(m => m).Where(m => m.Type != SichuanMeldType.Peng).ToArray();
        if (gangs.Length >= 2)
            Add(2,-1,-1,"DANGER_MAJOR_TWO_COMPLETED_GANGS",gangs.Select(m => m.EventIndex),
                "在局对手当前副露合计两杠以上（无分补杠的结构危险仍保留）");
        foreach (var seat in active)
        {
            var exposed = melds[seat];
            int peng = exposed.Count(m => m.Type == SichuanMeldType.Peng), gang = exposed.Length - peng;
            if (exposed.Length >= 4)
                Add(2,seat,-1,"DANGER_MAJOR_FOUR_MELDS",exposed.Select(m => m.EventIndex),$"座位{seat}四副落地，金钩结构危险");
            else if (peng >= 3)
                Add(1,seat,-1,"DANGER_GENERAL_THREE_PENG",exposed.Select(m => m.EventIndex),$"座位{seat}三副碰牌");
            else if (gang >= 1 && peng >= 1)
                Add(1,seat,-1,"DANGER_GENERAL_GANG_AND_PENG",exposed.Select(m => m.EventIndex),$"座位{seat}一杠一碰");

            int missing = state.DingQueSuits[seat];
            if (missing is <0 or >2) continue;
            var discards = state.PublicEvents.Where(e => e.Seat == seat
                && e.Type == SichuanPublicEventType.Discard && e.TileType is >=0 and <27)
                .OrderBy(e => e.EventIndex).ToArray();
            int clear = Array.FindIndex(discards,e => e.TileType / 9 != missing);
            if (clear < 0) continue;
            // Preserve the existing six-discard/80% evidence window, but only
            // deliberate hand discards can establish abandonment. Draw/unknown
            // origins stay in its denominator and cannot inflate the signal.
            var recent = discards.Skip(clear).Where(e => e.TileType / 9 != missing).TakeLast(6).ToArray();
            foreach (int abandoned in Enumerable.Range(0,3).Where(s => s != missing))
            {
                int target = 3 - missing - abandoned;
                var thrown = recent.Where(e => e.Origin == SichuanTileOrigin.Hand && e.TileType / 9 == abandoned).ToArray();
                if (thrown.Length < 3 || thrown.Length * 5 < recent.Length * 4
                    || exposed.Any(m => m.TileType / 9 != target)) continue;
                bool strong = exposed.Length >= 2
                    || thrown.Length >= 5 && thrown.Count(e => e.TileType % 9 is >=2 and <=6) >= 2;
                Add(strong ? 2 : 1,seat,target,strong ? "DANGER_MAJOR_FLUSH_ABANDONMENT" : "DANGER_GENERAL_FLUSH_ABANDONMENT",
                    thrown.Select(e => e.EventIndex),$"座位{seat}主动拆出收门{abandoned}，与目标门{target}副露一致；{(strong ? "明显" : "疑似")}清一色，公开行为推断而非已知暗手");
            }
        }
        return new(signals.Select(s => s.Level).DefaultIfEmpty(0).Max(),signals.ToArray());
    }
}
