using System.Text.Json;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

internal static class Chapter424CConditionsAudit
{
    private sealed record LiveProfile(string Name, int RemovalPerRecoveryKey, bool ExhaustAllRecoveryKeys);
    private sealed record DangerProfile(string Name, int ReadyOpponents, int CalledOpponents, int TurnIndex);

    public static int Run(string folder)
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(Path.Combine(folder, "4.2.4-fixtures.json")));
        var raw = doc.RootElement.EnumerateArray().Single(x => x.GetProperty("id").GetString() == "lower-13-4-13-C");
        var rows = new List<object>();
        var shiftSummaries = new List<object>();
        var errors = new List<string>();
        var checks = 0;
        void Check(bool ok, string name) { checks++; if (!ok) errors.Add(name); }

        var liveProfiles = new[]
        {
            new LiveProfile("normal", 0, false),
            new LiveProfile("thin", 1, false),
            new LiveProfile("exhausted_recovery", 0, true)
        };
        var wallTargets = new[] { 55, 32, 16, 8 };
        var dangerProfiles = new[]
        {
            new DangerProfile("quiet", 0, 0, 0),
            new DangerProfile("one_ready", 1, 1, 8),
            new DangerProfile("two_ready", 2, 2, 12)
        };
        var activeCounts = new[] { 4, 3, 2 };

        foreach (var shift in new[] { 0, 1, 2 })
        {
            var baseline = Chapter424Audit.Build(raw, shift);
            var baselineGang = new SichuanMeldCounterfactualEvaluator().Evaluate(
                baseline, "gang", Chapter424Audit.Map(raw.GetProperty("reaction_tile").GetInt32(), shift), 3, 1, 0, 0, 0);
            // Recovery keys are the specific replacement draws that already
            // produce a legal ready branch.  Including every draw with a
            // positive future ukeire would exhaust the whole wall and would
            // stop representing a finite public-depletion scenario.
            var recoveryKeys = baselineGang.ReplacementBranches
                .Where(b => !b.ImmediateWin && b.Shanten == 0)
                .Select(b => b.DrawTile)
                .Distinct()
                .ToArray();
            Check(recoveryKeys.Length > 0, $"s{shift} baseline has recovery keys");
            shiftSummaries.Add(new { shift, recoveryKeys, baselineGangShanten = baselineGang.Shanten, baselineGangLiveUkeire = baselineGang.LiveUkeire });

            foreach (var live in liveProfiles)
            foreach (var targetWall in wallTargets)
            foreach (var danger in dangerProfiles)
            foreach (var activeCount in activeCounts)
            {
                var state = BuildScenario(baseline, recoveryKeys, live, targetWall, danger, activeCount);
                var offer = Chapter424Audit.Map(raw.GetProperty("reaction_tile").GetInt32(), shift);
                var result = new SichuanReactionDecisionEngine().DecideReaction(state, offer, false, true, true, 1);
                var gang = new SichuanMeldCounterfactualEvaluator().Evaluate(state, "gang", offer, 3, 1, 0, 0, 0);
                var peng = new SichuanMeldCounterfactualEvaluator().Evaluate(state, "peng", offer, 2, 1, 0, 0, 0,
                    plannedDiscardTile: result.PlannedDiscardTile);
                var belief = new SichuanBeliefEngine().Build(state);
                var stage = new SichuanStageEvaluator().Evaluate(state, belief);
                var opponents = new SichuanOpponentDangerEvaluator().Evaluate(state, belief, stage);
                var maxThreat = opponents.Values.DefaultIfEmpty().Max(x => x?.DangerLevel ?? 0);

                Check(state.Remaining18.Sum() == state.WallCount + state.HandCounts.Skip(1).Sum(),
                    $"s{shift}/{live.Name}/{targetWall}/{danger.Name}/{activeCount} pool conservation");
                Check(result.Action.ActionType is SichuanActionType.Peng or SichuanActionType.Gang or SichuanActionType.Pass,
                    $"s{shift}/{live.Name}/{targetWall}/{danger.Name}/{activeCount} legal action");
                Check(gang.ReplacementBranches.Sum(b => b.Weight) is > 0.999999 and < 1.000001,
                    $"s{shift}/{live.Name}/{targetWall}/{danger.Name}/{activeCount} branch normalization");

                rows.Add(new
                {
                    shift,
                    liveProfile = live.Name,
                    targetWall,
                    actualWall = state.WallCount,
                    danger = danger.Name,
                    activeCount,
                    action = result.Action.ActionType.ToString(),
                    actionScores = result.ActionScores,
                    scoreDeltaGangMinusPeng = result.ActionScores.GetValueOrDefault("gang") - result.ActionScores.GetValueOrDefault("peng"),
                    pengShanten = peng.Shanten,
                    pengLiveUkeire = peng.LiveUkeire,
                    gangShanten = gang.Shanten,
                    gangLiveUkeire = gang.LiveUkeire,
                    gangValue = gang.Value,
                    gangImmediateGain = gang.ImmediateGangGain,
                    gangReplacementWinProbability = gang.ReplacementWinProbability,
                    gangReadyMass = gang.ReplacementBranches.Where(b => b.Shanten == 0 && b.LiveUkeire > 0).Sum(b => b.Weight),
                    gangDeadReadyMass = gang.ReplacementBranches.Where(b => b.Shanten == 0 && b.LiveUkeire <= 0).Sum(b => b.Weight),
                    gangUnreadyMass = gang.ReplacementBranches.Where(b => b.Shanten > 0).Sum(b => b.Weight),
                    maxThreat,
                    reasons = result.Reasons.Take(8).ToArray()
                });
            }
        }

        var report = new
        {
            auditOnly = true,
            checks,
            errors,
            cases = rows.Count,
            strategyVersion = SichuanStrategyContract.Version,
            recoveryKeyMethod = "baseline 4-13C gang branches with ready or positive live ukeire; thin removes one public remaining copy per key; exhausted removes all",
            scope = "Condition matrix for 4-13C. It measures current local counterfactual and reaction choices, not calibrated terminal EV; no production policy change.",
            shiftSummaries
        };
        File.WriteAllText(Path.Combine(folder, "chapter424c-conditions.json"), JsonSerializer.Serialize(new { report, rows }, new JsonSerializerOptions { WriteIndented = true }));

        var pengCount = rows.Count(x => x.ToString()!.Contains("action = Peng", StringComparison.Ordinal));
        var gangCount = rows.Count(x => x.ToString()!.Contains("action = Gang", StringComparison.Ordinal));
        Console.WriteLine($"CHAPTER424C_CONDITIONS cases={rows.Count} checks={checks} errors={errors.Count} peng={pengCount} gang={gangCount}");
        foreach (var error in errors.Take(12)) Console.WriteLine(error);
        return errors.Count == 0 ? 0 : 1;
    }

    private static SichuanStateView BuildScenario(
        SichuanStateView baseline,
        IReadOnlyList<int> recoveryKeys,
        LiveProfile live,
        int targetWall,
        DangerProfile danger,
        int activeCount)
    {
        var remaining = (int[])baseline.Remaining18.Clone();
        var visible = (int[])baseline.Visible18.Clone();
        foreach (var tile in recoveryKeys)
        {
            var remove = live.ExhaustAllRecoveryKeys ? remaining[tile] : Math.Min(live.RemovalPerRecoveryKey, remaining[tile]);
            remaining[tile] -= remove;
            visible[tile] += remove;
        }

        var neutral = Enumerable.Range(0, 27)
            .Where(tile => !recoveryKeys.Contains(tile) && baseline.Hand18[tile] == 0)
            .OrderBy(tile => tile)
            .ToArray();
        var currentWall = remaining.Sum() - baseline.HandCounts.Skip(1).Sum();
        var desiredWall = Math.Min(targetWall, currentWall);
        var trim = Math.Max(0, currentWall - desiredWall);
        foreach (var tile in neutral)
        {
            if (trim <= 0) break;
            var remove = Math.Min(trim, remaining[tile]);
            remaining[tile] -= remove;
            visible[tile] += remove;
            trim -= remove;
        }

        var active = Enumerable.Range(0, 4).Select(seat => seat < activeCount).ToArray();
        var ready = new bool[4];
        var called = new bool[4];
        for (var seat = 1; seat <= danger.ReadyOpponents && seat < 4; seat++)
        {
            ready[seat] = true;
            called[seat] = seat <= danger.CalledOpponents;
        }

        var rebuilt = SichuanStateCodec.FromRaw(
            baseline.SeatIndex, baseline.DealerSeat, baseline.CurrentSeat,
            remaining.Sum() - baseline.HandCounts.Skip(1).Sum(),
            baseline.Hand18, visible, remaining,
            baseline.Discards18.Select(x => x.AsEnumerable()),
            baseline.Melds18.Select(x => x.AsEnumerable()),
            dingQueSuits: baseline.DingQueSuits,
            handCounts: baseline.HandCounts,
            activeSeats: active,
            eventVersion: baseline.EventVersion + danger.TurnIndex + activeCount,
            informationMode: baseline.InformationMode);
        for (var seat = 0; seat < 4; seat++) rebuilt.MeldViews[seat].AddRange(baseline.MeldViews[seat]);
        rebuilt.PublicEvents.AddRange(baseline.PublicEvents);
        rebuilt.TurnIndex = danger.TurnIndex;
        rebuilt.IsReady.AsSpan().Clear();
        rebuilt.IsCalled.AsSpan().Clear();
        ready.CopyTo(rebuilt.IsReady, 0);
        called.CopyTo(rebuilt.IsCalled, 0);
        return rebuilt;
    }
}
