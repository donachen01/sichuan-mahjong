using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Rules;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanReactionDecisionEngine
{
    private readonly SichuanShantenEngine _shanten = new();
    private readonly SichuanUkeireEngine _ukeire = new();
    private readonly SichuanBeliefEngine _belief = new();
	private readonly SichuanWallAvailabilityEngine _wall = new();
    private readonly SichuanDangerEngine _danger = new();
	private readonly SichuanRoutePlanEngine _routePlan = new();
	private readonly SichuanUnifiedDecisionEngine _unified = new();
	private readonly SichuanMeldCounterfactualEvaluator _meldCounterfactual = new();
    private readonly SichuanReadyWaitPricing _readyPrices = new();
    private const int ReactionSearchDepth = 2;
    private const int ReactionSearchRollouts = 24;

    public SichuanReactionDecisionResult DecideReaction(
        SichuanStateView state,
        int reactionTileType,
        bool canHu,
        bool canPeng,
        bool canGang,
        int sourceSeat = -1,
        string reactionType = "discard",
        bool forceLightweight = false,
        bool mandatoryGang = false,
        SichuanRoundBrainSnapshot? roundBrain = null)
    {
        using var decisionScope = SichuanPolicyExecutionScope.EnterDecision();
        if (canHu)
        {
			var comparison = _unified.CompareDiscardHuWithPass(state, reactionTileType, sourceSeat, reactionType, canPeng, roundBrain, canGang);
			var selected = comparison.Candidates.First(candidate => candidate.Action.ActionType == comparison.SelectedAction);
			var actionScores = comparison.Candidates.ToDictionary(candidate => candidate.Action.ActionType.ToString().ToLowerInvariant(),
				candidate => (int)Math.Round(candidate.ExpectedNetScore * 1000.0));
			var selectedScore = actionScores[selected.Action.ActionType.ToString().ToLowerInvariant()];
            if (comparison.LocalReaction is { } claim)
            {
                claim.Action = claim.Action with { Score = selectedScore, Reason = comparison.Summary };
                claim.Reasons = comparison.Reasons.Concat(claim.Reasons).Distinct().ToArray();
                claim.ValueCandidates = comparison.Candidates;
                claim.ActionScores = actionScores;
                return claim;
            }
            return new SichuanReactionDecisionResult
            {
				Action = new SichuanAction(selected.Action.ActionType, reactionTileType, selectedScore, comparison.Summary),
				ShantenAfter = selected.Action.ActionType == SichuanActionType.Hu ? -1 : 0,
				CurrentShanten = 0,
				Reasons = comparison.Reasons,
                ValueCandidates = comparison.Candidates,
                ActionScores = actionScores
            };
        }

        var belief = _belief.Build(state);
		var wallAvailability = _wall.Build(state, belief);
        var roundStage = new SichuanStageEvaluator().Evaluate(state, belief).StageIndex;
        var meldCount = state.OwnMeldCount;
		var currentFollowUp = EvaluateWaitingFollowUp(state, wallAvailability, meldCount);
        var currentPlan = _routePlan.Evaluate(state, roundBrain);
        var maxReadyPosterior = belief.SeatReadyPosterior.Values.DefaultIfEmpty(0.0).Max();
        var threatLevel = ResolveThreatLevel(state, belief);
        var passDiscardRisk = currentFollowUp.BestDiscardTile >= 0 ? _danger.EvaluateDetail(currentFollowUp.BestDiscardTile, state, belief) : new SichuanDangerEvaluation();
        var passWallPosterior = EstimateWallPosterior(currentFollowUp.ImprovingTiles, belief);
        var passBlockPosterior = EstimateBlockPosterior(currentFollowUp.ImprovingTiles, belief);
        var scores = new Dictionary<string, int>();

        var passScore = BuildPassScore(currentFollowUp, roundStage, threatLevel, maxReadyPosterior, state.WallCount, passWallPosterior, passBlockPosterior, passDiscardRisk.Risk);
        scores["pass"] = passScore;
        var best = new SichuanReactionDecisionResult
        {
            Action = new SichuanAction(SichuanActionType.Pass, reactionTileType, passScore, "保持当前最快成叫路径"),
            ShantenAfter = currentFollowUp.Shanten,
            UkeireAfter = currentFollowUp.Ukeire,
            LiveUkeireAfter = currentFollowUp.LiveUkeire,
            CurrentShanten = currentFollowUp.Shanten,
            CurrentLiveUkeire = currentFollowUp.LiveUkeire,
            ThreatLevel = threatLevel,
            RoundStage = roundStage,
            MaxReadyPosterior = maxReadyPosterior,
            Reasons = BuildPassReasons(currentFollowUp, roundStage, threatLevel, maxReadyPosterior)
                .Append("CONTINUATION_LEGAL_READY_CONTEXT")
                .Concat(BuildRouteProtectionPassReasons(state, currentPlan))
                .Concat(currentPlan.Reasons)
                .ToArray(),
            PosteriorSummary = BuildPosteriorSummary(passWallPosterior, passBlockPosterior, passDiscardRisk.Risk, maxReadyPosterior, threatLevel),
            FutureSummary = BuildFutureSummary("pass", currentFollowUp, passDiscardRisk.Risk, passWallPosterior, passBlockPosterior),
            ActionScores = scores
        };

        var passDrawOffset = SichuanTurnOrder.DrawsBeforeSeatAfterDiscard(state, state.CurrentSeat, state.SeatIndex);
		var candidates = new List<(string action, SichuanReactionDecisionResult result, int[] handAfter, int meldCountAfter, int ownDrawOffset)>
        {
			("pass", best, (int[])state.Hand18.Clone(), meldCount, passDrawOffset)
        };

        if (canPeng && reactionTileType is >= 0 and < 27 && state.Hand18[reactionTileType] >= 2)
        {
            var pengResult = EvaluatePeng(state, belief, reactionTileType, currentFollowUp, currentPlan, roundStage, threatLevel, maxReadyPosterior, roundBrain, sourceSeat, forceLightweight);
            scores["peng"] = pengResult.Action.Score;
            var pengSearchHand = RemoveCopies(state.Hand18, reactionTileType, 2);
			var pengImmediateDiscard = state.InformationMode == "oracle"
                ? EvaluateBestFollowUp(pengSearchHand, wallAvailability.RepresentativeCounts18, meldCount + 1).BestDiscardTile
                : pengResult.PlannedDiscardTile;
            if (pengImmediateDiscard >= 0)
                pengSearchHand = RemoveCopies(pengSearchHand, pengImmediateDiscard, 1);
			candidates.Add(("peng", pengResult, pengSearchHand, meldCount + 1, SichuanTurnOrder.DrawsBeforeOwnTurnAfterClaim(state)));
            if (pengResult.Action.Score > best.Action.Score)
            {
                pengResult.ActionScores = scores;
                best = pengResult;
            }
        }

        if (canGang && reactionTileType is >= 0 and < 27 && state.Hand18[reactionTileType] >= 3)
        {
            var gangResult = EvaluateGang(state, belief, reactionTileType, currentFollowUp, currentPlan, roundStage, threatLevel, maxReadyPosterior, reactionType, sourceSeat);
            scores["gang"] = gangResult.Action.Score;
			candidates.Add(("gang", gangResult, RemoveCopies(state.Hand18, reactionTileType, 3), meldCount + 1, 0));
            if (gangResult.Action.Score > best.Action.Score)
            {
                gangResult.ActionScores = scores;
                best = gangResult;
            }
        }

		// Apply the same meld counterfactual before the reaction gates and search
        // choose a winner. Previously this adjustment was calculated after the
        // winner had already been selected, so it could not change the action.
		var unifiedMelds = _unified.RankMeldActions(
			state,
			reactionTileType,
			canPeng,
			canGang,
			routeLoss: currentPlan.ForbidsMelds ? 12.0 : 0.0,
			belief: belief,
            pengDiscardTile: candidates.FirstOrDefault(item => item.action == "peng").result?.PlannedDiscardTile ?? -1,
            gangSourceSeat:sourceSeat);
		foreach (var unifiedCandidate in unifiedMelds.Candidates.Where(item => item.IsAdmissible))
		{
			var key = unifiedCandidate.Action.ActionType.ToString().ToLowerInvariant();
			if (!scores.ContainsKey(key) || scores[key] <= int.MinValue / 8) continue;
			var commonValueScore = (int)Math.Round(Math.Clamp(unifiedCandidate.ExpectedNetScore, -1000000, 1000000) * 100.0);
			for (var index = 0; index < candidates.Count; index++)
			{
				if (candidates[index].action != key) continue;
				var item = candidates[index];
				var legacyDiagnostic = Math.Clamp(item.result.Action.Score, -40, 40);
                // Route loss is already inside the counterfactual value. A previous
                // discard is evidence, not a second irreversible financial penalty.
                var score = commonValueScore;
				item.result.Action = item.result.Action with { Score = score };
				item.result.Reasons = item.result.Reasons.Concat(new[]
				{
					$"统一动作净值 {unifiedCandidate.ExpectedNetScore:F2}",
					$"旧启发式仅作诊断 {legacyDiagnostic:+#;-#;0}，不参与选择"
                }).Concat(unifiedCandidate.ReasonCodes).Distinct().ToArray();
				candidates[index] = item;
				scores[key] = score;
				break;
			}
		}
        best = candidates.OrderByDescending(item => item.result.Action.Score).First().result;

        // Fair live interfaces share this fixed-count, two-own-draw search.
        // Omitting it in mobile/lightweight mode could change Peng vs Pass
        // for the identical public state. The separate oracle mode keeps its
        // existing lightweight boundary.
        if ((state.InformationMode == "public" || !forceLightweight)
            && candidates.All(c => c.result.PlannedSelfAction.Length == 0)
            && ShouldSearchReaction(candidates))
        {
            var simulations = 0;
			var bonusMap = EvaluateReactionSearchBonuses(state, belief, candidates, ref simulations);
            for (var index = 0; index < candidates.Count; index++)
            {
                var item = candidates[index];
                var bonus = bonusMap.GetValueOrDefault(item.action, 0.0);
                item.result.SearchUsed = true;
                item.result.SearchSimulations = simulations;
                item.result.SearchBonus = bonus;
                item.result.Action = item.result.Action with { Score = item.result.Action.Score + (int)Math.Round(bonus * 100.0) };
                var mergedReasons = item.result.Reasons.ToList();
                mergedReasons.Add($"短搜索修正 {bonus:F2}");
                if(state.InformationMode=="public")mergedReasons.Add("PUBLIC_REACTION_SHARED_BOUNDED_SEARCH");
                item.result.Reasons = mergedReasons;
                candidates[index] = item;
                scores[item.action] = item.result.Action.Score;
            }
            best = candidates
                .OrderByDescending(item => item.result.Action.Score)
                .Select(item => item.result)
                .First();
        }

        // 3.2 exception: an early four-pair hand with two live opponents
        // missing the same suit can have a real big-pair / Jin-Gou route.
        // The ordinary speed score otherwise keeps passing the useful claim
        // whenever Peng does not shorten shanten.  This is deliberately
        // narrow: it requires public ding-que evidence, enough pairs, an
        // early stage, and a legal post-claim continuation.
        var pairRouteException = HasPairRouteException(state, currentFollowUp, currentPlan, roundStage);
        var pairRoutePengIndex = candidates.FindIndex(item => item.action == "peng");
        if (pairRouteException && pairRoutePengIndex >= 0)
        {
            var item = candidates[pairRoutePengIndex];
            if (item.result.PlannedDiscardTile >= 0
                && item.result.ShantenAfter <= currentFollowUp.Shanten)
            {
                var passScoreForRoute = candidates.First(candidate => candidate.action == "pass").result.Action.Score;
                var routeScore = Math.Max(item.result.Action.Score, passScoreForRoute + 72);
                item.result.Action = item.result.Action with { Score = routeScore };
                item.result.Reasons = item.result.Reasons.Concat(new[] {
                    "3.2对子路线例外：四对以上＋两家同缺一门，碰后保留对对和/金钩路线",
                    "3.2尊杠机会仅作为条件收益，已与碰后结构和速度共同比较"
                }).Distinct().ToArray();
                candidates[pairRoutePengIndex] = item;
                scores["peng"] = routeScore;
                best = item.result;
            }
        }

        // Embedded pairs that leave only edge fragments (or a broken gap)
        // are the other half of 3.2.  The normal distance metric can count
        // the newly exposed meld as progress even when the useful remaining
        // shape is no better.  In the early public decision stage, preserve
        // the pass when no strong pair-route exception is present.
        if (!pairRouteException
            && best.Action.ActionType == SichuanActionType.Peng
            && IsWeakEmbeddedPairPeng(state, reactionTileType, roundStage))
        {
            var pass = candidates.First(candidate => candidate.action == "pass").result;
            pass.Reasons = pass.Reasons.Concat(new[] {
                "3.2嵌入对子：碰后只剩边张/残破间隔，未形成有效两面或坎张，保留抢和路线"
            }).Distinct().ToArray();
            best = pass;
        }

        // The positive mirror of the rule above: when the embedded pair is
        // the only pair in its suit and the claim leaves a genuine internal
        // two-sided/kanchan block, preserve the source's early useful-Peng
        // decision even if public-copy pricing makes the raw counterfactual
        // slightly pessimistic.  The four-pair/two-opponent exception above
        // handles the separate 3-5 route; this branch does not apply to a
        // same-suit second pair such as 1223347.
        if (!currentPlan.ForbidsMelds
            && best.Action.ActionType == SichuanActionType.Pass
            && IsStrongEmbeddedPairPeng(state, reactionTileType, roundStage))
        {
            var pengIndex = candidates.FindIndex(item => item.action == "peng");
            if (pengIndex >= 0)
            {
                var item = candidates[pengIndex];
                var passScoreForPositive = candidates.First(candidate => candidate.action == "pass").result.Action.Score;
                if (item.result.PlannedDiscardTile >= 0 && item.result.ShantenAfter <= currentFollowUp.Shanten)
                {
                    var score = Math.Max(item.result.Action.Score, passScoreForPositive + 72);
                    item.result.Action = item.result.Action with { Score = score };
                    item.result.Reasons = item.result.Reasons.Concat(new[] {
                        "3.2嵌入对子：碰后形成有效两面/坎张，局部结构实际改善"
                    }).Distinct().ToArray();
                    candidates[pengIndex] = item;
                    scores["peng"] = score;
                    best = item.result;
                }
            }
        }

		var finalPengCandidate = candidates.FirstOrDefault(item => item.action == "peng");
        var pengStructure = state.InformationMode != "oracle" && finalPengCandidate.result is { PlannedDiscardTile: >= 0 }
            ? Decision.SichuanPengStructureComparison.Build(state, reactionTileType, finalPengCandidate.result.PlannedDiscardTile) : null;
        var pengDevelopment = finalPengCandidate.result is { PlannedDiscardTile: >= 0 }
            ? new SichuanDevelopmentPolicy().EvaluatePeng(state,reactionTileType,finalPengCandidate.result.PlannedDiscardTile) : null;
        if (pengDevelopment is not null && finalPengCandidate.result is not null)
            finalPengCandidate.result.Reasons = finalPengCandidate.result.Reasons.Concat(pengDevelopment.Reasons).ToArray();
        var passCandidate = candidates.First(item => item.action == "pass").result;
        if (best.Action.ActionType == SichuanActionType.Peng && finalPengCandidate.result is not null
            && finalPengCandidate.result.PlannedSelfAction.Length == 0)
        {
            var peng = finalPengCandidate.result;
            var noSpeedGain = peng.ShantenAfter >= currentFollowUp.Shanten && peng.ShantenAfter > 0
                && (pengStructure is null || (pengStructure.Peng.MissingTiles >= pengStructure.Pass.MissingTiles
                    && pengStructure.Peng.LiveCopies <= pengStructure.Pass.LiveCopies
                    && pengStructure.Peng.ImprovementCopies <= pengStructure.Pass.ImprovementCopies));
            var wideFlexibleBeforeCall = currentFollowUp.Shanten >= 2
                && currentFollowUp.LiveUkeire >= 12
                && peng.ShantenAfter > 0
                && peng.LiveUkeireAfter <= currentFollowUp.LiveUkeire + 2;
            var narrowReadyTrap = currentFollowUp.Shanten == 1
                && peng.ShantenAfter == 0
                && currentFollowUp.LiveUkeire >= 12
                && peng.LiveUkeireAfter * 2 < currentFollowUp.LiveUkeire
                && roundStage <= 1;
            var damagesExistingReady = currentFollowUp.Shanten <= 0
                && peng.ShantenAfter <= 0
                && peng.LiveUkeireAfter < currentFollowUp.LiveUkeire;
			var deadReadyAfterPeng = peng.ShantenAfter <= 0
				&& peng.LiveUkeireAfter <= 0
				&& currentFollowUp.LiveUkeire > 0;
			var passWithinDecisionMargin = passCandidate.Action.Score >= peng.Action.Score - 45;
			if (deadReadyAfterPeng
				|| passWithinDecisionMargin && pengDevelopment?.Improves != true
                    && (noSpeedGain || wideFlexibleBeforeCall || narrowReadyTrap || damagesExistingReady))
            {
                passCandidate.Reasons = passCandidate.Reasons
					.Concat(new[] { deadReadyAfterPeng
						? "连续大脑反应闸门：拒绝碰成墙内 0 活张的死叫，保留门前真实改良张"
						: "连续大脑反应闸门：保留门前宽进张和当前听口，拒绝表面降向听的低质量碰牌" })
                    .ToArray();
                best = passCandidate;
            }
        }

        if (SichuanOpponentWideBedDefense.Applies(state))
        {
            foreach(var item in candidates.Where(c=>!c.result.OpponentWideBedDefenseAllowed))
            {
                item.result.Action=item.result.Action with{Score=int.MinValue/4};
                scores[item.action]=item.result.Action.Score;
            }
            if(!best.OpponentWideBedDefenseAllowed)
            {
                best=candidates.First(c=>c.action=="pass").result;
                best.Reasons=best.Reasons.Append("OPPONENT_WIDE_BED_AVOID_FORCED_RISK").ToArray();
            }
            best.Reasons=best.Reasons.Prepend(SichuanOpponentWideBedDefense.ActiveCode).ToArray();
        }

        var mandatoryGangCandidate = candidates.FirstOrDefault(item => item.action == "gang");
        if (mandatoryGang && mandatoryGangCandidate.result is not null)
        {
            mandatoryGangCandidate.result.Action = mandatoryGangCandidate.result.Action with
            {
                Score = best.Action.Score + 96,
                Reason = "规则要求执行杠牌"
            };
            scores["gang"] = mandatoryGangCandidate.result.Action.Score;
            best = mandatoryGangCandidate.result;
        }

        best.ValueCandidates = unifiedMelds.Candidates;
        if (!scores.ContainsKey("peng")) scores["peng"] = int.MinValue / 4;
        if (!scores.ContainsKey("gang")) scores["gang"] = int.MinValue / 4;
		best.Reasons = best.Reasons.Concat(new[] { "统一反事实层已参与全候选排序，最终动作服从规则、真实时序和连续大脑闸门" }).ToArray();
        best.ActionScores = new Dictionary<string, int>(scores);
        best.PengStructure = pengStructure;
        if (finalPengCandidate.result is not null)
            best.FutureSummary = best.FutureSummary.Concat(new[] {
                finalPengCandidate.result.PlannedSelfAction.Length > 0
                    ? $"PENG_IMMEDIATE_{finalPengCandidate.result.PlannedSelfAction.ToUpperInvariant()}_{finalPengCandidate.result.PlannedSelfActionTile}"
                    : $"PENG_PLANNED_DISCARD_{finalPengCandidate.result.PlannedDiscardTile}"
            }).ToArray();
        return best;
    }

    private SichuanReactionDecisionResult EvaluatePeng(
        SichuanStateView state,
        SichuanBeliefSnapshot belief,
        int reactionTileType,
        FollowUpSummary currentFollowUp,
        SichuanRoutePlanResult currentPlan,
        int roundStage,
        int threatLevel,
        double maxReadyPosterior,
        SichuanRoundBrainSnapshot? roundBrain,
        int sourceSeat,
        bool forceLightweight)
    {
        var handAfter = RemoveCopies(state.Hand18, reactionTileType, 2);
        var meldCountAfter = state.OwnMeldCount + 1;
        var plannedDiscard = -1;
        if (state.InformationMode != "oracle")
        {
            var projectedState = SichuanUnifiedDecisionEngine.ProjectPengContinuation(state, handAfter, reactionTileType, sourceSeat);
            plannedDiscard = new SichuanDecisionEngine().DecideDiscard(projectedState, forceLightweight, roundBrain).Action.TileType;
            if (plannedDiscard is < 0 or >= 27 || handAfter[plannedDiscard] <= 0)
                throw new InvalidOperationException("Peng continuation requires a legal discard from the current policy.");
        }
		var timing = _meldCounterfactual.Evaluate(
			state,
			"peng",
			reactionTileType,
			2,
			meldCountAfter,
			routeLoss: currentPlan.ForbidsMelds ? 12.0 : 0.0,
			risk: 0,
			gangGain: 0,
			belief: belief,
            plannedDiscardTile: plannedDiscard, gangSourceSeat: sourceSeat);

        if (timing.ImmediateSelfAction.Length > 0)
        {
            return new SichuanReactionDecisionResult
            {
                OpponentWideBedDefenseAllowed=SichuanOpponentWideBedDefense.SafeGang(state,belief,
                    currentFollowUp.Shanten,currentFollowUp.LiveUkeire,timing),
                Action = new SichuanAction(SichuanActionType.Peng, reactionTileType,
                    (int)Math.Round(timing.Value * 100), "碰后按同一自家动作策略开杠，再按实际补牌决定弃牌"),
                PlannedDiscardTile = -1, PlannedSelfAction = timing.ImmediateSelfAction,
                PlannedSelfActionTile = timing.ImmediateSelfActionTile,
                ShantenAfter = timing.Shanten, UkeireAfter = timing.LiveUkeire,
                LiveUkeireAfter = timing.LiveUkeire, CurrentShanten = currentFollowUp.Shanten,
                CurrentLiveUkeire = currentFollowUp.LiveUkeire, RoundStage = roundStage,
                ThreatLevel = threatLevel, MaxReadyPosterior = maxReadyPosterior,
                Reasons = new[] { "PENG_IMMEDIATE_SELF_ACTION_PRICED", "GANG_REPLACEMENT_PUBLIC_WALL_REBUILT",
                    "碰后仅允许其他合法暗杠；本次碰牌的补杠须等待后续自己的正常摸牌回合" },
                FutureSummary = new[] { timing.Transition }
            };
        }
		var followUp = new FollowUpSummary(
			timing.Shanten,
			timing.LiveUkeire,
			timing.LiveUkeire,
			timing.BestDiscardTile,
			Array.Empty<int>());
        var reDiscardsClaimedTile = followUp.BestDiscardTile == reactionTileType && followUp.BestDiscardTile >= 0;
        var currentPairCount = CountPairs(state.Hand18);
        var pairCountAfter = CountPairs(handAfter);
        var currentMeldCount = state.OwnMeldCount;
        var sevenPairsLikely = IsSevenPairsLikely(state.Hand18, currentMeldCount);
        var sevenPairsTenpai = IsSevenPairsTenpai(state.Hand18, currentMeldCount);
        var structureBoost = EstimatePengStructureBoost(
            reactionTileType,
            currentFollowUp,
            followUp,
            currentPairCount,
            pairCountAfter,
            sevenPairsLikely,
            roundStage);
        var oldHandPengBoost = EstimateOldHandPengBoost(
            currentFollowUp,
            followUp,
            currentPairCount,
            pairCountAfter,
            sevenPairsLikely,
            roundStage);
        var discardRisk = followUp.BestDiscardTile >= 0 ? _danger.EvaluateDetail(followUp.BestDiscardTile, state, belief) : new SichuanDangerEvaluation();
        var waitWallPosterior = EstimateWallPosterior(followUp.ImprovingTiles, belief);
        var waitBlockPosterior = EstimateBlockPosterior(followUp.ImprovingTiles, belief);
        var score = 96
            - followUp.Shanten * 108
            + followUp.LiveUkeire * 10
            + (currentFollowUp.Shanten - followUp.Shanten) * 118
            + (followUp.LiveUkeire - currentFollowUp.LiveUkeire) * 9
            + structureBoost
            + oldHandPengBoost
            + (int)Math.Round(waitWallPosterior * 96.0)
            - (int)Math.Round(waitBlockPosterior * 76.0)
            - discardRisk.Risk
            - roundStage * 12
            - threatLevel * 12;

        if (followUp.Shanten <= 0) score += 248;
        if (followUp.Shanten < currentFollowUp.Shanten) score += 132;
        if (followUp.Shanten == currentFollowUp.Shanten && followUp.Shanten <= 1 && followUp.LiveUkeire >= currentFollowUp.LiveUkeire - 2) score += 96;
        if (followUp.Shanten == 0 && currentFollowUp.Shanten > 0) score += 168;
        if (followUp.Shanten <= 1 && followUp.Shanten <= currentFollowUp.Shanten && followUp.LiveUkeire + 4 >= currentFollowUp.LiveUkeire)
            score += roundStage <= 1 ? 92 : 46;
        if (followUp.Shanten <= 0 && discardRisk.Risk < 70)
            score += 132;
        if (currentPairCount >= 3 && !sevenPairsLikely && followUp.Shanten <= currentFollowUp.Shanten)
            score += 64;
        if (followUp.Shanten > currentFollowUp.Shanten)
        {
            score -= 112;
        }
        else if (followUp.Shanten == currentFollowUp.Shanten && structureBoost + oldHandPengBoost < 80)
        {
            score -= 24;
        }
        if (followUp.LiveUkeire <= currentFollowUp.LiveUkeire && followUp.Shanten >= currentFollowUp.Shanten && structureBoost + oldHandPengBoost < 80) score -= 12;
        if (discardRisk.Risk >= 56) score -= 38;
        if (roundStage >= 2 && maxReadyPosterior >= 0.56 && followUp.Shanten > 0) score -= 72;
        if (maxReadyPosterior >= 0.68 && followUp.Shanten > 0) score -= 18;
        if (roundStage >= 2 && maxReadyPosterior >= 0.72 && discardRisk.Risk >= 70 && followUp.Shanten >= currentFollowUp.Shanten)
            score -= 460;
        if (maxReadyPosterior >= 0.88 && discardRisk.Risk >= 78 && followUp.Shanten > 0)
            score -= 180;
        if (roundStage <= 0 && followUp.Shanten == 0 && currentFollowUp.Shanten > 0 && followUp.LiveUkeire <= 3 && currentFollowUp.LiveUkeire >= 14)
            score -= 1080;
        if (ShouldPassWideNoSpeedPeng(currentFollowUp, followUp, roundStage, maxReadyPosterior))
            score -= 1180;
        if (reDiscardsClaimedTile)
            score -= 640;
        if (reDiscardsClaimedTile && state.Hand18[reactionTileType] >= 3)
            score -= 980;
        if (sevenPairsTenpai)
            score -= 1320;
        if (sevenPairsLikely && currentPairCount >= 5)
            score -= 6000;
        if (currentPlan.ForbidsMelds)
            score -= 6000;
        if (state.Hand18[reactionTileType] >= 3 && followUp.Shanten > 0)
            score -= 520;
		if (roundBrain?.WasTripletBroken(reactionTileType) == true)
			score -= 6000;

        var reasons = new List<string>
        {
            $"碰后最佳向听 {followUp.Shanten}",
            $"碰后活张 {followUp.LiveUkeire}",
            $"碰后首打危险 {discardRisk.Risk}",
        };
        if (currentPlan.ForbidsMelds)
            reasons.Add($"七对路线：{currentPlan.PrimaryRoute} 禁止碰牌，碰牌会破坏七对");
        if (state.Hand18[reactionTileType] >= 3 && followUp.Shanten > 0)
            reasons.Add("持续大脑：手中已有暗刻，碰牌会放弃第四张明杠收益");
        if (timing.ContinuationLegalContextApplied) reasons.Add("CONTINUATION_LEGAL_READY_CONTEXT");
        if (roundBrain?.WasTripletBroken(reactionTileType) == true)
            reasons.Add("持续大脑：此前主动拆过该暗刻，本次碰牌构成策略矛盾，强烈降权");
        if (sevenPairsLikely && currentPairCount >= 5)
            reasons.Add("七对路线：五对以上门清牌不碰，保留七对/龙七对");
        if (sevenPairsTenpai) reasons.Add("七对已听，碰牌会破坏听牌，优先过牌");
        if (reDiscardsClaimedTile) reasons.Add("碰后最优首打仍是同张，直接改碰属于无效副露");
        if (reDiscardsClaimedTile && state.Hand18[reactionTileType] >= 3)
            reasons.Add("已有三张可明杠时，碰后再打同张不如直接杠");
        if (followUp.Shanten <= 0) reasons.Add("碰后可直接成叫");
        if (followUp.Shanten < currentFollowUp.Shanten) reasons.Add("碰牌明显提速");
        if (followUp.Shanten == currentFollowUp.Shanten && followUp.Shanten <= 1 && followUp.LiveUkeire >= currentFollowUp.LiveUkeire - 2)
            reasons.Add("碰牌虽不降向听，但能更主动定型抢胡");
        if (followUp.Shanten <= 1 && followUp.LiveUkeire + 4 >= currentFollowUp.LiveUkeire)
            reasons.Add("老手进攻：碰后接近成叫且活张不差");
        if (followUp.Shanten >= currentFollowUp.Shanten) reasons.Add("碰牌未缩短成叫路径");
        if (structureBoost >= 60) reasons.Add("碰后对子冗余下降，牌型更利于早听");
        else if (structureBoost >= 30) reasons.Add("碰后结构更顺，提前定型");
        if (oldHandPengBoost >= 120) reasons.Add("对子多且七对路线不稳，老手主动碰牌抢听");
        else if (oldHandPengBoost >= 70) reasons.Add("碰牌不损连牌速度，优先定型逼近听牌");
        if (waitWallPosterior >= 0.45) reasons.Add("后验显示等张更偏向牌墙");
        if (waitBlockPosterior >= 0.38) reasons.Add("后验显示关键进张更可能在他家手里");
        if (discardRisk.Risk >= 56) reasons.Add("碰后第一打点炮风险偏高");
        if (roundStage >= 2 || maxReadyPosterior >= 0.48) reasons.Add("尾盘或后验压力偏高，非必要不碰");
        if (roundStage >= 2 && maxReadyPosterior >= 0.72 && discardRisk.Risk >= 70 && followUp.Shanten >= currentFollowUp.Shanten)
            reasons.Add("后期高后验且首打高危，碰牌未降向听，C# 强制降权");
        if (roundStage <= 0 && followUp.Shanten == 0 && currentFollowUp.Shanten > 0 && followUp.LiveUkeire <= 3 && currentFollowUp.LiveUkeire >= 14)
            reasons.Add("早期碰后虽成叫但听口过窄，放弃低价值碰牌");
        if (ShouldPassWideNoSpeedPeng(currentFollowUp, followUp, roundStage, maxReadyPosterior))
            reasons.Add("当前不碰也有宽进张，碰牌不降向听，优先保留门前弹性");

        var defenseAllowed = !SichuanOpponentWideBedDefense.Applies(state)
            || plannedDiscard>=0 && SichuanOpponentWideBedDefense.SafeClaim(currentFollowUp.Shanten,currentFollowUp.LiveUkeire,
                followUp.Shanten,followUp.LiveUkeire,SichuanOpponentWideBedDefense.ReferenceDiscardRisk(state,belief),
                _danger.Evaluate(plannedDiscard,state,belief));
        if(!defenseAllowed)reasons.Add("OPPONENT_WIDE_BED_REJECT_UNSAFE_PENG");
        return new SichuanReactionDecisionResult
        {
            OpponentWideBedDefenseAllowed=defenseAllowed,
            Action = new SichuanAction(SichuanActionType.Peng, reactionTileType, score, reasons[0]),
            PlannedDiscardTile = plannedDiscard,
            ShantenAfter = followUp.Shanten,
            UkeireAfter = followUp.Ukeire,
            LiveUkeireAfter = followUp.LiveUkeire,
            CurrentShanten = currentFollowUp.Shanten,
            CurrentLiveUkeire = currentFollowUp.LiveUkeire,
            ThreatLevel = threatLevel,
            RoundStage = roundStage,
            MaxReadyPosterior = maxReadyPosterior,
            Reasons = reasons,
            PosteriorSummary = BuildPosteriorSummary(waitWallPosterior, waitBlockPosterior, discardRisk.Risk, maxReadyPosterior, threatLevel),
            FutureSummary = BuildFutureSummary("peng", followUp, discardRisk.Risk, waitWallPosterior, waitBlockPosterior)
        };
    }

    private SichuanReactionDecisionResult EvaluateGang(
        SichuanStateView state,
        SichuanBeliefSnapshot belief,
        int reactionTileType,
        FollowUpSummary currentFollowUp,
        SichuanRoutePlanResult currentPlan,
        int roundStage,
        int threatLevel,
        double maxReadyPosterior,
        string reactionType,
        int sourceSeat)
    {
        var meldCountAfter = state.OwnMeldCount + 1;
        var timing = _meldCounterfactual.Evaluate(
            state,
            "gang",
            reactionTileType,
            3,
            meldCountAfter,
            routeLoss: currentPlan.ForbidsGangs ? 6.0 : 0,
            risk: 0,
			gangGain: 0,
			belief: belief,
            gangSourceSeat:sourceSeat);
        var followUp = new FollowUpSummary(
            timing.Shanten,
            timing.LiveUkeire,
            timing.LiveUkeire,
            timing.BestDiscardTile,
            Array.Empty<int>());
        var discardRisk = followUp.BestDiscardTile >= 0 ? _danger.EvaluateDetail(followUp.BestDiscardTile, state, belief) : new SichuanDangerEvaluation();
        var waitWallPosterior = EstimateWallPosterior(followUp.ImprovingTiles, belief);
        var waitBlockPosterior = EstimateBlockPosterior(followUp.ImprovingTiles, belief);
        var isMeldedGang = sourceSeat >= 0 && reactionType == "discard";
        var currentMeldCount = state.OwnMeldCount;
        var sevenPairsLikely = IsSevenPairsLikely(state.Hand18, currentMeldCount);
        var tripletRedundancy = state.Hand18[reactionTileType] >= 3;
        var gangTaxBonus = isMeldedGang ? 118 : 36;
        var meldedGangShapeBonus = 0;
        if (isMeldedGang && followUp.Shanten <= currentFollowUp.Shanten)
        {
            meldedGangShapeBonus += 96;
            if (!sevenPairsLikely) meldedGangShapeBonus += 132;
            if (tripletRedundancy) meldedGangShapeBonus += 58;
            if (followUp.LiveUkeire + 3 >= currentFollowUp.LiveUkeire) meldedGangShapeBonus += 48;
            if (roundStage <= 1 && maxReadyPosterior < 0.56) meldedGangShapeBonus += 52;
        }
        var score = 86
            - followUp.Shanten * 112
            + followUp.LiveUkeire * 11
            + (currentFollowUp.Shanten - followUp.Shanten) * 124
            + (int)Math.Round(waitWallPosterior * 74.0)
            - (int)Math.Round(waitBlockPosterior * 82.0)
            - (int)Math.Round(discardRisk.Risk * 0.82)
            - roundStage * 10
            - threatLevel * 12
            + gangTaxBonus
            + meldedGangShapeBonus;

        if (followUp.Shanten <= 0) score += 172;
        if (roundStage <= 1 && maxReadyPosterior < 0.52 && followUp.Shanten <= currentFollowUp.Shanten) score += 78;
        if (followUp.Shanten == 0 && currentFollowUp.Shanten > 0) score += 168;
        if (followUp.Shanten == currentFollowUp.Shanten && followUp.LiveUkeire >= currentFollowUp.LiveUkeire - 2) score += 112;
        if (followUp.Shanten <= currentFollowUp.Shanten && discardRisk.Risk < 64) score += 72;
        if (isMeldedGang && !sevenPairsLikely && followUp.Shanten <= currentFollowUp.Shanten && discardRisk.Risk < 72) score += 96;
        if (followUp.Shanten <= 0 && discardRisk.Risk < 70) score += 118;
        if (followUp.Shanten > currentFollowUp.Shanten) score -= 126;
        if (roundStage >= 1 && followUp.Shanten > 0) score -= 10;
        if (discardRisk.Risk >= 56) score -= 42;
        if (roundStage >= 2 && followUp.Shanten > 0) score -= 24;
        if (maxReadyPosterior >= 0.62 && followUp.Shanten > 0) score -= 12;
        if (sevenPairsLikely && CountPairs(state.Hand18) >= 5)
            score -= 6000;
        if (currentPlan.ForbidsGangs)
            score -= 6000;

        var reasons = new List<string>
        {
            $"杠后最佳向听 {followUp.Shanten}",
            $"杠后活张 {followUp.LiveUkeire}",
            $"杠后首打危险 {discardRisk.Risk}",
            "杠牌只在不拖慢成叫时考虑"
        };
        if (timing.ContinuationLegalContextApplied) reasons.Add("CONTINUATION_LEGAL_READY_CONTEXT");
        if (timing.BranchReadyValueApplied) reasons.Add("GANG_BRANCH_READY_VALUE_WEIGHTED_BEFORE_ROUNDING");
		if (timing.BrokenReadyOpportunityLoss>0)
			reasons.Add($"破坏当前听牌的分支机会成本 {timing.BrokenReadyOpportunityLoss:F4}，按当前过牌延续价值计入");
		if (timing.DeadReadyBranchMass>0)
			reasons.Add($"公开耗尽导致空听补牌分支 {timing.DeadReadyBranchMass:P1}，不按普通恢复听牌计价");
        if (currentPlan.ForbidsGangs)
            reasons.Add($"七对路线：{currentPlan.PrimaryRoute} 禁止杠牌，杠牌会破坏七对");
        if (sevenPairsLikely && CountPairs(state.Hand18) >= 5)
            reasons.Add("七对路线：五对以上门清牌不杠，保留七对/龙七对");
        if (followUp.Shanten <= 0) reasons.Add("杠后仍保持成叫");
        if (followUp.Shanten > currentFollowUp.Shanten) reasons.Add("杠牌会拖慢速度，直接降权");
        if (isMeldedGang && followUp.Shanten <= currentFollowUp.Shanten && !sevenPairsLikely)
            reasons.Add("明杠收益明确，且非七对路线");
        if (isMeldedGang && followUp.Shanten <= currentFollowUp.Shanten)
            reasons.Add("杠后不拖慢成叫，优先收雨钱/补牌");
        if (followUp.Shanten <= currentFollowUp.Shanten && discardRisk.Risk < 64) reasons.Add("杠后不拖慢且首打风险可控，主动收雨钱");
        if (waitWallPosterior >= 0.45) reasons.Add("后验显示后续摸进仍有支撑");
        if (waitBlockPosterior >= 0.38) reasons.Add("后验显示关键进张受阻");
        if (discardRisk.Risk >= 56) reasons.Add("杠后首打风险偏高");
        if (roundStage >= 2 || maxReadyPosterior >= 0.50) reasons.Add("尾盘或后验压力高，谨慎放弃杠牌");

        var defenseAllowed=SichuanOpponentWideBedDefense.SafeGang(state,belief,currentFollowUp.Shanten,currentFollowUp.LiveUkeire,timing);
        if(!defenseAllowed)reasons.Add("OPPONENT_WIDE_BED_REJECT_UNSAFE_GANG_BRANCH");
        return new SichuanReactionDecisionResult
        {
            OpponentWideBedDefenseAllowed=defenseAllowed,
            Action = new SichuanAction(SichuanActionType.Gang, reactionTileType, score, reasons[0]),
            ShantenAfter = followUp.Shanten,
            UkeireAfter = followUp.Ukeire,
            LiveUkeireAfter = followUp.LiveUkeire,
            CurrentShanten = currentFollowUp.Shanten,
            CurrentLiveUkeire = currentFollowUp.LiveUkeire,
            ThreatLevel = threatLevel,
            RoundStage = roundStage,
            MaxReadyPosterior = maxReadyPosterior,
            Reasons = reasons,
            PosteriorSummary = BuildPosteriorSummary(waitWallPosterior, waitBlockPosterior, discardRisk.Risk, maxReadyPosterior, threatLevel),
            FutureSummary = BuildFutureSummary("gang", followUp, discardRisk.Risk, waitWallPosterior, waitBlockPosterior)
        };
    }

    private FollowUpSummary EvaluateBestFollowUp(int[] hand18, int[] remaining18, int meldCount)
    {
        var currentShanten = _shanten.CalcBestShanten(hand18, meldCount);
        if (hand18.Sum() <= 1)
        {
            return new FollowUpSummary(currentShanten, 0, 0, -1, Array.Empty<int>());
        }

        var bestShanten = int.MaxValue;
        var bestUkeire = 0;
        var bestLive = 0;
        var bestTile = -1;

        for (var tileType = 0; tileType < hand18.Length; tileType++)
        {
            if (hand18[tileType] <= 0) continue;
            var shanten = _shanten.CalcShantenAfterDiscard(hand18, tileType, meldCount);
            var (ukeire, liveUkeire, _) = _ukeire.CalcUkeire(hand18, remaining18, tileType, meldCount);
            if (shanten < bestShanten
                || (shanten == bestShanten && liveUkeire > bestLive)
                || (shanten == bestShanten && liveUkeire == bestLive && ukeire > bestUkeire))
            {
                bestShanten = shanten;
                bestUkeire = ukeire;
                bestLive = liveUkeire;
                bestTile = tileType;
            }
        }

        if (bestTile < 0)
        {
            return new FollowUpSummary(currentShanten, 0, 0, -1, Array.Empty<int>());
        }

        var (_, _, improvingTiles) = _ukeire.CalcUkeire(hand18, remaining18, bestTile, meldCount);
        return new FollowUpSummary(bestShanten, bestUkeire, bestLive, bestTile, improvingTiles.ToArray());
    }

	private FollowUpSummary EvaluateWaitingFollowUp(SichuanStateView state, SichuanWallAvailability wallAvailability, int meldCount)
    {
        var hand18 = state.Hand18;
        var currentShanten = _shanten.CalcLegalShanten(hand18, meldCount, state.OwnDingQueSuit, meldCount == 0);
        var ready = currentShanten == 0 ? _readyPrices.Build(state, hand18, wallAvailability.ExpectedCounts18) : null;
        if (currentShanten == 0 && ready is null) currentShanten = 1;
        var improving = new List<int>();
		var live = 0.0;
        for (var draw = 0; draw < 27; draw++)
        {
			if (wallAvailability.ExpectedCounts18[draw] <= 0 || hand18[draw] >= 4) continue;
            var probe = (int[])hand18.Clone();
            probe[draw]++;
            var after = _shanten.CalcLegalShanten(probe, meldCount, state.OwnDingQueSuit, meldCount == 0);
            if (after >= currentShanten || (after == -1 && (ready is null || !ready.Waits.Any(w => w.TileType == draw)))) continue;
            improving.Add(draw);
			live += wallAvailability.ExpectedCounts18[draw];
        }
		return new FollowUpSummary(currentShanten, improving.Count, (int)Math.Round(live), -1, improving);
    }

    private static int[] RemoveCopies(int[] hand18, int tileType, int removeCount)
    {
        var clone = (int[])hand18.Clone();
        if (tileType < 0 || tileType >= clone.Length) return clone;
        clone[tileType] = Math.Max(0, clone[tileType] - removeCount);
        return clone;
    }

    private int ResolveThreatLevel(SichuanStateView state, SichuanBeliefSnapshot belief)
    {
        var total = 0;
        for (var seat = 0; seat < state.HasHu.Length; seat++)
        {
            if (seat == state.SeatIndex || state.HasHu[seat]) continue;
            var seatDanger = 0;
            if (belief.SeatReadyPosterior.GetValueOrDefault(seat, 0.0) >= 0.56) seatDanger += 2;
            else if (belief.SeatReadyPosterior.GetValueOrDefault(seat, 0.0) >= 0.40) seatDanger += 1;
            if (state.IsCalled[seat] || state.IsReady[seat]) seatDanger += 1;
            if (state.MeldCount(seat) >= 2) seatDanger += 1;
            total += seatDanger;
        }
        return Math.Clamp(total, 0, 5);
    }

    private static int BuildPassScore(FollowUpSummary currentFollowUp, int roundStage, int threatLevel, double maxReadyPosterior, int wallCount, double wallPosterior, double blockPosterior, int discardRisk)
    {
        var score = 24
            - currentFollowUp.Shanten * 84
            + currentFollowUp.LiveUkeire * 4
            + Math.Min(12, wallCount)
            + (int)Math.Round(wallPosterior * 48.0)
            - (int)Math.Round(blockPosterior * 88.0)
            - (int)Math.Round(discardRisk * 0.34)
            - roundStage * 12;
        if (threatLevel >= 3) score += 10;
        if (maxReadyPosterior >= 0.56) score += 12;
        return score;
    }

    private static IReadOnlyList<string> BuildPassReasons(FollowUpSummary currentFollowUp, int roundStage, int threatLevel, double maxReadyPosterior)
    {
        var reasons = new List<string>
        {
            $"当前最快向听 {currentFollowUp.Shanten}",
            $"当前潜在活张 {currentFollowUp.LiveUkeire}",
            "仅在副露收益不足时才选择过牌"
        };
        if (threatLevel >= 3 || maxReadyPosterior >= 0.56) reasons.Add("桌面压力偏高，过更稳");
        if (roundStage >= 2) reasons.Add("后期不为低价值副露冒险");
        return reasons;
    }

    private static IReadOnlyList<string> BuildRouteProtectionPassReasons(
        SichuanStateView state,
        SichuanRoutePlanResult currentPlan)
    {
        var currentMeldCount = state.OwnMeldCount;
        var pairCount = CountPairs(state.Hand18);
        if (currentPlan.ForbidsMelds)
            return Array.Empty<string>();
        if (currentMeldCount == 0 && pairCount >= 5 && IsSevenPairsLikely(state.Hand18, currentMeldCount))
            return new[] { "七对路线：五对以上门清牌优先过牌，保留七对/龙七对" };
        return Array.Empty<string>();
    }

    private static IReadOnlyList<string> BuildPosteriorSummary(double wallPosterior, double blockPosterior, int discardRisk, double maxReadyPosterior, int threatLevel)
    {
        return new[]
        {
            $"牌墙后验 {wallPosterior * 100.0:0}%",
            $"他家持张后验 {blockPosterior * 100.0:0}%",
            $"首打危险 {discardRisk}%",
            $"最高听牌后验 {maxReadyPosterior * 100.0:0}%",
            $"桌面威胁 {threatLevel}"
        };
    }

    private static IReadOnlyList<string> BuildFutureSummary(string action, FollowUpSummary followUp, int discardRisk, double wallPosterior, double blockPosterior)
    {
        var actionLabel = action switch
        {
            "pass" => "过后",
            "peng" => "碰后",
            "gang" => "杠后",
            _ => "后续"
        };
        return new[]
        {
            $"{actionLabel}最快向听 {followUp.Shanten}",
            $"{actionLabel}活张 {followUp.LiveUkeire}",
            $"{actionLabel}墙内进张偏强 {wallPosterior * 100.0:0}%",
            $"{actionLabel}被捏风险 {blockPosterior * 100.0:0}%",
            $"{actionLabel}首打风险 {discardRisk}%"
        };
    }

    private bool ShouldSearchReaction(IReadOnlyList<(string action, SichuanReactionDecisionResult result, int[] handAfter, int meldCountAfter, int ownDrawOffset)> candidates)
    {
        if (candidates.Count < 2) return false;
        var ordered = candidates
            .OrderByDescending(item => item.result.Action.Score)
            .ToArray();
        if (ordered[0].action is "peng" or "gang")
        {
            if (ordered[0].result.RoundStage <= 1)
                return true;
            if (ordered[0].result.CurrentShanten <= 1 || ordered[0].result.ShantenAfter <= 1)
                return true;
        }
        var gap = ordered[0].result.Action.Score - ordered[1].result.Action.Score;
        if (gap <= 90) return true;
        if (ordered[0].result.ShantenAfter == ordered[1].result.ShantenAfter && Math.Abs(ordered[0].result.LiveUkeireAfter - ordered[1].result.LiveUkeireAfter) <= 4)
            return true;
        return false;
    }

    private Dictionary<string, double> EvaluateReactionSearchBonuses(
        SichuanStateView state,
		SichuanBeliefSnapshot belief,
		IReadOnlyList<(string action, SichuanReactionDecisionResult result, int[] handAfter, int meldCountAfter, int ownDrawOffset)> candidates,
        ref int simulations)
    {
        var bonuses = candidates.ToDictionary(item => item.action, _ => 0.0);
        var firstSuit = CanonicalSampleFirstSuit(state, belief);
        for (var rollout = 0; rollout < ReactionSearchRollouts; rollout++)
        {
            var seed = unchecked(20260809
                ^ state.RoundIndex * 397
                ^ state.TurnIndex * 67
                ^ state.EventVersion.GetHashCode()
                ^ rollout * 7919);
			var wallOrder = _wall.SampleWallOrder(state, belief, seed, firstSuit);
            foreach (var candidate in candidates)
            {
				bonuses[candidate.action] += SimulateReactionFuture(
					state,
					candidate.handAfter,
					candidate.meldCountAfter,
					ReactionSearchDepth,
					wallOrder,
					candidate.ownDrawOffset);
                simulations++;
            }
        }
        foreach (var key in bonuses.Keys.ToArray())
            bonuses[key] /= Math.Max(1, ReactionSearchRollouts);
        var min = bonuses.Values.Min();
        return bonuses.ToDictionary(item => item.Key, item => (item.Value - min) * 0.18);
    }

    private static int CanonicalSampleFirstSuit(SichuanStateView state, SichuanBeliefSnapshot belief)
    {
        // Suit labels are arbitrary. The common random wall order must begin
        // from the same *structural* suit after a cyclic suit rotation, or a
        // near-tied Peng/Pass choice can flip solely because of tile indices.
        int Compare(int left, int right)
        {
            for (var rank = 0; rank < 9; rank++)
            {
                var a = left * 9 + rank; var b = right * 9 + rank;
                var difference = state.Hand18[a].CompareTo(state.Hand18[b]);
                if (difference != 0) return difference;
                difference = state.Remaining18[a].CompareTo(state.Remaining18[b]);
                if (difference != 0) return difference;
                difference = state.Visible18[a].CompareTo(state.Visible18[b]);
                if (difference != 0) return difference;
                difference = belief.TileWallPosterior.GetValueOrDefault(a, 0.0)
                    .CompareTo(belief.TileWallPosterior.GetValueOrDefault(b, 0.0));
                if (difference != 0) return difference;
            }
            return 0;
        }
        var first = 0;
        for (var suit = 1; suit < 3; suit++) if (Compare(suit, first) < 0) first = suit;
        return first;
    }

    private double SimulateReactionFuture(
		SichuanStateView state,
		int[] initialHand,
		int meldCount,
		int depth,
		IReadOnlyList<int> wallOrder,
		int ownDrawOffset)
    {
        var hand = (int[])initialHand.Clone();
		var remaining = new int[27];
		foreach (var tile in wallOrder.Where(tile => tile is >= 0 and < 27))
			remaining[tile]++;
        var total = 0.0;
		var ownDraws = 0;
		var activePlayers = Math.Max(2, state.ActiveSeats.Count(active => active));
		for (var drawIndex = 0; drawIndex < wallOrder.Count && ownDraws < depth; drawIndex++)
        {
			var draw = wallOrder[drawIndex];
			if (draw is < 0 or >= 27) continue;
			remaining[draw] = Math.Max(0, remaining[draw] - 1);
			var isOwnDraw = drawIndex >= ownDrawOffset
				&& (drawIndex - ownDrawOffset) % activePlayers == 0;
			if (!isOwnDraw) continue;
            hand[draw]++;
            var followUp = EvaluateBestFollowUp(hand, remaining, meldCount);
            total += (8 - followUp.Shanten) * 1.7 + followUp.LiveUkeire * 0.34 + followUp.Ukeire * 0.16;
            if (followUp.Shanten <= 0) total += 3.6;
            if (followUp.BestDiscardTile >= 0 && hand[followUp.BestDiscardTile] > 0)
                hand[followUp.BestDiscardTile]--;
			ownDraws++;
        }
		return total / Math.Max(1, ownDraws);
    }

    private static int EstimatePengStructureBoost(
        int reactionTileType,
        FollowUpSummary currentFollowUp,
        FollowUpSummary followUp,
        int currentPairCount,
        int pairCountAfter,
        bool sevenPairsLikely,
        int roundStage)
    {
        if (sevenPairsLikely) return 0;
        var boost = 0;
        var pairReduction = Math.Max(0, currentPairCount - pairCountAfter);
        if (pairReduction > 0 && followUp.Shanten <= currentFollowUp.Shanten)
            boost += 42 + pairReduction * 18;
        if (currentPairCount >= 4 && pairReduction > 0 && followUp.Shanten <= Math.Min(2, currentFollowUp.Shanten))
            boost += 34;
        if (currentFollowUp.Shanten <= 2 && followUp.Shanten <= currentFollowUp.Shanten && followUp.LiveUkeire + 2 >= currentFollowUp.LiveUkeire)
            boost += 28;
        if (roundStage <= 1 && IsEdgeHeavyPair(reactionTileType) && followUp.Shanten <= currentFollowUp.Shanten)
            boost += 22;
        if (followUp.Shanten == currentFollowUp.Shanten && followUp.LiveUkeire >= currentFollowUp.LiveUkeire && pairReduction > 0)
            boost += 20;
        return boost;
    }

    private static int EstimateOldHandPengBoost(
        FollowUpSummary currentFollowUp,
        FollowUpSummary followUp,
        int currentPairCount,
        int pairCountAfter,
        bool sevenPairsLikely,
        int roundStage)
    {
        var pairReduction = Math.Max(0, currentPairCount - pairCountAfter);
        if (pairReduction <= 0 || followUp.Shanten > currentFollowUp.Shanten)
            return 0;

        var boost = 0;
        var sevenPairsRouteWeak = !sevenPairsLikely || roundStage >= 1 || currentFollowUp.Shanten > 1;
        if (currentPairCount >= 3 && sevenPairsRouteWeak)
            boost += 78;
        if (currentPairCount >= 4 && sevenPairsRouteWeak)
            boost += 46;
        if (followUp.Shanten <= 1)
            boost += 72;
        if (followUp.Shanten == 0)
            boost += 96;
        if (followUp.LiveUkeire + 3 >= currentFollowUp.LiveUkeire)
            boost += 28;
        if (roundStage <= 1)
            boost += 24;
        return boost;
    }

    private static int CountPairs(int[] hand18)
    {
        var count = 0;
        for (var index = 0; index < hand18.Length; index++)
        {
            if (hand18[index] >= 2) count++;
        }
        return count;
    }

    private static bool HasPairRouteException(
        SichuanStateView state,
        FollowUpSummary currentFollowUp,
        SichuanRoutePlanResult currentPlan,
        int roundStage)
    {
        if (roundStage > 1 || currentFollowUp.Shanten < 2 || currentPlan.ForbidsMelds)
            return false;
        if (CountPairs(state.Hand18) < 4)
            return false;
        var activeOpponents = Enumerable.Range(0, state.DingQueSuits.Length)
            .Where(seat => seat != state.SeatIndex && state.ActiveSeats[seat] && !state.HasHu[seat])
            .Select(seat => state.DingQueSuits[seat])
            .Where(suit => suit is >= 0 and < 3)
            .ToArray();
        return activeOpponents.GroupBy(suit => suit).Any(group => group.Count() >= 2);
    }

    private static bool IsWeakEmbeddedPairPeng(SichuanStateView state, int reactionTileType, int roundStage)
    {
        if (roundStage > 1 || reactionTileType is < 0 or >= 27)
            return false;
        if (state.OwnDingQueSuit == reactionTileType / 9 || state.Hand18[reactionTileType] != 2)
            return false;
        var suitStart = reactionTileType / 9 * 9;
        var rank = reactionTileType % 9;
        var hasNeighbour = false;
        for (var delta = -2; delta <= 2; delta++)
        {
            if (delta == 0) continue;
            var r = rank + delta;
            if (r is >= 0 and < 9 && state.Hand18[suitStart + r] > 0)
            {
                hasNeighbour = true;
                break;
            }
        }
        if (!hasNeighbour) return false;

        var after = (int[])state.Hand18.Clone();
        after[reactionTileType] -= 2;
        var hasStrongBlock = false;
        for (var start = 0; start < 9; start++)
        {
            if (after[suitStart + start] <= 0) continue;
            if (start + 1 < 9 && after[suitStart + start + 1] > 0
                && start >= 2 && start <= 6)
                hasStrongBlock = true;
            if (start + 2 < 9 && after[suitStart + start + 2] > 0
                && start >= 2 && start <= 5)
                hasStrongBlock = true;
        }
        return !hasStrongBlock;
    }

    private static bool IsStrongEmbeddedPairPeng(SichuanStateView state, int reactionTileType, int roundStage)
    {
        if (roundStage > 1 || reactionTileType is < 0 or >= 27)
            return false;
        if (state.OwnDingQueSuit == reactionTileType / 9 || state.Hand18[reactionTileType] != 2)
            return false;
        var suitStart = reactionTileType / 9 * 9;
        var rank = reactionTileType % 9;
        for (var r = 0; r < 9; r++)
            if (r != rank && state.Hand18[suitStart + r] >= 2)
                return false;
        var after = (int[])state.Hand18.Clone();
        after[reactionTileType] -= 2;
        for (var start = 2; start <= 6; start++)
        {
            if (after[suitStart + start] <= 0) continue;
            if (start + 1 < 9 && after[suitStart + start + 1] > 0) return true;
            if (start + 2 < 9 && start <= 5 && after[suitStart + start + 2] > 0) return true;
        }
        return false;
    }

    private bool ShouldForceOldHandPeng(
        SichuanStateView state,
        int reactionTileType,
        FollowUpSummary currentFollowUp,
        SichuanReactionDecisionResult pengResult,
        int roundStage,
        int threatLevel,
        double maxReadyPosterior)
    {
        if (reactionTileType < 0 || reactionTileType >= state.Hand18.Length || state.Hand18[reactionTileType] < 2)
            return false;
        if (pengResult.ShantenAfter > currentFollowUp.Shanten)
            return false;
        if (threatLevel >= 4 && maxReadyPosterior >= 0.70 && pengResult.ShantenAfter > 0 && pengResult.ShantenAfter >= currentFollowUp.Shanten)
            return false;
        if (roundStage >= 2
            && pengResult.ShantenAfter >= currentFollowUp.Shanten
            && pengResult.LiveUkeireAfter + 4 < currentFollowUp.LiveUkeire
            && (state.WallCount <= 5 || threatLevel >= 4 || maxReadyPosterior >= 0.56))
        {
            return false;
        }
        var meldCount = state.OwnMeldCount;
        if (IsSevenPairsTenpai(state.Hand18, meldCount))
            return false;
        var sevenPairsLikely = IsSevenPairsLikely(state.Hand18, meldCount);
        if (sevenPairsLikely && currentFollowUp.Shanten <= 1 && roundStage <= 0)
            return false;
        var handAfter = RemoveCopies(state.Hand18, reactionTileType, 2);
        var followUp = EvaluateBestFollowUp(handAfter, state.Remaining18, meldCount + 1);
        if (followUp.BestDiscardTile == reactionTileType && followUp.BestDiscardTile >= 0)
            return false;
        if (ShouldPassWideNoSpeedPeng(currentFollowUp, followUp, roundStage, maxReadyPosterior))
            return false;
        var pairCount = CountPairs(state.Hand18);
        if (pengResult.ShantenAfter <= 0)
            return true;
        if (pengResult.ShantenAfter < currentFollowUp.Shanten)
            return true;
        if (pairCount >= 3 && pengResult.ShantenAfter <= 1)
            return true;
        if (pairCount >= 4 && roundStage <= 1)
            return true;
        return roundStage <= 1 && pengResult.LiveUkeireAfter + 4 >= currentFollowUp.LiveUkeire;
    }

    private static bool ShouldPassWideNoSpeedPeng(
        FollowUpSummary currentFollowUp,
        FollowUpSummary followUp,
        int roundStage,
        double maxReadyPosterior)
    {
        return roundStage <= 1
            && maxReadyPosterior < 0.56
            && currentFollowUp.Shanten >= 2
            && followUp.Shanten >= currentFollowUp.Shanten
            && currentFollowUp.LiveUkeire >= 12
            && followUp.LiveUkeire >= currentFollowUp.LiveUkeire
            && followUp.Shanten > 1;
    }

    private static bool ShouldForceMeldedGang(
        SichuanStateView state,
        int reactionTileType,
        FollowUpSummary currentFollowUp,
        SichuanReactionDecisionResult gangResult,
        int roundStage,
        int threatLevel,
        double maxReadyPosterior,
        string reactionType,
        int sourceSeat)
    {
        if (reactionType != "discard" || sourceSeat < 0)
            return false;
        if (reactionTileType < 0 || reactionTileType >= state.Hand18.Length || state.Hand18[reactionTileType] < 3)
            return false;
        if (gangResult.ShantenAfter > currentFollowUp.Shanten)
            return false;
        var meldCount = state.OwnMeldCount;
        if (IsSevenPairsLikely(state.Hand18, meldCount))
            return false;
        if (threatLevel >= 4 && maxReadyPosterior >= 0.70 && gangResult.ShantenAfter > 0)
            return false;
        if (roundStage >= 2 && maxReadyPosterior >= 0.62 && gangResult.ShantenAfter > 0)
            return false;
        if (gangResult.ShantenAfter <= 0)
            return true;
        if (gangResult.ShantenAfter < currentFollowUp.Shanten)
            return true;
        return roundStage <= 1 && gangResult.LiveUkeireAfter + 3 >= currentFollowUp.LiveUkeire;
    }

    private static bool ShouldForceLateWallTripletGang(
        SichuanStateView state,
        int reactionTileType,
        FollowUpSummary currentFollowUp,
        SichuanReactionDecisionResult gangResult,
        string reactionType,
        int sourceSeat)
    {
        if (reactionType != "discard" || sourceSeat < 0)
            return false;
        if (state.WallCount > 2)
            return false;
        if (reactionTileType < 0 || reactionTileType >= state.Hand18.Length || state.Hand18[reactionTileType] < 3)
            return false;
        var meldCount = state.OwnMeldCount;
        if (IsSevenPairsLikely(state.Hand18, meldCount))
            return false;
        return gangResult.ShantenAfter <= currentFollowUp.Shanten;
    }

    private static bool IsSevenPairsLikely(int[] hand18, int meldCount)
    {
        if (meldCount > 0) return false;
        var pairs = 0;
        var triplets = 0;
        var singles = 0;
        for (var index = 0; index < hand18.Length; index++)
        {
            if (hand18[index] >= 2) pairs++;
            if (hand18[index] >= 3) triplets++;
            if (hand18[index] == 1) singles++;
        }
        return pairs >= 5 && triplets <= 1 && singles <= 3;
    }

    private bool IsSevenPairsTenpai(int[] hand18, int meldCount)
    {
        return meldCount <= 0 && _shanten.CalcSevenPairsShanten(hand18) <= 0;
    }

    private static bool IsEdgeHeavyPair(int tileType)
    {
        var rank = tileType % 9 + 1;
        return rank is 1 or 2 or 8 or 9;
    }

    private static double EstimateWallPosterior(IReadOnlyList<int> improvingTiles, SichuanBeliefSnapshot belief)
    {
        if (improvingTiles.Count == 0) return 0.0;
        var total = 0.0;
        foreach (var tileType in improvingTiles)
            total += belief.TileWallPosterior.GetValueOrDefault(tileType, 0.0);
        return total / improvingTiles.Count;
    }

    private static double EstimateBlockPosterior(IReadOnlyList<int> improvingTiles, SichuanBeliefSnapshot belief)
    {
        if (improvingTiles.Count == 0) return 0.0;
        var total = 0.0;
        foreach (var tileType in improvingTiles)
        {
            var bestHolder = 0.0;
            foreach (var seatMap in belief.SeatTileHoldProbability.Values)
                bestHolder = Math.Max(bestHolder, seatMap.GetValueOrDefault(tileType, 0.0));
            total += bestHolder;
        }
        return total / improvingTiles.Count;
    }

    private sealed record FollowUpSummary(int Shanten, int Ukeire, int LiveUkeire, int BestDiscardTile, IReadOnlyList<int> ImprovingTiles);
}
