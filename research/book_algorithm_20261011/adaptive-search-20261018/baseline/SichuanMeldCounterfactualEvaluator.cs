using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Search;

namespace SichuanMahjong.AI.Core.Decision;

public sealed record SichuanGangReplacementBranch(int DrawTile,double Weight,int Shanten,int LiveUkeire,int DiscardTile,double TerminalReadyValue,bool ImmediateWin)
{
    public double NoImmediateOpponentHuProbability { get; init; } = 1;
    public double ReachReadyProbability { get; init; }
    public double FutureSelfDrawProbability { get; init; }
}

public sealed record SichuanMeldCounterfactual(
    string Action,
    int Shanten,
    int LiveUkeire,
    double RouteLoss,
    double Risk,
    double Value,
    double ExpectedFan)
{
    public IReadOnlyList<SichuanGangReplacementBranch> ReplacementBranches { get; init; } = Array.Empty<SichuanGangReplacementBranch>();
    public bool BranchReadyValueApplied { get; init; }
    public int BestDiscardTile { get; init; } = -1;
    public double ReplacementWinProbability { get; init; }
    public string Transition { get; init; } = string.Empty;
    public double StructuralValue { get; init; }
    public int ImmediateGangGain { get; init; }
    public double ExpectedGangRefundLoss { get; init; }
    public double ExpectedGangDiscardExtraLoss { get; init; }
    public double ExpectedDiscardRisk { get; init; }
    public double BrokenReadyOpportunityLoss { get; init; }
    public double DeadReadyBranchMass { get; init; }
    public double ReplacementWinGain { get; init; }
    public int ContinuationWallCount { get; init; }
    public int OwnFutureDrawBudget { get; init; }
    public bool ReplacementWallConstraintsRebuilt { get; init; }
    public bool ContinuationLegalContextApplied { get; init; }
    public string ImmediateSelfAction { get; init; } = string.Empty;
    public int ImmediateSelfActionTile { get; init; } = -1;
    public string ContinuationModel { get; init; } = "rounded_followup_legacy";
    public double ReachReadyProbability { get; init; }
    public double FutureSelfDrawProbability { get; init; }
    public double ExpectedFutureSelfDrawGain { get; init; }
}

public sealed class SichuanMeldCounterfactualEvaluator
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanUkeireEngine _ukeire = new();
	private readonly SichuanBeliefEngine _belief = new();
	private readonly SichuanWallAvailabilityEngine _wall = new();
    private readonly SichuanActionTreeEvaluator _tree = new();
    private readonly SichuanExactHandAnalyzer _hands = new();
    private readonly SichuanFanProjectionEngine _fans = new();
    private readonly SichuanReadyWaitPricing _readyPrices = new();

	public SichuanMeldCounterfactual Evaluate(
		SichuanStateView state,
		string action,
		int tileType,
		int removeCount,
		int meldCountAfter,
		double routeLoss,
		double risk,
		double gangGain,
		SichuanBeliefSnapshot? belief = null,
        int plannedDiscardTile = -1,
        int gangSourceSeat = -1)
        => SichuanPolicyExecutionScope.Memoize(
            $"meld/{SichuanDecisionCommand.Fingerprint(state)}/{(action=="gang"?"melded_gang":action)}/{tileType}/{removeCount}/{meldCountAfter}/{routeLoss:R}/{risk:R}/{gangGain:R}/{plannedDiscardTile}/{gangSourceSeat}",
            (SichuanPolicyExecutionScope.OwnPlan,belief),
            ()=>EvaluateCore(state,action,tileType,removeCount,meldCountAfter,routeLoss,risk,gangGain,belief,plannedDiscardTile,gangSourceSeat)) with { Action=action };

    private SichuanMeldCounterfactual EvaluateCore(SichuanStateView state,string action,int tileType,int removeCount,
        int meldCountAfter,double routeLoss,double risk,double gangGain,SichuanBeliefSnapshot? belief,
        int plannedDiscardTile,int gangSourceSeat)
    {
        using var timing = SichuanPolicyTiming.Measure("meld_core");

        if (action == "add_gang" && !SichuanAddedGangRules.CanUpgrade(state, tileType))
            throw new InvalidOperationException("Illegal added Gang before a later own draw.");

        // An unrelated concealed Gang may follow a Peng; an added Gang may
        // not. Its fourth copy must survive until a later normal own draw.
        if (action == "peng" && state.InformationMode == "public" && tileType is >= 0 and < 27
            && state.Hand18[tileType] >= 2 && state.WallCount > 0
            && state.Hand18.Where((_, t) => t != tileType).Any(n => n == 4))
        {
            var claimedHand = (int[])state.Hand18.Clone(); claimedHand[tileType] -= 2;
            var projected = SichuanUnifiedDecisionEngine.ProjectPengContinuation(
                state, claimedHand, tileType, gangSourceSeat >= 0 ? gangSourceSeat : state.CurrentSeat);
            var concealed = Enumerable.Range(0, 27).Where(t => t / 9 != state.OwnDingQueSuit
                && claimedHand[t] == 4).ToArray();
            var self = new SichuanSelfActionDecisionEngine().DecideSelfAction(projected, false,
                concealed, Array.Empty<int>(), roundBrain: SichuanDiscardPolicy.ForkPlan(state,projected,SichuanPolicyExecutionScope.OwnPlan));
            if (self.Action.ActionType == SichuanActionType.Gang)
            {
                var isConcealed = self.GangSubtype == "an_gang";
                var added = Evaluate(projected, self.GangSubtype, self.Action.TileType,
                    isConcealed ? 4 : 1, meldCountAfter + (isConcealed ? 1 : 0),
                    0, 0, 0);
                return added with
                {
                    Action = "peng", RouteLoss = routeLoss, Risk = risk,
                    Value = self.Action.Score / 100.0 - routeLoss - risk,
                    BestDiscardTile = -1, ImmediateSelfAction = self.GangSubtype,
                    ImmediateSelfActionTile = self.Action.TileType,
                    Transition = $"peng_then_{self.GangSubtype}_replacement_draw_then_discard"
                };
            }
        }
		belief ??= _belief.Build(state);
		var wallAvailability = _wall.Build(state, belief);
        var hand = (int[])state.Hand18.Clone();
        if (tileType is >= 0 and < 27) hand[tileType] = Math.Max(0, hand[tileType] - removeCount);
        var melds = state.MeldViews[state.SeatIndex].Count > 0
            ? state.MeldViews[state.SeatIndex].ToArray()
            : InferMeldViews(state);
        var projectedMelds = ProjectMelds(melds, action, tileType, state.EventVersion + 1);
        if(action is "peng" or "gang" or "melded_gang")
            projectedMelds[^1]=projectedMelds[^1] with { SourceSeat=gangSourceSeat>=0?gangSourceSeat:state.CurrentSeat };
        var activeSeatList = state.ActiveSeats
            .Select((active, seat) => (active, seat))
            .Where(item => item.active)
            .Select(item => item.seat)
            .ToArray();
        var settlement = new SichuanSettlementProjectionEngine();

        // Reaction timing matters. Pass keeps the thirteen-tile concealed hand
        // and waits for a later draw; Peng must discard immediately; Gang must
        // receive and evaluate the replacement draw before any discard.
		var isPass = action == "pass";
		var isContinue = action == "continue";
		var isGang = action.Contains("gang", StringComparison.OrdinalIgnoreCase);
		var isMeldedGang = action is "gang" or "melded_gang";
        var sourceSeat = gangSourceSeat >= 0 ? gangSourceSeat : state.CurrentSeat;
		var immediateGangGain = isGang ? ProjectImmediateGangGain(state, action, sourceSeat, tileType) : 0;
        if (isGang) gangGain = immediateGangGain;
        // The replacement draw is already evaluated below. Subsequent chance
        // nodes start after its discard, with one fewer wall tile.
        var continuationWallCount = Math.Max(0,state.WallCount-(isGang?1:0));
        var followUp = isPass
			? EvaluateWaitingHand(hand, state, wallAvailability, meldCountAfter, projectedMelds, activeSeatList, settlement)
            : isGang
				? EvaluateGangReplacement(hand, state, wallAvailability, meldCountAfter, projectedMelds, activeSeatList, settlement, isMeldedGang, sourceSeat, belief, immediateGangGain)
				: EvaluatePostClaimDiscards(hand, state, wallAvailability, meldCountAfter, projectedMelds, activeSeatList, settlement, plannedDiscardTile, belief);

        var activePlayers = Math.Clamp(state.ActiveSeats.Count(value => value), 2, 4);
		var isReady = followUp.Shanten == 0;
        var winScore = isReady ? Math.Max(3.5, followUp.ExpectedSelfDrawGain) : 0.0;
		var opponentLoss = followUp.Shanten == 0 ? 2.4 : 1.2;
		var ownTurnOffset = isPass
			? SichuanTurnOrder.DrawsBeforeSeatAfterDiscard(state, state.CurrentSeat, state.SeatIndex)
			: SichuanTurnOrder.DrawsBeforeOwnTurnAfterClaim(state);
        var chance = _tree.SearchChanceNodes(new SichuanActionTreeEvaluator.ChanceSearchRequest(
            isReady ? followUp.LiveUkeire : 0,
			continuationWallCount,
            activePlayers,
			ownTurnOffset,
            winScore,
            SichuanUnifiedDecisionEngine.EstimateOpponentWinPerDraw(state, belief, wallAvailability),
            opponentLoss,
			GangOpportunityProbability: 0,
			GangGain: 0,
			ChaJiaoValue: followUp.Shanten == 0 ? 0.35 : 0,
			MaxDraws: Math.Min(12, Math.Max(4, continuationWallCount)),
			Simulations: 256,
			Seed: 20260809 ^ state.RoundIndex ^ tileType ^ (int)(state.EventVersion % int.MaxValue)));
		var futureOwnDraws = Math.Max(0, (continuationWallCount - ownTurnOffset + activePlayers - 1) / activePlayers);
		var refundLoss = 0.0;
        if (isGang && SichuanRuleSnapshot.Frozen.EnableGangRefund)
        {
            // A non-ready actor cannot self-win without developing first.
            // Run the existing opponent-exit model through wall exhaustion,
            // rather than interpreting a truncated horizon as a draw.
            var terminal = _tree.SearchChanceNodes(new SichuanActionTreeEvaluator.ChanceSearchRequest(
                0, continuationWallCount, activePlayers, ownTurnOffset, 0,
                SichuanUnifiedDecisionEngine.EstimateOpponentWinPerDraw(state, belief, wallAvailability), 0,
                MaxDraws: continuationWallCount));
            var notReady = followUp.Branches.Count > 0
                ? followUp.Branches.Where(b => !b.ImmediateWin).Sum(b => b.Weight * b.NoImmediateOpponentHuProbability *
                    SichuanGangRefundRisk.NotReadyProbability(b.Shanten,b.LiveUkeire,continuationWallCount,futureOwnDraws))
                : SichuanGangRefundRisk.NotReadyProbability(followUp.Shanten,followUp.LiveUkeire,continuationWallCount,futureOwnDraws);
            refundLoss = immediateGangGain * Math.Clamp(terminal.DrawProbability,0,1) * notReady;
        }
        var progressChance = isReady || continuationWallCount <= 0 ? 0.0
			: 1.0 - Math.Pow(1.0 - Math.Clamp(followUp.LiveUkeire / Math.Max(1.0, continuationWallCount), 0.0, 1.0), futureOwnDraws);
        // Candidate is deliberately explicit until independent node checks and
        // latency checks support promotion. Never turn a rounded mean shanten
        // into a categorical ready/not-ready probability.
        bool twoStage = state.PolicyVariant == "two_stage_meld_candidate_v1";
        var staged = twoStage ? followUp.StageChance ?? EvaluateFollowUpChance(
            followUp, belief, ownTurnOffset) : null;
		var brokenReadyOpportunityLoss=0.0;
		var branchReadyApplied=false;
		if(isGang && followUp.Branches.Count>0)
		{
			var before=_shanten.CalcLegalShanten(state.Hand18,state.OwnMeldCount,state.OwnDingQueSuit,state.OwnMeldCount==0);
			var afterReady=SichuanReadyWaitPricing.HasLegalOwnedContext(state,hand,projectedMelds)
				&&_readyPrices.Build(state,hand,wallAvailability.ExpectedCounts18,projectedMelds) is {HasDrawableWait:true};
			if(before==0&&!afterReady)
			{
				// Use the same pass counterfactual as the competing action. This
				// keeps the opportunity cost on the current local model and avoids
				// inventing a separate ready-hand multiplier.
				var currentPass=Evaluate(state,"pass",-1,0,state.OwnMeldCount,0,0,0,belief);
			var deadReadyMass=followUp.Branches.Where(b=>!b.ImmediateWin&&b.Shanten==0&&b.LiveUkeire<=0)
				.Sum(b=>Math.Max(0,b.Weight));
			var lostMass=followUp.Branches.Where(b=>!b.ImmediateWin
					&&!(b.Shanten==0&&b.LiveUkeire>0)).Sum(b=>Math.Max(0,b.Weight));
				// The lost mass is valued against the same current-ready continuation
				// used by Pass. This is an opportunity cost, not a new probability or
				// a book-derived multiplier. A dead ready branch is lost as well.
				if(deadReadyMass>0.0&&lostMass>=0.5)
				{
					brokenReadyOpportunityLoss=lostMass*Math.Max(0,currentPass.Value);
					branchReadyApplied=true;
				}
			}
		}
		var value = followUp.BaseValue
			+ gangGain
			- refundLoss
			+ (staged?.Net ?? chance.ExpectedNetScore) * 0.32
			+ (twoStage ? 0 : progressChance * 0.4)
			+ Math.Clamp(followUp.ExpectedFan - 1.0, 0, 3) * 0.35
			+ Math.Clamp(followUp.ExpectedSelfDrawGain / 8.0, 0, 4) * 0.12
			+ Math.Clamp(followUp.ExpectedGangDrawBonus / 8.0, 0, 4) * 0.08
			+ EvaluateTerminalReadyValue(continuationWallCount, followUp)
			- brokenReadyOpportunityLoss
			- routeLoss
			- risk;
		if (state.PolicyVariant == "gang_branch_candidate_v1" && isGang && followUp.Branches.Count > 0)
		{
			branchReadyApplied=true;
			value += followUp.Branches.Sum(b => b.Weight * b.TerminalReadyValue) - EvaluateTerminalReadyValue(continuationWallCount, followUp);
		}
        // Do not reward a Peng for its speculative future added Gang. Its
        // structural progress is already measured; real later Gang events keep
        // their rule cash, roots and replacement transitions.
        return new SichuanMeldCounterfactual(action, followUp.Shanten, followUp.LiveUkeire, routeLoss, risk, value, followUp.ExpectedFan)
        {
            ReplacementBranches = followUp.Branches,
            BranchReadyValueApplied = branchReadyApplied,
            BestDiscardTile = followUp.BestDiscardTile,
            StructuralValue = followUp.BaseValue,
            ImmediateGangGain = immediateGangGain,
            ContinuationModel = twoStage ? "enumerated_ready_then_fixed_wait_public_model" : "rounded_followup_legacy",
            ReachReadyProbability = staged?.ReadyProbability ?? 0,
            FutureSelfDrawProbability = staged?.SelfDrawProbability ?? chance.OwnWinProbability,
            ExpectedFutureSelfDrawGain = staged?.ExpectedSelfDrawGain ?? chance.ExpectedOwnWinGain,
            ExpectedGangRefundLoss = refundLoss,
            ExpectedGangDiscardExtraLoss = followUp.GangDiscardExtraLoss,
            ExpectedDiscardRisk = followUp.DiscardRisk,
			BrokenReadyOpportunityLoss = brokenReadyOpportunityLoss,
			DeadReadyBranchMass = isGang && followUp.Branches.Count>0
				? followUp.Branches.Where(b=>!b.ImmediateWin&&b.Shanten==0&&b.LiveUkeire<=0).Sum(b=>Math.Max(0,b.Weight)) : 0,
            ReplacementWinGain = followUp.ExpectedGangDrawBonus,
            ContinuationWallCount = continuationWallCount,
            OwnFutureDrawBudget = futureOwnDraws,
            ReplacementWinProbability = followUp.ReplacementWinProbability,
            ReplacementWallConstraintsRebuilt = followUp.WallConstraintsRebuilt,
            ContinuationLegalContextApplied = true,
			Transition = isPass
				? "pass_wait_draw"
				: isContinue ? "continue_then_discard" : isGang ? "gang_replacement_draw_then_discard" : "peng_then_discard"
        };
	}

	public static int ProjectImmediateGangGain(SichuanStateView state, string action, int sourceSeat = -1, int tileType = -1)
    {
        var type=action switch {
            "an_gang" or "concealed_gang" => SichuanMeldType.ConcealedGang,
            "add_gang" => SichuanMeldType.AddedGang,
            "gang" or "melded_gang" => SichuanMeldType.MeldedGang,
            _ => throw new ArgumentException("Not a gang action",nameof(action))
        };
        var source=sourceSeat>=0?sourceSeat:state.CurrentSeat;
        var payers=Enumerable.Range(0,4).Where(s=>s!=state.SeatIndex && state.ActiveSeats[s] && !state.HasHu[s]).ToArray();
		var scoreEligible = type != SichuanMeldType.AddedGang
			|| state.CurrentSeat == state.SeatIndex
			&& state.LastDrawOrigin == SichuanTileOrigin.Draw
			&& tileType >= 0
			&& state.LastDrawTileType == tileType;
		var projection=new SichuanSettlementProjectionEngine().ProjectScenario(new SichuanSettlementScenario(
			GangEvents:[new SichuanGangScoreEvent(state.SeatIndex,type,payers,SourceSeat:source,ScoreEligible:scoreEligible)]));
        return projection.GangChanges[state.SeatIndex];
    }

	private static double EvaluateTerminalReadyValue(int wallCount, FollowUpEvaluation followUp)
	{
		if (wallCount > 8) return 0;
		var urgency = 1.0 - Math.Clamp(wallCount, 0, 8) / 9.0;
		if (followUp.Shanten <= 0)
			return 1.8 * urgency + Math.Min(1.2, followUp.LiveUkeire * 0.08);
		return -2.6 * urgency * Math.Min(2, followUp.Shanten);
	}

    private FollowUpEvaluation EvaluateWaitingHand(
        int[] hand,
        SichuanStateView state,
		SichuanWallAvailability wallAvailability,
        int meldCount,
        IReadOnlyList<SichuanMeldView> melds,
        IReadOnlyList<int> activeSeats,
        SichuanSettlementProjectionEngine settlement)
    {
        using var timing = SichuanPolicyTiming.Measure("meld_waiting");
        var shanten = _shanten.CalcLegalShanten(hand, meldCount, state.OwnDingQueSuit, meldCount == 0);
        var ready = shanten == 0 ? _readyPrices.Build(state, hand, wallAvailability.ExpectedCounts18, melds) : null;
        if (shanten == 0 && ready is null) shanten = 1;
        var improving = new List<int>();
		var liveTiles = new List<int>();
        for (var draw = 0; draw < 27; draw++)
        {
			if (wallAvailability.ExpectedCounts18[draw] <= 0 || hand[draw] >= 4) continue;
            hand[draw]++;
            var after = _shanten.CalcLegalShanten(hand, meldCount, state.OwnDingQueSuit, meldCount == 0);
            var legalDraw = after != -1 || SichuanReadyWaitPricing.HasLegalOwnedContext(state, hand, melds);
            hand[draw]--;
			if (after >= shanten || !legalDraw) continue;
            improving.Add(draw);
			liveTiles.Add(draw);
        }
		var expectedLive = ready is not null ? ready.PublicDrawableMass : wallAvailability.SumExpected(liveTiles);
		var live = expectedLive <= 0.000001 ? 0 : (int)Math.Ceiling(expectedLive);
		var priced = PriceReady(ready, state.SeatIndex, activeSeats);
        return new FollowUpEvaluation(
            shanten,
            live,
            -1,
            priced.ExpectedFan,
            priced.ExpectedSelfDrawGain,
            0,
            0,
            CommonContinuationValue(shanten, expectedLive, priced.ExpectedFan, priced.ExpectedSelfDrawGain, wallAvailability.WallCount))
            { Continuation = SichuanBranchState.Continuation(state, hand, melds, wallAvailability.WallCount) };
    }

    // The same continuation must have the same value whether reached by
    // waiting or claiming. Timing, route loss and immediate claim income are
    // priced outside this structural comparison.
    internal static double CommonContinuationValue(int shanten, double expectedLive,
        double fan, double selfDrawGain, int wallCount)
        => -shanten * 2.4 + expectedLive * 0.12 + fan * 0.20 + selfDrawGain * 0.025
            - (shanten == 0 && expectedLive <= 0.000001 && wallCount > 0 ? 3.2 : 0.0);

    private FollowUpEvaluation EvaluatePostClaimDiscards(
        int[] hand,
        SichuanStateView state,
		SichuanWallAvailability wallAvailability,
        int meldCount,
        IReadOnlyList<SichuanMeldView> melds,
        IReadOnlyList<int> activeSeats,
        SichuanSettlementProjectionEngine settlement,
        int plannedDiscardTile = -1,
        SichuanBeliefSnapshot? belief = null, double? projectedGangCash = null)
    {
        using var timing = SichuanPolicyTiming.Measure("meld_post_discard");
        belief ??= _belief.Build(state);
        var forcedSuit = state.OwnDingQueSuit is >= 0 and < 3
            && Enumerable.Range(state.OwnDingQueSuit*9,9).Any(t=>hand[t]>0) ? state.OwnDingQueSuit : -1;
		var analyses = _hands.AnalyzeDiscards(hand, state.Remaining18, meldCount, meldCount == 0, forcedSuit);
        var projected = SichuanBranchState.Continuation(state, hand, melds, wallAvailability.WallCount, projectedGangCash);
        if (plannedDiscardTile < 0)
            plannedDiscardTile = SichuanDiscardPolicy.Select(projected, source: state).Action.TileType;
        var projectedBelief = _belief.Build(projected);
        FollowUpEvaluation? best = null;
        foreach (var analysis in analyses)
        {
            if (plannedDiscardTile >= 0 && analysis.DiscardTileType != plannedDiscardTile) continue;
			var afterDiscard = (int[])hand.Clone();
            afterDiscard[analysis.DiscardTileType]--;
			var ready = analysis.Shanten == 0 ? _readyPrices.Build(state, afterDiscard, wallAvailability.ExpectedCounts18, melds) : null;
            var structuralDistance = _shanten.CalcLegalShanten(afterDiscard, meldCount, state.OwnDingQueSuit, meldCount == 0);
            var legalShanten = structuralDistance == 0 && ready is null ? 1 : structuralDistance;
			var priced = PriceReady(ready, state.SeatIndex, activeSeats);
			var expectedLive = wallAvailability.SumExpected(
				ready is not null ? ready.Waits.Select(wait => wait.TileType)
                    : _shanten.LegalImprovingTiles(afterDiscard, state.Remaining18, meldCount, state.OwnDingQueSuit));
			var live = expectedLive <= 0.000001 ? 0 : (int)Math.Ceiling(expectedLive);
            var baseValue = CommonContinuationValue(legalShanten, expectedLive,
                priced.ExpectedFan, priced.ExpectedSelfDrawGain, wallAvailability.WallCount);
            var gangDiscardExtra = SichuanGangDiscardLiability.ExpectedExtraLoss(state, analysis.DiscardTileType, belief, projectedGangCash);
            var discardRisk = new SichuanDangerEngine().EvaluateDetail(analysis.DiscardTileType,projected,projectedBelief).Risk/100.0;
            baseValue -= gangDiscardExtra + discardRisk;
            var candidate = new FollowUpEvaluation(
				legalShanten,
				live,
                analysis.DiscardTileType,
                priced.ExpectedFan,
                priced.ExpectedSelfDrawGain,
                0,
                0,
                baseValue) { GangDiscardExtraLoss = gangDiscardExtra, DiscardRisk = discardRisk,
                    Continuation = SichuanBranchState.AfterDiscard(projected, analysis.DiscardTileType) };
            if (best is null || candidate.BaseValue > best.BaseValue)
                best = candidate;
        }
        return best ?? throw new InvalidOperationException("shared_discard_policy_returned_illegal_continuation");
    }

    private FollowUpEvaluation EvaluateGangReplacement(
        int[] handAfterGang,
        SichuanStateView state,
		SichuanWallAvailability wallAvailability,
        int meldCount,
        IReadOnlyList<SichuanMeldView> melds,
        IReadOnlyList<int> activeSeats,
        SichuanSettlementProjectionEngine settlement,
        bool dianGangHua,
        int gangSourceSeat,
        SichuanBeliefSnapshot belief, int immediateGangGain)
    {
        using var timing = SichuanPolicyTiming.Measure("meld_replacement");
		var totalRemaining = wallAvailability.ExpectedCounts18.Sum(value => Math.Max(0, value));
        if (totalRemaining <= 0)
			return EvaluateWaitingHand(handAfterGang, state, wallAvailability, meldCount, melds, activeSeats, settlement);

        var shanten = 0.0;
        var live = 0.0;
        var expectedFan = 0.0;
        var expectedGain = 0.0;
        var gangBonus = 0.0;
        var replacementWin = 0.0;
        var baseValue = 0.0;
        var gangDiscardExtraLoss = 0.0;
        var discardRisk = 0.0;
        var discardWeights = new Dictionary<int, double>();
        var branches = new List<SichuanGangReplacementBranch>();
        var wallRebuilt = false;
        var staged = new SichuanTwoStageEstimate(0,0,0,0);
        for (var draw = 0; draw < 27; draw++)
        {
			var copies = Math.Max(0.0, wallAvailability.ExpectedCounts18[draw]);
            if (copies <= 0 || handAfterGang[draw] >= 4) continue;
            var weight = copies / (double)totalRemaining;
            var drawn = (int[])handAfterGang.Clone();
            drawn[draw]++;
            if (SichuanReadyWaitPricing.HasLegalOwnedContext(state, drawn, melds)
                && _hands.IsWinning(drawn, meldCount, meldCount == 0))
            {
				var winType = dianGangHua ? SichuanWinType.DianGangHua : SichuanWinType.GangSelfDraw;
				var sourceSeat = dianGangHua ? gangSourceSeat : -1;
                var fan = _fans.Project(drawn, melds, winType);
                var gain = settlement.ProjectWin(state.SeatIndex, sourceSeat, activeSeats, fan, winType).WinnerGain;
                expectedFan += fan.CappedFan * weight;
                expectedGain += gain * weight;
                gangBonus += gain * weight;
                replacementWin += weight;
                shanten -= weight;
                baseValue += gain * 0.20 * weight;
                // A replacement win has settled; it has no future ready/cha-jiao bonus.
                // Retain evaluated branches for factual reasons; current
                // ranking and the experimental selector remain unchanged.
                branches.Add(new(draw,weight,-1,0,-1,0,true));
                continue;
            }

			var branch = EvaluatePostClaimDiscards(
				drawn,
				state,
				_wall.AfterHypotheticalOwnDraw(state, belief, draw),
				meldCount,
				melds,
				activeSeats,
				settlement, belief: belief, projectedGangCash: immediateGangGain);
            wallRebuilt = true;
            var branchChance = state.PolicyVariant == "two_stage_meld_candidate_v1"
                ? EvaluateFollowUpChance(branch, belief, SichuanTurnOrder.DrawsBeforeOwnTurnAfterClaim(state)) : null;
            if (branchChance is not null) staged = new(
                staged.ReadyProbability+weight*branchChance.ReadyProbability,
                staged.SelfDrawProbability+weight*branchChance.SelfDrawProbability,
                staged.ExpectedSelfDrawGain+weight*branchChance.ExpectedSelfDrawGain,
                staged.ExpectedOpponentLoss+weight*branchChance.ExpectedOpponentLoss);
            shanten += branch.Shanten * weight;
            live += branch.LiveUkeire * weight;
            expectedFan += branch.ExpectedFan * weight;
            expectedGain += branch.ExpectedSelfDrawGain * weight;
            baseValue += branch.BaseValue * weight;
            gangDiscardExtraLoss += branch.GangDiscardExtraLoss * weight;
            discardRisk += branch.DiscardRisk * weight;
            branches.Add(new(draw,weight,branch.Shanten,branch.LiveUkeire,branch.BestDiscardTile,
                EvaluateTerminalReadyValue(Math.Max(0,state.WallCount-1),branch),false)
                { ReachReadyProbability = branchChance?.ReadyProbability ?? 0,
                    FutureSelfDrawProbability = branchChance?.SelfDrawProbability ?? 0,
                    NoImmediateOpponentHuProbability = branch.BestDiscardTile < 0 ? 1 :
                    SichuanGangDiscardLiability.NoImmediateHuProbability(state,branch.BestDiscardTile,belief) });
            if (branch.BestDiscardTile >= 0)
                discardWeights[branch.BestDiscardTile] = discardWeights.GetValueOrDefault(branch.BestDiscardTile) + weight;
        }
        var bestDiscard = discardWeights.OrderByDescending(item => item.Value).ThenBy(item => item.Key).Select(item => item.Key).DefaultIfEmpty(-1).First();
        return new FollowUpEvaluation(
            (int)Math.Round(shanten),
            (int)Math.Round(live),
            bestDiscard,
            expectedFan,
            expectedGain,
            gangBonus,
            replacementWin,
            baseValue) { Branches = branches.ToArray(), WallConstraintsRebuilt = wallRebuilt, GangDiscardExtraLoss = gangDiscardExtraLoss, DiscardRisk = discardRisk,
                StageChance = state.PolicyVariant == "two_stage_meld_candidate_v1" ? staged : null };
    }

    private SichuanTwoStageEstimate EvaluateFollowUpChance(FollowUpEvaluation followUp,
        SichuanBeliefSnapshot parentBelief, int offset)
        => followUp.Continuation is null ? new(0,0,0,0) : SichuanPolicyExecutionScope.Memoize(
            $"two-stage/{SichuanDecisionCommand.Fingerprint(followUp.Continuation)}/{offset}/{followUp.Shanten}",
            SichuanPolicyExecutionScope.OwnPlan,()=>EvaluateFollowUpChanceCore(followUp,offset));

    private SichuanTwoStageEstimate EvaluateFollowUpChanceCore(FollowUpEvaluation followUp,int offset)
    {
        using var timing = SichuanPolicyTiming.Measure("two_stage_followup");
        var s = followUp.Continuation;
        if(s is null || s.WallCount <= 0) return new(0,0,0,0);
        var belief = _belief.Build(s); var wall = _wall.Build(s,belief);
        int players = Math.Clamp(Enumerable.Range(0,4).Count(i=>s.ActiveSeats[i]&&!s.HasHu[i]),2,4);
        double hazard = SichuanUnifiedDecisionEngine.EstimateOpponentWinPerDraw(s,belief,wall);
        if(followUp.Shanten == 0)
        {
            var ready = _readyPrices.Build(s,s.Hand18,wall.ExpectedCounts18);
            if(ready is null || !ready.HasDrawableWait)return new(1,0,0,0);
            var chance = _tree.SearchChanceNodes(new(ready.PublicDrawableMass,s.WallCount,players,offset,
                ready.WeightedSelfDrawPerPayer*(players-1),hazard,2.4,MaxDraws:s.WallCount));
            return new(1,chance.OwnWinProbability,chance.ExpectedOwnWinGain,chance.ExpectedOpponentLoss);
        }
        if(followUp.Shanten != 1) return new(0,0,0,0);
        var transitions = new List<SichuanReadyTransition>();
        for(int draw=0;draw<27;draw++)
        {
            if(s.Remaining18[draw]<=0 || s.Hand18[draw]>=4 || wall.ExpectedCounts18[draw]<=0)continue;
            var hand=(int[])s.Hand18.Clone();hand[draw]++;
            if(_shanten.CalcLegalShanten(hand,s.OwnMeldCount,s.OwnDingQueSuit,s.OwnMeldCount==0)>0)continue;
            var branch=SichuanBranchState.AfterOwnDraw(s,hand,draw,s.WallCount-1);
            var discard=SichuanDiscardPolicy.Select(branch,source:s,searchLeaf:true).Action.TileType;
            var after=SichuanBranchState.AfterDiscard(branch,discard);
            var priced=_readyPrices.Build(after,after.Hand18,_wall.AfterHypotheticalOwnDraw(s,belief,draw).ExpectedCounts18);
            if(priced is {HasDrawableWait:true})transitions.Add(new(wall.ExpectedCounts18[draw],
                priced.PublicDrawableMass,priced.WeightedSelfDrawPerPayer*(players-1)));
        }
        return new SichuanTwoStageChanceModel().Evaluate(s.WallCount,players,offset,transitions,hazard,1.2);
    }

    private static WaitPricing PriceReady(SichuanReadyPrice? ready, int ownSeat, IReadOnlyList<int> activeSeats)
        => ready is { HasDrawableWait: true }
            ? new WaitPricing(ready.WeightedFan, ready.WeightedSelfDrawPerPayer * activeSeats.Count(s => s != ownSeat))
            : new WaitPricing(0, 0);

    private WaitPricing PriceWaits(
        int[] hand,
        IReadOnlyList<SichuanWaitAnalysis> waits,
		SichuanWallAvailability wallAvailability,
        IReadOnlyList<SichuanMeldView> melds,
        SichuanStateView state,
        IReadOnlyList<int> activeSeats,
        SichuanSettlementProjectionEngine settlement,
        bool gangSelfDraw)
    {
		var total = waits.Sum(wait => wallAvailability.ExpectedCounts18[wait.TileType]);
        if (total <= 0) return new WaitPricing(0, 0);
        var expectedFan = 0.0;
        var expectedGain = 0.0;
        foreach (var wait in waits)
        {
            var completed = (int[])hand.Clone();
            completed[wait.TileType]++;
            var winType = gangSelfDraw ? SichuanWinType.GangSelfDraw : SichuanWinType.SelfDraw;
            var fan = _fans.Project(completed, melds, winType);
			var weight = wallAvailability.ExpectedCounts18[wait.TileType] / total;
            expectedFan += fan.CappedFan * weight;
            expectedGain += settlement.ProjectWin(state.SeatIndex, -1, activeSeats, fan, winType).WinnerGain * weight;
        }
        return new WaitPricing(expectedFan, expectedGain);
    }

    private static SichuanMeldView[] InferMeldViews(SichuanStateView state)
        => state.Melds18[state.SeatIndex]
            .Where(tile => tile is >= 0 and < 27)
            .GroupBy(tile => tile)
            .Select((group, index) => new SichuanMeldView(
                group.Count() >= 4 ? SichuanMeldType.MeldedGang : SichuanMeldType.Peng,
                group.Key,
                -1,
                index))
            .ToArray();

    private static SichuanMeldView[] ProjectMelds(
        IReadOnlyList<SichuanMeldView> current,
        string action,
        int tileType,
        long eventVersion)
    {
		if (action is "pass" or "continue") return current.ToArray();
        if (action == "add_gang")
        {
            var upgraded = current.ToArray();
            var index = Array.FindIndex(upgraded, meld => meld.TileType == tileType && meld.Type == SichuanMeldType.Peng);
            if (index >= 0)
            {
                upgraded[index] = upgraded[index] with { Type = SichuanMeldType.AddedGang, EventIndex = eventVersion };
                return upgraded;
            }
            return current.Concat(new[] { new SichuanMeldView(SichuanMeldType.AddedGang, tileType, -1, eventVersion) }).ToArray();
        }
        var type = action switch
        {
            "an_gang" or "concealed_gang" => SichuanMeldType.ConcealedGang,
            "gang" or "melded_gang" => SichuanMeldType.MeldedGang,
            _ => SichuanMeldType.Peng
        };
        return current.Concat(new[] { new SichuanMeldView(type, tileType, -1, eventVersion) }).ToArray();
    }

    private sealed record FollowUpEvaluation(
        int Shanten,
        int LiveUkeire,
        int BestDiscardTile,
        double ExpectedFan,
        double ExpectedSelfDrawGain,
        double ExpectedGangDrawBonus,
        double ReplacementWinProbability,
        double BaseValue)
    {
        public IReadOnlyList<SichuanGangReplacementBranch> Branches { get; init; } = Array.Empty<SichuanGangReplacementBranch>();
        public bool WallConstraintsRebuilt { get; init; }
        public double GangDiscardExtraLoss { get; init; }
        public double DiscardRisk { get; init; }
        public SichuanStateView? Continuation { get; init; }
        public SichuanTwoStageEstimate? StageChance { get; init; }
    }

    private sealed record WaitPricing(double ExpectedFan, double ExpectedSelfDrawGain);
}
