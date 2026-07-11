using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanOpponentRangeEngine
{
    public SichuanOpponentRangeProfile BuildSeatRange(
        SichuanStateView state,
        SichuanEvidenceSnapshot evidence,
        int seat)
    {
        var discards = state.Discards18[seat];
        var meldTiles = state.Melds18[seat];
        var discardCount = discards.Count;
        var meldGroupCount = meldTiles.Count / 3;
        var pressure = EstimatePressure(state, seat, discardCount, meldGroupCount);
        var readyProbability = EstimateReadyProbability(state, seat, discardCount, meldGroupCount, pressure);
        var discardBySuit = new[] { 0, 0, 0 };
        var meldBySuit = new[] { 0, 0, 0 };
        foreach (var tile in discards.Where(tile => tile is >= 0 and < 27))
            discardBySuit[tile / 9]++;
        foreach (var tile in meldTiles.Where(tile => tile is >= 0 and < 27))
            meldBySuit[tile / 9]++;

        var suitDemand = new double[3];
        for (var suit = 0; suit < 3; suit++)
        {
            var meldFocus = meldTiles.Count == 0 ? 0.0 : meldBySuit[suit] / (double)Math.Max(1, meldTiles.Count);
            var heat = 0.24
                + meldFocus * 0.34
                + AverageVisibleScarcity(state, suit) * 0.18
                + ((state.IsCalled[seat] || state.IsReady[seat]) ? 0.08 : 0.0)
                - discardBySuit[suit] * 0.09;
            if (evidence.SeatAbandonedSuitEvidence[seat][suit] >= 0.56)
                heat *= 0.58;
            suitDemand[suit] = Math.Clamp(heat, 0.04, 0.98);
        }

        var hold = new double[27];
        var wait = new double[27];
        for (var tileType = 0; tileType < 27; tileType++)
        {
            var suit = tileType / 9;
            var rank = tileType % 9 + 1;
            var noHu = evidence.SeatNoHuEvidence[seat][tileType];
            var noPeng = evidence.SeatNoPengEvidence[seat][tileType];
            var noGang = evidence.SeatNoGangEvidence[seat][tileType];
            if (evidence.SeatExactSafeTiles[seat].Contains(tileType))
            {
                hold[tileType] = 0.01;
                wait[tileType] = Math.Clamp(readyProbability * 0.05 * (1.0 - noHu), 0.0, 0.12);
                continue;
            }

            var centerBias = rank is >= 3 and <= 7 ? 0.62 : rank is 2 or 8 ? 0.48 : 0.34;
            var visibleBias = Math.Max(0.05, 1.0 - state.Visible18[tileType] / 4.0);
            var sequenceAffinity = EstimateSequenceAffinity(state, seat, tileType);
            var wallScarcity = Math.Clamp(state.Remaining18[tileType] / 4.0, 0.0, 1.0);
            var posterior = centerBias * 0.28
                + visibleBias * 0.24
                + suitDemand[suit] * 0.30
                + pressure * 0.18
                + sequenceAffinity * 0.12
                + wallScarcity * 0.08
                - noHu * 0.22;
            posterior *= 1.0 - noHu * 0.42;
            posterior *= 1.0 - noPeng * 0.22;
            posterior *= 1.0 - noGang * 0.14;
            hold[tileType] = Math.Clamp((posterior * 0.48 + readyProbability * 0.24 + suitDemand[suit] * 0.20) * (1.0 - noPeng * 0.24) * (1.0 - noGang * 0.16), 0.01, 0.99);
            wait[tileType] = Math.Clamp(readyProbability * (posterior * 0.44 + suitDemand[suit] * 0.24 + sequenceAffinity * 0.20) * (1.0 - noHu * 0.76), 0.0, 0.98);
        }

        var wallPosterior = BuildWallPosterior(state, hold, seat);
        return new SichuanOpponentRangeProfile
        {
            Seat = seat,
            ReadyProbability = readyProbability,
            HoldProbability18 = hold,
            WaitProbability18 = wait,
            WallPosterior18 = wallPosterior,
            SuitDemand2 = suitDemand
        };
    }

    private static double EstimatePressure(SichuanStateView state, int seat, int discardCount, int meldGroupCount)
    {
        var wallPressure = state.WallCount <= 6 ? 0.16 : state.WallCount <= 10 ? 0.08 : 0.0;
        var pressure = 0.14
            + meldGroupCount * 0.14
            + (discardCount >= 10 ? 0.20 : discardCount >= 6 ? 0.11 : 0.0)
            + (state.IsCalled[seat] ? 0.18 : 0.0)
            + (state.IsReady[seat] ? 0.12 : 0.0)
            + wallPressure;
        return Math.Clamp(pressure, 0.05, 0.95);
    }

    private static double EstimateReadyProbability(SichuanStateView state, int seat, int discardCount, int meldGroupCount, double pressure)
    {
        if (state.IsReady[seat]) return 0.98;
        if (state.IsCalled[seat]) return 0.86;
        var posterior = 0.08
            + pressure * 0.42
            + meldGroupCount * 0.10
            + (discardCount >= 10 ? 0.16 : discardCount >= 7 ? 0.09 : 0.0)
            + (state.WallCount <= 6 ? 0.08 : state.WallCount <= 10 ? 0.04 : 0.0);
        return Math.Clamp(posterior, 0.04, 0.92);
    }

    private static double[] BuildWallPosterior(SichuanStateView state, double[] holdProbability, int seat)
    {
        var wallPosterior = new double[27];
        for (var tileType = 0; tileType < 27; tileType++)
        {
            var wallMass = Math.Max(0.01, state.Remaining18[tileType]);
            var seatMass = Math.Max(0.01, holdProbability[tileType]);
            wallPosterior[tileType] = Math.Clamp(wallMass / (wallMass + seatMass), 0.01, 0.98);
        }
        return wallPosterior;
    }

    private static double AverageVisibleScarcity(SichuanStateView state, int suit)
    {
        var start = suit * 9;
        var total = 0.0;
        for (var index = 0; index < 9; index++)
            total += Math.Max(0.0, 1.0 - state.Visible18[start + index] / 4.0);
        return total / 9.0;
    }

    private static double EstimateSequenceAffinity(SichuanStateView state, int seat, int tileType)
    {
        var suitStart = (tileType / 9) * 9;
        var rank = tileType % 9;
        var affinity = 0.0;
        if (rank - 2 >= 0)
            affinity += Math.Max(0.0, 1.0 - state.Visible18[suitStart + rank - 2] / 4.0) * 0.18;
        if (rank - 1 >= 0)
            affinity += Math.Max(0.0, 1.0 - state.Visible18[suitStart + rank - 1] / 4.0) * 0.26;
        if (rank + 1 < 9)
            affinity += Math.Max(0.0, 1.0 - state.Visible18[suitStart + rank + 1] / 4.0) * 0.26;
        if (rank + 2 < 9)
            affinity += Math.Max(0.0, 1.0 - state.Visible18[suitStart + rank + 2] / 4.0) * 0.18;
        if (state.IsCalled[seat] || state.IsReady[seat])
            affinity *= 1.06;
        return Math.Clamp(affinity, 0.0, 1.0);
    }
}
