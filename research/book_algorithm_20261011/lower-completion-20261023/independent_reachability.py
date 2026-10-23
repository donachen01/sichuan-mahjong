"""Inverse count-vector enumeration for public flush goals, no production API."""
import json
from pathlib import Path
from functools import lru_cache
from itertools import combinations_with_replacement
D=Path(__file__).parent
# Build all legal count vectors by exhaustive incoming multisets, checking
# the independent partition oracle from prepare.py without executing its writer.
namespace={"lru_cache":lru_cache};raw=(D/'prepare.py').read_text();exec(raw[raw.index('@lru_cache(None)'):raw.index('def tile(')],namespace)
wins=namespace['wins'];seven=namespace['seven']
@lru_cache(None)
def goals(melds):
 n=14-3*melds;result=[]
 for xs in combinations_with_replacement(range(9),n):
  a=[0]*9
  for x in xs:a[x]+=1
  if max(a)>4:continue
  h=tuple(a+[0]*18)
  if wins(h,4-melds) or melds==0 and seven(h):result.append(a)
 return result

def analyze(hand,remaining,exposed,suit,melds):
 if any(n for t,n in enumerate(exposed) if t//9!=suit):return None
 target=hand[suit*9:suit*9+9];avail=remaining[suit*9:suit*9+9];ex=exposed[suit*9:suit*9+9]
 best=99;nearest=[]
 for g in goals(melds):
  need=[max(0,g[i]-target[i]) for i in range(9)]
  if any(g[i]+ex[i]>4 or need[i]>avail[i] for i in range(9)):continue
  dist=sum(need)
  if dist<best:best=dist;nearest=[need]
  elif dist==best:nearest.append(need)
 if not nearest:return None
 required=[suit*9+i for i in range(9) if all(n[i]>0 for n in nearest)]
 useful=[suit*9+i for i in range(9) if any(n[i]>0 for n in nearest)]
 return dict(minimum=best,required=required,useful=useful,nearest_patterns=len(nearest))
rows=[]
for c in json.loads((D/'cases.json').read_text()):
 if c['id']!='lower-76-6-28-base-offer-m4':continue
 h=c['hand'][:];ex=c['exposed'][:];remain=[4-h[t]-ex[t]-c['known'].count(t)-(t==c['offered']) for t in range(27)];suit=c['offered']//9
 before=analyze(h,remain,ex,suit,len(c['melds']))
 h[c['offered']]-=2;ex[c['offered']]+=3
 for discard in [6,7]:
  if not h[discard]:continue
  h[discard]-=1
  rows.append(dict(id=c['id'],discard=discard,before=before,after=analyze(h,remain,ex,suit,len(c['melds'])+1),public_remaining=remain))
  h[discard]+=1
(D/'independent-key-bottleneck.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
print([(r['discard'],r['before'],r['after']) for r in rows])
