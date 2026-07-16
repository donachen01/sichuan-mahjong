using SichuanMahjong.AI.Core.Models;

namespace SichuanMahjong.AI.Core.Domain;

public enum SichuanInformationMode { Public, Oracle }

public sealed record SichuanDecisionState(
    SichuanStateView PublicState,
    SichuanRuleSnapshot Rules,
    SichuanInformationMode InformationMode,
    IReadOnlyList<SichuanPublicEvent> Events,
    IReadOnlyList<SichuanMeldView>[] Melds,
    IReadOnlyList<int[]>? AllHands27 = null,
    IReadOnlyList<int>? ExactWall27 = null);
