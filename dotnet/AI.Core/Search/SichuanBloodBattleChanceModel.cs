using System.Numerics;

namespace SichuanMahjong.AI.Core.Search;

/// <summary>
/// Exact dynamic programming for the deliberately small, fixed-wait model.
/// Opponent hazards are estimates, not known hands. An opponent win removes
/// that seat; the observer continues and future self-draw payments shrink.
/// </summary>
internal sealed class SichuanBloodBattleChanceModel
{
    internal readonly record struct Value(double Win = 0, double OpponentWin = 0, double Draw = 0,
        double BattleEnd = 0, double Horizon = 0, double WinGain = 0, double Loss = 0, double Gang = 0,
        double ChaJiao = 0, double Continuation = 0)
    {
        public double Net => WinGain + Gang + ChaJiao + Continuation - Loss;
        public static Value Mix(Value a, Value b, double p) => new(
            a.Win*p+b.Win*(1-p), a.OpponentWin*p+b.OpponentWin*(1-p),
            a.Draw*p+b.Draw*(1-p), a.BattleEnd*p+b.BattleEnd*(1-p),
            a.Horizon*p+b.Horizon*(1-p), a.WinGain*p+b.WinGain*(1-p),
            a.Loss*p+b.Loss*(1-p), a.Gang*p+b.Gang*(1-p),
            a.ChaJiao*p+b.ChaJiao*(1-p), a.Continuation*p+b.Continuation*(1-p));
    }

    public Value Evaluate(SichuanActionTreeEvaluator.ChanceSearchRequest request)
    {
        var players = Math.Clamp(request.ActivePlayers, 2, 4);
        var wall = Math.Max(0, request.WallTiles);
        var live = Math.Clamp(request.LiveTiles, 0, wall);
        var initialOpponents = players - 1;
        var first = (players - Math.Clamp(request.OwnTurnOffset, 0, players-1)) % players;
        var opponentHazard = Math.Clamp(request.OpponentWinProbabilityPerDraw, 0, 1);
        var gangHazard = Math.Clamp(request.GangOpportunityProbability, 0, 1);
        var cache = new Dictionary<(int Wall, int Live, int Mask, int Next, int Depth), Value>();
        var low = (int)Math.Floor(live);
        var depth = Math.Min(wall, Math.Max(0, request.MaxDraws));
        var lower = Solve(wall, low, (1<<players)-1, first, depth);
        if (live == low) return lower;
        return Value.Mix(Solve(wall, low+1, (1<<players)-1, first, depth), lower, live-low);

        Value Solve(int remaining, int targets, int mask, int next, int left)
        {
            var opponents = BitOperations.PopCount((uint)mask)-1;
            if (opponents == 0) return new Value(BattleEnd: 1);
            if (remaining == 0)
                return new Value(Draw: 1, ChaJiao: request.ChaJiaoValue * opponents / initialOpponents);
            var key = (remaining, targets, mask, next, left);
            if (cache.TryGetValue(key, out var found)) return found;
            if (left == 0)
            {
                // Value the unfinished state using the same model to exhaustion,
                // while keeping it distinct from an observed wall draw terminal.
                var tail = Solve(remaining, targets, mask, next, remaining);
                return cache[key] = new Value(Horizon: 1, Continuation: tail.Net);
            }
            var hit = targets / (double)remaining;
            Value value;
            if (next == 0)
            {
                var win = new Value(Win: 1, WinGain: request.WinScore * opponents / initialOpponents);
                var miss = default(Value);
                if (targets < remaining)
                {
                    miss = Solve(remaining-1, targets, mask, Next(mask, next), left-1);
                    if (gangHazard > 0 && remaining > 1)
                    {
                        // A replacement consumes the next wall tile immediately.
                        var replacement = Solve(remaining-1, targets, mask, next, left-1);
                        replacement = replacement with { Gang = replacement.Gang + request.GangGain };
                        miss = Value.Mix(replacement, miss, gangHazard);
                    }
                }
                value = Value.Mix(win, miss, hit);
            }
            else
            {
                Value AfterDraw(int targetsAfter)
                {
                    var stay = opponentHazard < 1
                        ? Solve(remaining-1, targetsAfter, mask, Next(mask, next), left-1) : default;
                    if (opponentHazard == 0) return stay;
                    var exitedMask = mask & ~(1<<next);
                    var exit = Solve(remaining-1, targetsAfter, exitedMask, Next(exitedMask, next), left-1);
                    exit = exit with { OpponentWin = 1, Loss = exit.Loss + Math.Max(0, request.OpponentWinLoss) };
                    return Value.Mix(exit, stay, opponentHazard);
                }
                var hitValue = targets > 0 ? AfterDraw(targets-1) : default;
                var missValue = targets < remaining ? AfterDraw(targets) : default;
                value = Value.Mix(hitValue, missValue, hit);
            }
            return cache[key] = value;
        }
        int Next(int mask, int seat)
        {
            for (var offset=1; offset<=players; offset++)
            {
                var candidate=(seat+offset)%players;
                if ((mask & (1<<candidate)) != 0) return candidate;
            }
            return 0;
        }
    }
}
