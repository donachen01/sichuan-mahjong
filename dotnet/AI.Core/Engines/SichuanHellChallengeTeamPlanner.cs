using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public static class SichuanHellChallengeTeamPlanner
{
    public static SichuanHellChallengeTeamPlan BuildPlan(
        SichuanStateView state,
        IReadOnlyList<IReadOnlyList<int>> allHands18,
        IReadOnlyList<int> exactWall18,
        IReadOnlyList<int>? currentScores = null)
    {
        var humanPressure = SichuanHellChallengeEngine.ResolveHumanPressureLevel(state, currentScores);
        var targetSeat = 0;
        var bestAiSeat = ResolveBestAiSeat(currentScores, fallbackSeat: state.SeatIndex);
        var orderedAiSeats = new[] { 1, 2, 3 };
        var plans = new List<SichuanHellChallengeSeatPlan>();

        foreach (var seat in orderedAiSeats)
        {
            var role = ResolveRole(seat, state.SeatIndex, bestAiSeat, currentScores);
            var roleWeight = role switch
            {
                "lead_suppressor" => 120,
                "interceptor" => 95,
                "catch_up" => 75,
                _ => 60
            };
            var pressureBonus = humanPressure * roleWeight;
            plans.Add(new SichuanHellChallengeSeatPlan
            {
                Seat = seat,
                Role = role,
                PressureBonus = pressureBonus,
                DiscardSafetyBias = pressureBonus + humanPressure * 35,
                CallInterceptionBias = pressureBonus + humanPressure * 55,
                Summary = $"{RoleLabel(role)} P{humanPressure}"
            });
        }

        return new SichuanHellChallengeTeamPlan
        {
            TargetSeat = targetSeat,
            HumanPressureLevel = humanPressure,
            SeatPlans = plans,
            Reasons = new[]
            {
                $"三家协作：共同压制本家 P{humanPressure}",
                $"三家协作：主压制座位 {bestAiSeat}",
                $"三家协作：牌墙透视 {exactWall18.Take(27).Sum()} 张"
            }
        };
    }

    private static string ResolveRole(int seat, int actingSeat, int bestAiSeat, IReadOnlyList<int>? currentScores)
    {
        if (seat == bestAiSeat)
            return "lead_suppressor";
        if (seat == actingSeat)
            return "interceptor";
        if (currentScores is not null && currentScores.Count > seat && currentScores[seat] <= currentScores.Skip(1).Take(3).Min())
            return "catch_up";
        return "interceptor";
    }

    private static int ResolveBestAiSeat(IReadOnlyList<int>? currentScores, int fallbackSeat)
    {
        if (currentScores is null || currentScores.Count < 4)
            return fallbackSeat is >= 1 and <= 3 ? fallbackSeat : 1;
        var bestSeat = 1;
        var bestScore = currentScores[1];
        for (var seat = 2; seat <= 3; seat++)
        {
            if (currentScores[seat] <= bestScore)
                continue;
            bestSeat = seat;
            bestScore = currentScores[seat];
        }
        return bestSeat;
    }

    private static string RoleLabel(string role) => role switch
    {
        "lead_suppressor" => "主压制",
        "interceptor" => "截断",
        "catch_up" => "追赶",
        _ => "协防"
    };
}
