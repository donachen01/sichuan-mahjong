"""Exhaustive labeled-entity allocation oracle for short concealed-hand urns.
Checks joint target/proposal density and posterior price correlations, without
calling production pattern enumeration, shanten or inference functions.
"""
from pathlib import Path
from itertools import permutations
from collections import Counter
import json,math
D=Path(__file__).resolve().parent
folder=D/'retention-micro'
rows=json.loads((folder/'retention-diagnostic.json').read_text())['rows']
fixtures=json.loads((folder/'retention-diagnostic-fixtures.json').read_text())
checks=0;fail=[];summary=[]
def ck(ok,why):
 global checks
 checks+=1
 if not ok:fail.append(why)
for r in rows:
 state=fixtures[r['id']]['state'];report=r['report'];pool=state['Remaining18'];seats=[i for i in range(4) if i!=state['SeatIndex']]
 assert all(state['HandCounts'][s]==1 and len(state['Melds18'][s])==12 for s in seats)
 ck(report['Supported'],r['id']+' supported')
 entities=[t for t,n in enumerate(pool) for _ in range(n)]
 dq=state['DingQueSuits'];held=[set(state['Melds18'][s]) for s in range(4)]
 def ready(s,t):return t//9!=dq[s] and t not in held[s]
 priors={s:sum(n for t,n in enumerate(pool) if ready(s,t))/sum(pool) for s in seats}
 q={s:r['priors'][str(s)] for s in seats}
 def likelihood(s,t):return q[s]/priors[s] if ready(s,t) else (1-q[s])/(1-priors[s])
 worlds=[];z=0
 for indices in permutations(range(len(entities)),len(seats)):
  selected=[entities[i] for i in indices];weight=math.prod(likelihood(s,t) for s,t in zip(seats,selected));z+=weight
  remain=pool[:]
  for t in selected:remain[t]-=1
  worlds.append((selected,remain,weight))
 expected=[sum(w*wall[t] for _,wall,w in worlds)/z for t in range(27)]
 ratios=[]
 for p in report['Particles']:
  remain=pool[:];ratio=1
  for s in seats:
   t=next(i for i,n in enumerate(p['Hands27'][s]) if n)
   total=sum(remain);nr=sum(n for k,n in enumerate(remain) if ready(s,k));pr=nr/total
   qp=0 if nr==0 else 1 if nr==total else q[s]
   proposal=(qp*remain[t]/nr) if ready(s,t) else ((1-qp)*remain[t]/(total-nr))
   ratio*=likelihood(s,t)*(remain[t]/total)/proposal;remain[t]-=1
  ratios.append(ratio)
 norm=sum(ratios)
 for p,v in zip(report['Particles'],ratios):ck(abs(p['Weight']-v/norm)<1e-12,r['id']+' exact joint importance density')
 error=max(abs(a-b) for a,b in zip(expected,report['ExpectedWall']))
 ck(error<.07,r['id']+' empirical physical posterior error '+str(error))
 # Exact empirical price correlation for each sampled entity allocation.
 for s in seats:
  for t in range(27):
   probability=0;ron=0;selfprice=0;current=0
   for p in report['Particles']:
    if p['Hands27'][s][t] and ready(s,t):
     pure=all(k//9==t//9 for k in state['Melds18'][s]);price=16 if pure else 4
     current+=p['Weight'];draw=p['Weight']*p['Wall27'][t]/state['WallCount']
     probability+=draw;ron+=draw*price;selfprice+=draw*(price+1)
   ck(abs(probability-report['DrawRonProbability'][s][t])<1e-12,r['id']+' coupled draw probability')
   ck(abs(ron-report['DrawRonCost'][s][t])<1e-12,r['id']+' coupled Ron payment')
   ck(abs(selfprice-report['DrawSelfCost'][s][t])<1e-12,r['id']+' coupled self payment')
   ck(abs(current-report['CurrentRonProbability'][s][t])<1e-12,r['id']+' current Ron probability')
 summary.append(dict(id=r['id'],exact_allocations=len(worlds),samples=report['Samples'],ess=report['EffectiveSamples'],maximum_mean_error=error))
(D/'retention-independent.json').write_text(json.dumps(dict(checks=checks,failures=fail,rows=summary),indent=2)+'\n')
print('RETENTION',checks,'checks',len(fail),'failures',summary)
print('\n'.join(fail[:5]));raise SystemExit(bool(fail))
