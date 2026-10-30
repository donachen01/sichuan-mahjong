"""One-task independent physical backgrounds, not a recurring regression list."""
from pathlib import Path
from collections import Counter
import random,json
root=Path(__file__).resolve().parent
fixtures={}
owns={'two_pairs':[0,0,3,3,6,7,9,10,11,12,14,15,16,17],
      'three_pairs':[0,0,3,3,6,6,9,10,11,12,14,15,16,17],
      'ready_choice':[0,1,2,3,4,5,6,7,8,9,10,11,13,17]}
for kind,own in owns.items():
 for cleared in [False,True]:
  for wall_size in [12,25]:
   pool=Counter({t:4 for t in range(27)})
   hands=[[],own.copy(),[],[]];rivers=[[],[],[],[]]
   for t in own:pool[t]-=1
   def take_where(predicate,n):
    out=[]
    for t in list(pool):
     while pool[t]>0 and predicate(t) and len(out)<n:out.append(t);pool[t]-=1
    assert len(out)==n
    return out
   if not cleared:
    hands[0]=[9,13]
    for t in hands[0]:pool[t]-=1
   hands[0]+=take_where(lambda t:t//9!=1,13-len(hands[0]))
   for seat in [2,3]:hands[seat]=take_where(lambda t:t//9!=2,13)
   if cleared:rivers[0]=take_where(lambda t:t//9!=1,1)
   rest=list(pool.elements());rng=random.Random(20261024+wall_size);rng.shuffle(rest)
   wall=rest[:wall_size]
   for i,t in enumerate(rest[wall_size:]):rivers[[1,2,3][i%3]].append(t)
   for seat in [1,2,3]:rivers[seat].sort(key=lambda t:(t//9!=2,t))
   # These are fresh compatible backgrounds, not reconstructions of book hands.
   assert Counter(own+sum([hands[x] for x in [0,2,3]],[])+sum(rivers,[])+wall)==Counter({t:4 for t in range(27)})
   id=f'{kind}/cleared{cleared}/wall{wall_size}'
   fixtures[id]={'id':id,'kind':kind,'cleared':cleared,'wall':wall,'hands':hands,'rivers':rivers,'dq':[1,2,2,2],'draw':own[-1]}
root.joinpath('unseen-inputs.json').write_text(json.dumps(fixtures,indent=2))
print('fresh physical backgrounds',len(fixtures))
