"""Book reread arithmetic. No production imports and no stored action labels.

Group packing enumerates multisets of complete groups, then subtracts the
chosen pair. It intentionally does not call the production shanten/analyzer.
This is a scoped study helper, not a CI or standing regression list.
"""
from collections import Counter
from functools import lru_cache
from pathlib import Path
import hashlib, json, sys

D=Path(__file__).resolve().parent
ROOT=D.parents[2]
OLD=D.parent/'lower-completion-20261023'

def save(p,x):
    p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')

def parse(text):
    a=[0]*27
    for group in text.split():
        for rank in group[1:]: a[{'s':0,'p':9,'m':18}[group[0]]+int(rank)-1]+=1
    return a

def label(t): return '条筒万'[t//9]+str(t%9+1)

@lru_cache(None)
def pack(a,n,lower=0):
    if sum(a)!=3*n:return ()
    if n==0:return ((),) if not any(a) else ()
    result=[]
    # Candidate groups are ordered by (type,start); combinations, not ordered
    # partitions, avoid counting permutations as different decompositions.
    for code in range(lower,54):
        kind,t=divmod(code,27)
        indices=(t,t,t) if kind==0 else (t,t+1,t+2)
        if kind==1 and t%9>6:continue
        need=Counter(indices)
        if any(a[i]<v for i,v in need.items()):continue
        b=list(a)
        for i,v in need.items():b[i]-=v
        for suffix in pack(tuple(b),n-1,code):
            result.append(((2 if kind==0 else 1,t),)+suffix)
    return tuple(result)

def decompose(a,meld_count=0,seven=True):
    if sum(a)+3*meld_count!=14 or any(n<0 or n>4 for n in a):return []
    result=[]
    for pair,n in enumerate(a):
        if n<2:continue
        b=list(a);b[pair]-=2
        for groups in pack(tuple(b),4-meld_count):
            result.append(('N',tuple(sorted(((0,pair),)+groups))))
    if seven and not meld_count and all(n%2==0 for n in a):
        groups=tuple((0,t) for t,n in enumerate(a) for _ in range(n//2))
        if len(groups)==7:result.append(('S',groups))
    return result

def key(d):return d[0]+':'+'|'.join(f'{k}:{t}' for k,t in sorted(d[1]))

def score(completed,ex,melds,ds):
    owned=[completed[t]+ex[t] for t in range(27)]
    qing=len({t//9 for t,n in enumerate(owned) if n})==1
    seven=any(k=='S' for k,_ in ds)
    triplets=any(k=='N' and all(g!=1 for g,_ in groups) for k,groups in ds)
    dragon=seven and any(n==4 for n in completed)
    jing=melds==4
    jiang=triplets and all(t%9 in (1,4,7) for t,n in enumerate(owned) if n)
    shiba=melds==4 and sum(n==4 for n in ex)==4
    base=4 if shiba or qing and (seven or jing) else 3 if jiang or qing and triplets or dragon else 2 if qing or seven or jing else 1 if triplets else 0
    roots=sum(n==4 for n in owned)-int(dragon)
    fan=min(4,base+roots)
    return {'base_fan':base,'roots':roots,'fan':fan,'hand_score':2**fan,'self_per_payer':2**fan+1}

def waits(a,ex=None,remaining=None):
    ex=ex or [0]*27
    melds=sum(ex)//3
    # callers with a gang pass the true group count separately below
    return get_waits(a,ex,melds,remaining)

def get_waits(a,ex,melds,remaining=None):
    remaining=remaining if remaining is not None else [4-a[t]-ex[t] for t in range(27)]
    result=[]
    for t in range(27):
        if a[t]+ex[t]>=4 or remaining[t]<=0:continue
        b=a[:];b[t]+=1
        ds=decompose(b,melds,melds==0)
        if ds:result.append({'tile':t,'copies':remaining[t],'keys':sorted(set(map(key,ds))),
                             'heads':sorted({u for kind,g in ds if kind=='N' for k,u in g if k==0}),
                             'score':score(b,ex,melds,ds)})
    return result

def transform(a,suit,mirror):
    out=[0]*27
    for t,n in enumerate(a):
        out[((t//9+suit)%3)*9+(8-t%9 if mirror else t%9)]=n
    return out

def source_section(section):
    data=json.loads((OLD/'structures.json').read_text())
    return [r for r in data if r['section']==section]

def exact(section):
    out=D/section;out.mkdir(exist_ok=True)
    source=source_section(section)
    oracle=[]; summaries=[]; invariant_checks=0
    for r in source:
        for row in r['rows']:
            a=r['hand'][:]
            if row['discard']>=0:a[row['discard']]-=1
            ex=r['exposed'];melds=len(r['melds'])
            known=[0]*27
            if row['discard']>=0:known[row['discard']]=1
            supply=[4-a[t]-ex[t]-known[t] for t in range(27)]
            ws=get_waits(a,ex,melds,supply)
            summaries.append({'id':r['id'],'discard':row['discard'],'hand':a,'meld_count':melds,
                'waits':[{**w,'label':label(w['tile'])} for w in ws],
                'structural_waits':get_waits(a,ex,melds),
                'wait_kind_count':len(ws),'unseen_copy_upper_bound':sum(w['copies'] for w in ws)})
            for suit in range(3):
                for mirror in (False,True):
                    h=transform(a,suit,mirror);e=transform(ex,suit,mirror)
                    k=transform(known,suit,mirror)
                    rem=[4-h[t]-e[t]-k[t] for t in range(27)]
                    expected=get_waits(h,e,melds,rem)
                    oracle.append({'id':f"{r['id']}/d{row['discard']}/s{suit}/m{int(mirror)}",
                        'hand':h,'exposed':e,'meld_count':melds,'remaining':rem,'expected':expected})
                    for w in expected:
                        # Changing public supply removes the draw route, without
                        # changing the structural decomposition of the hand.
                        zero=rem[:];zero[w['tile']]=0
                        oracle.append({'id':oracle[-1]['id']+'/dead'+str(w['tile']),
                            'hand':h,'exposed':e,'meld_count':melds,'remaining':zero,
                            'expected':[v for v in expected if v['tile']!=w['tile']]})
                        for head in w['heads']:
                            weighted=sum((t%9+1)*n for t,n in enumerate(h))+(w['tile']%9+1)
                            assert (weighted-2*(head%9+1))%3==0
                            invariant_checks+=1
    save(out/'source-exact.json',summaries)
    save(out/'oracle.json',oracle)
    save(out/'independent-summary.json',{'section':section,'source_rows':len(summaries),
        'oracle_contexts':len(oracle),'mod3_witness_checks':invariant_checks,
        'method':'independent unordered group multiset exact cover; legal four-copy constraint',
        'not_blind':True,'failures':[]})
    save(out/'structures.json',[r for r in source])
    # Existing source hand transcription is reused only after original-page
    # visual review. New full backgrounds are explicitly constructed.
    cases=[r for r in json.loads((OLD/'cases.json').read_text()) if r['section']==section]
    if section=='6.1':
        expanded=[]
        for c in cases:
            base=c['hand'][:];base[c['draw']]-=1
            ex=c['exposed'];melds=len(c['melds'])
            for w in get_waits(base,ex,melds):
                a=base[:];a[w['tile']]+=1
                expanded.append({**c,'id':c['id']+'/wait-'+str(w['tile']),
                    'hand':a,'draw':w['tile'],'note':c['note']+'; declared current draw, not original history'})
        cases=expanded
    save(out/'cases.json',cases)
    print(json.dumps({'section':section,'source_rows':len(summaries),'oracle_contexts':len(oracle),
        'formal_cases':len(cases),'mod3_witness_checks':invariant_checks}))

if __name__=='__main__':exact(sys.argv[1])
