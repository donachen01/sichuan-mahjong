using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanDangerEngine
{
    public int Evaluate(int tileType, SichuanStateView state, SichuanBeliefSnapshot belief)
        => EvaluateDetail(tileType, state, belief).Risk;

    public SichuanDangerEvaluation EvaluateDetail(int tileType, SichuanStateView state, SichuanBeliefSnapshot belief)
    {
        var risk = 6.0;
        var topThreatSeat = -1;
        var topThreatScore = 0.0;
        var reasons = new List<string>();
        var suit = tileType / 9;
        foreach (var (seat, pressure) in belief.SeatPressure)
        {
            var tileDanger = 0.22;
            if (belief.SeatTileDanger.TryGetValue(seat, out var perTile) && perTile.TryGetValue(tileType, out var dangerValue))
                tileDanger = dangerValue;
            var holdProbability = belief.SeatTileHoldProbability.TryGetValue(seat, out var holdMap)
                ? holdMap.GetValueOrDefault(tileType, 0.0)
                : 0.0;
            var waitProbability = belief.SeatTileWaitProbability.TryGetValue(seat, out var waitMap)
                ? waitMap.GetValueOrDefault(tileType, 0.0)
                : 0.0;
            var noHuEvidence = belief.SeatTileNoHuEvidence.TryGetValue(seat, out var noHuMap)
                ? noHuMap.GetValueOrDefault(tileType, 0.0)
                : 0.0;
            var readyPosterior = belief.SeatReadyPosterior.GetValueOrDefault(seat, pressure);

            var threatScore = belief.SeatThreatScore.GetValueOrDefault(seat, 0.0);
            var suitDemand = belief.SeatSuitDemand.TryGetValue(seat, out var suits)
                ? suits.GetValueOrDefault(suit, 0.0)
                : 0.0;
            var strongAbandonedSuit = false;

            var seatRisk = pressure * 18.0
                + readyPosterior * 22.0
                + tileDanger * 18.0
                + holdProbability * 12.0
                + waitProbability * 36.0
                + suitDemand * 10.0
                + threatScore * 10.0;

            var isExactSafe = belief.SeatExactSafeTiles.TryGetValue(seat, out var exactSafeTiles) && exactSafeTiles.Contains(tileType);
            var isTailRisk = state.WallCount <= 7 && readyPosterior >= 0.52;
            if (isExactSafe)
            {
                seatRisk *= isTailRisk ? 0.36 : 0.14;
                reasons.Add($"座位{seat}现物偏安全");
            }
            var isAbandonedSuit = belief.SeatAbandonedSuits.TryGetValue(seat, out var abandonedSuits) && abandonedSuits.Contains(suit);
            strongAbandonedSuit = isAbandonedSuit && state.WallCount <= 3 && suitDemand <= 0.10;
            if (isAbandonedSuit)
            {
                seatRisk *= isTailRisk ? (strongAbandonedSuit ? 0.46 : 0.82) : 0.72;
                reasons.Add($"座位{seat}该门已弃多张");
            }
            if (noHuEvidence >= 0.56)
            {
                seatRisk *= isTailRisk ? 0.82 : 0.58;
                reasons.Add($"座位{seat}近期不要这张");
            }
            else if (noHuEvidence >= 0.24)
            {
                seatRisk *= isTailRisk ? 0.94 : 0.82;
                reasons.Add($"座位{seat}邻张舍出较多");
            }
            if (!isExactSafe && isTailRisk)
            {
                var tailFloorBase = strongAbandonedSuit ? 8.0 : isAbandonedSuit ? 30.0 : 38.0;
                var readyFloorScale = strongAbandonedSuit ? 6.0 : isAbandonedSuit ? 18.0 : 36.0;
                var waitFloorScale = strongAbandonedSuit ? 10.0 : isAbandonedSuit ? 24.0 : 34.0;
                var holdFloorScale = strongAbandonedSuit ? 5.0 : isAbandonedSuit ? 12.0 : 22.0;
                var floor = tailFloorBase
                    + Math.Max(0.0, readyPosterior - 0.52) * readyFloorScale
                    + waitProbability * waitFloorScale
                    + holdProbability * holdFloorScale
                    + (state.WallCount <= 3 && !strongAbandonedSuit ? 5.0 : 0.0);
                seatRisk = Math.Max(seatRisk, floor);
                reasons.Add($"座位{seat}尾盘安全证据打折");
            }
            else if (!isExactSafe && state.WallCount <= 3 && readyPosterior >= 0.40 && (holdProbability >= 0.18 || waitProbability >= 0.08))
            {
                seatRisk = Math.Max(seatRisk, 34.0 + holdProbability * 18.0 + waitProbability * 28.0);
                reasons.Add($"座位{seat}极尾盘保守处理");
            }

            if (state.IsCalled[seat] || state.IsReady[seat])
            {
                seatRisk *= 1.18;
                reasons.Add($"座位{seat}已报叫");
                reasons.Add($"座位{seat}听牌后验高");
            }

            if (HasExposedPung(state.Melds18[seat], tileType))
            {
                seatRisk += 18.0;
                reasons.Add($"座位{seat}已碰此张，需防点杠");
            }

            if (readyPosterior >= 0.56)
                reasons.Add($"座位{seat}听牌后验高");
            if (waitProbability >= 0.28)
                reasons.Add($"座位{seat}胡这张后验高");
            else if (holdProbability >= 0.20)
                reasons.Add($"座位{seat}持张后验高");

            if (seatRisk > topThreatScore)
            {
                topThreatScore = seatRisk;
                topThreatSeat = seat;
            }
            risk = Math.Max(risk, seatRisk);
        }

        var riskInt = Math.Clamp((int)Math.Round(risk), 0, 100);
        return new SichuanDangerEvaluation
        {
            Risk = riskInt,
            RiskLabel = ResolveRiskLabel(riskInt),
            TopThreatSeat = topThreatSeat,
            TopThreatScore = Math.Round(topThreatScore, 2),
            Reasons = reasons
                .Distinct()
                .OrderByDescending(item => item.Contains("后验"))
                .ThenByDescending(item => item.Contains("已报叫"))
                .Take(6)
                .Append(reasons.Count == 0 ? $"当前{ResolveRiskLabel(riskInt)}可控" : $"整体{ResolveRiskLabel(riskInt)}")
                .ToArray()
        };
    }

    private static string ResolveRiskLabel(int danger)
    {
        if (danger >= 78) return "极危险";
        if (danger >= 56) return "高危";
        if (danger >= 34) return "中危";
        return "低危";
    }

    private static bool HasExposedPung(IReadOnlyList<int> meldTiles, int tileType)
    {
        for (var index = 0; index + 2 < meldTiles.Count; index += 3)
        {
            if (meldTiles[index] == tileType && meldTiles[index + 1] == tileType && meldTiles[index + 2] == tileType)
                return true;
        }
        return false;
    }
}
