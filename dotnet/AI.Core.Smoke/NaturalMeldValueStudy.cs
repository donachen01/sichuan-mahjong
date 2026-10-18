using System.Text.Json;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Models;

internal static class NaturalMeldValueStudy
{
    public static int Run(string input,string output)
    {
        try
        {
            using var data=JsonDocument.Parse(File.ReadAllText(input));var rows=new List<object>();var evaluator=new SichuanMeldCounterfactualEvaluator();
            foreach(var r in data.RootElement.GetProperty("rows").EnumerateArray())
            {
                if(!r.GetProperty("only_public_inputs").GetBoolean())throw new Exception("not a public-only input");
                var s=PublicPosteriorNaturalStudy.State(r.GetProperty("public_input"));var belief=new SichuanBeliefEngine().Build(s);var native=r.GetProperty("native_public_predictor");bool reaction=r.GetProperty("phase").GetInt32()==6;int offered=r.GetProperty("offered_tile_type").GetInt32();int source=r.GetProperty("offered_source_seat").GetInt32();var features=new List<object>();
                foreach(var action in r.GetProperty("legal_root_actions").EnumerateArray())
                {
                    string a=action.GetProperty("action").GetString()!;int t=action.GetProperty("tile_type").GetInt32();if(a=="baseline")continue;
                    bool hu=a is "hu" or "self_hu";bool peng=a=="peng";bool gang=a.Contains("gang");double value;double shanten=0,live=0,fan=0,structure=0,cash=0,replacementGain=0,replacementProbability=0,draws=0;
                    if(hu)
                    {
                        if(a=="hu")value=native.GetProperty("actionScores").GetProperty("hu").GetDouble()/1000.0;
                        else value=new SichuanUnifiedDecisionEngine().ConfirmSelfDrawHu(s).Candidates.First(c=>c.Action.ActionType==SichuanActionType.Hu).WinGain;
                        // Hu income is the local rule-priced value; the dedicated gang
                        // cash/structural columns stay zero for a completed winning hand.
                    }
                    else
                    {
                        string kind=a=="discard"?"continue":a=="gang"?"melded_gang":a;int tile=reaction?offered:t;int remove=peng?2:a=="gang"?3:a=="an_gang"?4:a=="add_gang"?1:0;
                        int after=s.OwnMeldCount+(peng || a is "gang" or "an_gang"?1:0);int planned=a=="discard"?t:peng && native.TryGetProperty("pengStructure",out var ps) && ps.ValueKind==JsonValueKind.Object && ps.TryGetProperty("PlannedDiscard",out var pd)?(int)pd.GetDouble():-1;
                        int gangSource=source;
                        if(a=="add_gang")gangSource=s.MeldViews[s.SeatIndex].First(m=>m.TileType==t).SourceSeat;
                        var cf=evaluator.Evaluate(s,kind,tile,remove,after,0,0,0,belief,planned,gangSource);
                        value=cf.Value;shanten=cf.Shanten;live=cf.LiveUkeire;fan=cf.ExpectedFan;structure=cf.StructuralValue;cash=cf.ImmediateGangGain;replacementGain=cf.ReplacementWinGain;replacementProbability=cf.ReplacementWinProbability;draws=cf.OwnFutureDrawBudget;
                        if(reaction && native.TryGetProperty("actionScores",out var scores) && scores.TryGetProperty(a,out var actual))value=actual.GetDouble()/(scores.TryGetProperty("hu",out _)?1000.0:100.0);
                    }
                    double w=s.WallCount/108.0;double[] vector=[value/8,shanten/3,live/20,fan/4,structure/8,cash/8,replacementGain/16,replacementProbability,draws/12,hu?1:0,peng?1:0,gang?1:0,w*(hu?1:0),w*(peng?1:0),w*(gang?1:0)];
                    features.Add(new{action=a,tile_type=t,vector,local_heuristic_value=value,shanten,live_ukeire=live,expected_fan=fan,certain_rule_cash=cash,not_calibrated_full_game_value=true});
                }
                rows.Add(new{input_sha256=r.GetProperty("input_sha256").GetString(),seed=r.GetProperty("seed").GetInt32(),seat=s.SeatIndex,opponent=r.GetProperty("opponent").GetString(),features,allows_ron_refusal=SichuanStrategyContract.Assess(s).AllowsRonRefusal,only_public_inputs_read=true});
            }
            File.WriteAllText(output,JsonSerializer.Serialize(new{origin="public_only_current_core_meld_descriptors_before_fit",rows},new JsonSerializerOptions{WriteIndented=true}));Console.WriteLine($"NATURAL_MELD_VALUE public nodes={rows.Count}; actual future labels not opened");return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
    }
}
