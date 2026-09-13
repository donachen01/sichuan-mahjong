using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Inference;

/// <summary>
/// Evaluates whether a complete concealed-hand hypothesis is compatible with
/// generic public action evidence. It deliberately does not recognize fixed
/// discard or claim sequences from individual games.
/// </summary>
public static class SichuanOrderedPublicInference
{
    /// <summary>
    /// Scores a complete candidate hand against public decisions to decline
    /// Peng or Gang. Strategic passes remain possible, so contradictions only
    /// reduce the likelihood and never reveal or exclude a concealed hand.
    /// </summary>
    public static double CandidateHandCompatibility(
        SichuanStateView state,
        int seat,
        IReadOnlyList<int> hand27)
    {
        var compatibility = 1.0;
        var passedPairTiles = new List<int>();
        for (var tile = 0; tile < 27; tile++)
        {
            var copies = tile < hand27.Count ? hand27[tile] : 0;
            if (copies >= 2 && state.PassedPeng18[seat][tile] > 0)
            {
                compatibility *= 0.72;
                passedPairTiles.Add(tile);
            }
            if (copies >= 3 && state.PassedGang18[seat][tile] > 0)
                compatibility *= 0.74;
        }

        for (var index = 0; index < passedPairTiles.Count; index++)
        {
            for (var other = index + 1; other < passedPairTiles.Count; other++)
            {
                var left = passedPairTiles[index];
                var right = passedPairTiles[other];
                if (left / 9 == right / 9 && Math.Abs(left - right) == 1)
                    compatibility *= 0.62;
            }
        }
        return Math.Clamp(compatibility, 0.05, 1.0);
    }
}
