using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanHellOracleEngine
{
    private readonly SichuanHellChallengeEngine _challenge = new();

    public SichuanHellOracleResult DecideDiscard(
        SichuanStateView state,
        IReadOnlyList<IReadOnlyList<int>> allHands18,
        IReadOnlyList<int> exactWall18,
        int fairTileType = -1,
        int actualTileType = -1,
        IReadOnlyList<int>? currentScores = null)
    {
        var challenge = _challenge.DecideDiscard(state, allHands18, exactWall18, currentScores);
        var hand = state.Hand18;
        var meldCount = state.Melds18[state.SeatIndex].Count / 3;
        var bestTile = challenge.Action.TileType;
        var bestFeedsHumanHu = challenge.OracleFeedsHumanHu;
        var bestFeedsHumanPeng = challenge.OracleFeedsHumanPeng;
        var bestFeedsHumanGang = challenge.OracleFeedsHumanGang;
        var bestKeepsReady = challenge.ExactKeepsReady;
        var bestWallRemaining = challenge.ExactWallRemaining;

        var fairDealInTargetSeats = fairTileType >= 0
            ? ResolveDealInTargetSeats(state, allHands18, fairTileType)
            : Array.Empty<int>();
        var fairExactDealIn = fairDealInTargetSeats.Count > 0;
        var fairFeedsHumanHu = fairDealInTargetSeats.Contains(0);
        var fairFeedsHumanGang = fairTileType >= 0 && CanHumanGang(state, allHands18, fairTileType);
        var fairFeedsHumanPeng = fairTileType >= 0 && !fairFeedsHumanGang && CanHumanPeng(state, allHands18, fairTileType);
        var fairHand = fairTileType >= 0 && fairTileType < hand.Length && hand[fairTileType] > 0
            ? RemoveOne(hand, fairTileType)
            : Array.Empty<int>();
        var fairReadyTiles = fairHand.Length == 18 ? GetExactReadyTiles(fairHand, meldCount) : new List<int>();
        var fairExactWallRemaining = fairReadyTiles.Count > 0
            ? fairReadyTiles.Sum(tile => SichuanHellChallengeEngine.SafeCount(exactWall18, tile))
            : 0;
        var category = ClassifyDifference(
            state,
            fairTileType,
            bestTile,
            fairExactDealIn,
            fairFeedsHumanHu,
            bestFeedsHumanHu,
            fairFeedsHumanPeng,
            bestFeedsHumanPeng,
            fairFeedsHumanGang,
            bestFeedsHumanGang,
            bestKeepsReady,
            fairReadyTiles.Count > 0,
            bestWallRemaining,
            fairExactWallRemaining);
        var severity = ResolveSeverity(category, fairTileType, bestTile, state, allHands18, fairFeedsHumanHu, fairFeedsHumanGang);
        return new SichuanHellOracleResult
        {
            DecisionType = "discard",
            Action = challenge.Action,
            Category = category,
            Severity = severity,
            ExactDealIn = challenge.ExactDealIn,
            FairExactDealIn = fairExactDealIn,
            OracleExactDealIn = challenge.OracleExactDealIn,
            FairFeedsHumanHu = fairFeedsHumanHu,
            OracleFeedsHumanHu = bestFeedsHumanHu,
            FairFeedsHumanPeng = fairFeedsHumanPeng,
            OracleFeedsHumanPeng = bestFeedsHumanPeng,
            FairFeedsHumanGang = fairFeedsHumanGang,
            OracleFeedsHumanGang = bestFeedsHumanGang,
            HumanPressureLevel = challenge.HumanPressureLevel,
            FairDealInTargetSeats = fairDealInTargetSeats,
            OracleDealInTargetSeats = challenge.OracleDealInTargetSeats,
            ExactKeepsReady = bestKeepsReady,
            ExactWallRemaining = bestWallRemaining,
            SelectedShanten = challenge.SelectedShanten,
            SelectedLiveUkeire = challenge.SelectedLiveUkeire,
            SelectedWaitCount = challenge.SelectedWaitCount,
            SelectedTier = challenge.SelectedTier,
            FairTileType = fairTileType,
            ActualTileType = actualTileType,
            Reasons = challenge.Reasons
        };
    }

    private static string ClassifyDifference(
        SichuanStateView state,
        int fairTileType,
        int oracleTileType,
        bool fairExactDealIn,
        bool fairFeedsHumanHu,
        bool oracleFeedsHumanHu,
        bool fairFeedsHumanPeng,
        bool oracleFeedsHumanPeng,
        bool fairFeedsHumanGang,
        bool oracleFeedsHumanGang,
        bool oracleKeepsReady,
        bool fairKeepsReady,
        int oracleWallRemaining,
        int fairWallRemaining)
    {
        if (fairTileType < 0 || oracleTileType < 0)
            return "missing_result";
        if (fairTileType == oracleTileType)
            return "same_action";
        if (fairFeedsHumanHu && !oracleFeedsHumanHu)
            return "human_hu_suppression";
        if (fairFeedsHumanGang && !oracleFeedsHumanGang)
            return "human_gang_suppression";
        if (fairFeedsHumanPeng && !oracleFeedsHumanPeng)
            return "human_peng_suppression";
        if (fairExactDealIn)
            return "risk_underestimated";
        if (state.WallCount <= 6 && oracleKeepsReady && !fairKeepsReady)
            return "situation_goal_error";
        if (oracleKeepsReady && !fairKeepsReady)
            return "wait_shape_error";
        if (oracleWallRemaining >= fairWallRemaining + 4)
            return "wall_posterior_error";
        return "hand_efficiency_error";
    }

    private static string ResolveSeverity(
        string category,
        int fairTileType,
        int oracleTileType,
        SichuanStateView state,
        IReadOnlyList<IReadOnlyList<int>> allHands18,
        bool fairFeedsHumanHu,
        bool fairFeedsHumanGang)
    {
        if (category == "same_action")
            return "none";
        if (category == "missing_result")
            return "medium";
        if (fairFeedsHumanHu || fairFeedsHumanGang)
            return "high";
        if (fairTileType >= 0 && AnyOpponentCanHu(state, allHands18, fairTileType))
            return "high";
        return category == "risk_underestimated" ? "high" : "medium";
    }

    private static bool AnyOpponentCanHu(SichuanStateView state, IReadOnlyList<IReadOnlyList<int>> allHands18, int discardTileType)
        => ResolveDealInTargetSeats(state, allHands18, discardTileType).Count > 0;

    private static bool CanHumanPeng(SichuanStateView state, IReadOnlyList<IReadOnlyList<int>> allHands18, int discardTileType)
        => SichuanHellChallengeEngine.CanHumanPeng(state, allHands18, discardTileType);

    private static bool CanHumanGang(SichuanStateView state, IReadOnlyList<IReadOnlyList<int>> allHands18, int discardTileType)
        => SichuanHellChallengeEngine.CanHumanGang(state, allHands18, discardTileType);

    private static IReadOnlyList<int> ResolveDealInTargetSeats(SichuanStateView state, IReadOnlyList<IReadOnlyList<int>> allHands18, int discardTileType)
        => SichuanHellChallengeEngine.ResolveDealInTargetSeats(state, allHands18, discardTileType);

    private static int[] RemoveOne(int[] hand18, int tileType)
        => SichuanHellChallengeEngine.RemoveOne(hand18, tileType);

    private static List<int> GetExactReadyTiles(int[] hand18, int meldCount)
        => SichuanHellChallengeEngine.GetExactReadyTiles(hand18, meldCount);
}
