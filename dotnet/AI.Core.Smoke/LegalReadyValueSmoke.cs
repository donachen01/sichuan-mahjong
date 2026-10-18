using SichuanMahjong.AI.Core.Codec;
using SichuanMahjong.AI.Core.Decision;
using SichuanMahjong.AI.Core.Domain;
using SichuanMahjong.AI.Core.Entry;
using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Rules;

internal static class LegalReadyValueSmoke
{
    public static int Run()
    {
        int checks = 0;
        void Check(bool ok, string why) { checks++; if (!ok) throw new Exception(why); }
        try
        {
            foreach (int rotation in Enumerable.Range(0, 3))
            {
                int Map(int t) => (t + rotation * 9) % 27;
                var dead = Fixture(rotation, false);
                var after = dead.Hand18.ToArray(); after[Map(12)]--;
                var price = new SichuanReadyWaitPricing().Build(dead, after, new double[27]);
                Check(price is not null && price.PublicDrawableMass == 0 && price.Waits.Any(w => w.TileType == Map(4)), "oracle legal dead wait missing");
                var ranked = new SichuanUnifiedDecisionEngine().RankDiscards(dead);
                var candidate = ranked.Candidates.Single(c => c.Action.TileType == Map(12));
                var chaJiao = candidate.ReasonCodes.Single(c => c.StartsWith("CHA_JIAO_"));
                Check(double.Parse(chaJiao[9..], System.Globalization.CultureInfo.InvariantCulture) > 0,
                    "Legal dead wait lost actual cha-jiao price in unified ranking: " + chaJiao);
                Check(candidate.ReasonCodes.Contains("LEGAL_READY_DEAD_WAIT_CHA_JIAO"), "dead-wait mechanism did not reach actual candidate");
                var invalid = Fixture(rotation, true);
                after = invalid.Hand18.ToArray(); after[Map(12)]--;
                Check(new SichuanReadyWaitPricing().Build(invalid, after, new double[27]) is null, "fifth copy oracle accepts impossible wait");
                var native = new SichuanAiFacade().DecideDiscard(invalid);
                var wrong = native.Candidates.Single(c => c.TileType == Map(12));
                Check(wrong.Shanten > 0 && wrong.Reasons.Contains("STRUCTURAL_READY_NOT_LEGAL"), "actual discard still protects a fifth-copy pseudo-ready hand");
            }
            Console.WriteLine($"LEGAL_READY_VALUE PASS checks={checks}; public dead legal vs owned fifth-copy, actual ranking and facade"); return 0;
        }
        catch (Exception e) { Console.Error.WriteLine($"LEGAL_READY_VALUE FAIL checks={checks}: {e.Message}"); return 1; }
    }

    internal static SichuanStateView Fixture(int rotation, bool fifth, int currentSeat = 0)
    {
        int Map(int t) => (t + rotation * 9) % 27;
        var h = new int[27];
        foreach (int t in fifth ? new[] { 1, 2, 5, 5, 12 } : new[] { 4, 12 }) h[Map(t)]++;
        var melds = (fifth ? new[] { (0, 4), (3, 4), (8, 3) } : new[] { (0, 3), (1, 3), (2, 3), (3, 3) })
            .Select(x => new SichuanMeldView(x.Item2 == 4 ? SichuanMeldType.ConcealedGang : SichuanMeldType.Peng, Map(x.Item1), 0, 0)).ToArray();
        var visible = new int[27]; foreach (var m in melds) visible[m.TileType] += m.Type == SichuanMeldType.Peng ? 3 : 4;
        // All non-owned copies are placed in historical public zones or three
        // legal-size concealed hands; this is a synthetic physical108 endpoint.
        var pool = Enumerable.Range(0, 27).Select(t => 4 - h[t] - visible[t]).ToArray();
        var foreign = new int[27];
        for (int seat = 1; seat < 4; seat++)
        for (int i = 0; i < 13; i++)
        {
            int missing = (rotation + seat - 1) % 3;
            int t = Enumerable.Range(0, 27).Where(t => pool[t] > 0 && t / 9 != missing
                && (fifth || t != Map(4))).OrderBy(t => (t - rotation * 9 + 27) % 27).First();
            pool[t]--; foreign[t]++;
        }
        for (int t = 0; t < 27; t++) visible[t] += pool[t];
        var s = SichuanStateCodec.FromRaw(0, 0, currentSeat, 0, h, visible,
            dingQueSuits: [(rotation + 2) % 3, rotation, (rotation + 1) % 3, (rotation + 2) % 3],
            handCounts: [h.Sum(), 13, 13, 13]);
        s.MeldViews[0].AddRange(melds);
        foreach (var m in melds) s.Melds18[0].AddRange(Enumerable.Repeat(m.TileType, m.Type == SichuanMeldType.Peng ? 3 : 4));
        s.Phase = 5;
        for (int t = 0; t < 27; t++)
            if (s.Remaining18[t] != foreign[t] || h[t] + visible[t] + foreign[t] != 4)
                throw new Exception("Illegal physical108 fixture");
        return s;
    }
}
