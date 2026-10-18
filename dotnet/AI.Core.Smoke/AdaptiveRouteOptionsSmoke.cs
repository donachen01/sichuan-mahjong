using System.Text.Json;

internal static class AdaptiveRouteOptionsSmoke
{
    public static int Run(string input, string output)
    {
        int checks = 0;
        void Check(bool value, string why) { checks++; if (!value) throw new Exception(why); }
        try
        {
            using var fixtures = JsonDocument.Parse(File.ReadAllText(input));
            int cases = 0; var exposed = new int[27];
            foreach (var fixture in fixtures.RootElement.EnumerateArray())
            {
                int[] original = fixture.GetProperty("hand").EnumerateArray().Select(v => v.GetInt32()).ToArray();
                int[] originalMeld = fixture.GetProperty("exposed").EnumerateArray().Select(v => v.GetInt32()).ToArray();
                int target = fixture.GetProperty("target").GetInt32(), missing = fixture.GetProperty("missing").GetInt32();
                int groups = fixture.GetProperty("melds").GetInt32();
                int[] originalSupply = fixture.TryGetProperty("supply", out var specified)
                    ? specified.EnumerateArray().Select(v => v.GetInt32()).ToArray()
                    : Enumerable.Range(0,27).Select(t => 4-original[t]-originalMeld[t]).ToArray();
                var baseOptions = AdaptiveRouteOptionsStudy.Assess(original, originalSupply, originalMeld, groups, target, missing);
                foreach (int[] permutation in new int[][] { [0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0] })
                foreach (bool mirror in new[] { false, true })
                {
                    int Map(int t) => permutation[t/9]*9+(mirror?8-t%9:t%9);
                    var hand = new int[27]; var supply = new int[27]; var meld = new int[27];
                    for (int t=0;t<27;t++) { hand[Map(t)]=original[t]; supply[Map(t)]=originalSupply[t]; meld[Map(t)]=originalMeld[t]; }
                    var beforeHand=hand.ToArray(); var beforeSupply=supply.ToArray(); var beforeMeld=meld.ToArray();
                    var options=AdaptiveRouteOptionsStudy.Assess(hand,supply,meld,groups,permutation[target],permutation[missing]);
                    cases++;
                    Check(options.Root==baseOptions.Root,"Route distance changed under suit/rank relabelling");
                    Check(options.Draws.Select(d=>d.Tile).Order().SequenceEqual(baseOptions.Draws.Select(d=>Map(d.Tile)).Order()),"Draw support changed");
                    foreach (var d in options.Draws)
                    {
                        var drawn=hand.ToArray();drawn[d.Tile]++;
                        bool clear=d.Tile/9!=permutation[missing];
                        Check(d.Hu==(clear&&BookFlushTempoSmoke.IndependentWin(drawn,groups)),"Independent terminal Hu disagrees");
                        if(d.Hu) { Check(d.Choices.Length==0,"A legal self-Hu was replaced by an improvement discard");continue; }
                        var legal=Enumerable.Range(0,27).Where(t=>drawn[t]>0&&(clear||t==d.Tile)).ToArray();
                        Check(d.Choices.Select(c=>c.Discard).SequenceEqual(legal),"Missing/illegal concrete draw discard");
                        foreach(var c in d.Choices)
                        {
                            var after=drawn.ToArray();after[c.Discard]--;
                            Check(after.Sum()==13-3*groups,"Discard changed waiting hand size");
                            VerifyReady(after,meld,groups,permutation[missing],c.Routes.StandardShanten,c.Routes.SevenPairsShanten,Check);
                        }
                        Check(d.OrdinaryFallbackDiscards.All(t=>d.Choices.Any(c=>c.Discard==t&&c.Routes.StandardShanten==d.BestStandardShanten)),"Fallback is not a concrete optimal standard discard");
                        Check(d.JointProgressDiscards.All(t=>d.Choices.Any(c=>c.Discard==t&&c.Routes.StandardShanten<options.Root.StandardShanten&&c.Routes.FlushDistance>=0&&c.Routes.FlushDistance<options.Root.FlushDistance)),"Joint progress used different future actions");
                        var old=baseOptions.Draws.Single(x=>Map(x.Tile)==d.Tile);
                        Check(d.BestStandardShanten==old.BestStandardShanten&&d.OrdinaryFallbackDiscards.Order().SequenceEqual(old.OrdinaryFallbackDiscards.Select(Map).Order()),"Fallback changed under relabelling");
                    }
                    foreach(var claim in options.PengChannels)
                    {
                        var owned=meld.ToArray();owned[claim.OfferedTile]+=3;
                        foreach(var c in claim.Choices)
                        {
                            var after=hand.ToArray();after[claim.OfferedTile]-=2;after[c.Discard]--;
                            Check(after.Sum()==13-3*(groups+1)&&Enumerable.Range(0,27).All(t=>after[t]>=0&&after[t]+owned[t]<=4),"Peng concrete continuation violates copies/hand size");
                            Check(c.Routes.SevenPairsShanten==-2,"Peng retained closed seven-pairs route");
                            VerifyReady(after,owned,groups+1,permutation[missing],c.Routes.StandardShanten,-2,Check);
                        }
                    }
                    Check(hand.SequenceEqual(beforeHand)&&supply.SequenceEqual(beforeSupply)&&meld.SequenceEqual(beforeMeld),"Assessor mutated its caller's latest state");
                }
                var empty=AdaptiveRouteOptionsStudy.Assess(original,new int[27],originalMeld,groups,target,missing);
                Check(empty.Draws.Length==0&&empty.PengChannels.Length==0,"Exhausted unseen support fabricated options");
            }
            // Independent separation witness: six disconnected pairs + one single.
            var pairsHand=new int[27];foreach(int t in new[]{0,3,6,9,12,15})pairsHand[t]=2;pairsHand[17]=1;
            var separated=AdaptiveRouteOptionsStudy.Assess(pairsHand,Enumerable.Range(0,27).Select(t=>4-pairsHand[t]).ToArray(),exposed,0,1,2);
            Check(separated.Root.SevenPairsShanten==0&&separated.Root.StandardShanten>0,"Seven-pairs ready was relabelled ordinary ready");
            var pairWin=separated.Draws.Single(d=>d.Tile==17);
            Check(pairWin.Hu&&pairWin.WinningRoutes!.SevenPairsShanten==-1&&pairWin.WinningRoutes.StandardShanten>=0,"Seven-pairs self-Hu lost its route identity");
            File.WriteAllText(output,JsonSerializer.Serialize(new { passed=true,checks,cases,
                scope="Synthetic textbook-derived hands with declared synthetic copy supply; independent Hu/standard-vs-pairs-ready oracle, 6 suit permutations/rank reflection, same-action concrete discard/Peng choices. Not original book worlds or strength."},new JsonSerializerOptions{WriteIndented=true}));
            Console.WriteLine($"ADAPTIVE_ROUTE_OPTIONS_FOCUSED PASS checks={checks} cases={cases}");return 0;
        }
        catch(Exception e) { Console.Error.WriteLine($"ADAPTIVE_ROUTE_OPTIONS_FOCUSED FAIL checks={checks}: {e}");return 1; }
    }

    private static void VerifyReady(int[] hand,int[] exposed,int groups,int missing,int standard,int pairs,Action<bool,string> check)
    {
        bool stdReady=false,pairReady=false;
        for(int t=0;t<27;t++)
        {
            if(t/9==missing||hand[t]+exposed[t]>=4)continue;
            hand[t]++;
            bool pair=groups==0&&hand.All(n=>n%2==0);
            // The independent oracle accepts seven pairs separately. A standard
            // decomposition must be explicitly searched even when both exist.
            stdReady|=IndependentStandardWin(hand,groups);
            pairReady|=pair;hand[t]--;
        }
        check((standard==0)==stdReady,"Independent standard-ready oracle disagrees (including fifth/dead waits)");
        if(groups==0)check((pairs==0)==pairReady,"Independent seven-pairs-ready oracle disagrees");
    }

    private static bool IndependentStandardWin(int[] input,int groups)
    {
        var c=input.ToArray();
        bool Sets(int left)
        {
            int t=Array.FindIndex(c,n=>n>0);if(t<0)return left==0;if(left==0)return false;
            if(c[t]>=3){c[t]-=3;bool ok=Sets(left-1);c[t]+=3;if(ok)return true;}
            if(t%9<=6&&c[t+1]>0&&c[t+2]>0){c[t]--;c[t+1]--;c[t+2]--;bool ok=Sets(left-1);c[t]++;c[t+1]++;c[t+2]++;if(ok)return true;}
            return false;
        }
        for(int p=0;p<27;p++){if(c[p]<2)continue;c[p]-=2;bool ok=Sets(4-groups);c[p]+=2;if(ok)return true;}
        return false;
    }
}
