using SichuanMahjong.AI.Core.Models;
using SichuanMahjong.AI.Core.Engines;
using SichuanMahjong.AI.Core.Strategy;

namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Source 6.3/6.4 conditional development proposal to the one arbiter.
/// No self-Hu/Gang permissions are bypassed, and hard defense keeps priority.</summary>
public static class SichuanFlushDevelopmentPolicy
{
    public static SichuanCourseTempoChoice? Select(SichuanStateView s,
        IReadOnlyList<SichuanCandidateDetail> candidates,int incumbent)
    {
        if(s.InformationMode!="public"||s.WallCount<16||s.OwnDingQueSuit is <0 or >2
            ||s.Hand18.Skip(s.OwnDingQueSuit*9).Take(9).Any(n=>n>0)
            ||SichuanDistinctDingQueHuPolicy.AssessDanger(s,new())!=0)return null;
        var current=candidates.First(c=>c.TileType==incumbent);
        if(current.Shanten<=0)return null;
        int target=Enumerable.Range(0,3).Where(x=>x!=s.OwnDingQueSuit)
            .OrderByDescending(x=>s.Hand18.Skip(x*9).Take(9).Sum()+s.Melds18[s.SeatIndex].Count(t=>t/9==x)).First();
        var shape=SichuanFlushSkeletonEngine.Analyze(s,target);
        if(shape.TwiceBlocks<9)return null;
        int suppliers=Enumerable.Range(0,4).Count(seat=>seat!=s.SeatIndex&&s.ActiveSeats[seat]&&!s.HasHu[seat]&&s.DingQueSuits[seat]==target);
        var exposed=new int[27];
        foreach(var m in SichuanFlushCopyCapacity.OwnMeldCopies(s))exposed[m.Tile]+=m.Copies;
        var reach=new SichuanFlushStructureEngine();
        bool NearReady(SichuanCandidateDetail c)
        {
            var h=s.Hand18.ToArray();h[c.TileType]--;
            var geometry=reach.Analyze(h,s.Remaining18,exposed,target,s.OwnMeldCount);
            return geometry.FeasiblePatterns>0&&geometry.MinimumAdditionalTiles<=2;
        }
        var choices=candidates.Where(c=>c.TileType/9!=target&&c.TileType/9!=s.OwnDingQueSuit
            &&c.ExpectedDealInLoss<=current.ExpectedDealInLoss+0.10&&c.Danger<42)
            .Where(c=>shape.TwiceBlocks>=10&&suppliers>=2&&s.WallCount>=28
                ?c.Shanten<=current.Shanten+1
                :c.Shanten<=current.Shanten&&c.LiveUkeire+1>=current.LiveUkeire
                    ||suppliers>=2&&s.WallCount>=20&&NearReady(c)&&c.Shanten<=current.Shanten+1)
            .OrderBy(c=>c.Shanten).ThenByDescending(c=>c.UnifiedActionValue).ThenByDescending(c=>c.LiveUkeire).ThenBy(c=>c.TileType).ToArray();
        if(choices.Length==0||choices[0].TileType==incumbent)return null;
        var chosen=choices[0];
        return new(chosen.TileType,"FLUSH_DISJOINT_BLOCKS_CONDITIONAL_INVESTMENT",[
            $"清色互斥拆分 {shape.Blocks:F1} 手；独立对子 {shape.PairBlocks} 组，定缺供牌者 {suppliers} 家",
            shape.TwiceBlocks>=10&&suppliers>=2&&s.WallCount>=28
                ?"早段五搭及供给支持，允许有限速度投资；首打处于低危险区且新增估计失分不超过0.10底"
                :"清色与普通退路同距且有效进张损失至多一张，不以一色张数强行承诺",
            "FLUSH_BLOCKS_ARE_STRUCTURE_NOT_GUARANTEED_SUPPLY_OR_EXPECTED_INCOME"]);
    }
    public static bool SupportsClaim(SichuanStateView s,int tile,int source,int discard)
    {
        if(discard<0||s.WallCount<20||SichuanDistinctDingQueHuPolicy.AssessDanger(s,new())!=0
            ||new SichuanShantenEngine().CalcLegalShanten(s.Hand18,s.OwnMeldCount,s.OwnDingQueSuit)<=0)return false;
        int target=tile/9;
        int suppliers=Enumerable.Range(0,4).Count(seat=>seat!=s.SeatIndex&&s.ActiveSeats[seat]&&!s.HasHu[seat]&&s.DingQueSuits[seat]==target);
        if(suppliers<2||discard/9==target)return false;
        var hand=s.Hand18.ToArray();hand[tile]-=2;
        var claim=SichuanUnifiedDecisionEngine.ProjectPengContinuation(s,hand,tile,source);
        if(SichuanFlushSkeletonEngine.Analyze(claim,target).TwiceBlocks<9)return false;
        hand=hand.ToArray();hand[discard]--;
        var exposed=new int[27];foreach(var m in SichuanFlushCopyCapacity.OwnMeldCopies(claim))exposed[m.Tile]+=m.Copies;
        var structure=new SichuanFlushStructureEngine().Analyze(hand,claim.Remaining18,exposed,target,claim.OwnMeldCount);
        var beforeExposed=new int[27];foreach(var m in SichuanFlushCopyCapacity.OwnMeldCopies(s))beforeExposed[m.Tile]+=m.Copies;
        var before=new SichuanFlushStructureEngine().Analyze(s.Hand18,s.Remaining18,beforeExposed,target,s.OwnMeldCount);
        var shape=SichuanFlushSkeletonEngine.Analyze(claim,target);
        bool supported=structure.FeasiblePatterns>0&&before.FeasiblePatterns>0
            &&structure.RequiredInEveryNearestPattern.All(t=>claim.Remaining18[t]>=2)
            &&(structure.MinimumAdditionalTiles<before.MinimumAdditionalTiles
                ||shape.TwiceBlocks>=10&&structure.MinimumAdditionalTiles<=before.MinimumAdditionalTiles);
        return supported&&new SichuanDangerEngine().EvaluateDetail(discard,s,new SichuanBeliefEngine().Build(s)).Risk<42;
    }

    public static bool CreatesNewBottleneck(SichuanStateView s,int tile,int source,int discard)
    {
        if(s.OwnMeldCount<1||s.WallCount<20||discard<0||discard/9==tile/9
            ||new SichuanShantenEngine().CalcLegalShanten(s.Hand18,s.OwnMeldCount,s.OwnDingQueSuit)<=0)return false;
        var h=s.Hand18.ToArray();h[tile]-=2;
        var p=SichuanUnifiedDecisionEngine.ProjectPengContinuation(s,h,tile,source);h=h.ToArray();h[discard]--;
        var beforeEx=new int[27];foreach(var m in SichuanFlushCopyCapacity.OwnMeldCopies(s))beforeEx[m.Tile]+=m.Copies;
        var afterEx=new int[27];foreach(var m in SichuanFlushCopyCapacity.OwnMeldCopies(p))afterEx[m.Tile]+=m.Copies;
        var engine=new SichuanFlushStructureEngine();
        var before=engine.Analyze(s.Hand18,s.Remaining18,beforeEx,tile/9,s.OwnMeldCount);
        var after=engine.Analyze(h,p.Remaining18,afterEx,tile/9,p.OwnMeldCount);
        return before.FeasiblePatterns>0&&after.FeasiblePatterns>0
            &&before.MinimumAdditionalTiles<=3&&after.MinimumAdditionalTiles>=2
            &&after.RequiredInEveryNearestPattern.Any(t=>p.Remaining18[t]<=1
                &&(!before.RequiredInEveryNearestPattern.Contains(t)||s.Remaining18[tile]==0));
    }

}
