namespace SichuanMahjong.AI.Core.Decision;

/// <summary>Approved chapter 4.2.2 eligibility ceilings, not profitability.
/// Round eight belongs to the late band. A printed 1–2 is a ceiling of two;
/// the current income/cost assessment may always cash out earlier.</summary>
public static class SichuanConcealedTripletHuTable
{
    public static int Distinct(int live, int round, int danger, int independent)
    {
        var n=Math.Clamp(independent,0,2);
        if(danger>=2)return 0;
        if(live>=10)return round<8 ? new[]{2,2,int.MaxValue}[n] : new[]{0,1,2}[n];
        if(live>=7)return danger>0 ? new[]{0,0,1}[n]
            : round<8 ? new[]{1,2,int.MaxValue}[n] : new[]{0,1,1}[n];
        if(live>=5)return danger>0 ? 0 : round<8 ? new[]{0,1,int.MaxValue}[n] : new[]{0,0,1}[n];
        // The source's <=4 row is normal conditions only. Do not make a
        // narrower wait greedier than its 5–6/general-danger neighbour.
        return live>0&&danger==0 ? new[]{0,0,1}[n] : 0;
    }

    public static int TwoMissing(int live,int round,int danger,int sameSuitIndependent)
    {
        var n=Math.Clamp(sameSuitIndependent,0,2);
        if(danger>=2)return 0;
        if(live>=8)return round<8 ? new[]{2,int.MaxValue,int.MaxValue}[n] : new[]{0,1,2}[n];
        if(live>=6)return danger>0 ? new[]{0,0,1}[n]
            : round<8 ? new[]{1,2,int.MaxValue}[n] : new[]{0,0,1}[n];
        return live>0&&danger==0 ? new[]{0,0,1}[n] : 0;
    }

    public static (int Cap,string Goal) WideBed(int live,int danger,int sameSuitIndependent)
    {
        var n=Math.Clamp(sameSuitIndependent,0,2);
        if(live<=0||danger>=2)return (0,"take_hu");
        if(live>=5)return (danger==0||n>=1?int.MaxValue:2,"wait_self_draw");
        if(live>=3)return (danger==0?int.MaxValue:new[]{0,2,int.MaxValue}[n],"wait_self_draw");
        if(danger==0)return n>0?(int.MaxValue,"wait_live_gang"):(0,"take_hu");
        // Remaining excludes the offered tile. Zero future effective copies
        // means the present legal Ron is the last copy and must be taken.
        return n>=2?(int.MaxValue,"wait_last_copy"):(0,"take_hu");
    }
}
