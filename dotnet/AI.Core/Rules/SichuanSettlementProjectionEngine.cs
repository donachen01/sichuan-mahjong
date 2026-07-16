using SichuanMahjong.AI.Core.Domain;

namespace SichuanMahjong.AI.Core.Rules;

public sealed record SichuanSettlementProjection(int[] ScoreChanges, int WinnerGain, int TotalPaid);

public sealed record SichuanGangScoreEvent(
    int ActorSeat,
    SichuanMeldType GangType,
    IReadOnlyList<int> PayerSeats,
    bool IsGangDiscardWin = false);

public sealed record SichuanGangRefundEvent(
    int ActorSeat,
    SichuanMeldType GangType,
    IReadOnlyList<int> PayerSeats);

public sealed record SichuanHuJiaoTransferEvent(
    int WinnerSeat,
    SichuanMeldType GangType,
    IReadOnlyList<int> PayerSeats);

public sealed record SichuanDrawAssessment(
    int Seat,
    bool IsTing,
    bool IsHuaZhu,
    int ChaJiaoScore);

public sealed record SichuanSettlementScenario(
    IReadOnlyList<SichuanGangScoreEvent>? GangEvents = null,
    IReadOnlyList<SichuanGangRefundEvent>? GangRefunds = null,
    IReadOnlyList<SichuanHuJiaoTransferEvent>? TransferEvents = null,
    IReadOnlyList<SichuanDrawAssessment>? DrawAssessments = null,
    bool IsRoundResolved = true);

public sealed record SichuanSettlementBreakdown(
    int[] ScoreChanges,
    int[] GangChanges,
    int[] RefundChanges,
    int[] TransferChanges,
    int[] ChaJiaoChanges,
    int[] HuaZhuChanges);

public sealed class SichuanSettlementProjectionEngine
{
    public SichuanSettlementProjection ProjectWin(int winner, int sourceSeat, IReadOnlyList<int> activeSeats, SichuanFanProjection fan, SichuanWinType winType)
    {
        var changes = new int[4];
        var payers = winType is SichuanWinType.SelfDraw or SichuanWinType.GangSelfDraw
            ? activeSeats.Where(seat => seat != winner).ToArray()
            : sourceSeat is >= 0 and < 4 ? new[] { sourceSeat } : Array.Empty<int>();
        foreach (var payer in payers)
        {
            changes[payer] -= fan.PerPayerScore;
            changes[winner] += fan.PerPayerScore;
        }
        return new SichuanSettlementProjection(changes, changes[winner], -changes.Where((_, seat) => seat != winner).Sum());
    }

    public static int GangUnit(SichuanMeldType type) => type switch
    {
        SichuanMeldType.MeldedGang or SichuanMeldType.ConcealedGang => 2,
        SichuanMeldType.AddedGang => 1,
        _ => 0
    };

    public SichuanSettlementBreakdown ProjectScenario(SichuanSettlementScenario scenario)
    {
        var gang = new int[4];
        var refunds = new int[4];
        var transfers = new int[4];
        var chaJiao = new int[4];
        var huaZhu = new int[4];
        if (scenario.IsRoundResolved)
        {
            foreach (var item in scenario.GangEvents ?? Array.Empty<SichuanGangScoreEvent>())
            {
                if (item.IsGangDiscardWin) continue;
                ApplyPayments(gang, item.ActorSeat, item.PayerSeats, GangUnit(item.GangType));
            }
            foreach (var item in scenario.GangRefunds ?? Array.Empty<SichuanGangRefundEvent>())
                ApplyPayments(refunds, item.ActorSeat, item.PayerSeats, -GangUnit(item.GangType));
            foreach (var item in scenario.TransferEvents ?? Array.Empty<SichuanHuJiaoTransferEvent>())
                ApplyPayments(transfers, item.WinnerSeat, item.PayerSeats, GangUnit(item.GangType));
        }

        var assessments = scenario.DrawAssessments ?? Array.Empty<SichuanDrawAssessment>();
        var ting = assessments.Where(item => item.IsTing && !item.IsHuaZhu).ToArray();
        foreach (var payer in assessments.Where(item => !item.IsTing && !item.IsHuaZhu))
            foreach (var receiver in ting)
                ApplyPayment(chaJiao, receiver.Seat, payer.Seat, Math.Max(1, receiver.ChaJiaoScore));
        foreach (var payer in assessments.Where(item => item.IsHuaZhu))
            foreach (var receiver in ting)
                ApplyPayment(huaZhu, receiver.Seat, payer.Seat, Math.Max(1, receiver.ChaJiaoScore));

        var total = new int[4];
        for (var seat = 0; seat < 4; seat++)
            total[seat] = gang[seat] + refunds[seat] + transfers[seat] + chaJiao[seat] + huaZhu[seat];
        return new SichuanSettlementBreakdown(total, gang, refunds, transfers, chaJiao, huaZhu);
    }

    private static void ApplyPayments(int[] changes, int receiver, IEnumerable<int> payers, int unit)
    {
        foreach (var payer in payers) ApplyPayment(changes, receiver, payer, unit);
    }

    private static void ApplyPayment(int[] changes, int receiver, int payer, int unit)
    {
        if (receiver is < 0 or >= 4 || payer is < 0 or >= 4 || receiver == payer || unit == 0) return;
        changes[receiver] += unit;
        changes[payer] -= unit;
    }
}
