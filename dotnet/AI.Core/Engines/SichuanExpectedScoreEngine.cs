using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanExpectedScoreEngine
{
    public SichuanExpectedScore EvaluateDiscardCandidate(
        SichuanStateView state,
        int[] handAfterDiscard18,
        int shanten,
        int liveUkeire,
        int waitCount,
        int qualityScore,
        double tenpaiProbability,
        double selfDrawProbability,
        double winProbability,
        double dealInProbability,
        double topThreatScore,
        double maxReadyPosterior,
        double wallDrawPosterior,
        int roundStage,
        IReadOnlyList<string> routesAfter)
    {
        var activeOpponentCount = CountActiveOpponents(state);
        var estimatedFan = EstimateFan(handAfterDiscard18, routesAfter, shanten, waitCount, liveUkeire, roundStage);
        var estimatedBaseScore = ScoreFromFan(estimatedFan);
        var selfDrawShare = EstimateSelfDrawShare(selfDrawProbability, winProbability, wallDrawPosterior, waitCount);
        var discardWinShare = 1.0 - selfDrawShare;
        var winGainPerWin = discardWinShare * estimatedBaseScore
            + selfDrawShare * (estimatedBaseScore + 1) * activeOpponentCount;
        var winGain = winProbability * winGainPerWin;

        var opponentFan = EstimateOpponentFan(maxReadyPosterior, topThreatScore, roundStage, state.WallCount);
        var opponentBaseScore = ScoreFromFan(opponentFan);
        var dealInLoss = dealInProbability * opponentBaseScore;

        var drawProbability = EstimateDrawProbability(state.WallCount, roundStage);
        var drawRiskLoss = EstimateDrawRiskLoss(
            shanten,
            tenpaiProbability,
            maxReadyPosterior,
            drawProbability,
            activeOpponentCount,
            opponentBaseScore,
            roundStage);
        var readyValue = EstimateReadyValue(
            shanten,
            liveUkeire,
            waitCount,
            qualityScore,
            wallDrawPosterior,
            tenpaiProbability,
            roundStage);

        var net = winGain - dealInLoss - drawRiskLoss + readyValue;
        var reasons = BuildReasons(estimatedFan, estimatedBaseScore, winGain, dealInLoss, drawRiskLoss, readyValue);
        return new SichuanExpectedScore
        {
            Net = net,
            WinGain = winGain,
            DealInLoss = dealInLoss,
            DrawRiskLoss = drawRiskLoss,
            ReadyValue = readyValue,
            EstimatedFan = estimatedFan,
            EstimatedBaseScore = estimatedBaseScore,
            Reasons = reasons
        };
    }

    private static int CountActiveOpponents(SichuanStateView state)
    {
        var count = 0;
        for (var seat = 0; seat < state.HasHu.Length; seat++)
        {
            if (seat != state.SeatIndex && !state.HasHu[seat])
                count++;
        }
        return Math.Max(1, count);
    }

    private static double EstimateFan(
        int[] handAfterDiscard18,
        IReadOnlyList<string> routesAfter,
        int shanten,
        int waitCount,
        int liveUkeire,
        int roundStage)
    {
        var hasQing = routesAfter.Contains("清一色");
        var hasQiDui = routesAfter.Contains("七对");
        var hasDuiDui = routesAfter.Contains("对对胡");
        var baseFan = 1.0;
        if (hasQing && hasQiDui) baseFan = 4.0;
        else if (hasQing && hasDuiDui) baseFan = 4.0;
        else if (hasQing || hasQiDui || hasDuiDui) baseFan = 3.0;

        var guiPotential = CountGuiPotential(handAfterDiscard18);
        var fan = baseFan + Math.Min(2, guiPotential) * 0.42;
        if (shanten <= 0 && waitCount >= 2) fan += 0.18;
        if (shanten <= 1 && liveUkeire >= 8) fan += 0.10;
        if (roundStage >= 2 && shanten > 0) fan -= 0.35;
        return Math.Clamp(fan, 1.0, 3.0);
    }

    private static int CountGuiPotential(int[] handAfterDiscard18)
    {
        var count = 0;
        for (var index = 0; index < handAfterDiscard18.Length; index++)
        {
            if (handAfterDiscard18[index] >= 3)
                count++;
        }
        return count;
    }

    private static int ScoreFromFan(double fan)
    {
        if (fan < 1.75) return 1;
        if (fan < 2.75) return 2;
        return 4;
    }

    private static double EstimateSelfDrawShare(double selfDrawProbability, double winProbability, double wallDrawPosterior, int waitCount)
    {
        var probabilityShare = winProbability <= 0.001 ? 0.0 : selfDrawProbability / Math.Max(0.001, winProbability);
        var wallShare = 0.24 + wallDrawPosterior * 0.42 + Math.Min(4, waitCount) * 0.055;
        return Math.Clamp(probabilityShare * 0.46 + wallShare * 0.54, 0.12, 0.82);
    }

    private static double EstimateOpponentFan(double maxReadyPosterior, double topThreatScore, int roundStage, int wallCount)
    {
        var fan = 1.25 + maxReadyPosterior * 1.35 + Math.Clamp(topThreatScore / 100.0, 0.0, 1.0) * 1.10;
        if (roundStage >= 2) fan += 0.45;
        if (wallCount <= 5) fan += 0.25;
        return Math.Clamp(fan, 1.0, 3.0);
    }

    private static double EstimateDrawProbability(int wallCount, int roundStage)
    {
        var baseProbability = roundStage switch
        {
            0 => 0.10,
            1 => 0.22,
            _ => 0.38
        };
        if (wallCount <= 4) baseProbability += 0.18;
        else if (wallCount <= 8) baseProbability += 0.08;
        return Math.Clamp(baseProbability, 0.06, 0.68);
    }

    private static double EstimateDrawRiskLoss(
        int shanten,
        double tenpaiProbability,
        double maxReadyPosterior,
        double drawProbability,
        int activeOpponentCount,
        int opponentBaseScore,
        int roundStage)
    {
        var notReadyProbability = shanten <= 0 ? 0.05 : 1.0 - tenpaiProbability;
        var pressure = Math.Clamp(0.32 + maxReadyPosterior * 0.58 + roundStage * 0.08, 0.0, 0.98);
        return drawProbability * notReadyProbability * pressure * activeOpponentCount * opponentBaseScore * 0.58;
    }

    private static double EstimateReadyValue(
        int shanten,
        int liveUkeire,
        int waitCount,
        int qualityScore,
        double wallDrawPosterior,
        double tenpaiProbability,
        int roundStage)
    {
        var speedValue = shanten <= 0 ? 1.25 : shanten == 1 ? 0.58 : 0.12;
        var waitValue = waitCount * 0.22 + liveUkeire * 0.045 + qualityScore / 220.0;
        var wallValue = wallDrawPosterior * 0.55;
        var stageMultiplier = roundStage >= 2 ? 1.18 : roundStage == 1 ? 1.06 : 0.92;
        return (speedValue + waitValue + wallValue + tenpaiProbability * 0.34) * stageMultiplier;
    }

    private static IReadOnlyList<string> BuildReasons(
        double estimatedFan,
        int estimatedBaseScore,
        double winGain,
        double dealInLoss,
        double drawRiskLoss,
        double readyValue)
    {
        return new[]
        {
            $"净分期望：估番 {estimatedFan:0.0}，基础 {estimatedBaseScore} 分",
            $"收益 {winGain:0.00} / 点炮损失 {dealInLoss:0.00}",
            $"查叫风险 {drawRiskLoss:0.00} / 成叫价值 {readyValue:0.00}"
        };
    }
}
