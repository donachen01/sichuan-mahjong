"""Independent finite set packing over explicit block recipes, no production import."""
import json,random
from pathlib import Path
D=Path(__file__).parent
source=json.loads((D/'structures.json').read_text());rows=[]
def solve(hand,available,exposed,meld_count,suit):
 if any(n and t//9!=suit for t,n in enumerate(exposed)):return [0,0,0]
 h=hand[suit*9:suit*9+9];a=available[suit*9:suit*9+9];recipes=[]
 for i,n in enumerate(h):
  if n>=3:recipes.append(([i]*3,0,999))
  if n>=2:recipes.append(([i]*2,1,a[i]))
  if i<=6 and h[i] and h[i+1] and h[i+2]:recipes.append(([i,i+1,i+2],0,999))
  for delta in (1,2):
   if i+delta>=9 or not h[i+delta]:continue
   copies=a[i+1] if delta==2 else (a[i-1] if i else 0)+(a[i+2] if i+2<9 else 0)
   if copies>=2:recipes.append(([i,i+delta],0,copies))
 best=(0,0,0)
 def select(first,chosen,pairs,weak,dead):
  nonlocal best
  singles=any(n>0 and a[t]>0 for t,n in enumerate(h));blocks=min(10,2*(chosen+meld_count)+int(singles))
  if not pairs and not singles:blocks=max(0,blocks-1)
  if dead<=1:best=max(best,(blocks,pairs,0 if weak==999 else weak))
  if chosen+meld_count==5:return
  for ix in range(first,len(recipes)):
   tiles,p,cp=recipes[ix];ok=True
   for t in tiles:
    h[t]-=1
    if h[t]<0:ok=False
   if ok:select(ix,chosen+1,pairs+p,min(weak,cp),dead+int(p and cp==0))
   for t in tiles:h[t]+=1
 select(0,0,0,999,0);return list(best)
for r in source:
 h=r['hand'];ex=r['exposed'];dq=r['dq'];suit=max(range(3),key=lambda s:sum(h[s*9:s*9+9])+sum(ex[s*9:s*9+9]));a=[4-h[t]-ex[t] for t in range(27)]
 rows.append(dict(id=r['id'],hand=h,remaining=a,melds=r['melds'],suit=suit,dq=dq,expected=solve(h[:],a,ex,len(r['melds']),suit)))
(D/'skeleton-oracle.json').write_text(json.dumps(rows))
print('Independent disjoint block set packings',len(rows))
