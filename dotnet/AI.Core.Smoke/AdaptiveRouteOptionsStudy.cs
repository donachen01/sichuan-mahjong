using System.Security.Cryptography;
using System.Text.Json;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Strategy;

// Offline research only: the game does not reference this executable.
internal static class AdaptiveRouteOptionsStudy
{
    internal sealed record Point(int StandardShanten, int SevenPairsShanten, int FlushDistance);
    internal sealed record Choice(int Discard, Point Routes);
    internal sealed record Draw(int Tile, bool Hu, Point? WinningRoutes, Choice[] Choices,
        int BestStandardShanten, int[] OrdinaryFallbackDiscards, int[] JointProgressDiscards);
    internal sealed record Claim(int OfferedTile, Choice[] Choices, int[] OrdinaryFallbackDiscards);
    internal sealed record Options(Point Root, Draw[] Draws, Claim[] PengChannels,
        int[] OrdinaryProgressDraws, int[] JointProgressDraws);

    internal static Options Assess(int[] initial, int[] initialSupply, int[] exposed,
        int groups, int target, int missing)
    {
        if (initial.Length != 27 || initialSupply.Length != 27 || exposed.Length != 27
            || initial.Sum() + groups * 3 != 13 || groups is < 0 or > 4
            || target is < 0 or > 2 || missing is < -1 or > 2 || target == missing
            || Enumerable.Range(0, 27).Any(t => initial[t] < 0 || exposed[t] < 0
                || initialSupply[t] < 0 || initial[t] + exposed[t] + initialSupply[t] > 4
                || exposed[t] > 0 && t / 9 != target)
            || missing >= 0 && initial.Skip(missing * 9).Take(9).Any(n => n > 0))
            throw new ArgumentException("Expected a cleared, compatible, bounded waiting hand.");
        var shanten = new SichuanShantenEngine();
        var exact = new SichuanExactHandAnalyzer();
        var flush = new SichuanFlushStructureEngine();
        var hand = initial.ToArray(); var supply = initialSupply.ToArray(); var meld = exposed.ToArray();
        bool Clear() => missing < 0 || !hand.Skip(missing * 9).Take(9).Any(n => n > 0);
        bool Win(int g, bool allowPairs) => Clear() && exact.IsWinning(hand, g, allowPairs);
        // Standard Hu is deliberately separate from seven pairs. Dead but
        // physically legal waits still qualify for cha-jiao; a fifth copy does not.
        bool Ready(int g, bool pairs)
        {
            for (int t = 0; t < 27; t++)
            {
                if (t / 9 == missing || hand[t] + meld[t] >= 4) continue;
                hand[t]++; bool ok = pairs ? g == 0 && hand.All(n => n % 2 == 0) : Win(g, false); hand[t]--;
                if (ok) return true;
            }
            return false;
        }
        Point Describe(int g)
        {
            int standard = shanten.CalcStandardShanten(hand, g);
            if (standard == 0 && !Ready(g, false)) standard = 1;
            int pairs = g == 0 ? shanten.CalcSevenPairsShanten(hand) : -2;
            if (pairs == 0 && !Ready(g, true)) pairs = 1;
            var f = flush.Analyze(hand, supply, meld, target, g);
            return new(standard, pairs, f.MinimumAdditionalTiles);
        }
        Choice[] LegalDiscards(int g)
        {
            var choices = new List<Choice>();
            bool mustClear = !Clear();
            for (int discard = 0; discard < 27; discard++)
            {
                if (hand[discard] == 0 || mustClear && discard / 9 != missing) continue;
                hand[discard]--; choices.Add(new(discard, Describe(g))); hand[discard]++;
            }
            return choices.ToArray();
        }
        var root = Describe(groups);
        var draws = new List<Draw>();
        for (int t = 0; t < 27; t++)
        {
            if (supply[t] == 0) continue;
            hand[t]++; supply[t]--;
            if (Win(groups, groups == 0))
            {
                var winning = Describe(groups);
                draws.Add(new(t, true, winning, [], winning.StandardShanten, [], []));
            }
            else
            {
                var choices = LegalDiscards(groups);
                int best = choices.Min(c => c.Routes.StandardShanten);
                var fallback = choices.Where(c => c.Routes.StandardShanten == best).Select(c => c.Discard).ToArray();
                var joint = choices.Where(c => c.Routes.StandardShanten < root.StandardShanten
                    && root.FlushDistance > 0 && c.Routes.FlushDistance >= 0
                    && c.Routes.FlushDistance < root.FlushDistance).Select(c => c.Discard).ToArray();
                draws.Add(new(t, false, null, choices, best, fallback, joint));
            }
            hand[t]--; supply[t]++;
        }
        var pengs = new List<Claim>();
        if (groups < 4)
        for (int t = target * 9; t < target * 9 + 9; t++)
        {
            if (hand[t] < 2 || supply[t] == 0 || meld[t] > 0) continue;
            // Hypothetical offer, not an assertion that another seat will discard
            // it or that this seat will win priority. Source/priority are evaluated
            // when the actual offer arrives; seven pairs closes after this Peng.
            hand[t] -= 2; supply[t]--; meld[t] += 3;
            var choices = LegalDiscards(groups + 1);
            int best = choices.Min(c => c.Routes.StandardShanten);
            pengs.Add(new(t, choices, choices.Where(c => c.Routes.StandardShanten == best)
                .Select(c => c.Discard).ToArray()));
            hand[t] += 2; supply[t]++; meld[t] -= 3;
        }
        return new(root, draws.ToArray(), pengs.ToArray(),
            draws.Where(d => d.BestStandardShanten < root.StandardShanten).Select(d => d.Tile).ToArray(),
            draws.Where(d => d.JointProgressDiscards.Length > 0 || d.Hu
                && d.WinningRoutes!.FlushDistance == 0).Select(d => d.Tile).ToArray());
    }

    public static int Run(string input, string output)
    {
        try
        {
            using var data = JsonDocument.Parse(File.ReadAllText(input)); var rows = new List<object>();
            foreach (var row in data.RootElement.GetProperty("rows").EnumerateArray())
            {
                var state = PublicPosteriorNaturalStudy.State(row.GetProperty("public_input"));
                var exposed = new int[27];
                foreach (var m in SichuanFlushCopyCapacity.OwnMeldCopies(state)) exposed[m.Tile] += m.Copies;
                var meldSuits = Enumerable.Range(0, 27).Where(t => exposed[t] > 0)
                    .Select(t => t / 9).Distinct().ToArray();
                if (meldSuits.Length > 1) throw new Exception("No compatible flush route for mixed own melds");
                int target = meldSuits.Length == 1 ? meldSuits[0]
                    : Enumerable.Range(0, 3).Where(s => s != state.OwnDingQueSuit)
                        .OrderByDescending(s => state.Hand18.Skip(s * 9).Take(9).Sum()).First();
                var wall = new SichuanWallAvailabilityEngine().Build(state, new SichuanBeliefEngine().Build(state));
                var options = new List<object>();
                foreach (var c in row.GetProperty("native_public_predictor").GetProperty("candidates").EnumerateArray())
                {
                    double v = c.GetProperty("tileType").GetDouble();
                    if (v != Math.Floor(v) || v is < 0 or > 26) throw new Exception("Invalid tile");
                    int t = (int)v; var after = state.Hand18.ToArray();
                    if (after[t] == 0) throw new Exception("Invalid discard"); after[t]--;
                    options.Add(new { tile = t, options = Assess(after, state.Remaining18,
                        exposed, state.OwnMeldCount, target, state.OwnDingQueSuit) });
                }
                rows.Add(new { input_sha256 = row.GetProperty("input_sha256").GetString(),
                    target_suit = target, candidates = options, wall = wall.ExpectedCounts18,
                    known_wall = wall.KnownWallCounts18, public_only = true, outcomes_read = false });
            }
            File.WriteAllText(output, JsonSerializer.Serialize(new { rows,
                input_sha256 = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(input))).ToLowerInvariant(),
                meaning = "Concrete same-action standard/seven-pairs/flush structural options; not probabilities of claims, terminal wins, money or strength. Hypothetical future reactions require current priority checks."
            }, new JsonSerializerOptions { WriteIndented = true }));
            Console.WriteLine($"ADAPTIVE_ROUTE_OPTIONS PASS public_roots={rows.Count}; no future labels loaded"); return 0;
        }
        catch (Exception e) { Console.Error.WriteLine(e); return 1; }
    }
}
