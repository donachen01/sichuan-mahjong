using System.Diagnostics;
using System.Security.Cryptography;
using System.Text.Json;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Strategy;

// Research executable only. This is not referenced by the game or a release AI.
internal static class BookFlushTempoStudy
{
    internal sealed record Tempo(int OrdinaryShanten, int FlushDistance,
        int[] OrdinaryAfterDraw, int[] FlushAtBestOrdinary, bool[] JointProgress,
        bool[] RouteConflict, int[] PengProgressTiles,
        double JointWallMass, double ConflictWallMass, int DrawTypesExamined);

    internal static Tempo Assess(int[] initial, int[] initialSupply, int[] exposed,
        int melds, int target, int missing, double[] wall)
    {
        if (initial.Length != 27 || initialSupply.Length != 27 || exposed.Length != 27 || wall.Length != 27
            || initial.Sum() + melds * 3 != 13 || target == missing || target is < 0 or > 2
            || Enumerable.Range(0, 27).Any(t => initial[t] < 0 || initialSupply[t] < 0 ||
                initial[t] + exposed[t] + initialSupply[t] > 4 || exposed[t] > 0 && t / 9 != target))
            throw new ArgumentException("Expected a public, physically bounded, compatible waiting hand.");
        var shanten = new SichuanShantenEngine();
        var flush = new SichuanFlushStructureEngine();
        var hand = initial.ToArray(); var supply = initialSupply.ToArray();
        var exact = new SichuanExactHandAnalyzer();
        int Distance(int groups)
        {
            int n = shanten.CalcBestShanten(hand, groups);
            if (n != 0 || hand.Sum() + 3 * groups != 13) return n;
            // Shanten alone does not subtract own exposed copies. A fifth-copy
            // pseudo-wait is not a ready continuation; publicly dead legal waits
            // remain ready for cha-jiao, so use physical capacity, not live supply.
            for (int t = 0; t < 27; t++)
            {
                if (t / 9 == missing || hand[t] + exposed[t] >= 4) continue;
                hand[t]++; bool win = exact.IsWinning(hand, groups, groups == 0); hand[t]--;
                if (win) return 0;
            }
            return 1;
        }
        int Normal() => Distance(melds);
        var normal = Normal();
        var root = flush.Analyze(hand, supply, exposed, target, melds);
        var levels = Enumerable.Repeat(9, 27).ToArray();
        var jointDistances = Enumerable.Repeat(-1, 27).ToArray();
        var joint = new bool[27]; var conflicts = new bool[27]; var examined = 0;
        for (int draw = 0; draw < 27; draw++)
        {
            if (supply[draw] == 0 || hand[draw] + exposed[draw] >= 4) continue;
            examined++; hand[draw]++; supply[draw]--;
            // A legal ordinary win is terminal for this local opportunity. Never
            // require discarding it merely to make a flush descriptor look better.
            bool clear = missing < 0 || hand.Skip(missing * 9).Take(9).Sum() == 0;
            if (clear && Normal() < 0)
            {
                levels[draw] = -1;
                bool sameSuit = hand.Where((n, t) => n > 0 && t / 9 != target).Any() == false;
                jointDistances[draw] = sameSuit ? 0 : -1;
                joint[draw] = sameSuit && root.FeasiblePatterns > 0 && root.MinimumAdditionalTiles > 0;
                conflicts[draw] = !sameSuit;
            }
            else
            {
                bool mustClear = missing >= 0 && hand.Skip(missing * 9).Take(9).Sum() > 0;
                var choices = new List<(int Tile, int Level)>();
                for (int discard = 0; discard < 27; discard++)
                {
                    if (hand[discard] == 0 || mustClear && discard / 9 != missing) continue;
                    hand[discard]--; choices.Add((discard, Normal())); hand[discard]++;
                }
                var bestNormal = choices.Min(c => c.Level);
                levels[draw] = bestNormal;
                int closest = int.MaxValue;
                // Compare the SAME continuation action for both routes. Taking
                // a separate best discard for each would manufacture compatibility.
                foreach (var option in choices.Where(c => c.Level == bestNormal))
                {
                    hand[option.Tile]--;
                    var f = flush.Analyze(hand, supply, exposed, target, melds);
                    if (f.FeasiblePatterns > 0) closest = Math.Min(closest, f.MinimumAdditionalTiles);
                    hand[option.Tile]++;
                }
                if (closest != int.MaxValue) jointDistances[draw] = closest;
                joint[draw] = root.FeasiblePatterns > 0 && closest < root.MinimumAdditionalTiles && bestNormal < normal;
                conflicts[draw] = root.FeasiblePatterns > 0 && bestNormal < normal && closest > root.MinimumAdditionalTiles;
            }
            hand[draw]--; supply[draw]++;
        }
        var claims = new List<int>();
        if (melds < 4 && (missing < 0 || hand.Skip(missing * 9).Take(9).Sum() == 0))
        for (int offered = target * 9; offered < target * 9 + 9; offered++)
        {
            if (hand[offered] < 2 || supply[offered] == 0 || exposed[offered] > 0) continue;
            hand[offered] -= 2; supply[offered]--; exposed[offered] += 3;
            bool helpful = false;
            for (int discard = 0; discard < 27; discard++)
            {
                if (hand[discard] == 0) continue;
                hand[discard]--;
                var f = flush.Analyze(hand, supply, exposed, target, melds + 1);
                if (root.FeasiblePatterns > 0 && f.FeasiblePatterns > 0 && f.MinimumAdditionalTiles < root.MinimumAdditionalTiles
                    && Distance(melds + 1) <= normal) helpful = true;
                hand[discard]++;
            }
            exposed[offered] -= 3; supply[offered]++; hand[offered] += 2;
            if (helpful) claims.Add(offered);
        }
        return new(normal, root.MinimumAdditionalTiles, levels, jointDistances, joint, conflicts,
            claims.ToArray(), Enumerable.Range(0, 27).Where(t => joint[t]).Sum(t => wall[t]),
            Enumerable.Range(0, 27).Where(t => conflicts[t]).Sum(t => wall[t]), examined);
    }

    public static int Run(string input, string output)
    {
        try
        {
            using var data = JsonDocument.Parse(File.ReadAllText(input)); var rows = new List<object>();
            var watch = Stopwatch.StartNew();
            foreach (var row in data.RootElement.GetProperty("rows").EnumerateArray())
            {
                // This file contains extracted public inputs, not physical game snapshots.
                var state = PublicPosteriorNaturalStudy.State(row.GetProperty("public_input"));
                int target = Enumerable.Range(0, 3).Where(s => s != state.OwnDingQueSuit)
                    .OrderByDescending(s => state.Hand18.Skip(s * 9).Take(9).Sum()).First();
                var exposed = new int[27];
                foreach (var meld in SichuanFlushCopyCapacity.OwnMeldCopies(state)) exposed[meld.Tile] += meld.Copies;
                var wall = new SichuanWallAvailabilityEngine().Build(state, new SichuanBeliefEngine().Build(state));
                var candidates = new List<object>();
                foreach (var candidate in row.GetProperty("native_public_predictor").GetProperty("candidates").EnumerateArray())
                {
                    double encoded = candidate.GetProperty("tileType").GetDouble();
                    if (encoded != Math.Floor(encoded) || encoded is < 0 or > 26) throw new Exception("Invalid candidate tile");
                    int tile = (int)encoded; var after = state.Hand18.ToArray();
                    if (after[tile] <= 0) throw new Exception("Discard does not exist"); after[tile]--;
                    candidates.Add(new { tileType = tile, tempo = Assess(after, state.Remaining18, exposed.ToArray(),
                        state.OwnMeldCount, target, state.OwnDingQueSuit, wall.ExpectedCounts18) });
                }
                rows.Add(new { input_sha256 = row.GetProperty("input_sha256").GetString(),
                    seed = row.GetProperty("seed").GetInt32(), target_suit = target, candidates,
                    public_only = true, terminal_outcomes_read = false });
            }
            File.WriteAllText(output, JsonSerializer.Serialize(new {
                stage = "research_only_book_joint_tempo_features", rows,
                public_file_sha256 = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(input))).ToLowerInvariant(),
                elapsed_seconds = watch.Elapsed.TotalSeconds,
                meaning = "One next-draw plus legal discard structural compatibility; wall mass remains uncalibrated. Peng descriptors are possible channels, not claim probabilities or legal reaction decisions. No terminal rollout."
            }, new JsonSerializerOptions { WriteIndented = true }));
            Console.WriteLine($"BOOK_FLUSH_TEMPO public_nodes={rows.Count} elapsed={watch.Elapsed.TotalSeconds:F2}s; no hidden state or outcomes read");
            return 0;
        }
        catch (Exception e) { Console.Error.WriteLine(e); return 1; }
    }
}
