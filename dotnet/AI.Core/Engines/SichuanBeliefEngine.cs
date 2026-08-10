using System.Diagnostics;
using System.Text;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanBeliefEngine
{
    private const int CacheLimit = 256;
    private static readonly object CacheLock = new();
    private static readonly Dictionary<string, SichuanBeliefSnapshot> Cache = new();
    private static readonly Queue<string> CacheOrder = new();
    private static long _callCount;
    private static long _cacheHits;
    private static long _cacheMisses;
    private static long _buildCount;
    private static long _totalBuildMs;

    private readonly SichuanEvidenceEngine _evidence = new();
    private readonly SichuanOpponentRangeEngine _range = new();
    private readonly SichuanPosteriorNormalizer _normalizer = new();
    private readonly SichuanHiddenHandInferenceEngine _hiddenInference = new();

    public SichuanBeliefSnapshot Build(SichuanStateView state)
    {
        var cacheKey = BuildCacheKey(state);
        lock (CacheLock)
        {
            _callCount++;
            if (Cache.TryGetValue(cacheKey, out var cached))
            {
                _cacheHits++;
                return cached;
            }

            _cacheMisses++;
        }

        var stopwatch = Stopwatch.StartNew();
        var snapshot = BuildUncached(state);
        stopwatch.Stop();

        lock (CacheLock)
        {
            _buildCount++;
            _totalBuildMs += stopwatch.ElapsedMilliseconds;
            Cache[cacheKey] = snapshot;
            CacheOrder.Enqueue(cacheKey);
            while (CacheOrder.Count > CacheLimit)
            {
                var oldestKey = CacheOrder.Dequeue();
                Cache.Remove(oldestKey);
            }
        }

        return snapshot;
    }

    public static SichuanBeliefDiagnostics GetDiagnostics()
    {
        lock (CacheLock)
        {
            return new SichuanBeliefDiagnostics(
                _callCount,
                _cacheHits,
                _cacheMisses,
                _buildCount,
                _totalBuildMs,
                Cache.Count);
        }
    }

    public static void ResetDiagnostics()
    {
        lock (CacheLock)
        {
            _callCount = 0;
            _cacheHits = 0;
            _cacheMisses = 0;
            _buildCount = 0;
            _totalBuildMs = 0;
            Cache.Clear();
            CacheOrder.Clear();
        }
    }

    private SichuanBeliefSnapshot BuildUncached(SichuanStateView state)
    {
        var snapshot = new SichuanBeliefSnapshot();
        var evidence = _evidence.Build(state);
        var particleBudget = state.WallCount <= 12 ? 48 : 32;
        var particlePosterior = _hiddenInference.Infer(
            state,
            particleBudget,
            unchecked(20260713 + state.SeatIndex * 1009 + (int)(state.EventVersion % int.MaxValue)),
            SichuanInformationMode.Public);
        snapshot.Unknown18 = state.Remaining18.Take(27).Concat(Enumerable.Repeat(0, 27)).Take(27).ToArray();
        var seatWeightsByTile = new Dictionary<int, Dictionary<int, double>>();
        var activeSeats = new List<int>();
        for (var seat = 0; seat < 4; seat++)
        {
            if (seat == state.SeatIndex || state.HasHu[seat]) continue;
            activeSeats.Add(seat);
            var discards = state.Discards18[seat];
            var meldTiles = state.Melds18[seat];
            var discardCount = discards.Count;
            var meldGroupCount = meldTiles.Count / 3;
            var isAggressive = state.IsCalled[seat] || state.IsReady[seat];
            var range = _range.BuildSeatRange(state, evidence, seat);

            var wallPressure = state.WallCount <= 6 ? 0.16 : state.WallCount <= 10 ? 0.08 : 0.0;
            var pressure = 0.14
                + meldGroupCount * 0.14
                + (discardCount >= 10 ? 0.20 : discardCount >= 6 ? 0.11 : 0.0)
                + (state.IsCalled[seat] ? 0.18 : 0.0)
                + (state.IsReady[seat] ? 0.12 : 0.0)
                + wallPressure;
            pressure = Math.Clamp(pressure, 0.05, 0.95);
            snapshot.SeatPressure[seat] = pressure;
            snapshot.SeatReadyPosterior[seat] = Math.Clamp(
                range.ReadyProbability * 0.85 + particlePosterior.ReadyProbabilities[seat] * 0.15,
                0.0,
                0.99);

            var discardBySuit = new[] { 0, 0, 0 };
            var meldBySuit = new[] { 0, 0, 0 };
            var discardByTile = new int[27];
            foreach (var tileType in discards)
            {
                if (tileType is < 0 or >= 27) continue;
                discardBySuit[tileType / 9]++;
                discardByTile[tileType]++;
            }
            foreach (var tileType in meldTiles)
            {
                if (tileType is < 0 or >= 27) continue;
                meldBySuit[tileType / 9]++;
            }

            var exactSafeTiles = evidence.SeatExactSafeTiles[seat];
            snapshot.SeatExactSafeTiles[seat] = exactSafeTiles;

            var abandonedSuits = new HashSet<int>();
            var suitDemand = new Dictionary<int, double>();
            for (var suit = 0; suit < 3; suit++)
            {
                if (evidence.SeatAbandonedSuitEvidence[seat][suit] >= 0.56)
                    abandonedSuits.Add(suit);

                var meldFocus = meldTiles.Count == 0 ? 0.0 : meldBySuit[suit] / (double)meldTiles.Count;
                var visibleScarcity = AverageVisibleScarcity(state, suit);
                var heat = 0.24
                    + meldFocus * 0.34
                    + visibleScarcity * 0.18
                    + (isAggressive ? 0.08 : 0.0)
                    - discardBySuit[suit] * 0.09;
                suitDemand[suit] = range.SuitDemand2[suit];
            }
            snapshot.SeatAbandonedSuits[seat] = abandonedSuits;
            snapshot.SeatSuitDemand[seat] = suitDemand;
            BuildPublicReadFeatures(snapshot, state, seat, discards, meldTiles, abandonedSuits);

            var perTile = new Dictionary<int, double>();
            var holdWeights = new Dictionary<int, double>();
            var waitWeights = new Dictionary<int, double>();
            var noHuEvidence = new Dictionary<int, double>();
            for (var tileType = 0; tileType < 27; tileType++)
            {
                var suit = tileType / 9;
                var rank = tileType % 9 + 1;
                var noHu = evidence.SeatNoHuEvidence[seat][tileType];
                noHuEvidence[tileType] = noHu;
                if (exactSafeTiles.Contains(tileType))
                {
                    perTile[tileType] = 0.03;
                    holdWeights[tileType] = BlendPosterior(
                        range.HoldProbability18[tileType],
                        particlePosterior.HoldProbabilities[seat][tileType]);
                    waitWeights[tileType] = BlendPosterior(
                        range.WaitProbability18[tileType],
                        particlePosterior.WaitProbabilities[seat][tileType]);
                    continue;
                }

                var centerBias = rank is >= 3 and <= 7 ? 0.62 : rank is 2 or 8 ? 0.48 : 0.34;
                var visibleBias = Math.Max(0.05, 1.0 - state.Visible18[tileType] / 4.0);
                var nearDiscardPenalty = CountNearbyDiscards(discardByTile, tileType) * 0.08;
                var sameTilePenalty = discardByTile[tileType] * 0.24;
                var meldRankBoost = meldBySuit[suit] > 0 ? 0.08 : 0.0;
                var sequenceAffinity = EstimateSequenceAffinity(state, seat, tileType);
                var wallScarcity = Math.Clamp(state.Remaining18[tileType] / 4.0, 0.0, 1.0);
                var tileHeat = EstimateTileHeat(state, tileType);

                var posterior = centerBias * 0.28
                    + visibleBias * 0.24
                    + suitDemand[suit] * 0.30
                    + pressure * 0.18
                    + sequenceAffinity * 0.12
                    + wallScarcity * 0.08
                    + tileHeat * 0.06
                    + meldRankBoost
                    - nearDiscardPenalty
                    - sameTilePenalty;

                if (abandonedSuits.Contains(suit))
                    posterior *= 0.58;
                if (isAggressive)
                    posterior += 0.04;
                posterior *= 1.0 - noHu * 0.42;

                perTile[tileType] = Math.Clamp(posterior, 0.03, 0.98);
                holdWeights[tileType] = BlendPosterior(
                    range.HoldProbability18[tileType],
                    particlePosterior.HoldProbabilities[seat][tileType]);
                waitWeights[tileType] = BlendPosterior(
                    range.WaitProbability18[tileType],
                    particlePosterior.WaitProbabilities[seat][tileType]);
            }

            snapshot.SeatTileDanger[seat] = perTile;
            snapshot.SeatTileHoldProbability[seat] = holdWeights;
            snapshot.SeatTileWaitProbability[seat] = waitWeights;
            snapshot.SeatTileNoHuEvidence[seat] = noHuEvidence;
            seatWeightsByTile[seat] = holdWeights;
            snapshot.SeatThreatScore[seat] = Math.Clamp(
                pressure * 0.42
                + snapshot.SeatReadyPosterior[seat] * 0.24
                + suitDemand.Values.DefaultIfEmpty(0.0).Max() * 0.25
                + meldGroupCount * 0.08
                + (isAggressive ? 0.12 : 0.0),
                0.05,
                0.99);
        }

        BuildPosteriorMatrix(state, snapshot, activeSeats, seatWeightsByTile, particlePosterior, _normalizer);
        return snapshot;
    }

    private static void BuildPublicReadFeatures(
        SichuanBeliefSnapshot snapshot,
        SichuanStateView state,
        int seat,
        IReadOnlyList<int> discards,
        IReadOnlyList<int> meldTiles,
        IReadOnlySet<int> abandonedSuits)
    {
        var discardCount = Math.Max(1, discards.Count);
        var handCut = state.PublicEvents.Count(item =>
            item.Seat == seat && item.Type == SichuanPublicEventType.Discard && item.Origin == SichuanTileOrigin.Hand);
        var drawCut = state.PublicEvents.Count(item =>
            item.Seat == seat && item.Type == SichuanPublicEventType.Discard && item.Origin == SichuanTileOrigin.Draw);
        var rootCount = meldTiles.Count(tile => tile is >= 0 and < 27) / 3
            + (seat == state.SeatIndex ? state.Hand18.Count(tile => tile >= 3) : 0);
        var brokenLines = 0;
        var liveLines = 0;
        foreach (var tile in discards.Where(tile => tile is >= 0 and < 27).Distinct())
        {
            var rank = tile % 9;
            var hasLeft = rank > 0 && discards.Contains(tile - 1);
            var hasRight = rank < 8 && discards.Contains(tile + 1);
            if (hasLeft || hasRight) brokenLines++;
            if (!hasLeft && !hasRight) liveLines++;
        }
        snapshot.PublicReadFeatures[$"seat:{seat}:hand_cut_ratio"] = handCut / (double)discardCount;
        snapshot.PublicReadFeatures[$"seat:{seat}:draw_cut_ratio"] = drawCut / (double)discardCount;
        snapshot.PublicReadFeatures[$"seat:{seat}:筋线断张"] = Math.Clamp(brokenLines / 9.0, 0, 1);
        snapshot.PublicReadFeatures[$"seat:{seat}:孤张活性"] = Math.Clamp(liveLines / 9.0, 0, 1);
        snapshot.PublicReadFeatures[$"seat:{seat}:根潜力"] = Math.Clamp(rootCount / 6.0, 0, 1);
        snapshot.PublicReadFeatures[$"seat:{seat}:定缺竞争"] = Math.Clamp(
            abandonedSuits.Count == 0 ? 0 : abandonedSuits.Count / 3.0,
            0,
            1);
    }

    private static double BlendPosterior(double matureEstimate, double combinatoricEstimate)
        => Math.Clamp(matureEstimate * 0.85 + combinatoricEstimate * 0.15, 0.0, 0.99);

    private static string BuildCacheKey(SichuanStateView state)
    {
        var builder = new StringBuilder(512);
        builder.Append("seat=").Append(state.SeatIndex)
            .Append("|dealer=").Append(state.DealerSeat)
            .Append("|current=").Append(state.CurrentSeat)
            .Append("|wall=").Append(state.WallCount)
            .Append("|turn=").Append(state.TurnIndex)
            .Append("|phase=").Append(state.Phase)
            .Append("|event=").Append(state.EventVersion)
            .Append("|mode=").Append(state.InformationMode);
        AppendIntArray(builder, "|hand=", state.Hand18);
        AppendIntArray(builder, "|visible=", state.Visible18);
        AppendIntArray(builder, "|remaining=", state.Remaining18);
        AppendBoolArray(builder, "|called=", state.IsCalled);
        AppendBoolArray(builder, "|ready=", state.IsReady);
        AppendBoolArray(builder, "|hu=", state.HasHu);
        AppendListArray(builder, "|discards=", state.Discards18);
        AppendListArray(builder, "|melds=", state.Melds18);
        AppendMatrix(builder, "|passedHu=", state.PassedHu18);
        AppendMatrix(builder, "|passedPeng=", state.PassedPeng18);
        AppendMatrix(builder, "|passedGang=", state.PassedGang18);
        return builder.ToString();
    }

    private static void AppendIntArray(StringBuilder builder, string label, IReadOnlyList<int> values)
    {
        builder.Append(label);
        for (var index = 0; index < values.Count; index++)
        {
            if (index > 0) builder.Append(',');
            builder.Append(values[index]);
        }
    }

    private static void AppendBoolArray(StringBuilder builder, string label, IReadOnlyList<bool> values)
    {
        builder.Append(label);
        for (var index = 0; index < values.Count; index++)
        {
            if (index > 0) builder.Append(',');
            builder.Append(values[index] ? '1' : '0');
        }
    }

    private static void AppendListArray(StringBuilder builder, string label, IReadOnlyList<List<int>> values)
    {
        builder.Append(label);
        for (var seat = 0; seat < values.Count; seat++)
        {
            if (seat > 0) builder.Append('/');
            for (var index = 0; index < values[seat].Count; index++)
            {
                if (index > 0) builder.Append(',');
                builder.Append(values[seat][index]);
            }
        }
    }

    private static void AppendMatrix(StringBuilder builder, string label, IReadOnlyList<int[]> values)
    {
        builder.Append(label);
        for (var seat = 0; seat < values.Count; seat++)
        {
            if (seat > 0) builder.Append('/');
            for (var index = 0; index < values[seat].Length; index++)
            {
                if (index > 0) builder.Append(',');
                builder.Append(values[seat][index]);
            }
        }
    }

    private static void BuildPosteriorMatrix(
        SichuanStateView state,
        SichuanBeliefSnapshot snapshot,
        IReadOnlyList<int> activeSeats,
        IReadOnlyDictionary<int, Dictionary<int, double>> seatWeightsByTile,
        SichuanHiddenHandPosterior particlePosterior,
        SichuanPosteriorNormalizer normalizer)
    {
        var normalized = normalizer.Normalize(state, activeSeats, seatWeightsByTile);
        for (var tileType = 0; tileType < 27; tileType++)
        {
            if (state.WallCount <= 0)
            {
                snapshot.TileWallPosterior[tileType] = 0.0;
                continue;
            }
            var particleWallShare = state.Remaining18[tileType] <= 0
                ? 0.0
                : Math.Clamp(particlePosterior.WallProbabilities[tileType] / state.Remaining18[tileType], 0.0, 1.0);
            snapshot.TileWallPosterior[tileType] = Math.Clamp(
                normalized.WallProbability18[tileType] * 0.85 + particleWallShare * 0.15,
                0.0,
                0.98);
            foreach (var seat in activeSeats)
            {
                if (!snapshot.SeatTileHoldProbability.TryGetValue(seat, out var seatMap))
                    continue;
                if (normalized.SeatHoldProbability18.TryGetValue(seat, out var seatProbabilities))
                    seatMap[tileType] = Math.Clamp(seatProbabilities[tileType], 0.0, 0.98);
            }
        }
    }

    private static double EstimateReadyPosterior(SichuanStateView state, int seat, int discardCount, int meldGroupCount, double pressure)
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

    private static double AverageVisibleScarcity(SichuanStateView state, int suit)
    {
        var start = suit * 9;
        var total = 0.0;
        for (var index = 0; index < 9; index++)
        {
            total += Math.Max(0.0, 1.0 - state.Visible18[start + index] / 4.0);
        }
        return total / 9.0;
    }

    private static int CountNearbyDiscards(int[] discardByTile, int tileType)
    {
        var suit = tileType / 9;
        var rank = tileType % 9;
        var count = 0;
        for (var offset = -2; offset <= 2; offset++)
        {
            if (offset == 0) continue;
            var neighborRank = rank + offset;
            if (neighborRank is < 0 or >= 9) continue;
            count += discardByTile[suit * 9 + neighborRank];
        }
        return count;
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

    private static double EstimateTileHeat(SichuanStateView state, int tileType)
    {
        var suit = tileType / 9;
        var rank = tileType % 9;
        var heat = 0.0;
        for (var seat = 0; seat < state.Discards18.Length; seat++)
        {
            foreach (var discard in state.Discards18[seat])
            {
                if (discard / 9 != suit) continue;
                var gap = Math.Abs((discard % 9) - rank);
                if (gap == 0) heat -= 0.16;
                else if (gap == 1) heat += 0.08;
                else if (gap == 2) heat += 0.04;
            }
        }
        return Math.Clamp(0.5 + heat, 0.0, 1.0);
    }
}
