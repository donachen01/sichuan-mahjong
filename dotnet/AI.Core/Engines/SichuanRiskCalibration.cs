namespace SichuanMahjong.AI.Core.Engines;

public static class SichuanRiskCalibration
{
    public static double ToDealInProbability(int danger, int roundStage, double maxReadyPosterior)
    {
        var normalized = Math.Clamp(danger, 0, 100) / 100.0;
        var baseProbability = normalized switch
        {
            < 0.30 => 0.012 + normalized * 0.12,
            < 0.56 => 0.045 + (normalized - 0.30) * 0.34,
            < 0.78 => 0.135 + (normalized - 0.56) * 0.58,
            _ => 0.265 + (normalized - 0.78) * 0.64
        };
        var stageBoost = roundStage switch
        {
            <= 0 => 0.88,
            1 => 1.0,
            _ => 1.12
        };
        var posteriorBoost = 0.84 + Math.Clamp(maxReadyPosterior, 0.0, 0.98) * 0.32;
        return Math.Clamp(baseProbability * stageBoost * posteriorBoost, 0.002, 0.54);
    }
}
