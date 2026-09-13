namespace SichuanMahjong.AI.Core.Inference;

public enum SichuanHiddenHandProposal
{
    BehaviorWeightedLegacy,
    PublicPriorThenLikelihood
}

public sealed record SichuanHiddenHandParticle(int[][] Hands27, int[] Wall27, double Weight);

public sealed record SichuanHiddenHandPosterior(
    double[][] HoldProbabilities,
    double[] ReadyProbabilities,
    double[][] WaitProbabilities,
    double[][] RouteProbabilities,
    double[] WallProbabilities,
    int ParticleCount,
    double EffectiveSampleSize);
