using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Inference;

// Reproducible fit: tools/ai/fit_readiness_calibration.py, evidence in
// evidence/ai_continuation_20260928/readiness_calibration.json. Calibrated on
// self-play; these values are not universal human-opponent probabilities.
internal static class SichuanReadinessCalibration
{
    private static readonly double[] LegacyWeights = {
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

    // Frozen before independent holdout; 24 complete games gate passed.
    // Evidence: research/book_algorithm_20261011/gap-closure-round2-20261030/holdout-evaluation.json
    private static readonly double[] Weights = {
        -2.8891331307837169,
        0.43934793592293325,
        0.24672846543119753,
        -0.13684888903480513,
        0.3091936078773343,
        -0.13663897464434238,
        0.53434863633864382,
        0.84881125709068317,
        -0.50248008741790962,
        2.1204308881283711,
    };

    internal static double Apply(SichuanStateView state, int seat, double baseline)
    {
        if (state.DingQueSuits[seat] is < 0 or > 2) return baseline;
        var timeline = SichuanOpponentTimeline.Build(state, seat);
        var p = Math.Clamp(baseline, .001, .999);
        var features = new[] {1.0, Math.Log(p/(1-p)), (60-state.WallCount)/60.0,
            state.MeldCount(seat)/4.0, state.Discards18[seat].Count/12.0,
            timeline.RecentHandDiscards/4.0, timeline.RecentDrawDiscards/4.0,
            timeline.RecentCentralDiscards/4.0, timeline.LastDiscardWasMissing ? 1.0 : 0.0,
            SichuanOpponentTimeline.MustHaveClearedMissing(state, seat) ? 1.0 : 0.0};
        var weights=state.PolicyVariant is "current" or "adaptive_search_v1" or "cash_cost_before_v1"?Weights:LegacyWeights;
        var logit = features.Zip(weights, (a,b) => a*b).Sum();
        return 1/(1+Math.Exp(-Math.Clamp(logit, -35, 35)));
    }
}
