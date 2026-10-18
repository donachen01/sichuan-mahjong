using System.Text.Json;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class DrawWinnerAssessmentSmoke
{
    public static int Run(string output)
    {
        var checks=0;
        void Check(bool ok,string why){checks++;if(!ok)throw new InvalidOperationException(why);}
        try
        {
            var rows=new List<object>();
            var scorer=new SichuanSettlementProjectionEngine();
            foreach(var winner in Enumerable.Range(0,4))
            foreach(var ting in Enumerable.Range(0,4).Where(s=>s!=winner))
            foreach(var unready in Enumerable.Range(0,4).Where(s=>s!=winner && s!=ting))
            foreach(var price in new[]{1,2,4,8,16})
            foreach(var previousWin in new[]{-1,0,1,16,999})
            {
                var hua=Enumerable.Range(0,4).Single(s=>s!=winner && s!=ting && s!=unready);
                var expected=new int[4];expected[ting]=price+16;expected[unready]=-price;expected[hua]=-16;
                var result=scorer.ProjectScenario(new(DrawAssessments:[
                    new(winner,true,previousWin==999,16,HasWon:true,WonScore:previousWin),
                    new(ting,true,false,price),new(unready,false,false,0),new(hua,false,true,0)]));
                Check(result.ScoreChanges.SequenceEqual(expected),"winner received/paid terminal draw settlement");
                Check(result.ChaJiaoChanges[winner]==0 && result.HuaZhuChanges[winner]==0,"exited winner classified as active");
                Check(result.ScoreChanges.Sum()==0,"draw settlement not zero sum");
                rows.Add(new{winner,ting,unready,hua,price,previousWin,expected});
            }
            File.WriteAllText(output,JsonSerializer.Serialize(rows,new JsonSerializerOptions{WriteIndented=true}));
            Console.WriteLine($"DRAW_WINNER_ASSESSMENT matrix PASS cases={rows.Count} checks={checks}");

            var own=Hand(18,18,19,20,21,24,25,26,12,13,14,15,16);
            var f=HuIncomeCostSmoke.Fixture(own,[],2,11);
            f.State.ActiveSeats[1]=false;f.State.HasHu[1]=true;f.State.WonScores[1]=-1;
            f.State.DingQueSuits[1]=2;
            f.State.DingQueSuits[2]=1;
            // A real exited self-Hu hand: 0000 1111 2222 33 can be
            // decomposed into 000/111/222/012/33. Preserve all 108 copies.
            f.Particle.Hands27[1][3]++;f.Particle.Hands27[2][3]--;
            f.Particle.Hands27[2][18]++;
            f.State.HandCounts[1]=14;
            f.State.Visible18[18]--;f.State.Remaining18[18]++;
            var removed=f.State.PublicEvents.FindLastIndex(e=>e.Type==SichuanPublicEventType.Discard && e.TileType==18);
            f.State.Discards18[f.State.PublicEvents[removed].Seat].Remove(18);
            f.State.PublicEvents.RemoveAt(removed);
            f.State.PublicEvents.Insert(f.State.PublicEvents.Count-1,new(0,0,1,SichuanPublicEventType.Hu,3,SourceSeat:1));
            for(var i=0;i<f.State.PublicEvents.Count;i++)f.State.PublicEvents[i]=f.State.PublicEvents[i] with{EventIndex=i+1};
            Check(new SichuanExactHandAnalyzer().IsWinning(f.Particle.Hands27[1]),"exited fixture hand is not a real Hu");
            Check(Enumerable.Range(0,27).All(t=>own[t]+f.State.Visible18[t]+f.Particle.Hands27.Sum(h=>h[t])==4),"exited fixture four-copy conservation");
            var evaluator=new SichuanPublicEndgameEvaluator();
            var unknown=evaluator.AnalyzeHuContinuation(f.State,11,2,samples:32,seed:713);
            Check(unknown.Candidates.Count==2,"unknown historical Hu price blocked valid public research: "+unknown.Status);
            Check(unknown.Candidates.Single(c=>c.Action==SichuanActionType.Hu).DrawSettlement==0,"Hu root collected later cha-jiao");
            foreach(var previousWin in new[]{1,999})
            {
                f.State.WonScores[1]=previousWin;
                var known=evaluator.AnalyzeHuContinuation(f.State,11,2,samples:32,seed:713);
                Check(known.Candidates.SequenceEqual(unknown.Candidates),"past Hu price changed future draw value");
            }

            var complete=own.ToArray();complete[11]++;
            var visible=f.State.Visible18.ToArray();visible[11]--;
            var self=SichuanStateCodec.FromRaw(0,0,0,0,complete,visible,
                dingQueSuits:f.State.DingQueSuits,handCounts:[14,14,13,13]);
            self.ActiveSeats[1]=false;self.HasHu[1]=true;self.WonScores[1]=-1;
            self.LastDrawOrigin=SichuanTileOrigin.Draw;self.LastDrawTileType=11;self.OwnDrawReason="normal_draw";
            for(var seat=0;seat<4;seat++)self.Discards18[seat].AddRange(f.State.Discards18[seat]);
            self.Discards18[2].RemoveAt(self.Discards18[2].Count-1);
            self.PublicEvents.AddRange(f.State.PublicEvents.Take(f.State.PublicEvents.Count-1));
            var selfReport=evaluator.AnalyzeSelfHuContinuation(self,[11],32,717);
            Check(selfReport.Candidates.Count==2,"self-Hu unknown historic price: "+selfReport.Status);
            Check(selfReport.Candidates.Single(c=>c.Action==SichuanActionType.Hu).DrawSettlement==0,"self-Hu root collected cha-jiao");
            var discardReport=evaluator.AnalyzeContinuation(self,[11],4,32,719,includeUnready:true);
            Check(discardReport.Candidates.Count==1,"discard research still requires exited Hu price: "+discardReport.Status);
            Console.WriteLine($"DRAW_WINNER_ASSESSMENT PASS cases={rows.Count} checks={checks}; C# settlement, Hu/self-Hu/discard research, historical-price invariance");
            return 0;
        }
        catch(Exception e){Console.Error.WriteLine($"DRAW_WINNER_ASSESSMENT FAIL checks={checks}: {e}");return 1;}
    }
    private static int[] Hand(params int[] tiles){var h=new int[27];foreach(var t in tiles)h[t]++;return h;}
}
