"""Independent one-task legal-release and finite-copy enumeration; no AI imports."""
from pathlib import Path
import itertools,json
root=Path(__file__).resolve().parent
proof=[]
for missing in range(3):
 for held_rank in [0,3,8]:
  for drawn_rank in [1,4,7]:
   held=missing*9+held_rank;drawn=missing*9+drawn_rank;choices=sorted({held,drawn})
   proof.append({'missing':missing,'held_missing':held,'drawn_target':drawn,'legal_discards':choices,'guaranteed_target':all(x==drawn for x in choices)})
assert len(proof)==27 and all(not x['guaranteed_target'] for x in proof)
root.joinpath('independent-release-counterexamples.json').write_text(json.dumps({'checks':27,'failures':[],'rows':proof},indent=2))
rows=[]
for wall in range(1,7):
 for hidden in range(1,6):
  for copies in range(1,min(4,wall+hidden)+1):
   positions=list(itertools.combinations(range(wall+hidden),copies))
   p=sum(any(i<wall for i in x) for x in positions)/len(positions)
   mean=sum(sum(i<wall for i in x) for x in positions)/len(positions)
   rows.append({'wall':wall,'hidden':hidden,'copies':copies,'expected_wall':mean,'p_in_wall':p,'count':len(positions)})
root.joinpath('independent-allocation-oracle.json').write_text(json.dumps(rows,indent=2))
print('independent release cases',len(proof),'neutral finite allocations',len(rows))
