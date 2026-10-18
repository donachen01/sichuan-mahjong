using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;
using SichuanMahjong.AI.Core.Strategy;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>A narrow one-off-suit investment with two available own draws.
/// Known target copies give exact ordered-position receipt arithmetic under
/// a fixed no-claim/no-exit schedule. Other-suit wall weights and danger remain
/// public approximations. This is not terminal simulation or whole-game EV.</summary>
public sealed class SichuanSingleLaneReadyInvestment
{
    public double TwoDrawIncome(SichuanStateView state, int discard, SichuanWallAvailability wall)
    {
        var lane = SichuanSingleLaneEvaluator.ResolveSuit(state);
        if (lane < 0 || state.WallCount < 2) return 0;
        var hand = state.Hand18.ToArray(); hand[discard]--;
        var prices = new SichuanReadyWaitPricing();
        var payers = Enumerable.Range(0, 4).Count(s => s != state.SeatIndex && state.ActiveSeats[s] && !state.HasHu[s]);
        var ready = prices.Build(state, hand, wall.ExpectedCounts18);
        if (ready is not null)
        {
            var income = ready.Waits.Sum(w => w.PublicWallWeight * w.SelfDrawPerPayer) * payers;
            return income / wall.WallCount + (1 - ready.PublicDrawableMass / wall.WallCount)
                * income / (wall.WallCount - 1);
        }
        var other = Enumerable.Range(0, 27).Where(t => t / 9 != lane && hand[t] > 0).ToArray();
        if (other.Length != 1 || hand[other[0]] != 1) return 0;
        double total = 0;
        for (int draw = lane * 9; draw < lane * 9 + 9; draw++)
        {
            var copies = wall.KnownWallCounts18[draw];
            if (copies <= 0 || hand[draw] >= 4) continue;
            hand[draw]++; hand[other[0]]--;
            var remaining = wall.KnownWallCounts18.Select(n => (double)n).ToArray(); remaining[draw]--;
            var after = prices.Build(state, hand, remaining);
            if (after is not null)
                total += copies / (double)wall.WallCount
                    * after.Waits.Sum(w => w.PublicWallWeight * w.SelfDrawPerPayer) * payers / (wall.WallCount - 1);
            hand[other[0]]++; hand[draw]--;
        }
        return total;
    }

    public SichuanCourseTempoChoice? Select(SichuanStateView state,
        IReadOnlyList<SichuanCandidateDetail> candidates, int incumbent,
        SichuanWallAvailability wall, double currentChaJiao)
    {
        var lane = SichuanSingleLaneEvaluator.ResolveSuit(state);
        var current = candidates.First(c => c.TileType == incumbent);
        if (state.InformationMode != "public" || lane < 0 || state.OwnDingQueSuit is < 0 or > 2 || state.WallCount < 8
            || !SichuanSingleLaneSupply.HasKnownWallSuit(state, lane)
            || SichuanSingleLaneSupply.DrawSchedule(state).Count(s => s == state.SeatIndex) < 2
            || SichuanDistinctDingQueHuPolicy.AssessDanger(state, new()) > 0
            || state.Hand18.Skip(state.OwnDingQueSuit * 9).Take(9).Any(n => n > 0)
            || SichuanDevelopmentPolicy.Melds(state,state.SeatIndex).Any(m => m.TileType / 9 != lane)) return null;
        var reference = TwoDrawIncome(state, incumbent, wall);
        var options = candidates.Where(c => c.TileType / 9 != lane && c.Shanten is 0 or 1
                && c.Shanten <= current.Shanten + 1 && c.Danger <= 45)
            .Select(c => (Candidate:c, Income:TwoDrawIncome(state,c.TileType,wall)))
            .Where(x => x.Income > reference + Math.Max(0, x.Candidate.ExpectedDealInLoss - current.ExpectedDealInLoss)
                // Late investment must cover losing the entire current
                // projected cha-jiao receipt, rather than treating it as free.
                + (state.WallCount <= 8 ? Math.Max(0,currentChaJiao) : 0) + 1e-9)
            .OrderByDescending(x => x.Income).ThenBy(x => x.Candidate.Danger).ToArray();
        if (options.Length == 0 || options[0].Candidate.TileType == incumbent) return null;
        var best = options[0];
        return new(best.Candidate.TileType, best.Candidate.Shanten == 0
            ? "SINGLE_LANE_READY_QUALITY_CASH_OUT" : "SINGLE_LANE_READY_QUALITY_INVESTMENT", new[] {
            best.Candidate.Shanten == 0 ? "单行道目标门已形成有效听牌，舍掉副门兑现优质听口，不让换听发展机械撤销本次成叫"
                : "单行道公开清缺和活张支持：允许牺牲眼前下叫，保留目标门并在下一次进张后弃掉最后一张副门",
            $"两次本家摸牌条件收入：保留路线 {best.Income:F4}，原路线 {reference:F4}；计入首打风险差及尾盘查叫机会成本",
            "SINGLE_LANE_TWO_OWN_DRAWS_CONDITIONAL_RECEIPTS_NOT_TERMINAL_EV"
        });
    }
}
