using System.Text.Json;
using System.Text.Json.Serialization;

namespace SichuanMahjong.AI.Core.Learning;

public sealed class SichuanLearningEngine
{
    private const int MaxRecentRounds = 60;
    private const int MaxAdjustmentHistory = 120;

    private static readonly IReadOnlyDictionary<string, string> ParameterLabels = new Dictionary<string, string>
    {
        ["lookahead_candidate_count"] = "前瞻候选数",
        ["lookahead_draw_samples"] = "前瞻样本数",
        ["add_gang_min_score"] = "补杠阈值",
        ["an_gang_min_score"] = "暗杠阈值",
        ["intermediate_top_pick_count"] = "中级随机池",
        ["attack_tendency"] = "进攻倾向",
        ["defense_tendency"] = "防守倾向",
        ["fast_ting_priority"] = "快速听牌",
        ["self_draw_priority"] = "自摸优先",
        ["forced_cleanup_tendency"] = "成叫/查叫优先",
        ["big_hand_tendency"] = "做大倾向",
        ["opponent_read_tendency"] = "读牌能力"
    };

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    public LearningProfile LoadOrCreate(string learningFilePath)
    {
        if (!File.Exists(learningFilePath))
        {
            var profile = LearningProfile.CreateDefault();
            SaveProfile(learningFilePath, profile);
            return profile;
        }

        var json = File.ReadAllText(learningFilePath);
        var loaded = JsonSerializer.Deserialize<LearningProfile>(json, JsonOptions);
        return LearningProfile.MergeWithDefaults(loaded ?? LearningProfile.CreateDefault());
    }

    public LearningProfile RecordHumanRound(
        string learningFilePath,
        string learningHistoryFilePath,
        LearningRoundResult roundResult)
    {
        var profile = LoadOrCreate(learningFilePath);

        var humanDelta = roundResult.ScoreChanges.TryGetValue("0", out var delta) ? delta : 0;
        var humanDealIn = DidHumanDealIn(roundResult.WinEvents);
        var aiWinCount = CountAiWins(roundResult.WinEvents);
        var aiSelfDrawCount = CountAiSelfDraws(roundResult.WinEvents);
        var aiGangCount = CountAiGangs(roundResult.GangEvents);

        profile.TotalHumanRounds += 1;
        profile.LastUpdatedUnix = DateTimeOffset.UtcNow.ToUnixTimeSeconds();

        profile.Rolling.HumanTotalDelta += humanDelta;
        if (humanDelta > 0) profile.Rolling.HumanPositiveRounds += 1;
        else if (humanDelta < 0) profile.Rolling.HumanNegativeRounds += 1;
        if (humanDealIn) profile.Rolling.HumanDealInCount += 1;
        profile.Rolling.AiWinCount += aiWinCount;
        profile.Rolling.AiSelfDrawCount += aiSelfDrawCount;
        profile.Rolling.AiGangCount += aiGangCount;
        if (string.Equals(roundResult.EndReason, "draw_wall_empty", StringComparison.Ordinal))
            profile.Rolling.DrawRounds += 1;

        profile.RecentRounds.Add(new RecentRoundEntry
        {
            RoundIndex = roundResult.RoundIndex,
            TimestampUnix = profile.LastUpdatedUnix,
            HumanDelta = humanDelta,
            HumanDealIn = humanDealIn,
            AiWinCount = aiWinCount,
            AiSelfDrawCount = aiSelfDrawCount,
            AiGangCount = aiGangCount,
            EndReason = roundResult.EndReason ?? string.Empty,
            ScoreChanges = NormalizeScoreChanges(roundResult.ScoreChanges)
        });
        while (profile.RecentRounds.Count > MaxRecentRounds)
            profile.RecentRounds.RemoveAt(0);

        RecalculateParameterBias(profile);
        SaveProfile(learningFilePath, profile);
        SaveReadableHistory(learningHistoryFilePath, profile);
        return profile;
    }

    public void SaveProfile(string learningFilePath, LearningProfile profile)
    {
        var directory = Path.GetDirectoryName(learningFilePath);
        if (!string.IsNullOrEmpty(directory))
            Directory.CreateDirectory(directory);
        File.WriteAllText(learningFilePath, JsonSerializer.Serialize(profile, JsonOptions));
    }

    private static Dictionary<string, int> NormalizeScoreChanges(Dictionary<string, int> raw)
        => raw.ToDictionary(item => item.Key, item => item.Value);

    private static bool DidHumanDealIn(IEnumerable<LearningWinEvent> winEvents)
        => winEvents.Any(item => item.SourceSeat == 0 && item.WinnerSeat != 0 && !item.WinType.Contains("self_draw", StringComparison.OrdinalIgnoreCase));

    private static int CountAiWins(IEnumerable<LearningWinEvent> winEvents)
        => winEvents.Count(item => item.WinnerSeat != 0);

    private static int CountAiSelfDraws(IEnumerable<LearningWinEvent> winEvents)
        => winEvents.Count(item => item.WinnerSeat != 0 && item.WinType.Contains("self_draw", StringComparison.OrdinalIgnoreCase));

    private static int CountAiGangs(IEnumerable<LearningGangEvent> gangEvents)
        => gangEvents.Count(item => item.ActorSeat != 0);

    private static void RecalculateParameterBias(LearningProfile profile)
    {
        var previousAdjustments = profile.ParameterAdjustments.Clone();
        var previousBias = profile.ParameterBias.Clone();
        var totalRounds = Math.Max(1, profile.TotalHumanRounds);
        var rolling = profile.Rolling;

        var humanAvgDelta = rolling.HumanTotalDelta / (double)totalRounds;
        var humanPositiveRate = rolling.HumanPositiveRounds / (double)totalRounds;
        var humanDealInRate = rolling.HumanDealInCount / (double)totalRounds;
        var drawRate = rolling.DrawRounds / (double)totalRounds;
        var aiSelfDrawRate = rolling.AiSelfDrawCount / (double)totalRounds;
        var humanNegativeRate = rolling.HumanNegativeRounds / (double)totalRounds;
        var aiWinAverage = rolling.AiWinCount / (double)totalRounds;
        var aiGangAverage = rolling.AiGangCount / (double)totalRounds;

        var riskBias = 0;
        var attackBias = 0;
        var gangBias = 0;
        var lookaheadBias = 0;
        var adjustments = ParameterAdjustmentSet.CreateEmpty();
        var reasons = new List<string>();

        if (humanAvgDelta > 0.8 || humanPositiveRate > 0.42)
        {
            lookaheadBias += 2;
            riskBias += 1;
            adjustments.Bump("lookahead_candidate_count", 1);
            adjustments.Bump("lookahead_draw_samples", 2);
            adjustments.Bump("defense_tendency", 1);
            adjustments.Bump("opponent_read_tendency", 1);
            reasons.Add("真人长期占优，Sichuan AI 提高读牌、防炮与尾盘收缩强度。");
        }
        if (humanAvgDelta > 2.0)
        {
            lookaheadBias += 1;
            attackBias += 1;
            adjustments.Bump("attack_tendency", 1);
            adjustments.Bump("lookahead_draw_samples", 1);
            adjustments.Bump("fast_ting_priority", 1);
            reasons.Add("真人优势明显，Sichuan AI 提高成叫搜索和听牌转化强度。");
        }
        if (humanDealInRate > 0.24)
        {
            riskBias += 1;
            adjustments.Bump("defense_tendency", 1);
            adjustments.Bump("opponent_read_tendency", 1);
            adjustments.Bump("forced_cleanup_tendency", 1);
            adjustments.Bump("add_gang_min_score", 4);
            adjustments.Bump("an_gang_min_score", 3);
            reasons.Add("真人点炮偏高，Sichuan AI 强化尾盘防炮并收紧杠牌。");
        }
        if (drawRate > 0.28)
        {
            attackBias += 1;
            gangBias += 1;
            adjustments.Bump("attack_tendency", 1);
            adjustments.Bump("fast_ting_priority", 1);
            adjustments.Bump("add_gang_min_score", -3);
            adjustments.Bump("an_gang_min_score", -2);
            adjustments.Bump("big_hand_tendency", -1);
            reasons.Add("流局偏高，Sichuan AI 提高成叫、自摸与中盘提速倾向。");
        }
        if (aiSelfDrawRate < 0.16 && totalRounds >= 6)
        {
            attackBias += 1;
            lookaheadBias += 1;
            adjustments.Bump("self_draw_priority", 1);
            adjustments.Bump("lookahead_draw_samples", 1);
            adjustments.Bump("fast_ting_priority", 1);
            reasons.Add("AI 自摸收益偏低，增加定缺后前瞻样本并抬高自摸权重。");
        }
        if (aiWinAverage < 0.90 && totalRounds >= 6)
        {
            adjustments.Bump("attack_tendency", 1);
            adjustments.Bump("lookahead_candidate_count", 1);
            adjustments.Bump("fast_ting_priority", 1);
            reasons.Add("AI 胡牌频率偏低，提升快速成叫与候选搜索权重。");
        }
        if (aiGangAverage < 0.18 && drawRate > 0.16 && totalRounds >= 6)
        {
            adjustments.Bump("add_gang_min_score", -2);
            adjustments.Bump("an_gang_min_score", -2);
            reasons.Add("AI 杠收益偏少且流局偏多，适度放宽中前盘杠牌收益窗口。");
        }
        if (humanNegativeRate > 0.58 && aiWinAverage >= 1.0)
        {
            adjustments.Bump("big_hand_tendency", 1);
            adjustments.Bump("defense_tendency", 1);
            reasons.Add("AI 已能稳定压制真人，适度提高归收益追求与稳守质量。");
        }
        if (reasons.Count == 0)
            reasons.Add("数据量仍在积累，当前以Sichuan骨灰级基准做小步微调。");

        profile.ParameterBias = new ParameterBias
        {
            RiskBias = Math.Clamp(riskBias, 0, 5),
            AttackBias = Math.Clamp(attackBias, 0, 5),
            GangBias = Math.Clamp(gangBias, 0, 5),
            LookaheadBias = Math.Clamp(lookaheadBias, 0, 6)
        };
        profile.ParameterAdjustments = adjustments.Clamp();
        profile.SummaryStats = new SummaryStats
        {
            HumanAverageDelta = humanAvgDelta,
            HumanPositiveRate = humanPositiveRate,
            HumanNegativeRate = humanNegativeRate,
            HumanDealInRate = humanDealInRate,
            AiWinAverage = aiWinAverage,
            AiSelfDrawRate = aiSelfDrawRate,
            AiGangAverage = aiGangAverage,
            DrawRate = drawRate
        };
        profile.LastAdjustmentReasons = reasons;
        AppendAdjustmentHistory(profile, previousBias, previousAdjustments);
    }

    private static void AppendAdjustmentHistory(LearningProfile profile, ParameterBias previousBias, ParameterAdjustmentSet previousAdjustments)
    {
        var changedParameters = profile.ParameterAdjustments.ToChangedList(previousAdjustments);
        var changedBias = profile.ParameterBias.ToChangedList(previousBias);
        if (changedParameters.Count == 0 && changedBias.Count == 0)
            return;

        profile.AdjustmentHistory.Add(new AdjustmentHistoryEntry
        {
            RoundIndex = profile.TotalHumanRounds,
            TimestampUnix = profile.LastUpdatedUnix,
            ParameterBias = profile.ParameterBias.Clone(),
            ParameterAdjustments = profile.ParameterAdjustments.Clone(),
            ChangedBias = changedBias,
            ChangedParameters = changedParameters,
            Reasons = profile.LastAdjustmentReasons.ToList()
        });
        while (profile.AdjustmentHistory.Count > MaxAdjustmentHistory)
            profile.AdjustmentHistory.RemoveAt(0);
    }

    private static void SaveReadableHistory(string learningHistoryFilePath, LearningProfile profile)
    {
        var directory = Path.GetDirectoryName(learningHistoryFilePath);
        if (!string.IsNullOrEmpty(directory))
            Directory.CreateDirectory(directory);
        var readableHistory = profile.AdjustmentHistory.Select(entry =>
        {
            var changedLines = entry.ChangedParameters
                .Select(item => $"{ParameterLabels.GetValueOrDefault(item.Key, item.Key)}：{item.Before} → {item.After}")
                .ToList();
            return new Dictionary<string, object?>
            {
                ["round_index"] = entry.RoundIndex,
                ["timestamp_unix"] = entry.TimestampUnix,
                ["summary_text"] = $"第 {entry.RoundIndex} 局后：{(changedLines.Count > 0 ? string.Join("；", changedLines) : "参数未变化")}",
                ["reasons_text"] = string.Join(" / ", entry.Reasons),
                ["changed_parameters_text"] = changedLines,
                ["changed_parameters"] = entry.ChangedParameters,
                ["changed_bias"] = entry.ChangedBias
            };
        }).ToList();

        var payload = new Dictionary<string, object?>
        {
            ["updated_unix"] = profile.LastUpdatedUnix,
            ["total_human_rounds"] = profile.TotalHumanRounds,
            ["latest_reasons"] = profile.LastAdjustmentReasons,
            ["current_parameter_adjustments"] = profile.ParameterAdjustments,
            ["current_parameter_adjustments_text"] = BuildCurrentAdjustmentTextLines(profile),
            ["latest_reasons_text"] = string.Join(" / ", profile.LastAdjustmentReasons),
            ["latest_summary_text"] = BuildLatestAdjustmentSummaryText(profile),
            ["readable_adjustment_history"] = readableHistory,
            ["adjustment_history"] = profile.AdjustmentHistory
        };

        File.WriteAllText(learningHistoryFilePath, JsonSerializer.Serialize(payload, JsonOptions));
    }

    private static List<string> BuildCurrentAdjustmentTextLines(LearningProfile profile)
    {
        var lines = new List<string>();
        foreach (var key in ParameterLabels.Keys)
        {
            var value = profile.ParameterAdjustments.Get(key);
            if (value == 0) continue;
            lines.Add($"{ParameterLabels[key]}{value:+#;-#;0}");
        }
        return lines;
    }

    private static string BuildLatestAdjustmentSummaryText(LearningProfile profile)
    {
        if (profile.AdjustmentHistory.Count == 0)
            return "暂无参数学习历史";
        var latest = profile.AdjustmentHistory[^1];
        var changedLines = latest.ChangedParameters
            .Select(item => $"{ParameterLabels.GetValueOrDefault(item.Key, item.Key)}：{item.Before} → {item.After}")
            .ToList();
        if (changedLines.Count == 0)
            return "最近一轮学习未引起参数变化";
        return $"第 {latest.RoundIndex} 局后：{string.Join("；", changedLines)}";
    }
}

public sealed class LearningProfile
{
    [JsonPropertyName("version")] public int Version { get; set; } = 1;
    [JsonPropertyName("total_human_rounds")] public int TotalHumanRounds { get; set; }
    [JsonPropertyName("last_updated_unix")] public long LastUpdatedUnix { get; set; }
    [JsonPropertyName("rolling")] public RollingStats Rolling { get; set; } = new();
    [JsonPropertyName("parameter_bias")] public ParameterBias ParameterBias { get; set; } = new();
    [JsonPropertyName("parameter_adjustments")] public ParameterAdjustmentSet ParameterAdjustments { get; set; } = ParameterAdjustmentSet.CreateEmpty();
    [JsonPropertyName("summary_stats")] public SummaryStats SummaryStats { get; set; } = new();
    [JsonPropertyName("last_adjustment_reasons")] public List<string> LastAdjustmentReasons { get; set; } = new();
    [JsonPropertyName("recent_rounds")] public List<RecentRoundEntry> RecentRounds { get; set; } = new();
    [JsonPropertyName("adjustment_history")] public List<AdjustmentHistoryEntry> AdjustmentHistory { get; set; } = new();

    public static LearningProfile CreateDefault() => new();

    public static LearningProfile MergeWithDefaults(LearningProfile loaded)
        => loaded ?? CreateDefault();
}

public sealed class RollingStats
{
    [JsonPropertyName("human_total_delta")] public int HumanTotalDelta { get; set; }
    [JsonPropertyName("human_positive_rounds")] public int HumanPositiveRounds { get; set; }
    [JsonPropertyName("human_negative_rounds")] public int HumanNegativeRounds { get; set; }
    [JsonPropertyName("human_deal_in_count")] public int HumanDealInCount { get; set; }
    [JsonPropertyName("ai_win_count")] public int AiWinCount { get; set; }
    [JsonPropertyName("ai_self_draw_count")] public int AiSelfDrawCount { get; set; }
    [JsonPropertyName("ai_gang_count")] public int AiGangCount { get; set; }
    [JsonPropertyName("draw_rounds")] public int DrawRounds { get; set; }
}

public sealed class ParameterBias
{
    [JsonPropertyName("risk_bias")] public int RiskBias { get; set; }
    [JsonPropertyName("attack_bias")] public int AttackBias { get; set; }
    [JsonPropertyName("gang_bias")] public int GangBias { get; set; }
    [JsonPropertyName("lookahead_bias")] public int LookaheadBias { get; set; }

    public ParameterBias Clone() => new() { RiskBias = RiskBias, AttackBias = AttackBias, GangBias = GangBias, LookaheadBias = LookaheadBias };

    public List<ChangedValue> ToChangedList(ParameterBias previous)
        => new List<ChangedValue?>
        {
            CreateChanged("risk_bias", previous.RiskBias, RiskBias),
            CreateChanged("attack_bias", previous.AttackBias, AttackBias),
            CreateChanged("gang_bias", previous.GangBias, GangBias),
            CreateChanged("lookahead_bias", previous.LookaheadBias, LookaheadBias)
        }.Where(item => item is not null).Cast<ChangedValue>().ToList();

    private static ChangedValue? CreateChanged(string key, int before, int after)
        => before == after ? null : new ChangedValue { Key = key, Before = before, After = after, Delta = after - before };
}

public sealed class ParameterAdjustmentSet
{
    [JsonPropertyName("lookahead_candidate_count")] public int LookaheadCandidateCount { get; set; }
    [JsonPropertyName("lookahead_draw_samples")] public int LookaheadDrawSamples { get; set; }
    [JsonPropertyName("add_gang_min_score")] public int AddGangMinScore { get; set; }
    [JsonPropertyName("an_gang_min_score")] public int AnGangMinScore { get; set; }
    [JsonPropertyName("intermediate_top_pick_count")] public int IntermediateTopPickCount { get; set; }
    [JsonPropertyName("attack_tendency")] public int AttackTendency { get; set; }
    [JsonPropertyName("defense_tendency")] public int DefenseTendency { get; set; }
    [JsonPropertyName("fast_ting_priority")] public int FastTingPriority { get; set; }
    [JsonPropertyName("self_draw_priority")] public int SelfDrawPriority { get; set; }
    [JsonPropertyName("forced_cleanup_tendency")] public int ForcedCleanupTendency { get; set; }
    [JsonPropertyName("big_hand_tendency")] public int BigHandTendency { get; set; }
    [JsonPropertyName("opponent_read_tendency")] public int OpponentReadTendency { get; set; }

    public static ParameterAdjustmentSet CreateEmpty() => new();

    public ParameterAdjustmentSet Clone() => new()
    {
        LookaheadCandidateCount = LookaheadCandidateCount,
        LookaheadDrawSamples = LookaheadDrawSamples,
        AddGangMinScore = AddGangMinScore,
        AnGangMinScore = AnGangMinScore,
        IntermediateTopPickCount = IntermediateTopPickCount,
        AttackTendency = AttackTendency,
        DefenseTendency = DefenseTendency,
        FastTingPriority = FastTingPriority,
        SelfDrawPriority = SelfDrawPriority,
        ForcedCleanupTendency = ForcedCleanupTendency,
        BigHandTendency = BigHandTendency,
        OpponentReadTendency = OpponentReadTendency
    };

    public void Bump(string key, int amount)
    {
        switch (key)
        {
            case "lookahead_candidate_count": LookaheadCandidateCount += amount; break;
            case "lookahead_draw_samples": LookaheadDrawSamples += amount; break;
            case "add_gang_min_score": AddGangMinScore += amount; break;
            case "an_gang_min_score": AnGangMinScore += amount; break;
            case "intermediate_top_pick_count": IntermediateTopPickCount += amount; break;
            case "attack_tendency": AttackTendency += amount; break;
            case "defense_tendency": DefenseTendency += amount; break;
            case "fast_ting_priority": FastTingPriority += amount; break;
            case "self_draw_priority": SelfDrawPriority += amount; break;
            case "forced_cleanup_tendency": ForcedCleanupTendency += amount; break;
            case "big_hand_tendency": BigHandTendency += amount; break;
            case "opponent_read_tendency": OpponentReadTendency += amount; break;
        }
    }

    public int Get(string key) => key switch
    {
        "lookahead_candidate_count" => LookaheadCandidateCount,
        "lookahead_draw_samples" => LookaheadDrawSamples,
        "add_gang_min_score" => AddGangMinScore,
        "an_gang_min_score" => AnGangMinScore,
        "intermediate_top_pick_count" => IntermediateTopPickCount,
        "attack_tendency" => AttackTendency,
        "defense_tendency" => DefenseTendency,
        "fast_ting_priority" => FastTingPriority,
        "self_draw_priority" => SelfDrawPriority,
        "forced_cleanup_tendency" => ForcedCleanupTendency,
        "big_hand_tendency" => BigHandTendency,
        "opponent_read_tendency" => OpponentReadTendency,
        _ => 0
    };

    public ParameterAdjustmentSet Clamp()
    {
        LookaheadCandidateCount = Math.Clamp(LookaheadCandidateCount, -6, 6);
        LookaheadDrawSamples = Math.Clamp(LookaheadDrawSamples, -4, 6);
        AddGangMinScore = Math.Clamp(AddGangMinScore, -12, 12);
        AnGangMinScore = Math.Clamp(AnGangMinScore, -12, 12);
        IntermediateTopPickCount = Math.Clamp(IntermediateTopPickCount, -6, 6);
        AttackTendency = Math.Clamp(AttackTendency, -6, 6);
        DefenseTendency = Math.Clamp(DefenseTendency, -6, 6);
        FastTingPriority = Math.Clamp(FastTingPriority, -6, 6);
        SelfDrawPriority = Math.Clamp(SelfDrawPriority, -6, 6);
        ForcedCleanupTendency = Math.Clamp(ForcedCleanupTendency, -6, 6);
        BigHandTendency = Math.Clamp(BigHandTendency, -6, 6);
        OpponentReadTendency = Math.Clamp(OpponentReadTendency, -6, 6);
        return this;
    }

    public List<ChangedValue> ToChangedList(ParameterAdjustmentSet previous)
    {
        var keys = new[]
        {
            "lookahead_candidate_count", "lookahead_draw_samples", "add_gang_min_score", "an_gang_min_score",
            "intermediate_top_pick_count", "attack_tendency", "defense_tendency", "fast_ting_priority",
            "self_draw_priority", "forced_cleanup_tendency", "big_hand_tendency", "opponent_read_tendency"
        };
        return keys
            .Select(key =>
            {
                var before = previous.Get(key);
                var after = Get(key);
                return before == after ? null : new ChangedValue { Key = key, Before = before, After = after, Delta = after - before };
            })
            .Where(item => item is not null)
            .Cast<ChangedValue>()
            .ToList();
    }
}

public sealed class SummaryStats
{
    [JsonPropertyName("human_average_delta")] public double HumanAverageDelta { get; set; }
    [JsonPropertyName("human_positive_rate")] public double HumanPositiveRate { get; set; }
    [JsonPropertyName("human_negative_rate")] public double HumanNegativeRate { get; set; }
    [JsonPropertyName("human_deal_in_rate")] public double HumanDealInRate { get; set; }
    [JsonPropertyName("ai_win_average")] public double AiWinAverage { get; set; }
    [JsonPropertyName("ai_self_draw_rate")] public double AiSelfDrawRate { get; set; }
    [JsonPropertyName("ai_gang_average")] public double AiGangAverage { get; set; }
    [JsonPropertyName("draw_rate")] public double DrawRate { get; set; }
}

public sealed class RecentRoundEntry
{
    [JsonPropertyName("round_index")] public int RoundIndex { get; set; }
    [JsonPropertyName("timestamp_unix")] public long TimestampUnix { get; set; }
    [JsonPropertyName("human_delta")] public int HumanDelta { get; set; }
    [JsonPropertyName("human_deal_in")] public bool HumanDealIn { get; set; }
    [JsonPropertyName("ai_win_count")] public int AiWinCount { get; set; }
    [JsonPropertyName("ai_self_draw_count")] public int AiSelfDrawCount { get; set; }
    [JsonPropertyName("ai_gang_count")] public int AiGangCount { get; set; }
    [JsonPropertyName("end_reason")] public string EndReason { get; set; } = string.Empty;
    [JsonPropertyName("score_changes")] public Dictionary<string, int> ScoreChanges { get; set; } = new();
}

public sealed class AdjustmentHistoryEntry
{
    [JsonPropertyName("round_index")] public int RoundIndex { get; set; }
    [JsonPropertyName("timestamp_unix")] public long TimestampUnix { get; set; }
    [JsonPropertyName("parameter_bias")] public ParameterBias ParameterBias { get; set; } = new();
    [JsonPropertyName("parameter_adjustments")] public ParameterAdjustmentSet ParameterAdjustments { get; set; } = ParameterAdjustmentSet.CreateEmpty();
    [JsonPropertyName("changed_bias")] public List<ChangedValue> ChangedBias { get; set; } = new();
    [JsonPropertyName("changed_parameters")] public List<ChangedValue> ChangedParameters { get; set; } = new();
    [JsonPropertyName("reasons")] public List<string> Reasons { get; set; } = new();
}

public sealed class ChangedValue
{
    [JsonPropertyName("key")] public string Key { get; set; } = string.Empty;
    [JsonPropertyName("before")] public int Before { get; set; }
    [JsonPropertyName("after")] public int After { get; set; }
    [JsonPropertyName("delta")] public int Delta { get; set; }
}

public sealed class LearningRoundResult
{
    [JsonPropertyName("round_index")] public int RoundIndex { get; set; }
    [JsonPropertyName("end_reason")] public string EndReason { get; set; } = string.Empty;
    [JsonPropertyName("score_changes")] public Dictionary<string, int> ScoreChanges { get; set; } = new();
    [JsonPropertyName("win_events")] public List<LearningWinEvent> WinEvents { get; set; } = new();
    [JsonPropertyName("gang_events")] public List<LearningGangEvent> GangEvents { get; set; } = new();
}

public sealed class LearningWinEvent
{
    [JsonPropertyName("winner_seat")] public int WinnerSeat { get; set; }
    [JsonPropertyName("source_seat")] public int SourceSeat { get; set; }
    [JsonPropertyName("win_type")] public string WinType { get; set; } = string.Empty;
}

public sealed class LearningGangEvent
{
    [JsonPropertyName("actor_seat")] public int ActorSeat { get; set; }
}

public sealed class LearningRecordPayload
{
    [JsonPropertyName("learning_file_path")] public string LearningFilePath { get; set; } = string.Empty;
    [JsonPropertyName("learning_history_file_path")] public string LearningHistoryFilePath { get; set; } = string.Empty;
    [JsonPropertyName("round_result")] public LearningRoundResult RoundResult { get; set; } = new();
}
