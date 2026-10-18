using System.Text.Json;
using System.Text.Json.Serialization;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class NaturalSelfHuContinuationSmoke
{
    public static int Run(string input,string output)
    {
        try
        {
            using var data=JsonDocument.Parse(File.ReadAllText(input));
            var rows=new List<object>();var options=new JsonSerializerOptions{PropertyNameCaseInsensitive=true};options.Converters.Add(new JsonStringEnumConverter());
            foreach(var e in data.RootElement.GetProperty("entries").EnumerateArray().Where(e=>e.GetProperty("three_opponents_publicly_cleared").GetBoolean()))
            {
                var q=e.GetProperty("request");int N(string name)=>q.GetProperty(name).GetInt32();
                int[] A(string name)=>q.GetProperty(name).EnumerateArray().Select(v=>v.GetInt32()).ToArray();
                bool[] B(string name)=>q.GetProperty(name).EnumerateArray().Select(v=>v.GetBoolean()).ToArray();
                int[][] M(string name)=>q.GetProperty(name).EnumerateArray().Select(a=>a.EnumerateArray().Select(v=>v.GetInt32()).ToArray()).ToArray();
                var state=SichuanStateCodec.FromRaw(N("seatIndex"),N("dealerSeat"),N("currentSeat"),N("wallCount"),A("hand18"),A("visible18"),A("remaining18"),M("discards18"),M("melds18"),M("passedHu18"),M("passedPeng18"),M("passedGang18"),A("scores"),N("roundIndex"),N("totalRounds"),N("remainingRounds"),N("visibleVersion"),N("handVersion"),N("strategyContextVersion"),A("dingQueSuits"),A("handCounts"),A("lockedFans"),A("lockTurns"),B("unlockOnOwnDraw"),B("activeSeats"),N("eventVersion"));
                state.Phase=N("phase");state.TurnIndex=N("turnIndex");state.WonScores=A("wonScores");
                Array.Copy(B("hasHu"),state.HasHu,4);Array.Copy(B("isCalled"),state.IsCalled,4);Array.Copy(B("isReady"),state.IsReady,4);
                state.LastDrawTileType=N("lastDrawTileType");state.LastDrawOrigin=Enum.Parse<SichuanTileOrigin>(q.GetProperty("lastDrawOrigin").GetString()!,true);
                state.OwnDrawReason=q.GetProperty("ownDrawReason").GetString()!;state.LastGangSeat=N("lastGangSeat");state.LastGangSourceSeat=N("lastGangSourceSeat");state.LastGangTileType=N("lastGangTileType");state.LastGangType=q.GetProperty("lastGangType").GetString()!;
                state.PublicEvents.AddRange(JsonSerializer.Deserialize<SichuanPublicEvent[]>(q.GetProperty("publicEvents").GetRawText(),options)!);
                var melds=JsonSerializer.Deserialize<SichuanMeldView[][]>(q.GetProperty("meldViews").GetRawText(),options)!;for(int s=0;s<4;s++)state.MeldViews[s].AddRange(melds[s]);
                var (winType,source)=SichuanSelfDrawContext.Resolve(state);var fan=new SichuanFanProjectionEngine().Project(state.Hand18,state.MeldViews[state.SeatIndex],winType);
                var payers=Enumerable.Range(0,4).Where(s=>s!=state.SeatIndex && state.ActiveSeats[s] && !state.HasHu[s]).ToArray();
                var actual=new SichuanSettlementProjectionEngine().ProjectWin(state.SeatIndex,source,payers,fan,winType);
                if(actual.WinnerGain*1000!=e.GetProperty("score").GetInt32())throw new Exception("public transport adapter changed measured root pricing");
                var target=e.GetProperty("target_suit").GetInt32();var discards=Enumerable.Range(0,27).Where(t=>state.Hand18[t]>0 && t/9!=target).ToArray();
                var result=new SichuanPublicEndgameEvaluator().AnalyzeSelfHuContinuation(state,discards,32,20261119);
                if(result.Candidates.Count!=discards.Length+1)throw new Exception(result.Status);
                rows.Add(new{opponent=e.GetProperty("opponent").GetString(),request_sha256=e.GetProperty("request_sha256").GetString(),target_suit=target,wall_count=state.WallCount,root_rule_gain=actual.WinnerGain,grounding="natural_public_node_with_model_sampled_full_continuations",not_measured_counterfactual_ground_truth=true,not_blind=true,not_strength_calibrated=true,result});
                File.WriteAllText(output,JsonSerializer.Serialize(rows,new JsonSerializerOptions{WriteIndented=true}));
                Console.WriteLine($"NATURAL_SELF_HU_STUDY node={rows.Count} wall={state.WallCount} refusal_discard_candidates={discards.Length}");
            }
            return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
}
