"""Independent legal meld continuations; exhaustive local math, not optimal EV.
No production evaluator is imported. Replacement draws and subsequent discards
are alternatives, not known future events or summable independent benefits.
"""
import json,sys,math
from pathlib import Path
from collections import Counter
from independent import get_waits,decompose,score,save,label
from progress import shanten
D=Path(__file__).resolve().parent
section=sys.argv[1];folder=D/section;out=folder/'meld-math';out.mkdir(exist_ok=True)
oracle=[];records=[]
for c in json.loads((folder/'cases.json').read_text()):
    if c['id'].endswith('public-loss'):continue
    h=c['hand'];ex=c['exposed'];mc=len(c['melds']);known=Counter(c['known'])
    actions=[]
    if 'offered' in c:
        t=c['offered']
        if h[t]>=2:actions.append(('peng',t,2,3))
        if h[t]>=3:actions.append(('gang',t,3,4))
    else:
        actions += [('an_gang',t,4,4) for t in range(27) if h[t]==4]
        actions += [('add_gang',t,1,1) for t in range(27) if h[t] and ex[t]==3]
    for action,t,remove,add in actions:
        a=h[:];a[t]-=remove;e=ex[:];e[t]+=add
        m=mc+(action!='add_gang')
        rem=[4-a[k]-e[k]-known[k] for k in range(27)]
        assert min(rem)>=0
        draws=[-1] if action=='peng' else [k for k,n in enumerate(rem) if n>0]
        branches=[]
        for draw in draws:
            b=a[:];supply=rem[:]
            if draw>=0:b[draw]+=1;supply[draw]-=1
            immediate=bool(decompose(b,m,m==0)) and not any(b[k] for k in range(c['dq']*9,c['dq']*9+9))
            candidates=[]
            forced=any(b[k] for k in range(c['dq']*9,c['dq']*9+9))
            for discard,n in enumerate(b):
                if not n or forced and discard//9!=c['dq']:continue
                post=b[:];post[discard]-=1
                ws=get_waits(post,e,m,supply)
                if any(post[k] for k in range(c['dq']*9,c['dq']*9+9)):ws=[]
                # exact analyzer ignores dingque; its math oracle is deliberately
                # structural, while the summary below enforces missing suit.
                ew=get_waits(post,e,m,supply)
                oid=f"{c['id']}/{action}{t}/draw{draw}/discard{discard}"
                oracle.append({'id':oid,'hand':post,'exposed':e,'meld_count':m,'remaining':supply,'expected':ew})
                candidates.append({'discard':discard,'ordinary_shanten':shanten(tuple(post),m),
                    'waits':[{**w,'label':label(w['tile'])} for w in ws],
                    'live_copies':sum(w['copies'] for w in ws)})
            branches.append({'draw':draw,'draw_copy_upper_bound':rem[draw] if draw>=0 else None,
                             'immediate_hu':immediate,'candidates':candidates})
        records.append({'id':c['id'],'action':action,'tile':t,'fixed_melds_after':m,
                        'branches':branches,'assumption':'unknown public counts zero except declared known; not wall probability'})
save(out/'oracle.json',oracle);save(out/'branches.json',records)
save(out/'probability-illustration.json',[{'unknown_pool':n,'scheduled_draws':d,'success_copies':k,
    'p_at_least_one':1-math.comb(n-k,d)/math.comb(n,d),
    'condition':'uniform exchangeable physical copies; no exit/claim; illustrative not original table'}
    for n,d in [(48,3),(70,3),(48,6)] for k in [4,6,8,18]])
print('MELD',len(records),'actions',len(oracle),'post-discard wait/price contexts')
