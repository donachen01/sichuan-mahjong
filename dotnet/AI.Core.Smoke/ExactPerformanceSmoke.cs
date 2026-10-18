using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Rules;
internal static class ExactPerformanceSmoke
{
    public static int Run()
    {
        var random=new Random(731);var engine=new SichuanShantenEngine();var exact=new SichuanExactHandAnalyzer();
        var method=typeof(SichuanShantenEngine).GetMethod("Search",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Static)!;
        var original=typeof(SichuanExactHandAnalyzer).GetMethod("EnumerateWinningDecompositionsUnfiltered",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance)!;
        IReadOnlyList<SichuanHandDecomposition> Reference(int[] hand,int melds,bool pairs=true) =>
            (IReadOnlyList<SichuanHandDecomposition>)original.Invoke(exact,[hand,melds,pairs])!;
        string Describe(IReadOnlyList<SichuanHandDecomposition> items) =>
            string.Join("|",items.Select(item => item.IsSevenPairs+":"+string.Join(",",item.Groups)));
        for(var sample=0;sample<12000;sample++)
        {
            var melds=sample%5;var hand=new int[27];
            for(var n=0;n<14-melds*3-(sample%2);n++){var tile=random.Next(27);if(hand[tile]==4){n--;continue;}hand[tile]++;}
            object[] args={(int[])hand.Clone(),0,melds,0,0,8};method.Invoke(null,args);
            var before=Math.Max(-1,(int)args[5]);var after=engine.CalcStandardShanten(hand,melds);
            if(before!=after)throw new Exception($"distance disagreement {sample}: {before}/{after}");
            if(sample<2000 && exact.IsWinning(hand,melds)!= (Reference(hand,melds).Count>0))throw new Exception("winning predicate disagreement");
            if(sample<2000 && Describe(exact.EnumerateWinningDecompositions(hand,melds))!=Describe(Reference(hand,melds)))throw new Exception("filtered decomposition disagreement");
        }
        // Construct completions so the filter is checked against many positive
        // cases, including exposed melds; uniform random hands rarely win.
        for(var sample=0;sample<2000;sample++)
        {
            var melds=sample%5;var hand=new int[27];
            var pair=random.Next(27);hand[pair]=2;
            for(var group=0;group<4-melds;group++)
            {
                var tile=random.Next(27);
                if(random.Next(2)==0) hand[tile]+=3;
                else { tile=tile/9*9+random.Next(7);hand[tile]++;hand[tile+1]++;hand[tile+2]++; }
            }
            if(hand.Any(n=>n>4)) {sample--;continue;}
            foreach(var pairs in new[]{false,true})
            {
                if(Describe(exact.EnumerateWinningDecompositions(hand,melds,pairs))!=Describe(Reference(hand,melds,pairs)))
                    throw new Exception("constructed completion disagreement");
                var removed=Array.FindIndex(hand,n=>n>0);hand[removed]--;
                var remaining=Enumerable.Range(0,27).Select(t=>random.Next(5)).ToArray();
                var expected=new List<string>();
                for(var draw=0;draw<27;draw++)
                {
                    if(hand[draw]>=4 || remaining[draw]==0)continue;
                    hand[draw]++;var decompositions=Reference(hand,melds,pairs);hand[draw]--;
                    if(decompositions.Count>0)expected.Add(draw+":"+remaining[draw]+":"+Describe(decompositions));
                }
                var actual=exact.EnumerateWaits(hand,remaining,melds,pairs)
                    .Select(w=>w.TileType+":"+w.LiveCount+":"+Describe(w.Decompositions));
                if(string.Join("|",actual)!=string.Join("|",expected))throw new Exception("wait decomposition disagreement");
                hand[removed]++;
            }
        }
        // Deliberately include winning hands; uniformly random hands rarely win.
        foreach(var tiles in new int[][] { [0,1,2,3,4,5,9,10,11,15,16,17,18,18],
            [0,0,0,0,2,2,4,4,9,9,11,11,18,18], [0,0,0,1,1,1,9,9,9,18,18,18,20,20] })
        {
            var hand=new int[27];foreach(var t in tiles)hand[t]++;
            foreach(var pairs in new[]{false,true})
                if(exact.IsWinning(hand,0,pairs)!=(Reference(hand,0,pairs).Count>0)
                    || Describe(exact.EnumerateWinningDecompositions(hand,0,pairs)) != Describe(Reference(hand,0,pairs)))
                    throw new Exception("winning fixture disagreement");
        }
        Console.WriteLine("EXACT_PERFORMANCE PASS 12000 distances, 2000 winning predicates, 2000 constructed completions and their waits agree with original enumerators");return 0;
    }
}
