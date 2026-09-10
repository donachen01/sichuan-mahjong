using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Domain;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanRoundBrainEngine
{
    private readonly object _gate = new();
    private readonly SichuanRoutePlanEngine _routePlanner = new();
    private readonly Dictionary<(int round, int seat), BrainState> _brains = new();

    public SichuanRoundBrainSnapshot Observe(SichuanStateView state)
    {
        lock (_gate)
        {
            PruneOldRounds(state.RoundIndex);
            var key = (state.RoundIndex, state.SeatIndex);
            var rawPlan = _routePlanner.Evaluate(state);
            var stage = ResolveStage(state);
            if (!_brains.TryGetValue(key, out var brain))
            {
                brain = BrainState.Create(state, rawPlan, stage);
                _brains[key] = brain;
            }
            else if (brain.IsNewDeal(state))
            {
                brain = BrainState.Create(state, rawPlan, stage);
                _brains[key] = brain;
            }
            else if (!brain.IsSameObservation(state))
            {
                brain.Observe(state, rawPlan, stage);
            }
            return brain.ToSnapshot();
        }
    }

    public void RecordDiscard(SichuanStateView state, int tileType, SichuanRoutePlanResult plan)
    {
        lock (_gate)
        {
            if (_brains.TryGetValue((state.RoundIndex, state.SeatIndex), out var brain))
                brain.RecordDecision($"出牌 {tileType}，执行路线 {plan.PrimaryRoute}");
        }
    }

    public void RecordReaction(SichuanStateView state, SichuanAction action)
    {
        lock (_gate)
        {
            if (_brains.TryGetValue((state.RoundIndex, state.SeatIndex), out var brain))
                brain.RecordDecision($"反应 {action.ActionType} {action.TileType}");
        }
    }

    private void PruneOldRounds(int currentRound)
    {
        foreach (var key in _brains.Keys.Where(key => key.round < currentRound - 1).ToArray())
            _brains.Remove(key);
    }

    private static int ResolveStage(SichuanStateView state)
    {
        var maxDiscards = state.Discards18.Max(list => list.Count);
        if (state.WallCount <= 6 || maxDiscards >= 15) return 2;
        if (state.WallCount <= 13 || maxDiscards >= 9 || state.Melds18.Sum(list => list.Count / 3) >= 5) return 1;
        return 0;
    }

    private sealed class BrainState
    {
        private int[] _lastHand = new int[27];
        private int _lastWallCount;
        private int _lastDiscardCount;
        private int _lastMeldTileCount;
        private int _lastObservationHash;
        private readonly HashSet<int> _brokenTriplets = new();
        private readonly List<string> _history = new();

        public int RoundIndex { get; private set; }
        public int SeatIndex { get; private set; }
        public int Revision { get; private set; }
        public int Stage { get; private set; }
        public string PrimaryRoute { get; private set; } = "平胡";
        public string FallbackRoute { get; private set; } = "平胡";
        public int Commitment { get; private set; }
        public int TargetSuit { get; private set; } = -1;
        public Dictionary<string, int> RouteWeights { get; private set; } = new();
		public double RiskBudget { get; private set; }
		public int MaxThreatSeat { get; private set; } = -1;
		public double MaxThreatScore { get; private set; }
		public long ObservationVersion { get; private set; }

        public static BrainState Create(SichuanStateView state, SichuanRoutePlanResult plan, int stage)
        {
            var ordered = plan.RouteWeights.OrderByDescending(item => item.Value).ToArray();
            var lead = ordered.Length > 1 ? ordered[0].Value - ordered[1].Value : 20;
            var brain = new BrainState
            {
                RoundIndex = state.RoundIndex,
                SeatIndex = state.SeatIndex,
                Revision = 1,
                Stage = stage,
                PrimaryRoute = plan.PrimaryRoute,
                FallbackRoute = ordered.Skip(1).FirstOrDefault().Key ?? "平胡",
                Commitment = Math.Clamp(28 + lead * 2, 25, 72),
                TargetSuit = plan.TargetSuit,
                RouteWeights = new Dictionary<string, int>(plan.RouteWeights),
                _lastHand = (int[])state.Hand18.Clone(),
                _lastWallCount = state.WallCount,
                _lastDiscardCount = state.Discards18.Sum(list => list.Count),
                _lastMeldTileCount = state.Melds18.Sum(list => list.Count),
                _lastObservationHash = BuildObservationHash(state)
            };
			brain.UpdateThreatAndRisk(state);
            var targetCount = CountSuit(state.Hand18, plan.TargetSuit);
            var offSuitCount = state.Hand18.Sum() - targetCount;
            if (SichuanRoutePlanEngine.IsFlushRoute(plan.PrimaryRoute) && targetCount >= 10 && offSuitCount <= 3)
                brain.Commitment = Math.Max(brain.Commitment, 76);
            brain._history.Add($"开局战略：{brain.PrimaryRoute}，备用 {brain.FallbackRoute}，承诺度 {brain.Commitment}");
            return brain;
        }

        public void Observe(SichuanStateView state, SichuanRoutePlanResult rawPlan, int stage)
        {
            CaptureBrokenTriplets(state);
            Stage = stage;
            RouteWeights = new Dictionary<string, int>(rawPlan.RouteWeights);
            var currentWeight = RouteWeights.GetValueOrDefault(PrimaryRoute, 0);
            var challenger = RouteWeights.OrderByDescending(item => item.Value).FirstOrDefault();
            var switchMargin = 8 + Commitment / 5 + stage * 3;
            if (Revision <= 2 && stage == 0)
                switchMargin += 40;
            if (SichuanRoutePlanEngine.IsFlushRoute(PrimaryRoute) && TargetSuit is >= 0 and < 3)
            {
                var targetCount = CountSuit(state.Hand18, TargetSuit) + state.Melds18[state.SeatIndex].Count(tile => tile / 9 == TargetSuit);
                var offSuitCount = state.Hand18.Sum() + state.Melds18[state.SeatIndex].Count - targetCount;
                if (targetCount >= 10 && offSuitCount <= 4)
                    switchMargin += 40;
            }

            if (currentWeight <= 0 || (challenger.Key != PrimaryRoute && challenger.Value >= currentWeight + switchMargin))
            {
                var old = PrimaryRoute;
                FallbackRoute = currentWeight > 0 ? old : rawPlan.SecondaryRoutes.FirstOrDefault() ?? "平胡";
                PrimaryRoute = challenger.Key ?? rawPlan.PrimaryRoute;
                TargetSuit = rawPlan.TargetSuit;
                Commitment = Math.Clamp(30 + Math.Max(0, challenger.Value - currentWeight), 28, 68);
                _history.Add($"策略调整：{old} -> {PrimaryRoute}，优势 {challenger.Value - currentWeight}");
            }
            else
            {
                if (challenger.Key == PrimaryRoute)
                    Commitment = Math.Min(92, Commitment + (stage == 0 ? 2 : 1));
                else
                    Commitment = Math.Max(24, Commitment - 2);
                if (SichuanRoutePlanEngine.IsFlushRoute(PrimaryRoute) && TargetSuit < 0)
                    TargetSuit = rawPlan.TargetSuit;
                FallbackRoute = RouteWeights
                    .Where(item => item.Key != PrimaryRoute)
                    .OrderByDescending(item => item.Value)
                    .Select(item => item.Key)
                    .FirstOrDefault() ?? FallbackRoute;
            }

            _lastHand = (int[])state.Hand18.Clone();
            _lastWallCount = state.WallCount;
            _lastDiscardCount = state.Discards18.Sum(list => list.Count);
            _lastMeldTileCount = state.Melds18.Sum(list => list.Count);
            _lastObservationHash = BuildObservationHash(state);
			UpdateThreatAndRisk(state);
            Revision++;
        }

        public bool IsSameObservation(SichuanStateView state) => _lastObservationHash == BuildObservationHash(state);

        public bool IsNewDeal(SichuanStateView state)
        {
            var discardCount = state.Discards18.Sum(list => list.Count);
            var meldTileCount = state.Melds18.Sum(list => list.Count);
            var handDistance = Enumerable.Range(0, 27).Sum(tile => Math.Abs(state.Hand18[tile] - _lastHand[tile]));
            return state.WallCount > _lastWallCount + 2
                || (discardCount + 2 < _lastDiscardCount && state.WallCount >= _lastWallCount)
                || (discardCount == 0 && _lastDiscardCount > 0 && state.WallCount >= 30)
                || (discardCount == _lastDiscardCount
                    && meldTileCount == _lastMeldTileCount
                    && state.WallCount >= _lastWallCount - 1
                    && handDistance > 4);
        }

        private void CaptureBrokenTriplets(SichuanStateView state)
        {
            var ownMelds = state.Melds18[state.SeatIndex];
            for (var tile = 0; tile < 27; tile++)
            {
                if (_lastHand[tile] >= 3 && state.Hand18[tile] == 2 && !ownMelds.Contains(tile))
                {
                    _brokenTriplets.Add(tile);
                    _history.Add($"资产记录：主动拆刻 {tile}");
                }
            }
        }

        public void RecordDecision(string description)
        {
            _history.Add(description);
            while (_history.Count > 12) _history.RemoveAt(0);
        }

        private static int CountSuit(IReadOnlyList<int> hand, int suit)
        {
            if (suit is < 0 or > 2) return 0;
            return Enumerable.Range(suit * 9, 9).Sum(tile => hand[tile]);
        }

        private static int BuildObservationHash(SichuanStateView state)
        {
            var hash = new HashCode();
            hash.Add(state.RoundIndex);
            hash.Add(state.SeatIndex);
            hash.Add(state.WallCount);
            hash.Add(state.VisibleVersion);
            hash.Add(state.HandVersion);
            hash.Add(state.EventVersion);
			hash.Add(state.ExchangeThreeEnabled);
            foreach (var count in state.Hand18) hash.Add(count);
            foreach (var list in state.Discards18)
            {
                hash.Add(list.Count);
                foreach (var tile in list) hash.Add(tile);
            }
            foreach (var list in state.Melds18)
            {
                hash.Add(list.Count);
                foreach (var tile in list) hash.Add(tile);
            }
            return hash.ToHashCode();
        }

		private void UpdateThreatAndRisk(SichuanStateView state)
		{
			var threats = Enumerable.Range(0, 4)
				.Where(seat => seat != state.SeatIndex && state.ActiveSeats.ElementAtOrDefault(seat))
				.Select(seat => new
				{
					Seat = seat,
					Score = (state.IsReady.ElementAtOrDefault(seat) ? 0.48 : 0.0)
						+ Math.Min(0.40, state.Melds18[seat].Count / 3 * 0.11)
						+ Math.Min(0.22, state.PublicEvents.Count(item => item.Seat == seat && item.Type == SichuanPublicEventType.Discard && item.Origin == SichuanTileOrigin.Hand) * 0.018)
				})
				.OrderByDescending(item => item.Score)
				.ToArray();
			var max = threats.FirstOrDefault();
			MaxThreatSeat = max?.Seat ?? -1;
			MaxThreatScore = max?.Score ?? 0;
			var scoreLead = state.Scores.ElementAtOrDefault(state.SeatIndex) - state.Scores.Where((_, seat) => seat != state.SeatIndex).DefaultIfEmpty().Max();
			RiskBudget = Math.Clamp(0.72 - Stage * 0.16 - MaxThreatScore * 0.38 - Math.Max(0, scoreLead) * 0.004, 0.12, 0.86);
			ObservationVersion = state.EventVersion > 0 ? state.EventVersion : state.VisibleVersion;
		}

		private IReadOnlyDictionary<string, double> BuildRouteProbabilities()
		{
			if (RouteWeights.Count == 0) return new Dictionary<string, double>();
			var max = RouteWeights.Values.Max();
			var raw = RouteWeights.ToDictionary(item => item.Key, item => Math.Exp((item.Value - max) / 18.0));
			var total = raw.Values.Sum();
			return raw.ToDictionary(item => item.Key, item => total <= 0 ? 0 : item.Value / total);
		}

        public SichuanRoundBrainSnapshot ToSnapshot()
        {
            var triplets = Enumerable.Range(0, 27).Where(tile => _lastHand[tile] >= 3).ToHashSet();
            var quads = Enumerable.Range(0, 27).Where(tile => _lastHand[tile] >= 4).ToHashSet();
            return new SichuanRoundBrainSnapshot
            {
                RoundIndex = RoundIndex,
                SeatIndex = SeatIndex,
                Revision = Revision,
                Stage = Stage,
                PrimaryRoute = PrimaryRoute,
                FallbackRoute = FallbackRoute,
                Commitment = Commitment,
                TargetSuit = TargetSuit,
                RouteWeights = new Dictionary<string, int>(RouteWeights),
				RouteProbabilities = BuildRouteProbabilities(),
				RiskBudget = RiskBudget,
				MaxThreatSeat = MaxThreatSeat,
				MaxThreatScore = MaxThreatScore,
				ObservationVersion = ObservationVersion,
				RulesVersion = SichuanRuleSnapshot.Version,
                ProtectedTriplets = triplets,
                ProtectedQuads = quads,
                BrokenTriplets = new HashSet<int>(_brokenTriplets),
				Reasons = _history.TakeLast(5).ToArray(),
				DecisionHistory = _history.ToArray()
            };
        }
    }
}
