"""Independent forward enumeration, unlike C# backward density recursion."""
from pathlib import Path
from collections import defaultdict
from math import comb,prod,log,exp
import json
P=Path(__file__).resolve().parent
configs=[]
def add(name,counts,melds,exposed=None):
 pool=[0]*27
 for t,n in counts.items():pool[t]=n
 ex=[0]*27
 for t,n in (exposed or {}).items():ex[t]=n
 configs.append((name,pool,ex,melds))
add('single',{0:2,1:1,4:3,9:1},4,{10:3,11:3,12:3,13:3})
add('one-set',{0:2,1:2,2:2,3:1,9:2,10:1,11:1},3,{12:3,13:3,14:3})
add('one-set-scarce',{0:1,1:1,2:1,3:2,4:2,9:1},3,{12:3,13:3,14:3})
add('two-sets',{0:2,1:2,2:3,3:2,4:1,5:1},2,{12:3,13:3})
add('two-sets-roots',{0:4,1:2,2:2,3:2,4:1},2,{12:3,13:3})
add('seven-only',{0:2,2:2,4:2,6:2,8:2,9:2,11:2},0)
add('overlap-seven-ordinary',{t:2 for t in range(7)},0)
add('overlap-decompositions',{0:3,1:3,2:3,3:3,4:2},0)
add('missing-still-present',{0:2,1:2,2:2,3:1,18:2},3,{12:3,13:3,14:3})
rows=[];totals=[]
for name,pool,ex,mc in configs:
 likelihood=[(.5 if t%3==0 else 2.0 if t%3==1 else 1.0) if "scarce" in name or "roots" in name else 1.0 for t in range(27)]
 logs=[log(x) for x in likelihood]
 legal=[t for t in range(27) if t//9!=2]
 pairs=[(t,t) for t in legal]
 sets=[(t,t,t) for t in legal]+[(t,t+1,t+2) for t in legal if t%9<=6]
 def choices(h,groups):
  good=[]
  for g in groups:
   a=list(h)
   for t in g:a[t]+=1
   if max(a[t]+ex[t] for t in range(27))<=4 and sum(max(0,a[t]-pool[t]) for t in range(27))<=1:good.append(tuple(a))
  return good
 def forward(seven):
  dist={(0,)*27:1.0};steps=7 if seven else 5-mc
  for stage in range(steps):
   nex=defaultdict(float)
   for h,mass in dist.items():
    cs=choices(h,pairs if seven or stage==0 else sets)
    weights=[prod(comb(pool[t]+1-h[t],a[t]-h[t]) for t in range(27))*exp(max(-80,min(80,sum((a[t]-h[t])*logs[t] for t in range(27))))) for a in cs]
    for a,w in zip(cs,weights):nex[a]+=mass*w/sum(weights)
   dist=nex
  result=defaultdict(float)
  for full,mass in dist.items():
   removals=[t for t in range(27) if full[t]>0 and all(full[j]-(j==t)<=pool[j] for j in range(27))]
   denominator=sum(full[t] for t in removals)
   for t in removals:
    a=list(full);a[t]-=1;result[tuple(a)]+=mass*full[t]/denominator
  return result
 ordinary=forward(False);seven=forward(True) if mc==0 else {}
 density={h:(.9 if mc==0 else 1)*ordinary.get(h,0)+(.1 if mc==0 else 0)*seven.get(h,0) for h in set(ordinary)|set(seven)}
 assert 0<=sum(density.values())<=1+1e-12
 def hands(i,left,h):
  if i==27:
   if left==0:yield h
   return
  for n in range(min(pool[i],left)+1):yield from hands(i+1,left-n,h+[n])
 total=0
 for h in hands(0,13-3*mc,[]):
  if any(h[t]+ex[t]>4 for t in range(27)):continue
  physical=prod(comb(pool[t],h[t]) for t in range(27))/comb(sum(pool),sum(h))
  rows.append(dict(id=name+'/'+''.join(map(str,h)),pool=pool,exposed=ex,missing=2,melds=mc,hand=h,
   expected=density.get(tuple(h),0),physical=physical,logs=logs));total+=1
 totals.append(dict(id=name,hand_cases=total,proposal_success=sum(density.values())))
(P/'ready-density-oracle.json').write_text(json.dumps(rows,indent=2)+'\n')
(P/'ready-density-forward-summary.json').write_text(json.dumps(totals,indent=2)+'\n')
print('forward hand cases',len(rows),'configurations',len(totals))
