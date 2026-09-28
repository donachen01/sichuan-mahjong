namespace SichuanMahjong.AI.Core.Engines;

// Opening-only own-draw model. Samples unseen tiles without replacement and
// uses the same draw sequence for all three missing-suit choices. It never
// receives opponents' hands or the real wall order; claims are not modeled.
internal sealed class SichuanDingQueRollout
{
    internal sealed record Comparison(double[] Costs, int Samples, int Horizon,
        int? PreferredSuit, double PairedAdvantage, double StandardError);
    private readonly SichuanShantenEngine _shanten = new();

    internal Comparison Compare(IReadOnlyList<int> source, int incumbent, int samples = 24, int horizon = 10)
    {
        var values = Enumerable.Range(0, 3).Select(_ => new double[samples]).ToArray();
        var pool = Enumerable.Range(0, 27).SelectMany(t => Enumerable.Repeat(t, 4-source[t])).ToArray();
        var random = new Random(20260928);
        for (var sample = 0; sample < samples; sample++)
        {
            var order = (int[])pool.Clone();
            for (var i = 0; i < Math.Min(horizon, order.Length); i++)
            {
                var j = random.Next(i, order.Length);
                (order[i], order[j]) = (order[j], order[i]);
            }
            for (var suit = 0; suit < 3; suit++)
            {
                var hand = source.ToArray();
                if (hand.Sum() == 14) Discard(hand, suit);
                var turn = 0;
                while (turn < horizon && Distance(hand, suit) > 0)
                {
                    hand[order[turn++]]++;
                    Discard(hand, suit);
                }
                // At a bounded horizon, retain remaining progress cost rather
                // than claiming an unfinished hand is a draw or a ready hand.
                values[suit][sample] = turn + 2*Math.Max(0, Distance(hand, suit));
            }
        }
        var means = values.Select(v => v.Average()).ToArray();
        var best = Enumerable.Range(0,3).OrderBy(s => means[s]).ThenBy(s => s).First();
        var deltas = Enumerable.Range(0,samples).Select(i => values[incumbent][i]-values[best][i]).ToArray();
        var advantage = deltas.Average();
        var se = Math.Sqrt(deltas.Sum(d => Math.Pow(d-advantage,2))/Math.Max(1,samples-1)/samples);
        // This remains an opening tempo estimate, so require a material paired
        // advantage before replacing the structural baseline.
        return new(means, samples, horizon,
            best != incumbent && advantage > Math.Max(.5, 2.4*se) ? best : null, advantage, se);
    }

    private int Distance(int[] hand, int missing)
    {
        var clean = (int[])hand.Clone();
        Array.Clear(clean, missing*9, 9);
        return _shanten.CalcBestShanten(clean);
    }

    private void Discard(int[] hand, int missing)
    {
        for (var tile = missing*9; tile < missing*9+9; tile++)
            if (hand[tile] > 0) { hand[tile]--; return; }
        var best = -1;
        var distance = int.MaxValue;
        var retainedShape = int.MinValue;
        for (var tile = 0; tile < 27; tile++)
        {
            if (hand[tile] == 0) continue;
            hand[tile]--;
            var next = _shanten.CalcBestShanten(hand);
            // Deterministic local continuation, using only this hand. The tie
            // break preserves pairs and adjacent tiles; it sees no future draw.
            var shape = 0;
            for (var t = 0; t < 27; t++)
            {
                if (hand[t] >= 2) shape += 2;
                if (t%9 < 8 && hand[t] > 0 && hand[t+1] > 0) shape++;
            }
            hand[tile]++;
            if (next < distance || next == distance && shape > retainedShape)
            { best=tile; distance=next; retainedShape=shape; }
        }
        if (best >= 0) hand[best]--;
    }
}
