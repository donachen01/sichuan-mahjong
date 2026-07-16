namespace SichuanMahjong.AI.Core.Evaluation;

public enum SichuanDecisionErrorCategory { None, Rule, Wait, RemainingTiles, Posterior, Route, AttackDefense, Meld, PassHu, SearchBudget, Weight }

public sealed record SichuanDecisionJudgement(
    string Action,
    string BestAction,
    double ActionValue,
    double BestValue,
    double Regret,
    SichuanDecisionErrorCategory Category,
    IReadOnlyList<string> Reasons,
    bool RouteConsistent = true,
    double PredictedSuccessProbability = 0,
    bool? ActualSuccess = null,
    int PdfSource = 0);

public sealed record SichuanEvaluationMetrics(
    int Decisions,
    double AverageRegret,
    double SevereErrorRate,
    IReadOnlyDictionary<SichuanDecisionErrorCategory, int> Errors,
    double RouteConsistencyRate,
    double RuleErrorRate,
    double PassHuErrorRate,
    double MeldErrorRate,
    double CalibrationBrierScore,
    int CalibrationSamples,
    IReadOnlyDictionary<int, SichuanPdfEvaluationMetrics> ByPdf);

public sealed record SichuanPdfEvaluationMetrics(
    int Decisions,
    double AverageRegret,
    double SevereErrorRate,
    double RouteConsistencyRate);
