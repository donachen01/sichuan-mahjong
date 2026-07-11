namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanOpponentRangeProfile
{
    public int Seat { get; init; }
    public double ReadyProbability { get; init; }
    public double[] HoldProbability18 { get; init; } = new double[27];
    public double[] WaitProbability18 { get; init; } = new double[27];
    public double[] WallPosterior18 { get; init; } = new double[27];
    public double[] SuitDemand2 { get; init; } = new double[3];
}
