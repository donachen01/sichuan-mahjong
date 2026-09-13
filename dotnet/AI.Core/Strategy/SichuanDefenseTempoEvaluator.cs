using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Strategy;

public sealed record SichuanDefenseTempoEvaluation(
    double DiscardNowAdjustment,
    double FutureRisk,
    double TemporarySafetyReserve,
    double ThreatBenefitAsymmetry,
    int RecentPublicDiscardAge,
    IReadOnlyList<string> Reasons);

/// <summary>
/// Compares the timing of defensive exits using public events only. A tile
/// which just passed the table is a temporary reserve, not permanent safety;
/// a tile valuable to a visible flush threat can become harder to release.
/// </summary>
public sealed class SichuanDefenseTempoEvaluator
{
    public SichuanDefenseTempoEvaluation Evaluate(
        SichuanStateView state,
        SichuanBeliefSnapshot belief,
        int tileType,
        int currentDanger)
    {
        var activeThreats = Enumerable.Range(0, 4)
            .Where(seat => seat != state.SeatIndex && state.ActiveSeats[seat] && !state.HasHu[seat]
                && state.DingQueSuits[seat] != tileType / 9)
            .Select(seat => new
            {
                Seat = seat,
                Threat = belief.SeatThreatScore.GetValueOrDefault(seat, 0.0),
                SameSuitMelds = state.Melds18[seat].Count(tile => tile / 9 == tileType / 9) / 3.0
            })
            .OrderByDescending(item => item.Threat + item.SameSuitMelds * 0.16)
            .ToArray();
        var top = activeThreats.FirstOrDefault();
        var threatBenefit = top is null ? 0.0 : Math.Clamp(
            top.SameSuitMelds * 0.16 + top.Threat * 0.22,
            0.0,
            0.72);

        var ordered = state.PublicEvents.OrderBy(item => item.EventIndex).ToArray();
        var recentIndex = Array.FindLastIndex(ordered, item =>
            item.Type == SichuanPublicEventType.Discard && item.TileType == tileType && item.Seat != state.SeatIndex);
        var age = recentIndex < 0 ? int.MaxValue : ordered.Length - 1 - recentIndex;
        var recency = age == int.MaxValue ? 0.0 : Math.Exp(-Math.Max(0, age) / 3.0);
        var temporarySafety = recency * (0.42 + (top?.Threat ?? 0.0) * 0.18);

        var futureRisk = Math.Clamp(currentDanger / 100.0 * 0.62 + threatBenefit * 0.58, 0.0, 1.0);
        var adjustment = Math.Clamp(
            futureRisk * 0.82 + threatBenefit * 0.38 - temporarySafety * 1.18,
            -0.85,
            0.85);
        var reasons = new List<string>();
        if (temporarySafety >= 0.16) reasons.Add($"近期同张通过，临时安全储备 {temporarySafety:F2}，不可视为永久安全");
        if (threatBenefit >= 0.20) reasons.Add($"共同大牌威胁获得此张的收益不对称 {threatBenefit:F2}");
        if (adjustment >= 0.18) reasons.Add("未来风险增长较快，倾向提前退出");
        else if (adjustment <= -0.12) reasons.Add("保留近期安全张作为后续退出储备");
        return new SichuanDefenseTempoEvaluation(adjustment, futureRisk, temporarySafety, threatBenefit, age, reasons);
    }
}
