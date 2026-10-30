"""Independent suit-local disjoint shape packing, then whole-hand composition.
Computes ordinary shanten separately from seven-pairs/value improvements.
"""
from functools import lru_cache
from pathlib import Path
import itertools,json,sys
D=Path(__file__).resolve().parent

@lru_cache(None)
def suit_shapes(a):
    if not any(a):return frozenset([(0,0,0)])
    i=next(k for k,v in enumerate(a) if v);out=set()
    def take(indices,increment):
        b=list(a)
        for k in indices:
            b[k]-=1
            if b[k]<0:return
        for v in suit_shapes(tuple(b)):
            w=tuple(v[k]+increment[k] for k in range(3))
            if w[0]<=4 and w[1]<=4 and w[2]<=1:out.add(w)
    take([i],(0,0,0))
    if a[i]>=3:take([i]*3,(1,0,0))
    if i<=6 and a[i+1] and a[i+2]:take([i,i+1,i+2],(1,0,0))
    if a[i]>=2:
        take([i]*2,(0,1,0));take([i]*2,(0,0,1))
    for delta in (1,2):
        if i+delta<9 and a[i+delta]:take([i,i+delta],(0,1,0))
    return frozenset(out)

@lru_cache(None)
def shanten(a,mc):
    best=8
    for xs in itertools.product(*(suit_shapes(a[s*9:s*9+9]) for s in range(3))):
        m=mc+sum(x[0] for x in xs);t=sum(x[1] for x in xs);p=sum(x[2] for x in xs)
        if m<=4 and p<=1:best=min(best,8-2*m-min(t,4-m)-p)
    return best

if __name__=='__main__':
    folder=D/sys.argv[1];rows=[];queries={}
    def calc(h,mc):
        v=shanten(tuple(h),mc);queries[(tuple(h),mc)]=v;return v
    for r in json.loads((folder/'structures.json').read_text()):
        h=r['hand'];mc=len(r['melds']);ex=r['exposed']
        options=[t for t,n in enumerate(h) if n] if sum(h)%3==2 else [-1]
        for discard in options:
            a=h[:]
            if discard>=0:a[discard]-=1
            before=calc(a,mc);useful=[]
            for draw in range(27):
                copies=4-h[draw]-ex[draw]
                if draw//9==r['dq'] or copies<=0:continue
                b=a[:];b[draw]+=1
                if calc(b,mc)<before:useful.append({'tile':draw,'copies':copies})
            rows.append({'id':r['id'],'discard':discard,'ordinary_shanten':before,
                         'effective':useful,'kind_count':len(useful),'copies':sum(x['copies'] for x in useful)})
    (folder/'progress-independent.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
    q=[{'hand':list(h),'meld_count':m,'expected':v} for (h,m),v in queries.items()]
    (folder/'progress-oracle.json').write_text(json.dumps(q)+'\n')
    print('PROGRESS',len(rows),'candidates',len(q),'unique ordinary-distance states')
