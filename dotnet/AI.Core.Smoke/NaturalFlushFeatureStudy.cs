using System.Text.Json;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;

internal static class NaturalFlushFeatureStudy
{
    public static int Run(string input,string output)
    {
        try
        {
            using var file=JsonDocument.Parse(File.ReadAllText(input));var rows=new List<object>();
            var structure=new SichuanFlushStructureEngine();
            foreach(var row in file.RootElement.GetProperty("rows").EnumerateArray())
            {
                // Public file only. No node snapshot, hidden world or outcomes.
                var s=PublicPosteriorNaturalStudy.State(row.GetProperty("public_input"));
                var wall=new SichuanWallAvailabilityEngine().Build(s,new SichuanBeliefEngine().Build(s));
                int target=Enumerable.Range(0,3).Where(t=>t!=s.OwnDingQueSuit)
                    .OrderByDescending(t=>s.Hand18.Skip(t*9).Take(9).Sum()).First();
                var exposed=new int[27];
                if(s.MeldViews[s.SeatIndex].Count>0)
                    foreach(var m in s.MeldViews[s.SeatIndex])exposed[m.TileType]+=m.Type==SichuanMeldType.Peng?3:4;
                else foreach(int t in s.Melds18[s.SeatIndex])exposed[t]++;
                if(exposed.Where((n,t)=>n>0 && t/9!=target).Any())throw new Exception("selected flush incompatible with own public melds");
                var candidates=new List<object>();
                foreach(var c in row.GetProperty("native_public_predictor").GetProperty("candidates").EnumerateArray())
                {
                    double encodedTile=c.GetProperty("tileType").GetDouble();
                    if(encodedTile!=Math.Floor(encodedTile) || encodedTile is <0 or >26)throw new Exception("invalid public candidate tile index");
                    int tile=(int)encodedTile;var after=s.Hand18.ToArray();
                    if(after[tile]<=0)throw new Exception("candidate not own legal tile");after[tile]--;
                    var f=structure.Analyze(after,s.Remaining18,exposed,target,s.OwnMeldCount);
                    double targetCount=after.Skip(target*9).Take(9).Sum();
                    double[] features={f.MinimumAdditionalTiles/6.0,Math.Log(1+f.FeasiblePatterns)/12.0,
                        wall.SumExpected(f.UsefulDraws)/Math.Max(1,wall.WallCount),
                        wall.SumExpected(f.RequiredInEveryNearestPattern)/8.0,
                        f.UsefulDraws.Count/9.0,f.RequiredInEveryNearestPattern.Count/9.0,
                        targetCount/14.0,(after.Sum()-targetCount)/6.0};
                    candidates.Add(new{tileType=tile,features,feasible=f.FeasiblePatterns>0,
                        minimum_additional=f.MinimumAdditionalTiles,required_types=f.RequiredInEveryNearestPattern,
                        description="Exact public structural upper-bound features; wall mass is an uncalibrated supply model, not terminal completion probability"});
                }
                rows.Add(new{input_sha256=row.GetProperty("input_sha256").GetString(),seed=row.GetProperty("seed").GetInt32(),target_suit=target,candidates,public_only=true});
            }
            File.WriteAllText(output,JsonSerializer.Serialize(new{origin="public_only_flush_structure_features_before_labels",rows},new JsonSerializerOptions{WriteIndented=true}));
            Console.WriteLine($"NATURAL_FLUSH_FEATURES public_nodes={rows.Count}; hidden worlds/outcomes not read");return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
}
