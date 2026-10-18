using System.Reflection;
using System.Text.Json;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class Chapter422Application
{
    public static int Run(string folder)
    {
        using var doc=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"independent_cases.json")));
        var errors=new List<string>();var rows=new List<object>();var differences=new List<string>();int checks=0;
        void Check(bool ok,string message){checks++;if(!ok)errors.Add(message);}
        Check(SichuanConcealedTripletHuTable.Distinct(4,7,1,2)==0,"unlisted narrow general danger cannot relax the 5-6 danger exit");
        foreach(var r in doc.RootElement.GetProperty("pure_table").EnumerateArray())
        {
            var live=r.GetProperty("live").GetInt32();var rnd=r.GetProperty("round").GetInt32();
            var danger=r.GetProperty("danger").GetInt32();var dark=r.GetProperty("dark").GetInt32();
            var cap=r.GetProperty("kind").GetString() switch{
                "distinct"=>SichuanConcealedTripletHuTable.Distinct(live,rnd,danger,dark),
                "two_missing"=>SichuanConcealedTripletHuTable.TwoMissing(live,rnd,danger,dark),
                _=>SichuanConcealedTripletHuTable.WideBed(live,danger,dark).Cap};
            Check(cap==r.GetProperty("cap").GetInt32(),"pure source table "+r);
        }
        foreach(var r in doc.RootElement.GetProperty("table").EnumerateArray())
        {
            var s=Chapter412Smoke.State(r.GetProperty("payload"));var name=r.GetProperty("name").GetString()!;
            var targets=SichuanIndependentTriplet.LiveTargets(s).Order().ToArray();
            if(r.TryGetProperty("verifySameSuitOnly",out var scope)&&scope.GetBoolean())
                Check(SichuanIndependentTriplet.LiveTargets(s,1).Length==0,name+" foreign triplet cannot become same-suit target");
            else Check(targets.SequenceEqual(r.GetProperty("expectedTargets").EnumerateArray().Select(t=>t.GetInt32()).Order()),name+" independent targets");
            var result=SichuanStrategyContract.Assess(s);
            var cap=result.Discipline.Applies?result.Discipline.MaximumRefusals:result.Development.RefusalLimit;
            Check(cap==r.GetProperty("expectedCap").GetInt32(),name+$" cap {cap} expected {r.GetProperty("expectedCap")}");
            Check(result.AllowsRonRefusal==(cap>0),name+" eligibility");
            Check(SichuanStrategyContract.Assess(s).AllowsRonRefusal==result.AllowsRonRefusal,name+" repeated query");
            // Consume exactly one actual Ron refusal, not a decision query.
            var offer=r.GetProperty("offer").GetInt32();
            s.PublicEvents.Add(new(s.PublicEvents.Max(e=>e.EventIndex)+1,900,0,SichuanPublicEventType.Pass,
                offer,SourceSeat:s.CurrentSeat,CanHu:true));
            var used=SichuanStrategyContract.Assess(s);
            Check(used.Development.UsedRefusals==1,name+" actual refusal consumed");
            Check(used.AllowsRonRefusal==(cap>1),name+" used token respected");
            rows.Add(new{name,cap,targets});
        }
        foreach(var r in doc.RootElement.GetProperty("new_draw_cases").EnumerateArray())
        {
            var s=Chapter412Smoke.State(r.GetProperty("payload"));var name=r.GetProperty("name").GetString()!;
            s.LastDrawTileType=r.GetProperty("draw").GetInt32();s.LastDrawOrigin=SichuanTileOrigin.Draw;
            s.OwnDrawReason="normal_draw";s.Phase=5;
            var result=new SichuanDecisionEngine().DecideDiscard(s);
            var chosen=r.GetProperty("successors").EnumerateArray().Single(c=>c.GetProperty("discard").GetInt32()==result.Action.TileType);
            Check(chosen.GetProperty("waits").GetArrayLength()>0,name+" legal independently ready discard");
            var probe=new SichuanNewConcealedTripletPolicy().Evaluate(s,s.LastDrawTileType);
            var integratedProbe=new SichuanNewConcealedTripletPolicy().Evaluate(s,result.Action.TileType,result.Candidates);
            var expectedKeep=r.GetProperty("source_preference").GetString()=="keep";
            var keeps=chosen.GetProperty("keeps_triplet").GetBoolean();
            if(keeps!=expectedKeep)differences.Add(name);
            Check(keeps==expectedKeep,name+" source strategy direction in declared completion");
            var first=JsonSerializer.Serialize(probe);
            s.IsReady[1]=!s.IsReady[1];s.PassedHu18[2][0]=17;
            Check(first==JsonSerializer.Serialize(new SichuanNewConcealedTripletPolicy().Evaluate(s,s.LastDrawTileType)),name+" hidden flags ignored");
            Check(probe.Options.Length==0||probe.Options.All(o=>o.LocalOptionValue>=0&&double.IsFinite(o.LocalOptionValue)),name+" finite option values");
            // Broken premises must disable the new option, without touching
            // existing legal Hu/Gang or inventing a future fourth copy.
            var remaining=s.Remaining18[s.LastDrawTileType];s.Remaining18[s.LastDrawTileType]=0;
            var dead=new SichuanNewConcealedTripletPolicy().Evaluate(s,s.LastDrawTileType);
            Check(dead.SelectedDiscard==s.LastDrawTileType,name+" dead fourth no keep override");
            s.Remaining18[s.LastDrawTileType]=remaining;
            s.LastDrawTileType=-1;
            Check(new SichuanNewConcealedTripletPolicy().Evaluate(s,result.Action.TileType).Options.Length==0,name+" actual draw required");
            rows.Add(new{name,selected=result.Action.TileType,keeps,expectedKeep,probe,reasons=result.Reasons,
                candidates=result.Candidates.Where(c=>c.Shanten==0).Select(c=>new{c.TileType,c.Danger,c.ExpectedDealInLoss}),
                integratedProbe});
        }
        var exemplar=doc.RootElement.GetProperty("new_draw_cases")[6*7]; // 4-10B
        SichuanStateView DrawNode(JsonElement r)
        {
            var s=Chapter412Smoke.State(r.GetProperty("payload"));s.LastDrawTileType=r.GetProperty("draw").GetInt32();
            s.LastDrawOrigin=SichuanTileOrigin.Draw;s.OwnDrawReason="normal_draw";return s;
        }
        foreach(var level in new[]{1,2})
        {
            var s=DrawNode(exemplar);
            foreach(var t in new[]{18,19,20})s.MeldViews[1].Add(new(SichuanMeldType.Peng,t,2,0));
            if(level==2){s.MeldViews[1].Add(new(SichuanMeldType.ConcealedGang,21,1,0));
                s.MeldViews[2].Add(new(SichuanMeldType.ConcealedGang,22,2,0));}
            Check(new SichuanNewConcealedTripletPolicy().Evaluate(s,s.LastDrawTileType).Status=="defensive_wide_wait_first",
                "new triplet respects public danger "+level);
        }
        var wideNode=DrawNode(doc.RootElement.GetProperty("new_draw_cases")[6*9]);
        Check(new SichuanNewConcealedTripletPolicy().Evaluate(wideNode,wideNode.LastDrawTileType).Status=="defensive_wide_wait_first",
            "active opponent wide bed protects defense");
        wideNode.HasHu[1]=true;wideNode.ActiveSeats[1]=false;
        Check(new SichuanNewConcealedTripletPolicy().Evaluate(wideNode,wideNode.LastDrawTileType).Status!="defensive_wide_wait_first",
            "retired sole collector no longer triggers defense");
        var unknown=DrawNode(exemplar);unknown.PublicEvents.RemoveAt(unknown.PublicEvents.Count-1);
        Check(new SichuanNewConcealedTripletPolicy().Evaluate(unknown,unknown.LastDrawTileType).Status=="new_triplet_draw_unconfirmed",
            "actual own draw evidence required");
        var noReplacement=new SichuanStateView{SeatIndex=0,CurrentSeat=0,WallCount=1,
            LastDrawTileType=6,Hand18=DrawNode(exemplar).Hand18,DingQueSuits=new[]{2,0,1,2}};
        Check(new SichuanNewConcealedTripletPolicy().Evaluate(noReplacement,6).Options.Length==0,"no replacement no new triplet option");
        foreach(var name in new[]{"cashout_widened.json","cashout_restore_base.json"})
        {
            using var cash=JsonDocument.Parse(File.ReadAllText(Path.Combine(folder,"../../distinct-dingque-introduction-20261017",name)));
            var s=Chapter412Smoke.State(cash.RootElement);var rule=new SichuanDistinctDingQueHuPolicy().Evaluate(s);
            if(name=="cashout_widened.json")Check(!rule.AllowsRefusal&&rule.CashOutOrigin=="narrow_development_cashed","widening cannot renew cashed narrow route");
            else Check(rule.UsedRefusals==1&&rule.MaximumRefusals==1,"wide cashout preserves already used token");
        }
        var method=typeof(SichuanNewConcealedTripletPolicy).GetMethod("OptionValue",BindingFlags.Static|BindingFlags.NonPublic)!;
        foreach(var r in doc.RootElement.GetProperty("arithmetic").EnumerateArray())
        {
            var h=new int[27];foreach(var t in new[]{0,1,2,6,6,6,9,10,11,13})h[t]++;
            // Ready on Tong5 after discarding Tong6 from the 4-10 shape.
            var ms=new List<SichuanMeldView>{new(SichuanMeldType.Peng,3,1,0)};
            var s=new SichuanStateView{SeatIndex=0,CurrentSeat=0,WallCount=r.GetProperty("wall").GetInt32(),Hand18=h,
                DingQueSuits=r.GetProperty("ding").EnumerateArray().Select(x=>x.GetInt32()).ToArray()};
            for(int seat=1;seat<4;seat++)s.PublicEvents.Add(new(seat,seat,seat,SichuanPublicEventType.Discard,
                (s.DingQueSuits[seat]+1)%3*9,SourceSeat:seat));
            var counts=new double[27];counts[13]=r.GetProperty("waits").GetInt32();counts[6]=r.GetProperty("fourth").GetInt32();
            var wall=new SichuanWallAvailability(counts,counts.Select(x=>(int)x).ToArray(),s.WallCount);
            var p=new SichuanReadyWaitPricing().Build(s,h,counts,ms)!;
            var reduced=(int[])h.Clone();reduced[6]-=3;
            var after=r.GetProperty("canGang").GetBoolean()?new SichuanReadyWaitPricing().Build(s,reduced,counts,
                ms.Append(new SichuanMeldView(SichuanMeldType.ConcealedGang,6,0,0)).ToArray()):null;
            var value=(double)method.Invoke(null,new object?[]{s,6,p,after,h,ms,wall,null})!;
            Check(Math.Abs(value-r.GetProperty("expected").GetDouble())<1e-9,"exhaustive finite wall "+r+" actual="+value);
        }
        File.WriteAllText(Path.Combine(folder,"application_results.json"),JsonSerializer.Serialize(new{checks,errors,
            sourcePreferenceDifferences=differences,rows,version=SichuanStrategyContract.Version},new JsonSerializerOptions{WriteIndented=true}));
        Console.WriteLine($"CHAPTER422_APPLICATION checks={checks} errors={errors.Count} sourceTendencyDifferences={differences.Count}");
        foreach(var e in errors.Take(15))Console.WriteLine(e);
        return errors.Count==0?0:1;
    }
}
