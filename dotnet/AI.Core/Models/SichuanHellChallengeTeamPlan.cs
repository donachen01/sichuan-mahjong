namespace SichuanMahjong.AI.Core.Models;

public sealed class SichuanHellChallengeTeamPlan
{
    public int TargetSeat { get; init; }
    public int HumanPressureLevel { get; init; } = 1;
    public IReadOnlyList<SichuanHellChallengeSeatPlan> SeatPlans { get; init; } = Array.Empty<SichuanHellChallengeSeatPlan>();
    public IReadOnlyList<string> Reasons { get; init; } = Array.Empty<string>();

    public SichuanHellChallengeSeatPlan ForSeat(int seat)
        => SeatPlans.FirstOrDefault(item => item.Seat == seat)
            ?? new SichuanHellChallengeSeatPlan { Seat = seat, Role = seat == TargetSeat ? "target" : "support", PressureBonus = 0 };
}

public sealed class SichuanHellChallengeSeatPlan
{
    public int Seat { get; init; }
    public string Role { get; init; } = "support";
    public int PressureBonus { get; init; }
    public int DiscardSafetyBias { get; init; }
    public int CallInterceptionBias { get; init; }
    public string Summary { get; init; } = "";
}
