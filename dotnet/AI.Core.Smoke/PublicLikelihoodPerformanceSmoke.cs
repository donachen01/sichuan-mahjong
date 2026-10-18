using SichuanMahjong.AI.Core.Domain;

using System.Reflection;
using SichuanMahjong.AI.Core.Inference;
using SichuanMahjong.AI.Core.Models;

internal static class PublicLikelihoodPerformanceSmoke
{
    public static int Run()
    {
        var type = typeof(SichuanHiddenHandInferenceEngine);
        var flags = BindingFlags.Static | BindingFlags.NonPublic;
        var prepare = type.GetMethod("PreparePublicLikelihood", flags)!;
        var fast = type.GetMethod("PreparedPublicHandLogLikelihood", flags)!;
        var original = type.GetMethod("PublicHandLogLikelihood", flags)!;
        var random = new Random(41971);
        var comparisons = 0;
        for (var example = 0; example < 200; example++)
        {
            var state = RepresentativeHuSmoke.Book([18,18,19,20,21,24,25,26,12,13,14,15,16],[0,1,1,0]);
            state.PublicEvents.Clear();
            for (var i = 0; i < example % 53; i++)
                state.PublicEvents.Add(new SichuanPublicEvent(i+1,i,random.Next(4),
                    i%3==0 ? SichuanPublicEventType.Pass : SichuanPublicEventType.Discard,
                    random.Next(27), CanPeng: i%2==0, CanGang: i%4==0,
                    Origin: i%2==0 ? SichuanTileOrigin.Hand : SichuanTileOrigin.Unknown));
            for (var seat = 0; seat < 4; seat++)
            {
                state.Melds18[seat].Clear();
                for(var m=0;m<example%4;m++) state.Melds18[seat].AddRange(Enumerable.Repeat(random.Next(27),3));
                var evidence = prepare.Invoke(null,[state,seat])!;
                for(var sample=0;sample<16;sample++)
                {
                    var hand = new int[27];
                    for(var draw=0;draw<13;draw++) { int tile; do {tile=random.Next(27);} while(hand[tile]==4); hand[tile]++; }
                    var expected = (double)original.Invoke(null,[state,seat,hand])!;
                    var actual = (double)fast.Invoke(null,[evidence,hand])!;
                    if(BitConverter.DoubleToInt64Bits(expected)!=BitConverter.DoubleToInt64Bits(actual))
                        throw new Exception($"likelihood mismatch {example}/{seat}/{sample}: {expected:R}/{actual:R}");
                    comparisons++;
                }
            }
        }
        var shapeType = typeof(SichuanMahjong.AI.Core.Engines.SichuanHandShapeEngine);
        var cachedShape = shapeType.GetMethod("EnumerateMutuallyExclusiveProfiles", flags)!;
        var originalShape = shapeType.GetMethod("EnumerateMutuallyExclusiveProfilesUncached", flags)!;
        for (var i=0;i<1000;i++)
        {
            var melds = i%5;
            var hand = new int[27];
            for(var draw=0;draw<13-3*melds;draw++) {int tile; do{tile=random.Next(27);}while(hand[tile]==4);hand[tile]++;}
            string Describe(object value) => string.Join("|", ((System.Collections.IEnumerable)value).Cast<object>().Select(x=>x.ToString()));
            var expected = Describe(originalShape.Invoke(null,[hand,melds])!);
            for(var repeat=0;repeat<2;repeat++)
                if(Describe(cachedShape.Invoke(null,[hand,melds])!)!=expected) throw new Exception("shape cache mismatch");
        }
        Console.WriteLine("SHAPE_PROFILE_CACHE PASS 1000 hands, cold and cached results equal");
        Console.WriteLine($"PUBLIC_LIKELIHOOD PASS {comparisons} bit-exact comparisons across seats, history windows, melds and passes");
        return 0;
    }
}
