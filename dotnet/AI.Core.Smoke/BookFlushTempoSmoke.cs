using System.Text.Json;

internal static class BookFlushTempoSmoke
{
    public static int Run(string fixtures, string output)
    {
        try
        {
            using var file = JsonDocument.Parse(File.ReadAllText(fixtures));
            int checks = 0; var rows = new List<object>();
            void Check(bool ok, string message) { checks++; if (!ok) throw new Exception(message); }
            foreach (var f in file.RootElement.EnumerateArray())
            {
                int[] original = f.GetProperty("hand").EnumerateArray().Select(x => x.GetInt32()).ToArray();
                int[] originalExposed = f.GetProperty("exposed").EnumerateArray().Select(x => x.GetInt32()).ToArray();
                int target = f.GetProperty("target").GetInt32(), missing = f.GetProperty("missing").GetInt32();
                int groups = f.GetProperty("melds").GetInt32();
                int[] supply = f.TryGetProperty("supply", out var supplied)
                    ? supplied.EnumerateArray().Select(x => x.GetInt32()).ToArray()
                    : Enumerable.Range(0, 27).Select(t => 4 - original[t] - originalExposed[t]).ToArray();
                var wall = supply.Select(n => n * 30.0 / supply.Sum()).ToArray();
                var first = BookFlushTempoStudy.Assess(original, supply, originalExposed.ToArray(), groups, target, missing, wall);
                rows.Add(new { source = f.GetProperty("source").GetString(), assessment = first,
                    synthetic_supply = true, original_unknown_wall_not_reconstructed = true });
                foreach (var p in new int[][] { [0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0] })
                {
                    foreach (bool mirror in new[] { false, true })
                    {
                        int Map(int t) => p[t / 9] * 9 + (mirror ? 8 - t % 9 : t % 9);
                        int[] hand = new int[27], unseen = new int[27], exposed = new int[27]; var mass = new double[27];
                        for (int t = 0; t < 27; t++) { hand[Map(t)] = original[t]; unseen[Map(t)] = supply[t]; exposed[Map(t)] = originalExposed[t]; mass[Map(t)] = wall[t]; }
                        var oldHand = hand.ToArray(); var oldSupply = unseen.ToArray(); var oldExposed = exposed.ToArray();
                        var a = BookFlushTempoStudy.Assess(hand, unseen, exposed, groups, p[target], p[missing], mass);
                        Check(a.OrdinaryShanten == first.OrdinaryShanten && a.FlushDistance == first.FlushDistance, "route distance not invariant");
                        Check(hand.SequenceEqual(oldHand) && unseen.SequenceEqual(oldSupply) && exposed.SequenceEqual(oldExposed), "research mutated caller input");
                        Check(Math.Abs(a.JointWallMass - first.JointWallMass) < 1e-8 && Math.Abs(a.ConflictWallMass - first.ConflictWallMass) < 1e-8, "mass not invariant");
                        for (int t = 0; t < 27; t++)
                        {
                            Check(a.OrdinaryAfterDraw[Map(t)] == first.OrdinaryAfterDraw[t] && a.JointProgress[Map(t)] == first.JointProgress[t]
                                && a.RouteConflict[Map(t)] == first.RouteConflict[t] && a.FlushAtBestOrdinary[Map(t)] == first.FlushAtBestOrdinary[t], "draw event not invariant");
                            if (unseen[Map(t)] == 0) { Check(a.OrdinaryAfterDraw[Map(t)] == 9, "impossible fifth-copy draw examined"); continue; }
                            var drawn = hand.ToArray(); drawn[Map(t)]++;
                            bool clear = drawn.Skip(p[missing] * 9).Take(9).Sum() == 0;
                            bool win = clear && IndependentWin(drawn, groups);
                            Check((a.OrdinaryAfterDraw[Map(t)] == -1) == win, "one-draw Hu differs from independent decomposition");
                            if (win) continue;
                            bool ready = false;
                            for (int d = 0; d < 27; d++)
                            {
                                if (drawn[d] == 0 || !clear && d / 9 != p[missing]) continue;
                                drawn[d]--;
                                for (int w = 0; w < 27; w++)
                                {
                                    if (w / 9 == p[missing] || drawn[w] + exposed[w] >= 4) continue;
                                    drawn[w]++; ready |= IndependentWin(drawn, groups); drawn[w]--;
                                }
                                drawn[d]++;
                            }
                            Check((a.OrdinaryAfterDraw[Map(t)] == 0) == ready, "one-draw legal ready differs from independent completion; includes dead legal waits, excludes fifth copies");
                        }
                    }
                }
                var empty = BookFlushTempoStudy.Assess(original, new int[27], originalExposed.ToArray(), groups, target, missing, new double[27]);
                Check(empty.DrawTypesExamined == 0 && empty.PengProgressTiles.Length == 0 && empty.JointWallMass == 0, "exhausted supply fabricated a draw/claim");
            }
            File.WriteAllText(output, JsonSerializer.Serialize(new { checks, rows, passed = true,
                scope = "Book-derived synthetic public supply, six suit permutations and rank reflection; independent winning/ready decomposition oracle. Not complete original book worlds or strength." }, new JsonSerializerOptions { WriteIndented = true }));
            Console.WriteLine($"BOOK_FLUSH_TEMPO_FOCUSED PASS {checks}; independent win/ready oracle, suit/rank invariance and exhausted supply"); return 0;
        }
        catch (Exception e) { Console.Error.WriteLine(e); return 1; }
    }

    internal static bool IndependentWin(int[] input, int groups)
    {
        if (input.Sum() + groups * 3 != 14 || input.Any(n => n is < 0 or > 4)) return false;
        if (groups == 0 && input.All(n => n % 2 == 0)) return true;
        var c = input.ToArray();
        bool Sets(int left)
        {
            int t = Array.FindIndex(c, n => n > 0);
            if (t < 0) return left == 0;
            if (left == 0) return false;
            if (c[t] >= 3) { c[t] -= 3; bool ok = Sets(left - 1); c[t] += 3; if (ok) return true; }
            if (t % 9 <= 6 && c[t + 1] > 0 && c[t + 2] > 0)
            { c[t]--; c[t + 1]--; c[t + 2]--; bool ok = Sets(left - 1); c[t]++; c[t + 1]++; c[t + 2]++; if (ok) return true; }
            return false;
        }
        for (int p = 0; p < 27; p++)
        {
            if (c[p] < 2) continue; c[p] -= 2; bool ok = Sets(4 - groups); c[p] += 2; if (ok) return true;
        }
        return false;
    }
}
