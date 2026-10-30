from pathlib import Path
from itertools import combinations_with_replacement
from collections import Counter
import json,sys
P=Path(__file__).resolve().parent
sys.path.insert(0,str(P.parent/'reread-20261030'))
from independent import get_waits
cases=json.loads((P/'precision/cases.json').read_text());rows=[]
for c in cases:
 if '6-28' not in c['id']:continue
 offered=c['offered'];unknown=[4-c['hand'][t]-c['exposed'][t]-c['known'].count(t)-int(t==offered) for t in range(27)]
 for action in ['pass','peng']:
  h=c['hand'][:];ex=c['exposed'][:];mc=len(c['melds'])
  if action=='peng':h[offered]-=2;ex[offered]+=3;mc+=1
  # Flush-only nearest endpoints: remove each outside tile, so no same-suit
  # discard can be silently used to manufacture a distance improvement.
  h=[n if t//9==2 else 0 for t,n in enumerate(h)];need=13-3*mc-sum(h);goals=[]
  for ts in combinations_with_replacement(range(18,27),need):
   ct=Counter(ts)
   if any(n>unknown[t] for t,n in ct.items()):continue
   g=h[:]
   for t in ts:g[t]+=1
   if any(g[t]+ex[t]>4 for t in range(27)):continue
   waits=get_waits(g,ex,mc)
   live=[w['tile'] for w in waits if unknown[w['tile']]-ct[w['tile']]>0]
   if live:goals.append(dict(acquisitions=list(ts),waits=live))
  rows.append(dict(id=c['id'],action=action,required_acquisitions=need,nearest_ready_goals=goals,first_acquisition_union=sorted({t for g in goals for t in g['acquisitions']})))
(P/'independent-claim-shapes.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
for r in rows:print(r['id'],r['action'],'need',r['required_acquisitions'],'draw types',[t-17 for t in r['first_acquisition_union']],'goals',len(r['nearest_ready_goals']))
