using SichuanMahjong.AI.Core.Agents;
using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;

internal static class StrategyDeliverySmoke
{
    public static int Run()
    {
        try
        {
            void Check(bool ok,string label) { if (!ok) throw new Exception(label); }
            var hand = new int[27]; foreach(var t in new[]{0,1,2,3,4,6,7,9,10,11,13,14,16,18}) hand[t]++;
            var view=SichuanStateCodec.FromRaw(0,0,0,55,hand,new int[27],dingQueSuits:[2,0,1,2]);
            view.RoundId="delivery";view.HostGeneration=1;view.ViewVersion=1;
            var live=new SichuanAiFacade();live.Agents.Begin([view]);
            var action=live.DecideDiscard(view);
            var snapshot=live.Agents.Inspect(view);
            Check(snapshot.Decisions.Length==0,"production retained research trace");
            Check(snapshot.Proposal?.Tile==action.Action.TileType && snapshot.Plan is not null,"recording disabled necessary agent memory");
            try { live.Agents.ResearchRecordingEnabled=true; throw new Exception("active recording mode changed"); }
            catch(InvalidOperationException) { }
            var after=(int[])hand.Clone();after[action.Action.TileType]--;
            var observed=SichuanStateCodec.FromRaw(0,0,0,55,after,new int[27],dingQueSuits:[2,0,1,2]);
            observed.RoundId=view.RoundId;observed.HostGeneration=1;observed.ViewVersion=2;
            observed.PublicEvents.Add(new(1,1,0,SichuanPublicEventType.Discard,action.Action.TileType));
            live.Agents.Observe(observed);
            Check(live.Agents.Inspect(observed).Proposal?.Status=="executed" && live.Agents.Inspect(observed).Decisions.Length==0,"production authoritative confirmation lost");
            live.Agents.End(view.RoundId,1);
            live.Agents.ResearchRecordingEnabled=true;view.HostGeneration=2;live.Agents.Begin([view]);
            live.DecideDiscard(view);Check(live.Agents.Inspect(view).Decisions.Length==1,"research trace missing");
            var gate=new SichuanDiscardArbiter([1,2,3],1);
            Check(gate.TrySelect(2,SichuanDiscardArbiter.ExtremeSafety,"safety"),"safety rejected");
            Check(!gate.TrySelect(3,SichuanDiscardArbiter.GlobalPlan,"development") && gate.SelectedTile==2,"development overrode safety");
            Check(!gate.TrySelect(3,SichuanDiscardArbiter.SafeReadySettlement,"keep_ready"),"ready heuristic overrode hard safety");
            Check(!gate.TrySelect(26,999,"illegal"),"illegal proposal accepted");
            var random=new Random(20261002);int bucket=0,blocked=0;
            for(int i=0;i<120;i++)
            {
                var h=new int[27];while(h.Sum()<14) {var t=random.Next(18);if(h[t]<4)h[t]++;}
                var state=SichuanStateCodec.FromRaw(0,0,0,i%3==0?4:55,h,new int[27],dingQueSuits:[2,0,1,2]);
                state.PolicyVariant="bucket_local_candidate_v1";
                var result=new SichuanDecisionEngine().DecideDiscard(state);
                Check(h[result.Action.TileType]>0,"illegal actual decision");
                Check(result.Arbitration.Count==0 || result.Arbitration.Last(a=>a.Accepted).ProposedTile==result.Action.TileType,"final arbitration mismatch");
                var acceptedPriority=0;
                foreach(var a in result.Arbitration)
                {
                    if(a.Accepted) {Check(a.Priority>=acceptedPriority,"priority inversion");acceptedPriority=a.Priority;}
                    else blocked++;
                }
                if(result.Reasons.Contains("BUCKET_LOCAL_DOMINANCE")) {bucket++;Console.WriteLine($"BUCKET_CAUSAL case={i} hand={string.Join(',',h)} tile={result.Action.TileType}");}
            }
            Console.WriteLine($"STRATEGY_DELIVERY passed production_memory/research_trace/legality/priority; actual_states=120 bucket_final={bucket} blocked={blocked}");
            return 0;
        }
        catch(Exception e) {Console.Error.WriteLine(e);return 1;}
    }
}
