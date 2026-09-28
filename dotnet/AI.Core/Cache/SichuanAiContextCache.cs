using System.Diagnostics;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Cache;

public sealed class SichuanAiContextCache
{
    private readonly object _sync = new();
    private readonly SichuanStageEvaluator _stage = new();
    private readonly SichuanHandEvaluator _hand = new();
    private readonly SichuanLongTermEVPolicy _longTermEv = new();
    private readonly SichuanOpponentDangerEvaluator _opponents = new();
    private readonly SichuanTileDangerEvaluator _tiles = new();
    private readonly SichuanAttackEligibilityEvaluator _attack = new();
    private readonly SichuanStrategyModeStateMachine _strategy = new();

    private string _lastLowFrequencyKey = "";
    private string _lastObserverKey = "";
    private string _lastHandKey = "";
    private string _lastVisibleKey = "";
    private string _lastStrategyMode = "";
    private SichuanAiContext? _lastContext;

    public SichuanAiContext GetOrUpdate(SichuanStateView state, SichuanBeliefSnapshot belief)
    {
        // The facade serves all seats and native requests may overlap. Both the
        // cached context and the strategy mode belong to one observer at a time.
        lock (_sync)
            return GetOrUpdateLocked(state, belief);
    }

    private SichuanAiContext GetOrUpdateLocked(SichuanStateView state, SichuanBeliefSnapshot belief)
    {
        var observerKey = $"{state.SeatIndex}|{state.InformationMode}|{state.PolicyVariant}|{state.RoundIndex}";
        var observerChanged = _lastContext is null || observerKey != _lastObserverKey;
        var lowFrequencyKey = BuildLowFrequencyKey(state);
        var handKey = SichuanHandEvaluator.BuildHandKey(state);
        var visibleKey = BuildVisibleKey(state);
        var dirty = new SichuanAiContextDirtyFlags
        {
            Stage = observerChanged || lowFrequencyKey != _lastLowFrequencyKey,
            RoundGoal = observerChanged || lowFrequencyKey != _lastLowFrequencyKey,
            StrategyMode = observerChanged || lowFrequencyKey != _lastLowFrequencyKey || handKey != _lastHandKey || visibleKey != _lastVisibleKey,
            HandAnalysis = observerChanged || handKey != _lastHandKey,
            OpponentDanger = observerChanged || visibleKey != _lastVisibleKey,
            TileDanger = observerChanged || visibleKey != _lastVisibleKey,
            ScoreSituation = observerChanged || lowFrequencyKey != _lastLowFrequencyKey
        };

        var samples = new List<SichuanModulePerfSample>();
        var context = _lastContext is null ? new SichuanAiContext() : CloneContextShell(_lastContext);
        context.DirtyFlags = dirty;

        var stage = Measure("StageEvaluator", samples, () => dirty.Stage ? _stage.Evaluate(state, belief) : context.Stage);
        context.Stage = stage;

        var ev = Measure("LongTermEVPolicy", samples, () => dirty.ScoreSituation
            ? _longTermEv.Evaluate(state)
            : (Score: context.ScoreSituation, Risk: context.RiskTolerance, Goal: context.RoundGoal));
        context.ScoreSituation = ev.Score;
        context.RiskTolerance = ev.Risk;
        context.RoundGoal = ev.Goal;

        context.HandAnalysis = Measure("HandEvaluator", samples, () => dirty.HandAnalysis ? _hand.Evaluate(state, belief) : context.HandAnalysis);
        context.OpponentDangerProfiles = Measure("OpponentDangerEvaluator", samples, () => dirty.OpponentDanger ? _opponents.Evaluate(state, belief, context.Stage) : context.OpponentDangerProfiles);
        context.TileDangerMap = Measure("TileDangerEvaluator", samples, () => dirty.TileDanger ? _tiles.Evaluate(state, belief, context.OpponentDangerProfiles, context.Stage) : context.TileDangerMap);
        context.AttackEligibility = Measure("AttackEligibilityEvaluator", samples, () => _attack.Evaluate(
            context.HandAnalysis,
            context.Stage,
            context.OpponentDangerProfiles,
            context.ScoreSituation,
            context.RiskTolerance));
        context.StrategyMode = Measure("StrategyModeStateMachine", samples, () => _strategy.Evaluate(
                observerChanged ? "" : _lastStrategyMode,
            context.RoundGoal,
            context.AttackEligibility,
            context.Stage,
            context.ScoreSituation,
            context.OpponentDangerProfiles));

        context.UpdatedAtTurn = state.TurnIndex > 0 ? state.TurnIndex : state.Discards18.Sum(list => list.Count);
        context.ModulePerf = samples;
        context.ReasonCodes = BuildReasonCodes(context);

        _lastLowFrequencyKey = lowFrequencyKey;
        _lastObserverKey = observerKey;
        _lastHandKey = handKey;
        _lastVisibleKey = visibleKey;
        _lastStrategyMode = context.StrategyMode.Mode;
        _lastContext = context;
        return context;
    }

    private static T Measure<T>(string module, List<SichuanModulePerfSample> samples, Func<T> action)
    {
        var stopwatch = Stopwatch.StartNew();
        var result = action();
        stopwatch.Stop();
        var elapsed = stopwatch.Elapsed.TotalMilliseconds;
        samples.Add(new SichuanModulePerfSample
        {
            Module = module,
            ElapsedMs = Math.Round(elapsed, 3),
            Warning = elapsed >= ResolveBudget(module)
        });
        return result;
    }

    private static double ResolveBudget(string module) => module switch
    {
        "HandEvaluator" => 8.0,
        "TileDangerEvaluator" => 10.0,
        "OpponentDangerEvaluator" => 4.0,
        _ => 3.0
    };

    private static SichuanAiContext CloneContextShell(SichuanAiContext source) => new()
    {
        Stage = source.Stage,
        RoundGoal = source.RoundGoal,
        StrategyMode = source.StrategyMode,
        HandAnalysis = source.HandAnalysis,
        AttackEligibility = source.AttackEligibility,
        OpponentDangerProfiles = source.OpponentDangerProfiles,
        TileDangerMap = source.TileDangerMap,
        ScoreSituation = source.ScoreSituation,
        RiskTolerance = source.RiskTolerance,
        UpdatedAtTurn = source.UpdatedAtTurn,
        ModulePerf = source.ModulePerf,
        ReasonCodes = source.ReasonCodes
    };

    private static string BuildLowFrequencyKey(SichuanStateView state)
        => $"seat:{state.SeatIndex}|dealer:{state.DealerSeat}|mode:{state.InformationMode}|policy:{state.PolicyVariant}|{state.RoundIndex}|{state.TotalRounds}|{state.RemainingRounds}|{state.WallCount}|x3:{(state.ExchangeThreeEnabled ? 1 : 0)}|{string.Join(',', state.Scores)}|a:{string.Join(',', state.ActiveSeats.Select(item => item ? 1 : 0))}|h:{string.Join(',', state.HasHu.Select(item => item ? 1 : 0))}|{state.Discards18.Sum(list => list.Count)}|{state.Melds18.Sum(list => list.Count)}|{string.Join(',', state.IsCalled.Select(item => item ? 1 : 0))}|{string.Join(',', state.IsReady.Select(item => item ? 1 : 0))}";

    private static string BuildVisibleKey(SichuanStateView state)
        // Danger depends on observer blockers, surviving seats, public event
        // history and locks as well as the visible river. Use the full input
        // fingerprint so a same-wall reaction cannot leave a stale threat map.
        => SichuanMahjong.AI.Core.Analysis.SichuanStateFingerprint.BuildTurnKey(state, false, false);

    private static IReadOnlyList<string> BuildReasonCodes(SichuanAiContext context)
        => new[]
            {
                context.Stage.ReasonCode,
                context.RoundGoal.ReasonCode,
                context.RiskTolerance.ReasonCode,
                context.HandAnalysis.ReasonCode,
                context.AttackEligibility.ReasonCode,
                context.StrategyMode.ReasonCode
            }
            .Where(code => !string.IsNullOrWhiteSpace(code))
            .Distinct()
            .ToArray();
}
