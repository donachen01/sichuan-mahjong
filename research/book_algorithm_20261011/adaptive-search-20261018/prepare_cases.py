"""Focused synthetic public backgrounds for the approved compute-budget change.
Book hands retained; rivers/wall/round are explicit experiment assumptions.
No hidden actual wall or opponent hands are passed to policy.
"""
from pathlib import Path
import copy,json,random
root=Path(__file__).resolve().parent
repo=root.parents[2]
base=json.loads((repo/'research/book_algorithm_20261011/upper-followup-20261018/own-gang-real-input.json').read_text())[0]
rows=[]
real=copy.deepcopy(base);real['id']='saved-own-gang';rows.append(real)
for section in ('4.2.3','4.2.4'):
 for f in json.loads((repo/f'research/technical_theory_lower_20261002/sections/{section}-fixtures.json').read_text()):
  if 'reaction_tile' not in f or f['variant']=='C' and f['case']=='4-13':continue
  for wall in (38,8):
   s=copy.deepcopy(base);s['id']=f'{f["id"]}-assumed-wall{wall}';h=f['hand18'];tile=f['reaction_tile']
   assert sum(h)==13
   visible=[0]*27;rivers=[[] for _ in range(4)]
   visible[tile]=1;rivers[3].append(tile)
   target=108-sum(h)-39-wall
   rnd=random.Random(20261018)
   order=[t for t in range(27) for _ in range(4-h[t]-visible[t])];rnd.shuffle(order)
   for i,t in enumerate(order[:target-1]):visible[t]+=1;rivers[i%4].append(t)
   remaining=[4-h[t]-visible[t] for t in range(27)]
   missing=next(suit for suit in range(3) if sum(h[suit*9:suit*9+9])==0)
   s.update(hand18=h,visible18=visible,remaining18=remaining,discards18=rivers,wallCount=wall,
    dingQueSuits=[missing,(missing+1)%3,(missing+2)%3,missing],handCounts=[13]*4,
    reactionTileType=tile,canPeng=True,canGang=True,currentSeat=3,sourceSeat=3,
    roundId=s['id'],publicEvents=[],eventVersion=0,viewVersion=100,turnIndex=16,phase=6,
    assumedBackground='Book hand/reaction retained; synthetic public rivers and wall, not historical replay')
   assert sum(remaining)==wall+39
   rows.append(s)
   if section=='4.2.3' and wall==38 and f['variant'] in ('A','B'):
    own=copy.deepcopy(s);own['id']+='-own-concealed-gang';own['roundId']=own['id']
    own['hand18']=own['hand18'].copy();own['hand18'][tile]+=1
    own['handCounts'][0]=14;own['currentSeat']=0;own['phase']=5;own['lastDrawTileType']=tile
    own['visible18'][tile]-=1;own['discards18'][3].remove(tile)
    own.pop('reactionTileType');own['publicEvents']=[]
    assert sum(own['remaining18'])==own['wallCount']+39
    assert all(own['hand18'][t]+own['visible18'][t]+own['remaining18'][t]==4 for t in range(27))
    rows.append(own)
(root/'focused-inputs.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
print('Prepared',len(rows),'explicit scenarios')
