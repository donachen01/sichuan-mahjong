using System.Text.Json;
using System.Text.Json.Serialization;
using System.Security.Cryptography;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Inference;

internal static class PublicPosteriorNaturalStudy
{
    public static SichuanStateView State(JsonElement q)
    {
        int N(string k)=>q.GetProperty(k).GetInt32();
        int[] A(string k)=>q.GetProperty(k).EnumerateArray().Select(x=>x.GetInt32()).ToArray();
        bool[] B(string k)=>q.GetProperty(k).EnumerateArray().Select(x=>x.GetBoolean()).ToArray();
        int[][] M(string k)=>q.GetProperty(k).EnumerateArray().Select(x=>x.EnumerateArray().Select(v=>v.GetInt32()).ToArray()).ToArray();
        var s=SichuanStateCodec.FromRaw(N("seatIndex"),N("dealerSeat"),N("currentSeat"),N("wallCount"),A("hand18"),A("visible18"),A("remaining18"),M("discards18"),M("melds18"),M("passedHu18"),M("passedPeng18"),M("passedGang18"),A("scores"),N("roundIndex"),N("totalRounds"),N("remainingRounds"),N("visibleVersion"),N("handVersion"),N("strategyContextVersion"),A("dingQueSuits"),A("handCounts"),A("lockedFans"),A("lockTurns"),B("unlockOnOwnDraw"),B("activeSeats"),N("eventVersion"));
        s.Phase=N("phase");s.TurnIndex=N("turnIndex");s.WonScores=A("wonScores");
        Array.Copy(B("hasHu"),s.HasHu,4);Array.Copy(B("isCalled"),s.IsCalled,4);Array.Copy(B("isReady"),s.IsReady,4);
        s.LastDrawTileType=N("lastDrawTileType");s.LastDrawOrigin=Enum.Parse<SichuanTileOrigin>(q.GetProperty("lastDrawOrigin").GetString()!,true);
        s.OwnDrawReason=q.GetProperty("ownDrawReason").GetString()!;s.LastGangSeat=N("lastGangSeat");s.LastGangSourceSeat=N("lastGangSourceSeat");s.LastGangTileType=N("lastGangTileType");s.LastGangType=q.GetProperty("lastGangType").GetString()!;
        var opt=new JsonSerializerOptions{PropertyNameCaseInsensitive=true};opt.Converters.Add(new JsonStringEnumConverter());
        s.PublicEvents.AddRange(JsonSerializer.Deserialize<SichuanPublicEvent[]>(q.GetProperty("publicEvents").GetRawText(),opt)!);
        var melds=JsonSerializer.Deserialize<SichuanMeldView[][]>(q.GetProperty("meldViews").GetRawText(),opt)!;for(int seat=0;seat<4;seat++)s.MeldViews[seat].AddRange(melds[seat]);
        return s;
    }
    public static int Labels(string input,string output)
    {
        try
        {
            using var data=JsonDocument.Parse(File.ReadAllText(input));var rows=new List<object>();var exact=new SichuanMahjong.AI.Core.Rules.SichuanExactHandAnalyzer();
            int Tile(JsonElement t)=>Array.IndexOf(new[]{"tiao","tong","wan"},t.GetProperty("suit").GetString())*9+t.GetProperty("rank").GetInt32()-1;
            foreach(var entry in data.RootElement.EnumerateArray())
            {
                string path=entry.GetProperty("node").GetProperty("path").GetString()!;var bytes=File.ReadAllBytes(path);string hash=Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
                if(hash!=entry.GetProperty("node").GetProperty("sha256").GetString())throw new Exception("changed actual label world");
                using var node=JsonDocument.Parse(bytes);var state=node.RootElement.GetProperty("state");var wall=new int[27];foreach(var t in state.GetProperty("wall").EnumerateArray())wall[Tile(t)]++;
                var players=state.GetProperty("players").EnumerateArray().ToArray();int observer=node.RootElement.GetProperty("seat").GetInt32();var opponents=new List<object>();
                foreach(var player in players)
                {
                    int seat=player.GetProperty("seat").GetInt32();if(seat==observer || player.GetProperty("has_won").GetBoolean())continue;
                    var melds=player.GetProperty("melds").EnumerateArray().ToArray();var hand=new int[27];foreach(var t in player.GetProperty("hand_tiles").EnumerateArray())hand[Tile(t)]++;
                    if(hand.Sum()!=13-3*melds.Length)continue;var capacity=Enumerable.Range(0,27).Select(t=>4-hand[t]).ToArray();foreach(var meld in melds)foreach(var t in meld.GetProperty("tiles").EnumerateArray())capacity[Tile(t)]--;
                    string missing=player.GetProperty("ding_que").GetString()!;int suit=Array.IndexOf(new[]{"tiao","tong","wan"},missing);bool cleared=hand.Skip(suit*9).Take(9).Sum()==0;
                    var waits=cleared?exact.EnumerateWaits(hand,capacity,melds.Length,melds.Length==0).Where(w=>w.TileType/9!=suit).Select(w=>w.TileType).ToArray():Array.Empty<int>();
                    opponents.Add(new{seat,ready=waits.Length>0,waits,label="structural legal ready shape at waiting phase, fifth copies excluded; not private passed-Hu eligibility"});
                }
                rows.Add(new{input_sha256=hash,seed=node.RootElement.GetProperty("seed").GetInt32(),seat=observer,wall_counts=wall,opponents});
            }
            File.WriteAllText(output,JsonSerializer.Serialize(new{origin="separate_label_side_actual_hidden_world_only",rows},new JsonSerializerOptions{WriteIndented=true}));Console.WriteLine($"POSTERIOR_ACTUAL_LABELS nodes={rows.Count}; no prediction function used here");return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
    public static int Run(string input,string output)
    {
        try
        {
            using var file=JsonDocument.Parse(File.ReadAllText(input));var rows=new List<object>();
            foreach(var row in file.RootElement.GetProperty("rows").EnumerateArray())
            {
                // Deliberately read only the extracted public view; no node state,
                // physical wall, foreign hidden hands or branch outcome is opened.
                var q=row.GetProperty("public_input");var s=State(q);var b=new SichuanBeliefEngine().Build(s);var wall=new SichuanWallAvailabilityEngine().Build(s,b);
                if(Math.Abs(wall.ExpectedCounts18.Sum()-s.WallCount)>1e-6)throw new Exception("public posterior mass mismatch");
                int residual=s.WallCount-wall.KnownWallCounts18.Sum();int cap=s.Remaining18.Sum()-wall.KnownWallCounts18.Sum();
                var uniform=Enumerable.Range(0,27).Select(t=>(double)wall.KnownWallCounts18[t]+(cap==0?0:(s.Remaining18[t]-wall.KnownWallCounts18[t])*(double)residual/cap)).ToArray();
                var readyFeatures=new Dictionary<int,double[]>();
                foreach(var seat in b.SeatReadyPosterior.Keys)
                {
                    var timeline=SichuanOpponentTimeline.Build(s,seat);
                    double raw=b.PublicReadFeatures[$"seat:{seat}:uncalibrated_ready"];
                    double p=Math.Clamp(raw,.001,.999);
                    readyFeatures[seat]=new[]{1.0,Math.Log(p/(1-p)),(60-s.WallCount)/60.0,
                        s.MeldCount(seat)/4.0,s.Discards18[seat].Count/12.0,
                        timeline.RecentHandDiscards/4.0,timeline.RecentDrawDiscards/4.0,
                        timeline.RecentCentralDiscards/4.0,timeline.LastDiscardWasMissing?1.0:0.0,
                        SichuanOpponentTimeline.MustHaveClearedMissing(s,seat)?1.0:0.0};
                }
                rows.Add(new{input_sha256=row.GetProperty("input_sha256").GetString(),seed=row.GetProperty("seed").GetInt32(),seat=s.SeatIndex,wall_count=s.WallCount,wall_expected_counts=wall.ExpectedCounts18,known_wall_counts=wall.KnownWallCounts18,uniform_known_constrained_counts=uniform,ready_posterior=b.SeatReadyPosterior,ready_features=readyFeatures,wait_posterior=b.SeatTileWaitProbability,only_public_inputs_read=true});
            }
            File.WriteAllText(output,JsonSerializer.Serialize(new{origin="public_only_pre_label_current_core_predictions",public_file_sha256=Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(input))).ToLowerInvariant(),rows},new JsonSerializerOptions{WriteIndented=true}));
            Console.WriteLine($"PUBLIC_POSTERIOR_NATURAL predictions={rows.Count}; label worlds and outcomes not read");return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
}
