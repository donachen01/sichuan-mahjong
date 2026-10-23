"""Independent labelled-wall enumeration, no C# or production formula imported."""
from pathlib import Path
from itertools import permutations,product
from fractions import Fraction
import json
D=Path(__file__).parent
rows=[]
for counts in [(1,1,2),(2,1,2),(1,2,2),(2,2,2),(2,1,3),(3,1,2)]:
 wall=tuple(x for x,n in zip('ABO',counts) for _ in range(n));n=len(wall);worlds=set(permutations(wall))
 for same in (False,True):
  for earlier in range(min(3,counts[2]+1)):
   for middle in range(min(3,n-1-earlier)):
    a=earlier;b=a+1+middle
    if b>=n:continue
    win='A' if same else 'B';good=0
    for w in worlds:
     if w[a]!='A' or w[b]!=win:continue
     if any(w[k]!='O' for k in range(earlier)):continue
     if any(w[k]==win for k in range(a+1,b)):continue
     good+=1
    wc=counts[0]-1 if same else counts[1]
    rows.append(dict(args=[n,counts[2],counts[0],wc,wc,earlier,middle],expected=float(Fraction(good,len(worlds))),worlds=len(worlds)))
(D/'ordered-oracle.json').write_text(json.dumps(rows))
# All 5^5 local public supply neighborhoods. Retention is classified by listing
# complete sequences and pairs, and by listing surviving incomplete partners.
ret=[]
for c in product(range(5),repeat=5):
 a=[0]*27;a[2:7]=c;t=4
 complete=[i for i in (2,3,4) if all(a[j]>0 for j in (i,i+1,i+2) if j!=t)]
 partial=[j for j in (2,3,5,6) if a[j]>0]
 grade='EXHAUSTED' if a[t]==0 else 'UNCONSTRAINED' if complete else 'S' if a[t]==1 and not partial else 'A' if a[t]==1 else 'B'
 ret.append(dict(remaining=a,tile=t,grade=grade,sequence=bool(complete),pair=a[t]>=2,triplet=a[t]>=3))
(D/'retention-oracle.json').write_text(json.dumps(ret))
print('ordered labelled wall cases',len(rows),'retention neighborhoods',len(ret))
# First-target own draws and fourth-copy opponent offers share a first-event
# partition. Enumerate independent labelled permutations for the joint filters.
rows=[]
for labels in ['RWWOO','RRWTOO','RWWTOO','RRWWOO','RWTTOOO','RWWWTOO']:
 worlds=set(permutations(labels));n=len(labels)
 for first in 'RT':
  if first not in labels:continue
  for winning in 'RW':
   wc=labels.count(winning)-(first==winning)
   if wc<=0:continue
   for a in range(2):
    for b in range(2):
     for m in range(2):
      j=a+b;k=j+1+m
      if k>=n:continue
      good=0
      for w in worlds:
       if w[j]!=first or w[k]!=winning:continue
       if any(w[i]!='O' for i in range(a)):continue
       if any(w[i]=='R' for i in range(a,j)):continue
       if any(w[i]==winning for i in range(j+1,k)):continue
       good+=1
      # R is the claimable fourth-copy set. The selected winning class is
      # either R (overlap) or W (disjoint), covering both inclusion cases.
      post=labels.count(winning)-(first==winning)
      roots=labels.count('R')-(first=='R')-(winning=='R')
      overlap=roots if winning=='R' else 0
      args=[n,labels.count('O'),labels.count(first),wc,post,a,b,m,roots,overlap]
      rows.append(dict(args=args,expected=good/len(worlds),worlds=len(worlds)))
(D/'claim-ordered-oracle.json').write_text(json.dumps(rows))
print('joint first-event enumeration cases',len(rows))
