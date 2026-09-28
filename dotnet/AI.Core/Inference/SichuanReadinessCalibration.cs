using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Inference;

// Reproducible fit: tools/ai/fit_readiness_calibration.py, evidence in
// evidence/ai_continuation_20260928/readiness_calibration.json. Calibrated on
// self-play; these values are not universal human-opponent probabilities.
internal static class SichuanReadinessCalibration
{
    private static readonly double[] Weights = {
        -0.9702856618085739,
        0.77194627313898334,
        0.26915106511395703,
        -0.27065900894969708,
        0.45151167448011903,
        -0.42639694908718617,
        0.50552136233300693,
        0.21805998143637786,
        -0.43733609687386937,
        1.4303854580207362
    };

    internal static double Apply(SichuanStateView state, int seat, double baseline)
    {
        if (state.DingQueSuits[seat] is < 0 or > 2) return baseline;
        var timeline = SichuanOpponentTimeline.Build(state, seat);
        var p = Math.Clamp(baseline, .001, .999);
        var features = new[] {1.0, Math.Log(p/(1-p)), (60-state.WallCount)/60.0,
            state.MeldViews[seat].Count/4.0, state.Discards18[seat].Count/12.0,
            timeline.RecentHandDiscards/4.0, timeline.RecentDrawDiscards/4.0,
            timeline.RecentCentralDiscards/4.0, timeline.LastDiscardWasMissing ? 1.0 : 0.0,
            SichuanOpponentTimeline.MustHaveClearedMissing(state, seat) ? 1.0 : 0.0};
        var logit = features.Zip(Weights, (a,b) => a*b).Sum();
        return 1/(1+Math.Exp(-Math.Clamp(logit, -35, 35)));
    }
}
