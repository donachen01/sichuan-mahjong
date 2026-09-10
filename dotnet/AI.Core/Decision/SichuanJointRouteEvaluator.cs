using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanJointRouteBranch(
    int FirstDraw, double FirstDrawProbability, bool WinsImmediately,
    IReadOnlyList<int> BestDiscards, double ConditionalSecondDrawWinProbability);

public sealed record SichuanJointRouteEstimate(
    double ModelWinProbability, int OwnDrawsEvaluated, IReadOnlyList<SichuanJointRouteBranch> Branches);

/// <summary>
/// Probability of self-draw completion in at most two own draws under a fixed
/// schedule, no claims/exits, and no intervening observations. This is neither
/// full-game win probability nor monetary EV. Maximize AFTER marginalizing all
/// hypotheses for each observed first draw: the discard cannot know its hidden wall.
/// </summary>
public sealed class SichuanJointRouteEvaluator
{
    private readonly SichuanExactHandAnalyzer _hands = new();

    public static int FixedScheduleOwnDrawBudget(int wallCount, int activeSeatCount)
    {
        if (wallCount is < 0 or > 108 || activeSeatCount is < 2 or > 4)
            throw new ArgumentOutOfRangeException(nameof(wallCount), "Invalid fixed schedule");
        // Perspective: focal player has just discarded. Every active player
        // consumes one tile per rotation. Claims/exit transitions are NOT simulated.
        return wallCount / activeSeatCount;
    }

    public SichuanJointRouteEstimate Evaluate(
        IReadOnlyList<int> handAfterDiscard, IReadOnlyList<int> ownMeldCounts,
        SichuanJointWallDrawModel wall, int ownDrawBudget, int missingSuit = -1)
    {
        ArgumentNullException.ThrowIfNull(wall);
        if (handAfterDiscard.Count != 27 || ownMeldCounts.Count != 27
            || ownDrawBudget < 0 || ownDrawBudget > wall.WallCount || missingSuit is < -1 or > 2
            || handAfterDiscard.Any(n => n is < 0 or > 4)
            || ownMeldCounts.Any(n => n is not (0 or 3 or 4)))
            throw new ArgumentException("Invalid post-discard hand, melds, or draw budget");
        var meldCount = ownMeldCounts.Count(n => n > 0);
        if (meldCount > 4 || handAfterDiscard.Sum() != 13 - 3 * meldCount
            || Enumerable.Range(0, 27).Any(t => handAfterDiscard[t] + ownMeldCounts[t] + wall.MaximumCopies(t) > 4)
            || missingSuit >= 0 && Enumerable.Range(missingSuit * 9, 9)
                .Any(t => handAfterDiscard[t] > 0 || ownMeldCounts[t] > 0))
            throw new ArgumentException("Illegal four-copy counts, hand size, or unresolved missing suit");
        var draws = Math.Min(2, ownDrawBudget);
        if (draws == 0) return new(0, 0, Array.Empty<SichuanJointRouteBranch>());

        var hand = handAfterDiscard.ToArray();
        var branches = new List<SichuanJointRouteBranch>();
        var total = 0.0;
        for (var first = 0; first < 27; first++)
        {
            var firstProbability = wall.FirstProbability(first);
            if (firstProbability <= 0) continue;
            hand[first]++;
            if (CanWin(hand, meldCount, missingSuit))
            {
                total += firstProbability;
                branches.Add(new(first, firstProbability, true, Array.Empty<int>(), 0));
            }
            else if (draws == 2)
            {
                var best = -1.0;
                var discards = new List<int>();
                for (var discard = 0; discard < 27; discard++)
                {
                    if (hand[discard] <= 0 || first / 9 == missingSuit && discard != first) continue;
                    hand[discard]--;
                    var jointWin = 0.0;
                    for (var second = 0; second < 27; second++)
                    {
                        var joint = wall.JointProbability(first, second);
                        if (joint <= 0 || hand[second] >= 4) continue;
                        hand[second]++;
                        if (CanWin(hand, meldCount, missingSuit)) jointWin += joint;
                        hand[second]--;
                    }
                    hand[discard]++;
                    if (jointWin > best + 1e-12) { best = jointWin; discards.Clear(); }
                    if (Math.Abs(jointWin - best) <= 1e-12) discards.Add(discard);
                }
                total += best;
                branches.Add(new(first, firstProbability, false, discards.AsReadOnly(), best / firstProbability));
            }
            else branches.Add(new(first, firstProbability, false, Array.Empty<int>(), 0));
            hand[first]--;
        }
        return new(Math.Clamp(total, 0, 1), draws, branches.AsReadOnly());
    }

    private bool CanWin(int[] hand, int meldCount, int missingSuit)
        => (missingSuit < 0 || !hand.Skip(missingSuit * 9).Take(9).Any(n => n > 0))
            && _hands.IsWinning(hand, meldCount, meldCount == 0);
}
