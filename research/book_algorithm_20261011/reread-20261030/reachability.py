"""Inverse 9-rank count-vector enumeration, independent of production patterns.

Uses the old independent pair/set predicate after parsing only its definitions;
does not execute that historical study or overwrite any historical evidence.
"""
import ast,json,sys
from pathlib import Path
from functools import lru_cache
D=Path(__file__).resolve().parent
old=D.parent/'lower-completion-20261023'
tree=ast.parse((old/'prepare.py').read_text())
ns={'lru_cache':lru_cache}
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['wins','groups','seven']],type_ignores=[]),'<old-independent-predicate>','exec'),ns)

@lru_cache(None)
def goals(melds):
    total=14-3*melds;h=[0]*9;out=[]
    def visit(i,left):
        if i==9:
            if left:return
            a=tuple(h+[0]*18)
            if ns['wins'](a,4-melds) or melds==0 and ns['seven'](a):out.append(tuple(h))
            return
        for n in range(max(0,left-4*(8-i)),min(4,left)+1):
            h[i]=n;visit(i+1,left-n)
    visit(0,total)
    return out

def analyze(h,rem,ex,suit,mc):
    if any(n for t,n in enumerate(ex) if t//9!=suit):
        return {'minimum':-1,'required':[],'useful':[],'nearest_patterns':0}
    target=h[suit*9:suit*9+9];avail=rem[suit*9:suit*9+9];fixed=ex[suit*9:suit*9+9]
    best=99;nearest=[]
    for g in goals(mc):
        need=tuple(max(0,g[i]-target[i]) for i in range(9))
        if any(g[i]+fixed[i]>4 or need[i]>avail[i] for i in range(9)):continue
        distance=sum(need)
        if distance<best:best=distance;nearest=[need]
        elif distance==best:nearest.append(need)
    return {'minimum':best if nearest else -1,
        'required':[suit*9+i for i in range(9) if nearest and all(n[i]>0 for n in nearest)],
        'useful':[suit*9+i for i in range(9) if any(n[i]>0 for n in nearest)],'nearest_patterns':len(nearest)}

if __name__=='__main__':
    section=sys.argv[1];folder=D/section;rows=[]
    for r in json.loads((folder/'structures.json').read_text()):
        h=r['hand'];ex=r['exposed'];mc=len(r['melds'])
        suit=max(range(3),key=lambda s:sum(h[s*9:s*9+9])+sum(ex[s*9:s*9+9]))
        rem=[4-h[t]-ex[t] for t in range(27)]
        for mode in ['base','scarce','dead']:
            a=rem if mode=='base' else [min(v,1 if mode=='scarce' else 0) if t//9==suit else v for t,v in enumerate(rem)]
            e=analyze(h,a,ex,suit,mc)
            rows.append({'id':r['id']+'/'+mode,'hand':h,'exposed':ex,'remaining':a,'suit':suit,'meld_count':mc,'expected':e})
    (folder/'shape-oracle.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
    print('INVERSE_GOALS',len(rows),'source rows',len(rows)//3)
    for r in rows:
        if r['id'].endswith('/base'):print(r['id'],r['expected'])
