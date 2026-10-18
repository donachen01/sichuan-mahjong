using System.Text.Json;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

internal static class Chapter424Audit
{
    public static int Run(string folder)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"4.2.4-fixtures.json")));
        var rows=new List<object>();var errors=new List<string>();int checks=0;
        void Check(bool ok,string name){checks++;if(!ok)errors.Add(name);}
        foreach(var raw in doc.RootElement.EnumerateArray())
        foreach(var shift in new[]{0,1,2})
        {
            var s=Build(raw,shift);var id=raw.GetProperty("id").GetString()+$"-s{shift}";
            Check(s.Hand18.Sum()+3*s.OwnMeldCount is 13 or 14,id+" hand/meld count");
            Check(s.Remaining18.Sum()==s.WallCount+s.HandCounts.Skip(1).Sum(),id+" public pool");
            if(raw.TryGetProperty("reaction_tile",out var offer))
            {
                var tile=Map(offer.GetInt32(),shift);var result=new SichuanReactionDecisionEngine().DecideReaction(s,tile,false,true,true,1);
                Check(result.Action.ActionType is SichuanActionType.Peng or SichuanActionType.Gang or SichuanActionType.Pass,id+" legal reaction");
                rows.Add(new{id,kind="reaction",sourceNote=raw.GetProperty("note").GetString(),action=result.Action.ActionType.ToString(),
                    score=result.Action.Score,actionScores=result.ActionScores,reasons=result.Reasons,plannedDiscard=result.PlannedDiscardTile});
            }
            else
            {
                var gangTiles=Enumerable.Range(0,27).Where(t=>s.Hand18[t]==4).ToArray();
                var result=new SichuanSelfActionDecisionEngine().DecideSelfAction(s,false,gangTiles,Array.Empty<int>());
                Check(result.Action.ActionType is SichuanActionType.Gang or SichuanActionType.Pass,id+" legal self action");
                rows.Add(new{id,kind="self_action",sourceNote=raw.GetProperty("note").GetString(),action=result.Action.ActionType.ToString(),
                    subtype=result.GangSubtype,score=result.Action.Score,actionScores=result.ActionScores,reasons=result.Reasons});
            }
        }
        var report=new{auditOnly=true,checks,errors,rows,strategyVersion=SichuanStrategyContract.Version,
            scope="Current C# strategy audit of 4.2.4 source-shaped fixtures; no production change or source action assertion."};
        File.WriteAllText(Path.Combine(folder,"current_policy_audit.json"),JsonSerializer.Serialize(report,new JsonSerializerOptions{WriteIndented=true}));
        Console.WriteLine($"CHAPTER424_AUDIT cases={rows.Count} checks={checks} errors={errors.Count}");
        foreach(var e in errors.Take(12))Console.WriteLine(e);
        return errors.Count==0?0:1;
    }
    internal static int Map(int t,int shift)=>t<0?t:((t/9+shift)%3)*9+t%9;
    internal static SichuanStateView Build(JsonElement raw,int shift)
    {
        int[] A(string key)=>raw.GetProperty(key).EnumerateArray().Select(x=>x.GetInt32()).ToArray();
        var hand=A("hand18");var melds=raw.GetProperty("typed_melds").EnumerateArray()
            .Select(m=>new SichuanMeldView(Enum.Parse<SichuanMeldType>(m.GetProperty("type").GetString()!,true),
                Map(m.GetProperty("tiles")[0].GetInt32(),shift),m.GetProperty("type").GetString()=="peng"?1:-1,0)).ToArray();
        var h=new int[27];for(var t=0;t<27;t++)h[Map(t,shift)]=hand[t];
        var v=new int[27];foreach(var m in melds)v[m.TileType]+=m.Type==SichuanMeldType.Peng?3:4;
        var r=Enumerable.Range(0,27).Select(t=>4-h[t]-v[t]).ToArray();
        var wall=Math.Max(1,r.Sum()-39-(raw.TryGetProperty("reaction_tile",out _)?1:0));var ding=raw.TryGetProperty("own_missing_suit",out var miss)?new[]{(miss.GetInt32()+shift)%3,0,1,2}:new[]{-1,-1,-1,-1};
        var s=SichuanStateCodec.FromRaw(0,0,raw.TryGetProperty("reaction_tile",out _)?1:0,wall,h,v,r,
            dingQueSuits:ding,handCounts:new[]{hand.Sum(),13,13,13},activeSeats:new[]{true,true,true,true});
        s.MeldViews[0].AddRange(melds);s.HandCounts[0]=hand.Sum();
        if(raw.TryGetProperty("reaction_tile",out var offer))
        {
            var tile=Map(offer.GetInt32(),shift);s.Visible18[tile]++;s.Remaining18[tile]--;s.PublicEvents.Add(new(1,1,1,SichuanPublicEventType.Discard,tile,SichuanTileOrigin.Draw,1));
        }
        else
        {
            s.LastDrawTileType=Enumerable.Range(0,27).FirstOrDefault(t=>h[t]==4,-1);s.LastDrawOrigin=SichuanTileOrigin.Draw;s.OwnDrawReason="normal_draw";s.Phase=5;
        }
        return s;
    }
}
