using System;
using System.IO;
using System.Text;
using System.Text.Json;
using Godot;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Agents;

public partial class SichuanCSharpRuntime
{
    private readonly object _auditGate = new();
    private string _auditPath = "";
    private string _auditError = "";
    private long _auditSequence;
    private bool _decisionAuditEnabled;
    public bool DecisionAuditEnabled
    {
        get => _decisionAuditEnabled;
        set
        {
#if DEBUG
            if (value && (OS.HasFeature("ios") || OS.HasFeature("android") || OS.HasFeature("web")))
                throw new InvalidOperationException("research_recording_desktop_only");
            _facade.Agents.ResearchRecordingEnabled = value;
            _decisionAuditEnabled = value;
#else
            if (value) throw new InvalidOperationException("research_recording_not_in_production_build");
            _decisionAuditEnabled = false;
#endif
        }
    }
    public string GetDecisionAuditPath() => _auditPath;
    public string GetDecisionAuditError() => _auditError;

    public string UpdateRoundAgentsJson(string json) => Audit("UpdateRoundAgentsJson", json, () => UpdateRoundAgentsJsonCore(json));
    public string AnalyzeAgentDingQueJson(string json) => Audit("AnalyzeAgentDingQueJson", json, () => AnalyzeAgentDingQueJsonCore(json));
    public string AnalyzeDiscardJson(string json) => Audit("AnalyzeDiscardJson", json, () => AnalyzeDiscardJsonCore(json));
    public string AnalyzeReactionJson(string json) => Audit("AnalyzeReactionJson", json, () => AnalyzeReactionJsonCore(json));
    public string AnalyzeSelfActionJson(string json) => Audit("AnalyzeSelfActionJson", json, () => AnalyzeSelfActionJsonCore(json));
    public string AnalyzeDiscardAotCompact(string json, bool hellChallenge) => hellChallenge
        ? AnalyzeDiscardAotCompactCore(json,true) : Audit("AnalyzeDiscardAotCompact",json,()=>AnalyzeDiscardAotCompactCore(json,false));
    public string AnalyzeReactionAotCompact(string json, bool hellChallenge) => hellChallenge
        ? AnalyzeReactionAotCompactCore(json,true) : Audit("AnalyzeReactionAotCompact",json,()=>AnalyzeReactionAotCompactCore(json,false));
    public string AnalyzeSelfActionAotCompact(string json) => Audit("AnalyzeSelfActionAotCompact",json,()=>AnalyzeSelfActionAotCompactCore(json));

    // Explicit offline replay entry; a replay runtime must disable recording.
    // Raw requests preserve legality flags, ordering and checkpoint inputs.
    public string ReplayDecisionAuditEntry(string entry)
    {
        if (DecisionAuditEnabled) throw new InvalidOperationException("disable_recording_on_replay_runtime");
        using var doc=JsonDocument.Parse(entry); var e=doc.RootElement;
        if(e.GetProperty("policyVersion").GetString()!=SichuanStrategyContract.Version)
            throw new InvalidOperationException("replay_policy_version_mismatch");
        var input=e.GetProperty("request").GetString()!;
        return e.GetProperty("method").GetString() switch {
            "UpdateRoundAgentsJson"=>UpdateRoundAgentsJsonCore(input),
            "AnalyzeAgentDingQueJson"=>AnalyzeAgentDingQueJsonCore(input),
            "AnalyzeDiscardJson"=>AnalyzeDiscardJsonCore(input),
            "AnalyzeReactionJson"=>AnalyzeReactionJsonCore(input),
            "AnalyzeSelfActionJson"=>AnalyzeSelfActionJsonCore(input),
            "AnalyzeDiscardAotCompact"=>AnalyzeDiscardAotCompactCore(input,false),
            "AnalyzeReactionAotCompact"=>AnalyzeReactionAotCompactCore(input,false),
            "AnalyzeSelfActionAotCompact"=>AnalyzeSelfActionAotCompactCore(input),
            _=>throw new InvalidOperationException("unsupported_replay_method")
        };
    }

    private string Audit(string method,string request,Func<string> compute)
    {
        if (!DecisionAuditEnabled) return compute();
        lock(_auditGate)
        {
            // Capture the final agent histories before their round owner disposes them.
            var before=DecisionAuditEnabled ? AuditSnapshots(method,request) : "[]";
            var result=compute();
            if(!DecisionAuditEnabled)return result;
            try
            {
                if(_auditPath.Length==0)
                {
                    var folder=ProjectSettings.GlobalizePath("user://ai_replays");
#if DEBUG
                    var researchFolder=System.Environment.GetEnvironmentVariable("SICHUAN_RESEARCH_AUDIT_DIR");
                    if(!string.IsNullOrWhiteSpace(researchFolder))folder=Path.GetFullPath(researchFolder);
#endif
                    Directory.CreateDirectory(folder);
                    _auditPath=Path.Combine(folder,$"decisions-{DateTime.UtcNow:yyyyMMddTHHmmss}-{Guid.NewGuid():N}.jsonl");
                }
                using var buffer=new MemoryStream();
                using(var writer=new Utf8JsonWriter(buffer))
                {
                    writer.WriteStartObject();writer.WriteNumber("schemaVersion",1);
                    writer.WriteNumber("sequence",++_auditSequence);
                    writer.WriteString("policyVersion",SichuanStrategyContract.Version);
                    writer.WriteString("rulesVersion",SichuanMahjong.AI.Core.Domain.SichuanRuleSnapshot.Version);
                    writer.WriteString("method",method);writer.WriteString("request",request);
                    writer.WriteString("response",result);
                    writer.WriteString("snapshotsBefore",before);
                    writer.WriteString("snapshotsAfter",AuditSnapshots(method,request));
                    writer.WriteString("interpretation","observed_outcomes_are_not_counterfactual_values");
                    writer.WriteEndObject();
                }
                File.AppendAllText(_auditPath,Encoding.UTF8.GetString(buffer.ToArray())+"\n");
                _auditError="";
            }
            catch(Exception ex)
            {
                // A storage fault cannot silently replace a real game decision.
                _auditError=ex.Message;GD.PushWarning("AI 决策复盘保存失败："+ex.Message);
            }
            return result;
        }
    }
    private string AuditSnapshots(string method,string request)
    {
        try
        {
            using var doc=JsonDocument.Parse(request);var root=doc.RootElement;
            var snapshots=new System.Collections.Generic.List<AgentSnapshot>();
            if(method=="UpdateRoundAgentsJson")
            {
                if(root.GetProperty("operation").GetString()=="end")
                    snapshots.AddRange(_facade.Agents.InspectAll());
                else if(root.TryGetProperty("views",out var views))
                    foreach(var view in views.EnumerateArray())
                    {
                        var state=BuildState(JsonSerializer.Deserialize(view.GetRawText(),RuntimeJsonContext.Default.DiscardPayload)!);
                        try {snapshots.Add(_facade.Agents.Inspect(state));}catch(InvalidOperationException) { }
                    }
            }
            else
            {
                var state=BuildState(JsonSerializer.Deserialize(request,RuntimeJsonContext.Default.DiscardPayload)!);
                if(state.RoundId.Length>0)snapshots.Add(_facade.Agents.Inspect(state));
            }
            return "["+string.Join(",",snapshots.ConvertAll(s=>JsonSerializer.Serialize(
                method == "UpdateRoundAgentsJson" && root.GetProperty("operation").GetString()=="end"
                    ? s : s with { Decisions = s.Decisions.Length==0 ? Array.Empty<AgentDecisionTrace>() : new[]{s.Decisions[^1]} },
                RuntimeJsonContext.Default.AgentSnapshot)))+"]";
        }
        catch(Exception ex) { return "{\"auditSnapshotError\":"+JsonSerializer.Serialize(ex.Message)+"}"; }
    }
}
