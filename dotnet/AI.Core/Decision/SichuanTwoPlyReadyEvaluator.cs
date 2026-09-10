using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanTwoPlyReadyBranch(
	int DrawTileType,
	double DrawMass,
	int BestNextShanten,
	double BestReadyWaitMass,
	double BestReadyWaitShapeScore,
	IReadOnlyList<int> BestReadyWaits);

public sealed record SichuanTwoPlyReadySummary(
	double FirstStepImprovingMass,
	double OrderedTwoDrawWinProbability,
	double EquivalentWinningTileMass,
	double ExpectedReadyWaitShapeScore,
	double WorstReadyWaitShapeScore,
	double WorstReadyWaitMass,
	IReadOnlyList<SichuanTwoPlyReadyBranch> Branches)
{
	public static readonly SichuanTwoPlyReadySummary Empty = new(0, 0, 0, 0, 0, 0, Array.Empty<SichuanTwoPlyReadyBranch>());
}

/// <summary>
/// Prices a one-shanten route from public wall availability without treating an
/// improving draw as an immediate win.  Every improving draw is followed by an
/// exact best-discard enumeration. OrderedTwoDrawWinProbability is a plug-in
/// two-draw proxy, not a calibrated game win probability: marginal expected wall
/// counts do not identify conditional joint draws, claims, or own-draw horizon.
/// WorstReadyWaitMass includes dead reachable improving branches; the shape
/// minimum remains conditional on a live ready branch (shape is not availability).
/// </summary>
public sealed class SichuanTwoPlyReadyEvaluator
{
	private readonly SichuanExactHandAnalyzer _hands = new();
	private readonly SichuanShantenEngine _shanten = new();
	private readonly SichuanWaitShapeEngine _waitShape = new();

	public SichuanTwoPlyReadySummary Evaluate(
		IReadOnlyList<int> handAfterDiscard,
		IReadOnlyList<int> remaining18,
		SichuanWallAvailability wall,
		int meldCount,
		int currentShanten,
		IEnumerable<int> improvingTiles,
		bool allowSevenPairs)
	{
		if (currentShanten != 1 || wall.WallCount < 2)
			return SichuanTwoPlyReadySummary.Empty;

		var branches = new List<SichuanTwoPlyReadyBranch>();
		var firstStepMass = 0.0;
		var orderedCompletion = 0.0;
		var weightedReadyShape = 0.0;
		var worstReadyShape = double.PositiveInfinity;
		var worstReadyWaitMass = double.PositiveInfinity;
		foreach (var drawTile in improvingTiles.Where(tile => tile is >= 0 and < 27).Distinct())
		{
			var drawMass = Math.Max(0, wall.ExpectedCounts18[drawTile]);
			if (drawMass <= 0 || handAfterDiscard[drawTile] >= 4) continue;

			var drawnHand = handAfterDiscard.ToArray();
			drawnHand[drawTile]++;
			var adjustedRemaining = remaining18.ToArray();
			adjustedRemaining[drawTile] = Math.Max(0, adjustedRemaining[drawTile] - 1);
			var nextShantenByDiscard = new Dictionary<int, int>();
			for (var discardTile = 0; discardTile < 27; discardTile++)
			{
				if (drawnHand[discardTile] <= 0) continue;
				drawnHand[discardTile]--;
				nextShantenByDiscard[discardTile] = _shanten.CalcBestShanten(drawnHand, meldCount, allowSevenPairs);
				drawnHand[discardTile]++;
			}
			if (nextShantenByDiscard.Count == 0) continue;

			var bestShanten = nextShantenByDiscard.Values.Min();
			var bestWaitMass = 0.0;
			var bestWaitShape = double.NegativeInfinity;
			IReadOnlyList<int> bestWaits = Array.Empty<int>();
			foreach (var discardChoice in nextShantenByDiscard.Where(candidate => candidate.Value == bestShanten))
			{
				drawnHand[discardChoice.Key]--;
				var waitTiles = bestShanten == 0
					? _hands.EnumerateWaits(drawnHand, adjustedRemaining, meldCount, allowSevenPairs)
						.Select(wait => wait.TileType).Distinct().ToArray()
					: Array.Empty<int>();
				var waitMass = waitTiles.Sum(waitTile => Math.Max(0,
					wall.ExpectedCounts18[waitTile] - (waitTile == drawTile ? 1.0 : 0.0)));
				var waitShape = _waitShape.Evaluate(drawnHand, waitTiles).WaitShapeScore;
				drawnHand[discardChoice.Key]++;
				if (waitMass > bestWaitMass + 0.000001
					|| Math.Abs(waitMass - bestWaitMass) <= 0.000001 && waitShape > bestWaitShape + 0.000001
					|| Math.Abs(waitMass - bestWaitMass) <= 0.000001
						&& Math.Abs(waitShape - bestWaitShape) <= 0.000001 && waitTiles.Length > bestWaits.Count)
				{
					bestWaitMass = waitMass;
					bestWaitShape = waitShape;
					bestWaits = waitTiles;
				}
			}

			firstStepMass += drawMass;
			worstReadyWaitMass = Math.Min(worstReadyWaitMass, bestShanten == 0 ? bestWaitMass : 0);
			if (bestShanten == 0 && bestWaitMass > 0)
			{
				orderedCompletion += drawMass / wall.WallCount * bestWaitMass / (wall.WallCount - 1.0);
				weightedReadyShape += drawMass * bestWaitShape;
				worstReadyShape = Math.Min(worstReadyShape, bestWaitShape);
			}
			branches.Add(new SichuanTwoPlyReadyBranch(drawTile, drawMass, bestShanten, bestWaitMass,
				double.IsFinite(bestWaitShape) ? bestWaitShape : 0, bestWaits));
		}

		return new SichuanTwoPlyReadySummary(
			firstStepMass,
			Math.Clamp(orderedCompletion, 0, 1),
			Math.Clamp(orderedCompletion, 0, 1) * wall.WallCount,
			firstStepMass > 0 ? weightedReadyShape / firstStepMass : 0,
			double.IsFinite(worstReadyShape) ? worstReadyShape : 0,
			double.IsFinite(worstReadyWaitMass) ? worstReadyWaitMass : 0,
			branches);
	}
}
