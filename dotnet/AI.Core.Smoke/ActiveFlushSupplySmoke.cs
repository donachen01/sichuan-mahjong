using System.Text.Json;
using System.Text.RegularExpressions;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

internal static class ActiveFlushSupplySmoke
{
    public static int Run(string input, string output)
    {
        var failures = new List<object>(); int actual = 0, synthetic = 0, transitions = 0;
        using var document = JsonDocument.Parse(File.ReadAllText(input));
        var engine = new SichuanRoutePlanEngine();
        void Verify(SichuanStateView state, string origin)
        {
            var plan = engine.Evaluate(state);
            var other = Enumerable.Range(0, 4).Where(s => s != state.SeatIndex && state.ActiveSeats[s] && !state.HasHu[s]).ToArray();
            int supply = other.Count(s => state.DingQueSuits[s] == plan.TargetSuit);
            int competition = other.Count(s => state.DingQueSuits[s] != plan.TargetSuit);
            var reason = plan.Reasons.Single(s => s.Contains("门宽度："));
            var match = Regex.Match(reason, @"门宽度：(\d+) 家定缺，竞争 (\d+) 家");
            if (!match.Success || int.Parse(match.Groups[1].Value) != supply || int.Parse(match.Groups[2].Value) != competition)
                failures.Add(new { origin, reason, expectedSupply = supply, expectedCompetition = competition });
        }
        foreach (var row in document.RootElement.GetProperty("rows").EnumerateArray())
        {
            var state = PublicPosteriorNaturalStudy.State(row.GetProperty("public_input"));
            string id = row.GetProperty("input_sha256").GetString()!;
            Verify(state, "actual:" + id); actual++;
            var opponents = Enumerable.Range(0, 4).Where(s => s != state.SeatIndex).ToArray();
            var originalWon = state.HasHu.ToArray(); var originalActive = state.ActiveSeats.ToArray();
            // Deliberately cover both status fields independently: unknown/inactive
            // seats cannot supply merely because their historical declaration remains.
            for (int won = 0; won < 8; won++) for (int active = 0; active < 8; active++)
            {
                for (int i = 0; i < 3; i++)
                {
                    state.HasHu[opponents[i]] = (won & 1 << i) != 0;
                    state.ActiveSeats[opponents[i]] = (active & 1 << i) != 0;
                }
                Verify(state, $"status-only:{id}:{won}:{active}"); synthetic++;
            }
            Array.Copy(originalWon, state.HasHu, 4); Array.Copy(originalActive, state.ActiveSeats, 4);
            var brain = new SichuanRoundBrainEngine(); var before = brain.Observe(state);
            int departing = opponents.First();
            state.HasHu[departing] = true; state.ActiveSeats[departing] = false; state.EventVersion++;
            var after = brain.Observe(state); var current = engine.Evaluate(state);
            if (after.Revision <= before.Revision || after.RouteWeights.Count != current.RouteWeights.Count
                || current.RouteWeights.Any(p => !after.RouteWeights.TryGetValue(p.Key, out int v) || p.Value != v))
                failures.Add(new { origin = "latest-brain-after-exit:" + id });
            transitions++;
        }
        File.WriteAllText(output, JsonSerializer.Serialize(new { passed = failures.Count == 0, actualPublicRoots = actual,
            syntheticStatusCases = synthetic, latestBrainTransitions = transitions, failures,
            scope = "Actual extracted public roots plus synthetic status-only assertions. Counts and latest route weights, not independent worlds or strength. No requirement to abandon every still-feasible flush." }, new JsonSerializerOptions { WriteIndented = true }));
        Console.WriteLine($"ACTIVE_FLUSH_SUPPLY {(failures.Count == 0 ? "PASS" : "FAIL")} actual={actual} synthetic={synthetic} transitions={transitions} failures={failures.Count}");
        return failures.Count == 0 ? 0 : 1;
    }
}
