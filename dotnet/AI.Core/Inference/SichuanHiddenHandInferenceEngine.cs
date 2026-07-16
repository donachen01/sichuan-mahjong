using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Inference;

public sealed class SichuanHiddenHandInferenceEngine
{
    private readonly SichuanExactHandAnalyzer _analyzer = new();
    private readonly SichuanShantenEngine _shanten = new();

    public SichuanHiddenHandPosterior Infer(
        SichuanStateView state,
        int particleCount = 256,
        int seed = 20260713,
        SichuanInformationMode mode = SichuanInformationMode.Public,
        IReadOnlyList<int[]>? oracleHands = null,
        IReadOnlyList<int>? oracleWall = null)
    {
        if (mode == SichuanInformationMode.Oracle && oracleHands is not null)
            return BuildOracle(state, oracleHands, oracleWall);

        particleCount = Math.Clamp(particleCount, 32, 4096);
        var random = new Random(seed ^ state.VisibleVersion ^ (state.SeatIndex << 16));
        var pool = Enumerable.Range(0, 27).Select(tile => Math.Max(0, state.Remaining18[tile])).ToArray();
        var handSizes = ResolveHiddenHandSizes(state);
        var particles = new List<SichuanHiddenHandParticle>(particleCount);
        for (var sample = 0; sample < particleCount; sample++)
        {
            var remaining = (int[])pool.Clone();
            var hands = Enumerable.Range(0, 4).Select(_ => new int[27]).ToArray();
            var logWeight = 0.0;
            var valid = true;
            foreach (var seat in Enumerable.Range(0, 4).Where(seat => seat != state.SeatIndex && !state.HasHu[seat]))
            {
                for (var draw = 0; draw < handSizes[seat]; draw++)
                {
                    var tile = WeightedDraw(remaining, state, seat, random);
                    if (tile < 0) { valid = false; break; }
                    hands[seat][tile]++;
                    remaining[tile]--;
                    logWeight += BehaviorLogLikelihood(state, seat, tile, hands[seat][tile]);
                }
                if (!valid) break;
            }
            if (!valid) continue;
            particles.Add(new SichuanHiddenHandParticle(hands, remaining, Math.Exp(Math.Clamp(logWeight, -30, 20))));
        }
        return Aggregate(state, particles);
    }

    private SichuanHiddenHandPosterior Aggregate(SichuanStateView state, IReadOnlyList<SichuanHiddenHandParticle> particles)
    {
        var hold = Enumerable.Range(0, 4).Select(_ => new double[27]).ToArray();
        var waits = Enumerable.Range(0, 4).Select(_ => new double[27]).ToArray();
        var routes = Enumerable.Range(0, 4).Select(_ => new double[5]).ToArray();
        var ready = new double[4];
        var wall = new double[27];
        var totalWeight = particles.Sum(item => item.Weight);
        if (totalWeight <= 0) totalWeight = 1;
        var sumSquares = 0.0;
        foreach (var particle in particles)
        {
            var weight = particle.Weight / totalWeight;
            sumSquares += weight * weight;
            for (var tile = 0; tile < 27; tile++) wall[tile] += particle.Wall27[tile] * weight;
            for (var seat = 0; seat < 4; seat++)
            {
                for (var tile = 0; tile < 27; tile++)
                    if (particle.Hands27[seat][tile] > 0) hold[seat][tile] += weight;
                var meldCount = Math.Max(0, state.Melds18[seat].Count / 3);
                var hand = particle.Hands27[seat];
                var isReady = _shanten.CalcBestShanten(hand, meldCount, meldCount == 0) == 0;
                if (isReady)
                {
                    ready[seat] += weight;
                    var seatWaits = _analyzer.EnumerateWaits(hand, particle.Wall27, meldCount);
                    foreach (var wait in seatWaits) waits[seat][wait.TileType] += weight;
                }
                var route = ClassifyRoute(hand, meldCount);
                routes[seat][route] += weight;
            }
        }
        return new SichuanHiddenHandPosterior(hold, ready, waits, routes, wall, particles.Count, sumSquares <= 0 ? 0 : 1.0 / sumSquares);
    }

    private SichuanHiddenHandPosterior BuildOracle(SichuanStateView state, IReadOnlyList<int[]> hands, IReadOnlyList<int>? wallSource)
    {
        var hold = Enumerable.Range(0, 4).Select(_ => new double[27]).ToArray();
        var waits = Enumerable.Range(0, 4).Select(_ => new double[27]).ToArray();
        var routes = Enumerable.Range(0, 4).Select(_ => new double[5]).ToArray();
        var ready = new double[4];
        var wall = Enumerable.Range(0, 27).Select(tile => wallSource is not null && tile < wallSource.Count ? Math.Max(0, wallSource[tile]) : 0.0).ToArray();
        for (var seat = 0; seat < Math.Min(4, hands.Count); seat++)
        {
            var hand = Normalize(hands[seat]);
            for (var tile = 0; tile < 27; tile++) hold[seat][tile] = hand[tile] > 0 ? 1 : 0;
			var remaining = wall.Select(value => (int)Math.Round(value)).ToArray();
            var seatWaits = _analyzer.EnumerateWaits(hand, remaining, state.Melds18[seat].Count / 3);
            ready[seat] = seatWaits.Count > 0 ? 1 : 0;
            foreach (var wait in seatWaits) waits[seat][wait.TileType] = 1;
            routes[seat][ClassifyRoute(hand, state.Melds18[seat].Count / 3)] = 1;
        }
        return new SichuanHiddenHandPosterior(hold, ready, waits, routes, wall, 1, 1);
    }

    private static int WeightedDraw(int[] remaining, SichuanStateView state, int seat, Random random)
    {
        var weights = new double[27];
        var total = 0.0;
        for (var tile = 0; tile < 27; tile++)
        {
            if (remaining[tile] <= 0) continue;
            var weight = remaining[tile] * BehaviorTileLikelihood(state, seat, tile);
            weights[tile] = weight;
            total += weight;
        }
        if (total <= 0) return -1;
        var target = random.NextDouble() * total;
        for (var tile = 0; tile < 27; tile++)
        {
            target -= weights[tile];
            if (target <= 0) return tile;
        }
        return Array.FindLastIndex(remaining, value => value > 0);
    }

    private static double BehaviorTileLikelihood(SichuanStateView state, int seat, int tile)
    {
        var suit = tile / 9;
        var weight = 1.0;
        if (state.DingQueSuits[seat] == suit) weight *= 0.22;
        var sameSuitDiscards = state.Discards18[seat].Count(value => value / 9 == suit);
        weight *= Math.Exp(-sameSuitDiscards * 0.035);
        var sameSuitMelds = state.Melds18[seat].Count(value => value / 9 == suit);
        weight *= 1 + sameSuitMelds * 0.08;
        if (state.PassedPeng18[seat][tile] > 0) weight *= 0.38;
        if (state.PassedGang18[seat][tile] > 0) weight *= 0.55;
        weight *= PublicEventLikelihood(state, seat, tile);
        return Math.Max(0.01, weight);
    }

    private static double PublicEventLikelihood(SichuanStateView state, int seat, int tile)
    {
        var likelihood = 1.0;
        var tileSuit = tile / 9;
        var start = Math.Max(0, state.PublicEvents.Count - 24);
        for (var index = start; index < state.PublicEvents.Count; index++)
        {
            var item = state.PublicEvents[index];
            if (item.Seat != seat) continue;
            var age = state.PublicEvents.Count - index;
            var recency = 0.45 + 0.55 * Math.Exp(-age / 8.0);
            if (item.Type == SichuanPublicEventType.Discard)
            {
                if (item.TileType == tile)
                {
                    var rejection = item.Origin == SichuanTileOrigin.Hand ? 0.50 : 0.76;
                    likelihood *= 1.0 - (1.0 - rejection) * recency;
                }
                else if (item.TileType / 9 == tileSuit && item.Origin == SichuanTileOrigin.Hand)
                {
                    likelihood *= 1.0 - 0.055 * recency;
                }
            }
            else if (item.Type == SichuanPublicEventType.Pass && item.TileType == tile)
            {
                if (item.CanPeng) likelihood *= 1.0 - 0.40 * recency;
                if (item.CanGang) likelihood *= 1.0 - 0.28 * recency;
                if (item.CanHu) likelihood *= 1.0 - 0.18 * recency;
            }
        }
        return Math.Clamp(likelihood, 0.08, 1.20);
    }

    private static double BehaviorLogLikelihood(SichuanStateView state, int seat, int tile, int copyIndex)
    {
        var log = Math.Log(BehaviorTileLikelihood(state, seat, tile));
        if (copyIndex >= 2 && state.PassedPeng18[seat][tile] > 0) log -= 1.0;
        if (copyIndex >= 3 && state.PassedGang18[seat][tile] > 0) log -= 1.2;
        return log * 0.12;
    }

    private static int[] ResolveHiddenHandSizes(SichuanStateView state)
    {
        var sizes = new int[4];
        for (var seat = 0; seat < 4; seat++)
        {
            if (seat == state.SeatIndex || state.HasHu[seat]) continue;
            sizes[seat] = state.HandCounts[seat] > 0 ? state.HandCounts[seat] : Math.Max(1, 13 - state.Melds18[seat].Count);
        }
        return sizes;
    }

    private static int ClassifyRoute(IReadOnlyList<int> hand, int meldCount)
    {
        var suitTotals = Enumerable.Range(0, 3).Select(suit => Enumerable.Range(suit * 9, 9).Sum(tile => hand[tile])).ToArray();
        if (suitTotals.Max() >= hand.Sum() - 2) return 1; // 清一色
        if (meldCount == 0 && hand.Count(value => value >= 2) >= 5) return 2; // 七对
        if (hand.Count(value => value >= 3) + meldCount >= 3) return 3; // 大对子
        return 0; // 快速平胡
    }

    private static int[] Normalize(IReadOnlyList<int> source)
        => Enumerable.Range(0, 27).Select(index => index < source.Count ? Math.Clamp(source[index], 0, 4) : 0).ToArray();
}
