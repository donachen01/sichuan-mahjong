"""Exact independent shape/price and entity-transition audit of compiled policy.
The graph is observed output, not an oracle; only physical rules define checks.
"""
from pathlib import Path
from collections import Counter
import json,sys
D=Path(__file__).resolve().parent
sys.path.insert(0,str(D.parent/'reread-20261030'))
from independent import get_waits
checks=0;failures=[];graphs=0;states=0
for section in sys.argv[1:] or ['6.3']:
 rows=json.loads((D/section/'graphs.json').read_text())['rows']
 for row in rows:
  if row['plan'] is None:continue
  graphs+=1;gs=row['plan']['Stages'];states+=len(gs);base=row['exposed'];base_melds=sum(bool(n) for n in base)
  def fixed(stage):
   counts=Counter(stage['PengTiles']);return [base[t]+3*(counts[t]-int(base[t]>0)) for t in range(27)]
  for i,g in enumerate(gs):
   h=g['Hand'];ex=fixed(g);mc=len(g['PengTiles'])
   def check(ok,why):
    global checks
    checks+=1
    if not ok:failures.append(f"{row['id']}/{i} {why}")
   check(sum(h)+3*mc==13,'effective hand size')
   check(all(0<=h[t]+ex[t]<=4 for t in range(27)),'physical four copies')
   check(not any(h[row['missing']*9:row['missing']*9+9]),'missing suit cleared')
   ws=get_waits(h,ex,mc)
   check(g['Ready']==bool(ws),'exact legal readiness')
   expected={w['tile']:w['score'] for w in ws}
   for t in range(27):
    check(g['Ron'][t]==(expected[t]['hand_score'] if t in expected else 0),'Ron price '+str(t))
    check(g['Self'][t]==(expected[t]['self_per_payer'] if t in expected else 0),'self price '+str(t))
   for action in ['Own','Peng']:
    for t,nxt in enumerate(g[action+'Next']):
     if nxt<0:continue
     child=gs[nxt];a=h[:];b=ex[:]
     if action=='Own':a[t]+=1
     else:a[t]-=2;b[t]+=3
     discards=g.get(action+'Discards');discard=discards[t] if discards is not None else g['SpareDiscard']
     check(discard>=0 and a[discard]>0,action+' discard owned')
     if discard>=0:a[discard]-=1
     check(a==child['Hand'] and b==fixed(child),action+' exact entity transition')
     if action=='Peng':check(h[t]>=2,'Peng pair exists')
(D/'graphs-independent.json').write_text(json.dumps(dict(graphs=graphs,states=states,checks=checks,failures=failures),ensure_ascii=False,indent=2)+'\n')
print('GRAPH',graphs,'states',states,'checks',checks,'failures',len(failures))
print('\n'.join(failures[:5]))
raise SystemExit(bool(failures))
