using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using SichuanMahjong.AI.Core.Analysis;

namespace SichuanMahjong.AI.Core.Models;

/// <summary>The seat authority is the only issuer. Analysis engines return proposals.</summary>
public sealed record SichuanDecisionCommand(
    string Id, string Window, string RoundId, long Generation, long ViewVersion,
    int Seat, string StateKey, string Policy, int PlanRevision, string Action,
    int Tile, string GangSubtype, string ParentId = "", string ContinuationAction = "",
    int ContinuationTile = -1, string ContinuationState = "")
{
    public const string PolicyVersion = "unified-seat-policy-v2-adaptive-budget";
    public const int SchemaVersion = 1;
    public static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();
    public static string Fingerprint(SichuanStateView state) => Hash(
        $"{state.RoundId}/{state.HostGeneration}/{state.ViewVersion}/" + SichuanStateFingerprint.BuildTurnKey(state, true, false));

    // Explicit writer is safe under iOS NativeAOT; compact and JSON carry the same contract.
    public string ToWire()
    {
        using var stream = new MemoryStream();
        using (var w = new Utf8JsonWriter(stream))
        {
            w.WriteStartObject(); w.WriteNumber("schema", SchemaVersion);
            w.WriteString("id", Id); w.WriteString("window", Window); w.WriteString("roundId", RoundId);
            w.WriteNumber("generation", Generation); w.WriteNumber("viewVersion", ViewVersion); w.WriteNumber("seat", Seat);
            w.WriteString("stateKey", StateKey); w.WriteString("policy", Policy); w.WriteNumber("planRevision", PlanRevision);
            w.WriteString("action", Action); w.WriteNumber("tile", Tile); w.WriteString("gangSubtype", GangSubtype);
            w.WriteString("parentId", ParentId); w.WriteString("continuationAction", ContinuationAction);
            w.WriteNumber("continuationTile", ContinuationTile); w.WriteString("continuationState", ContinuationState);
            w.WriteEndObject();
        }
        return Encoding.UTF8.GetString(stream.ToArray());
    }
}
