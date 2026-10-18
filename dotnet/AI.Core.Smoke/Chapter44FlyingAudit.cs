using System.Text.Json;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class Chapter44FlyingAudit
{
    public static int Run(string folder)
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(Path.Combine(folder, "4.4-fixtures.json")));
        var rows = new List<object>();
        var errors = new List<string>();
        var checks = 0;
        void Check(bool ok, string name) { checks++; if (!ok) errors.Add(name); }

        foreach (var raw in doc.RootElement.EnumerateArray())
        {
            if (!raw.TryGetProperty("reaction_tile", out var offered))
            {
                for (var shift = 0; shift < 3; shift++)
                {
                    var state = Build(raw, shift);
                    var drawTile = Map(raw.GetProperty("case").GetString() == "4-24" ? 16 : 11, shift);
                    state.LastDrawTileType = drawTile;
                    var result = new SichuanAiFacade().DecideSelfAction(state, true, Array.Empty<int>(), Array.Empty<int>());
                    var id = $"{raw.GetProperty("id").GetString()}-s{shift}";
                    Check(state.Hand18.Sum() + state.OwnMeldCount * 3 == 14, id + " self-draw hand/meld count");
                    Check(result.Action.ActionType == SichuanActionType.Hu, id + " self-draw production Hu");
                    Check(result.Action.TileType == drawTile, id + " self-draw tile preserved");
                    rows.Add(new
                    {
                        id,
                        sourceNote = raw.GetProperty("note").GetString(),
                        kind = "self_action",
                        sourceExpected = "Hu",
                        drawTile,
                        productionAction = result.Action.ActionType.ToString(),
                        productionDiscard = -1,
                        policyAdmissible = true,
                        reasons = result.Reasons
                    });
                }
                continue;
            }
            for (var shift = 0; shift < 3; shift++)
            {
                var state = Build(raw, shift);
                var tile = Map(offered.GetInt32(), shift);
                var evidence = new SichuanDevelopmentPolicy().AssessRefusal(state, tile, SichuanWinType.Discard);
                var policy = new SichuanFlyingDecisionPolicy().Decide(state, tile, 1, evidence);
                var reaction = new SichuanReactionDecisionEngine().DecideReaction(
                    state, tile, true, true, false, 1, "discard", forceLightweight: true);

                Check(state.Hand18.Sum() + state.OwnMeldCount * 3 == 13,
                    $"{raw.GetProperty("case").GetString()}-s{shift} hand/meld count");
                Check(policy.Branches.All(branch => branch.Shanten == 0),
                    $"{raw.GetProperty("case").GetString()}-s{shift} branch re-tenpai");
                Check(policy.Branches.All(branch => branch.DiscardTile is >= 0 and < 27),
                    $"{raw.GetProperty("case").GetString()}-s{shift} branch discard legal range");
                Check(policy.Branches.All(branch => !branch.Reasons.Contains("PENG_THEN_IMMEDIATE_ADDED_GANG")),
                    $"{raw.GetProperty("case").GetString()}-s{shift} no immediate added Gang");
                Check(reaction.Action.ActionType is SichuanActionType.Hu or SichuanActionType.Peng or SichuanActionType.Pass,
                    $"{raw.GetProperty("case").GetString()}-s{shift} reaction legal");
                if (reaction.Action.ActionType == SichuanActionType.Peng)
                    Check(reaction.PlannedDiscardTile is >= 0 and < 27,
                        $"{raw.GetProperty("case").GetString()}-s{shift} production Peng has first discard");
                if (policy.IsAdmissible)
                {
                    Check(reaction.Action.ActionType == SichuanActionType.Peng,
                        $"{raw.GetProperty("case").GetString()}-s{shift} admissible flight reaches production Peng");
                    Check(reaction.PlannedDiscardTile == policy.DiscardTile,
                        $"{raw.GetProperty("case").GetString()}-s{shift} production first discard matches flight policy");
                }
                var sourceCase = raw.GetProperty("case").GetString() ?? string.Empty;
                if (sourceCase is "4-22" or "4-23")
                {
                    Check(policy.Branches.Any(branch => branch.FutureGangOptionCount > 0
                        && branch.FutureGangValue > 0),
                        $"{sourceCase}-s{shift} retains future natural Gang opportunity");
                    Check(policy.IsAdmissible && reaction.Action.ActionType == SichuanActionType.Peng,
                        $"{sourceCase}-s{shift} edge flight with future Gang reaches Peng");
                }

                rows.Add(new
                {
                    id = $"{raw.GetProperty("id").GetString()}-s{shift}",
                    sourceNote = raw.GetProperty("note").GetString(),
                    offered = tile,
                    policyAdmissible = policy.IsAdmissible,
                    selectedDiscard = policy.DiscardTile,
                    policyValue = policy.Value,
                    immediateHu = policy.ImmediateHuValue,
                    branchCount = policy.Branches.Count,
                    branches = policy.Branches.Select(branch => new
                    {
                        branch.DiscardTile, branch.Shanten, branch.WaitCount,
                        branch.BeforeWaitCount, branch.DrawableMass,
                        branch.BeforeDrawableMass, branch.WeightedWaitDelta,
                        branch.CounterfactualValue, branch.FutureGangProbability,
                        branch.FutureGangValue, branch.FutureGangOptionCount,
                        branch.RewaitWeightedFan, branch.RewaitSelfDrawPerPayer,
                        branch.RewaitWeightedHandScore, branch.FutureSelfDrawValue,
                        branch.Danger,
                        branch.Broadens, branch.IsAdmissible, branch.Reasons
                    }).ToArray(),
                    productionAction = reaction.Action.ActionType.ToString(),
                    productionDiscard = reaction.PlannedDiscardTile,
                    reasons = policy.Reasons
                });
            }
        }

        var report = new
        {
            auditOnly = false,
            checks,
            errors,
            cases = rows.Count,
            strategyVersion = SichuanStrategyContract.Version,
            policy = "FLYING_PENG_DISCARD_REENTER_TENPAI",
            scope = "All five 4.4 source-shaped examples: reaction flight chains plus self-draw Hu entries; verifies current production action and legal timing, not hidden-hand source-action identity."
        };
        File.WriteAllText(Path.Combine(folder, "chapter44-flying-audit.json"),
            JsonSerializer.Serialize(new { report, rows }, new JsonSerializerOptions { WriteIndented = true }));
        Console.WriteLine($"CHAPTER44_FLYING cases={rows.Count} checks={checks} errors={errors.Count}");
        foreach (var error in errors.Take(12)) Console.WriteLine(error);
        return errors.Count == 0 ? 0 : 1;
    }

    private static int Map(int tile, int shift) => tile < 0 ? tile : ((tile / 9 + shift) % 3) * 9 + tile % 9;

    private static SichuanStateView Build(JsonElement raw, int shift)
    {
        int[] A(string key) => raw.GetProperty(key).EnumerateArray().Select(x => x.GetInt32()).ToArray();
        var sourceHand = A("hand18");
        var hand = new int[27];
        for (var t = 0; t < 27; t++) hand[Map(t, shift)] = sourceHand[t];

        var melds = raw.GetProperty("typed_melds").EnumerateArray()
            .Select(m => new SichuanMeldView(
                Enum.Parse<SichuanMeldType>(m.GetProperty("type").GetString()!, true),
                Map(m.GetProperty("tiles")[0].GetInt32(), shift),
                m.GetProperty("type").GetString() == "peng" ? 1 : -1, 0))
            .ToArray();
        var visible = new int[27];
        foreach (var meld in melds) visible[meld.TileType] += meld.Type == SichuanMeldType.Peng ? 3 : 4;
        var remaining = Enumerable.Range(0, 27).Select(t => Math.Max(0, 4 - hand[t] - visible[t])).ToArray();
        var hasReaction = raw.TryGetProperty("reaction_tile", out _);
        var wall = Math.Max(1, remaining.Sum() - 39 - (hasReaction ? 1 : 0));
        var state = SichuanStateCodec.FromRaw(0, 0, hasReaction ? 1 : 0, wall, hand, visible, remaining,
            dingQueSuits: new[] { -1, -1, -1, -1 },
            handCounts: new[] { hand.Sum(), 13, 13, 13 },
            activeSeats: new[] { true, true, true, true });
        state.MeldViews[0].AddRange(melds);

        if (hasReaction)
        {
            var offered = Map(raw.GetProperty("reaction_tile").GetInt32(), shift);
            state.Visible18[offered]++;
            state.Remaining18[offered] = Math.Max(0, state.Remaining18[offered] - 1);
            state.PublicEvents.Add(new(1, 1, 1, SichuanPublicEventType.Discard, offered,
                SichuanTileOrigin.Draw, 1));
        }
        else
        {
            state.LastDrawOrigin = SichuanTileOrigin.Draw;
            state.OwnDrawReason = "normal_draw";
            state.Phase = 5;
        }
        return state;
    }
}
