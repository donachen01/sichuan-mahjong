using System.Text.Json;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Inference;
var outdir=Path.GetFullPath(args[0]);var rows=new List<object>();var failures=new List<string>();int checks=0;void C(bool b,string s){checks++;if(!b)failures.Add(s);}int[] H(params int[] t){var h=new int[27];foreach(var x in t)h[x]++;return h;}
using var raw=JsonDocument.Parse(File.ReadAllText(Path.Combine(outdir,"unseen-inputs.json")));
foreach(var entry in raw.RootElement.EnumerateObject()){
 var f=entry.Value;var hands=f.GetProperty("hands").EnumerateArray().Select(a=>H(a.EnumerateArray().Select(v=>v.GetInt32()).ToArray())).ToArray();var rivers=f.GetProperty("rivers").EnumerateArray().Select(a=>a.EnumerateArray().Select(v=>v.GetInt32()).ToList()).ToArray();
 var wallTypes=f.GetProperty("wall").EnumerateArray().Select(v=>v.GetInt32()).ToArray();var wallCounts=H(wallTypes);var visible=Enumerable.Range(0,27).Select(t=>rivers.Sum(r=>r.Count(x=>x==t))).ToArray();var remaining=Enumerable.Range(0,27).Select(t=>4-hands[1][t]-visible[t]).ToArray();
 var s=new SichuanStateView{SeatIndex=1,CurrentSeat=1,Phase=5,WallCount=wallTypes.Length,RoundIndex=1,RoundId=entry.Name,Hand18=hands[1],Visible18=visible,Remaining18=remaining,Discards18=rivers,HandCounts=[13,14,13,13],DingQueSuits=[1,2,2,2],ActiveSeats=[true,true,true,true],HasHu=[false,false,false,false],LastDrawTileType=f.GetProperty("draw").GetInt32(),LastDrawOrigin=SichuanTileOrigin.Draw,OwnDrawReason="normal_draw"};
 long idx=0;for(int seat=0;seat<4;seat++)foreach(int t in rivers[seat])s.PublicEvents.Add(new(++idx,(int)idx,seat,SichuanPublicEventType.Discard,t,SichuanTileOrigin.Hand,SourceSeat:seat));s.EventVersion=idx;
 var posterior=new SichuanPublicPosteriorAnalysis().AnalyzeSeedEnsemble(s,64,20261024,6);
 C(posterior.Supported||posterior.Reason=="insufficient_effective_samples","posterior either passes ESS or rejects explicitly "+entry.Name);
 C(!posterior.Supported||posterior.Runs.Count==6,"six independent posterior seeds when supported "+entry.Name);
 C(!posterior.Supported||posterior.Tiles.All(x=>x.MeanInWallProbability is >=0 and <=1&&x.SeedRange is >=0 and <=1),"posterior probabilities bounded when supported "+entry.Name);
 var d=new SichuanUnifiedDecisionEngine().RankDiscards(s);var sr=d.Candidates.SelectMany(c=>c.ReasonCodes).Where(x=>x.StartsWith("PUBLIC_SUPPLY_")).ToArray();C(sr.All(x=>x.Contains("outside_")||x.Contains("unstable")||x.Contains("public_first_opponent_step")),"supply reason explicit bounded status "+entry.Name);
 rows.Add(new{id=entry.Name,posteriorStatus=posterior.Reason,minEss=posterior.MinimumEffectiveSampleSize,maxSeedRange=posterior.MaximumSeedRange,supply=sr,candidates=d.Candidates.Select(c=>new{tile=c.Action.TileType,net=c.ExpectedNetScore,reasons=c.ReasonCodes.Where(x=>x.StartsWith("PUBLIC_SUPPLY_")).ToArray()})});
}
File.WriteAllText(Path.Combine(outdir,"supply-results.json"),JsonSerializer.Serialize(new{checks,failures,rows},new JsonSerializerOptions{WriteIndented=true}));Console.WriteLine($"SUPPLY checks={checks} failures={failures.Count}");foreach(var f in failures)Console.WriteLine("FAIL "+f);return failures.Count==0?0:1;
