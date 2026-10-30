"""Chapter 7 local public retention logic, witnessed by literal rank groups.
This proves combinatorial classification, not a discard or wall probability.
"""
import itertools,json
from pathlib import Path
D=Path(__file__).resolve().parent/'7.2'
def record(t,a,source='rank-neighbor-enumeration'):
    suit=t//9
    witnesses=[[suit*9+j,suit*9+j+1,suit*9+j+2] for j in range(7)
               if t in range(suit*9+j,suit*9+j+3)]
    seq=any(all(k==t or a[k]>0 for k in run) for run in witnesses)
    partial=any(a[k]>0 for k in range(suit*9,suit*9+9) if 0<abs(k-t)<=2)
    n=a[t];grade='EXHAUSTED' if n==0 else 'UNCONSTRAINED' if seq else 'B' if n>=2 else 'A' if partial else 'S'
    return dict(source=source,tile=t,remaining=a,grade=grade,sequence=seq,pair=n>=2,triplet=n>=3)
rows=[]
for t in range(27):
    neighbors=[k for k in range(t//9*9,t//9*9+9) if 0<abs(k-t)<=2]
    for bits in itertools.product([0,1],repeat=len(neighbors)):
        for n in range(5):
            a=[0]*27;a[t]=n
            for k,b in zip(neighbors,bits):a[k]=b
            rows.append(record(t,a))
table=json.loads((D.parent/'7.1-tables/formal-fixtures.json').read_text())
late=next(v for k,v in table.items() if 'late' in k)
rows.append(record(8,late['state']['Remaining18'],'source-7-2-late/9s'))
# Explicit source examples use original 13-tile hand, not the constructed Hu
# draw used only to verify execution in cases.json.
cs=json.loads((D/'cases.json').read_text())
for s in json.loads((D/'structures.json').read_text()):
    c=next(c for c in cs if c['source']==s['id'])
    a=[4-s['hand'][t]-s['exposed'][t]-c['known'].count(t) for t in range(27)]
    if '7-3' in s['id'] or '7-4' in s['id']:rows.append(record(19,a,s['id']))
    if '7-5' in s['id']:
        for t in [18,20]:rows.append(record(t,a,s['id']))
    if '7-6' in s['id']:
        # After opponent Peng777p, current offer9p is incorporated into our
        # Peng999p; discard3p. Supply counts retain all physical copies.
        h=s['hand'][:];e=s['exposed'][:];h[17]-=2;e[17]+=3;h[11]-=1
        known=c['known']+[11];a=[4-h[t]-e[t]-known.count(t) for t in range(27)];a[15]-=3
        rows.append(record(17,a,s['id']+'/after-Peng'))
(D/'retention-oracle.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print('RETENTION independent contexts',len(rows),'source classes',[(r['source'],r['grade']) for r in rows if r['source']!='rank-neighbor-enumeration'])
