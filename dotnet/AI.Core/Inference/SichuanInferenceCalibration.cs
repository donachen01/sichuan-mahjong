namespace SichuanMahjong.AI.Core.Inference;

public sealed record SichuanCalibrationBucket(
    double LowerBound,
    double UpperBound,
    int Count,
    double MeanPrediction,
    double ObservedFrequency);

public sealed record SichuanInferenceCalibration(
    double BrierScore,
    double TopThreeCoverage,
    int Samples,
    double CalibrationError,
    IReadOnlyList<SichuanCalibrationBucket> Buckets);

public static class SichuanInferenceCalibrationEvaluator
{
    public static SichuanInferenceCalibration Evaluate(IReadOnlyList<double[]> predictions, IReadOnlyList<int[]> truths)
    {
        var n = Math.Min(predictions.Count, truths.Count);
        if (n == 0) return new SichuanInferenceCalibration(0, 0, 0, 0, Array.Empty<SichuanCalibrationBucket>());
        var brier = 0.0;
        var covered = 0;
		var bucketPredictions = Enumerable.Range(0, 10).Select(_ => new List<(double prediction, double truth)>()).ToArray();
        for (var i = 0; i < n; i++)
        {
            for (var tile = 0; tile < 27; tile++)
            {
                var truth = tile < truths[i].Length && truths[i][tile] > 0 ? 1.0 : 0.0;
                var probability = tile < predictions[i].Length ? Math.Clamp(predictions[i][tile], 0, 1) : 0;
                brier += Math.Pow(probability - truth, 2);
				bucketPredictions[Math.Min(9, (int)(probability * 10))].Add((probability, truth));
            }
            var top = predictions[i].Select((value, tile) => (value, tile)).OrderByDescending(item => item.value).Take(3).Select(item => item.tile).ToHashSet();
            if (top.Any(tile => tile < truths[i].Length && truths[i][tile] > 0)) covered++;
        }
		var buckets = bucketPredictions.Select((values, index) => new SichuanCalibrationBucket(
			index / 10.0,
			(index + 1) / 10.0,
			values.Count,
			values.Count == 0 ? 0 : values.Average(item => item.prediction),
			values.Count == 0 ? 0 : values.Average(item => item.truth))).ToArray();
		var calibrationError = buckets.Sum(bucket => bucket.Count * Math.Abs(bucket.MeanPrediction - bucket.ObservedFrequency)) / Math.Max(1, n * 27.0);
        return new SichuanInferenceCalibration(brier / (n * 27), covered / (double)n, n, calibrationError, buckets);
    }
}
