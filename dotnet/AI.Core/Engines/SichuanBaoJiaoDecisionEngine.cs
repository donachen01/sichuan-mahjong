using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Engines;

public sealed class SichuanBaoJiaoDecisionEngine
{
    public SichuanBaoJiaoDecisionResult DecideBaoJiaoDeclaration(
        SichuanStateView state,
        IReadOnlyList<int> tingTileTypes,
        IReadOnlyList<SichuanBaoGangCandidate> baoGangCandidates,
        int planScore) => new()
        {
            Declare = false,
            SelectedBaoGangKeys = Array.Empty<string>(),
            Score = 0,
            Reasons = new[] { "四川规则不启用报叫" },
            CandidateScores = new Dictionary<string, int> { ["disabled"] = 0 }
        };
}
