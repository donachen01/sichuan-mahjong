using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

namespace SichuanMahjong.AI.Core.Evaluation;

public sealed record SichuanOfflineActionValue(
    string Action,
    double Value,
    int Shanten,
    int LiveUkeire,
    int BestDiscardTile,
    double ImmediateWinProbability,
    string Transition);

/// <summary>
/// Offline judge for action timing and coarse terminal value. It deliberately
/// does not call the production decision or meld-value engines.
/// </summary>
public sealed class SichuanOfflineCounterfactualEvaluator
{
    private readonly SichuanActionTransitionEngine _transitions = new();
    private readonly SichuanExactHandAnalyzer _hands = new();
    private readonly SichuanShantenEngine _shanten = new();

    public SichuanOfflineActionValue EvaluateReactionPass(SichuanStateView state)
    {
        var source = _transitions.FromState(state);
        var passed = _transitions.ApplyPass(source);
        return EvaluateWaiting(state, passed.Hand27, passed.MeldCount, "pass", "pass_wait_draw");
    }

    public SichuanOfflineActionValue EvaluatePeng(SichuanStateView state, int tileType)
    {
        var claimed = _transitions.ApplyPeng(_transitions.FromState(state), tileType);
        return EvaluateImmediateDiscard(state, claimed.Hand27, claimed.MeldCount, "peng", "peng_then_discard");
    }

    public SichuanOfflineActionValue EvaluateMeldedGang(SichuanStateView state, int tileType)
    {
        var gang = _transitions.ApplyMeldedGang(_transitions.FromState(state), tileType);
        return EvaluateReplacementDraw(state, gang, "gang", immediateGangGain: 2.0);
    }

    public SichuanOfflineActionValue EvaluateSelfContinue(SichuanStateView state)
    {
        var source = _transitions.FromState(state);
        return EvaluateImmediateDiscard(state, source.Hand27, source.MeldCount, "pass", "continue_then_discard");
    }

    public SichuanOfflineActionValue EvaluateConcealedGang(SichuanStateView state, int tileType)
    {
        var gang = _transitions.ApplyConcealedGang(_transitions.FromState(state), tileType);
        return EvaluateReplacementDraw(state, gang, "concealed_gang", immediateGangGain: 2.0);
    }

    public SichuanOfflineActionValue EvaluateAddedGang(SichuanStateView state, int tileType)
    {
        var gang = _transitions.ApplyAddedGang(_transitions.FromState(state), tileType);
        return EvaluateReplacementDraw(state, gang, "added_gang", immediateGangGain: 1.0);
    }

    private SichuanOfflineActionValue EvaluateWaiting(
        SichuanStateView state,
        int[] hand,
        int meldCount,
        string action,
        string transition)
    {
        var current = _shanten.CalcBestShanten(hand, meldCount, meldCount == 0);
        var live = 0;
        for (var draw = 0; draw < 27; draw++)
        {
            if (state.Remaining18[draw] <= 0 || hand[draw] >= 4) continue;
            hand[draw]++;
            var after = _shanten.CalcBestShanten(hand, meldCount, meldCount == 0);
            hand[draw]--;
            if (after < current) live += state.Remaining18[draw];
        }
        var value = -current * 4.0 + live * 0.16 + TerminalReadyValue(state, current, live);
        return new SichuanOfflineActionValue(action, value, current, live, -1, 0, transition);
    }

    private SichuanOfflineActionValue EvaluateImmediateDiscard(
        SichuanStateView state,
        int[] hand,
        int meldCount,
        string action,
        string transition)
    {
        var analyses = _hands.AnalyzeDiscards(hand, state.Remaining18, meldCount, meldCount == 0);
        var best = analyses
            .Select(item => new
            {
                Analysis = item,
                Value = -item.Shanten * 4.0
                    + (state.WallCount <= 0 ? 0 : item.LiveUkeire * 0.16)
                    + (state.WallCount <= 0 ? item.Waits.Count : item.Waits.Sum(wait => wait.LiveCount)) * 0.12
                    - (state.WallCount <= 0 ? Math.Max(0, item.Shanten) * 3.5 : item.StructuralLoss * 0.035)
                    + TerminalReadyValue(state, item.Shanten, item.LiveUkeire)
            })
            .OrderByDescending(item => item.Value)
            .ThenBy(item => item.Analysis.DiscardTileType)
            .FirstOrDefault();
        return best is null
            ? new SichuanOfflineActionValue(action, -100, 8, 0, -1, 0, transition)
            : new SichuanOfflineActionValue(action, best.Value, best.Analysis.Shanten, best.Analysis.LiveUkeire, best.Analysis.DiscardTileType, 0, transition);
    }

    private SichuanOfflineActionValue EvaluateReplacementDraw(
        SichuanStateView state,
        SichuanSimulatedHandState gang,
        string action,
        double immediateGangGain)
    {
        var eligible = Enumerable.Range(0, 27)
            .Where(tile => state.Remaining18[tile] > 0 && gang.Hand27[tile] < 4)
            .ToArray();
        var total = eligible.Sum(tile => state.Remaining18[tile]);
        if (total <= 0)
            return new SichuanOfflineActionValue(action, -100, 8, 0, -1, 0, "gang_without_replacement_tile");

        var value = immediateGangGain;
        var averageShanten = 0.0;
        var averageLive = 0.0;
        var winProbability = 0.0;
        var discardWeights = new Dictionary<int, double>();
        foreach (var draw in eligible)
        {
            var weight = state.Remaining18[draw] / (double)total;
            var replacement = _transitions.ApplyReplacementDraw(gang, draw);
            if (_hands.IsWinning(replacement.Hand27, replacement.MeldCount, replacement.MeldCount == 0))
            {
                winProbability += weight;
                averageShanten -= weight;
                value += 4.0 * weight;
                continue;
            }
            var branch = EvaluateImmediateDiscard(state, replacement.Hand27, replacement.MeldCount, action, "gang_replacement_branch");
            value += branch.Value * weight;
            averageShanten += branch.Shanten * weight;
            averageLive += branch.LiveUkeire * weight;
            if (branch.BestDiscardTile >= 0)
                discardWeights[branch.BestDiscardTile] = discardWeights.GetValueOrDefault(branch.BestDiscardTile) + weight;
        }
        var bestDiscard = discardWeights.OrderByDescending(item => item.Value).ThenBy(item => item.Key).Select(item => item.Key).DefaultIfEmpty(-1).First();
        return new SichuanOfflineActionValue(
            action,
            value,
            (int)Math.Round(averageShanten),
            (int)Math.Round(averageLive),
            bestDiscard,
            winProbability,
            "gang_replacement_draw_then_discard");
    }

    private static double TerminalReadyValue(SichuanStateView state, int shanten, int live)
    {
        if (state.WallCount > 8) return 0;
        var urgency = 1.0 - Math.Clamp(state.WallCount, 0, 8) / 9.0;
        return shanten <= 0
            ? 1.8 * urgency + Math.Min(1.2, live * 0.08)
            : -2.6 * urgency * Math.Min(2, shanten);
    }
}
