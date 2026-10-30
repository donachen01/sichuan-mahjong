"""Independent information-set recursion over explicit physical permutations.
Unobserved rival draws do not split the information set. No production imports.
"""
from functools import lru_cache
from itertools import permutations
from pathlib import Path
import json,math
D=Path(__file__).resolve().parent
cases=[]
def solve(counts,wall,players,forced,offset,prices,hazard,locked=0,budget=2147483647):
 # A quarter-grid random shift produces the declared dependent-rounding
 # prior. Enumerate each allocation's physical permutations with its own mass.
 weights={}
 for u in [.125,.375,.625,.875]:
  ns=[];cumulative=0
  for n in counts:
   ns.append(math.floor(cumulative+n+u)-math.floor(cumulative+u));cumulative+=n
  symbols=[k for k,n in enumerate(ns) for _ in range(n)]+[-1]*(wall-sum(ns))
  possible=set(permutations(symbols))
  for w in possible:weights[w]=weights.get(w,0)+.25/len(possible)
 walls=tuple(sorted(weights));mass=tuple(weights[w] for w in walls)
 @lru_cache(None)
 def visit(ids,pos,mask,actor,lock,budget):
  payers=bin(mask).count("1")-1
  if not payers:return (0,0,0,0,0,0,1)
  if pos==wall:return (0,0,0,0,1.25*payers/(players-1),1,0)
  if actor==0:lock=0
  def nxt(live):return next((actor+d)%players for d in range(1,players+1) if live>>(actor+d)%players&1)
  def advance(selected,lock2,exit_possible):
   stay=visit(selected,pos+1,mask,nxt(mask),lock2,budget)
   if not exit_possible or not hazard:return stay
   exited=mask&~(1<<actor);leave=list(visit(selected,pos+1,exited,nxt(exited),lock2,budget));leave[3]+=2.4
   return tuple((1-hazard)*a+hazard*b for a,b in zip(stay,leave))
  if actor and not forced>>actor&1:return advance(ids,lock,True)
  grouped={}
  for i in ids:grouped.setdefault(walls[i][pos],[]).append(i)
  out=[0.]*7
  for symbol,ix in grouped.items():
   selected=tuple(ix)
   if symbol<0:v=advance(selected,lock,actor!=0)
   elif actor==0:v=((prices[symbol]+1)*payers,1,0,0,0,0,0)
   else:
    price=prices[symbol];continuation=visit(selected,pos+1,mask,nxt(mask),max(lock,price),budget if price<=lock or budget==2147483647 else max(0,budget-1))
    net=continuation[0]-continuation[3]+continuation[4]
    v=continuation if price<=lock or budget>0 and net>=price+max(.25,price*.25) else (price,0,1,0,0,0,0)
   for k in range(7):out[k]+=v[k]*sum(mass[i] for i in ix)/sum(mass[i] for i in ids)
  return tuple(out)
 return visit(tuple(range(len(walls))),0,(1<<players)-1,(players-offset)%players,locked,budget)
for wall in [3,4,5,6]:
 for counts in [(1,),(2,),(1,1),(2,1),(1,1,1)]:
  if sum(counts)>wall:continue
  for players in [2,3,4]:
   for forced in [0,2,(1<<players)-2]:
    for hazard in [0,.125]:
     offset=players-1;prices=[2,4,8][:len(counts)]
     e=solve(counts,wall,players,forced,offset,prices,hazard)
     cases.append(dict(wall=wall,players=players,offset=offset,forced=forced,counts=counts,prices=prices,hazard=hazard,locked=0,expected=e))
# Existing passed-Hu lock is cleared by the next actual own draw.
for lock in [2,4,8]:
 e=solve((1,1),5,3,6,2,[2,4],0,lock)
 cases.append(dict(wall=5,players=3,offset=2,forced=6,counts=[1,1],prices=[2,4],hazard=0,locked=lock,expected=e))
for counts in [(.5,), (1.25,), (.5,.75), (1.5,.75), (.25,.75,1.25)]:
 for players in [2,3,4]:
  for forced in [0,2,(1<<players)-2]:
   prices=[2,4,8][:len(counts)];wall=5;offset=players-1;hazard=.125
   e=solve(counts,wall,players,forced,offset,prices,hazard)
   cases.append(dict(wall=wall,players=players,offset=offset,forced=forced,counts=counts,prices=prices,hazard=hazard,locked=0,expected=e))
for budget in [0,1,2]:
 for forced in [2,6]:
  for counts in [(2,1),(.75,1.25)]:
   e=solve(counts,5,3,forced,2,[2,4],.125,0,budget)
   cases.append(dict(wall=5,players=3,offset=2,forced=forced,counts=counts,prices=[2,4],hazard=.125,locked=0,budget=budget,expected=e))
(D/'stopping-oracle.json').write_text(json.dumps(cases)+'\n')
print('independent explicit-wall information-set cases',len(cases))
