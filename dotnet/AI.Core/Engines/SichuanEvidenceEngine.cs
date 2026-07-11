using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanEvidenceEngine
{
    public SichuanEvidenceSnapshot Build(SichuanStateView state)
    {
        var snapshot = new SichuanEvidenceSnapshot();
        for (var seat = 0; seat < 4; seat++)
        {
            var discards = state.Discards18[seat];
            var discardByTile = new int[27];
            var discardBySuit = new int[3];
            foreach (var tileType in discards)
            {
                if (tileType is < 0 or >= 27) continue;
                snapshot.SeatExactSafeTiles[seat].Add(tileType);
                discardByTile[tileType]++;
                discardBySuit[tileType / 9]++;
            }

            for (var tileType = 0; tileType < 27; tileType++)
            {
                snapshot.SeatNoHuEvidence[seat][tileType] = Math.Max(
                    EstimateNoHuEvidence(discards, discardByTile, tileType),
                    BuildPassedReactionEvidence(state.PassedHu18, seat, tileType, 0.36, 0.94));
                snapshot.SeatNoPengEvidence[seat][tileType] = BuildPassedReactionEvidence(state.PassedPeng18, seat, tileType, 0.30, 0.88);
                snapshot.SeatNoGangEvidence[seat][tileType] = BuildPassedReactionEvidence(state.PassedGang18, seat, tileType, 0.34, 0.90);
            }

            for (var suit = 0; suit < 3; suit++)
                snapshot.SeatAbandonedSuitEvidence[seat][suit] = Math.Clamp(discardBySuit[suit] / 5.0, 0.0, 0.92);

            snapshot.SeatRecentDiscardTrend[seat] = discards
                .Where(tile => tile is >= 0 and < 27)
                .TakeLast(4)
                .ToArray();
        }
        return snapshot;
    }

    private static double BuildPassedReactionEvidence(int[][] countsBySeat, int seat, int tileType, double singlePassEvidence, double cap)
    {
        if (seat < 0 || seat >= countsBySeat.Length || tileType is < 0 or >= 27)
            return 0.0;
        var count = countsBySeat[seat][tileType];
        if (count <= 0)
            return 0.0;
        return Math.Clamp(singlePassEvidence + (count - 1) * 0.18, 0.0, cap);
    }

    private static double EstimateNoHuEvidence(IReadOnlyList<int> discards, int[] discardByTile, int tileType)
    {
        var sameDiscardCount = tileType is >= 0 and < 27 ? discardByTile[tileType] : 0;
        var evidence = sameDiscardCount switch
        {
            >= 2 => 0.82,
            1 => 0.58,
            _ => 0.0
        };
        if (discards.Count > 0 && discards[^1] == tileType)
            evidence = Math.Max(evidence, 0.76);
        if (discards.Count >= 2 && discards[^2] == tileType)
            evidence = Math.Max(evidence, 0.66);

        var suitStart = (tileType / 9) * 9;
        var rank = tileType % 9;
        var nearbyDiscards = 0;
        for (var offset = -1; offset <= 1; offset++)
        {
            if (offset == 0) continue;
            var neighbor = suitStart + rank + offset;
            if (neighbor >= suitStart && neighbor < suitStart + 9)
                nearbyDiscards += discardByTile[neighbor];
        }
        if (nearbyDiscards >= 3)
            evidence = Math.Max(evidence, 0.38);
        else if (nearbyDiscards >= 2)
            evidence = Math.Max(evidence, 0.24);
        return Math.Clamp(evidence, 0.0, 0.92);
    }
}
