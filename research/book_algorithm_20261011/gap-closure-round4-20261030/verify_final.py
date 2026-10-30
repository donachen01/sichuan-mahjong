"""One-off round4 exact-behavior and timing audit, not a future test suite."""
from pathlib import Path
import json,hashlib
import numpy as np
P=Path(__file__).resolve().parent
ROOT=P.parents[2]
def read(n):return json.loads((P/n).read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def timing(a):
 return dict(n=len(a),total_ms=float(np.sum(a)),median_ms=float(np.median(a)),
             p95_ms=float(np.quantile(a,.95)),maximum_ms=float(max(a)))
ids=read('binary-identities.json');a=read('profile-reference.json');b=read('profile-optimized.json')
assert a['core_identity']==ids[str((P/'before/round3-executed-core.dll').relative_to(ROOT))]
assert b['core_identity']==ids['dotnet/AI.Core/bin/Debug/net10.0/SichuanMahjong.AI.Core.dll']
assert a['core_identity']!=b['core_identity']
assert not a['failure'] and not b['failure']
assert a['scores']==b['scores'] and a['deal_sha256']==b['deal_sha256']
assert len(a['steps'])==len(b['steps'])==60
keys=['phase','actor','wall_after','event_sha256']
for x,y in zip(a['steps'],b['steps']):assert all(x[k]==y[k] for k in keys),('slow trace',x['step'])
old=read('../gap-closure-round3-20261030/benchmark-final.json')
original=next(x for x in old['complete_games'] if x['seed']==92625157 and x['controlled']==0)
assert original['deal_sha256']==a['deal_sha256'] and original['scores']==a['scores']
aa=read('equivalence-reference.json');bb=read('equivalence-optimized.json')
assert aa['core_identity']==a['core_identity'] and bb['core_identity']==b['core_identity']
assert not aa['failure'] and not bb['failure'] and len(aa['games'])==len(bb['games'])==8
before=[];after=[];steps=0
for x,y in zip(aa['games'],bb['games']):
 assert x['seed']==y['seed'] and x['scores']==y['scores'] and x['deal_sha256']==y['deal_sha256']
 assert x['fully_settled'] and y['fully_settled'] and sum(y['scores'].values())==0 and set(y['scores'])=={'0','1','2','3'}
 assert len(x['trace'])==len(y['trace'])
 for i,(u,v) in enumerate(zip(x['trace'],y['trace'])):
  assert all(u[k]==v[k] for k in keys),('natural trace',x['seed'],i)
  steps+=1
  if u['phase'] in [5,6]:before.append(u['ms']);after.append(v['ms'])
repeat_old=read('equivalence-reference-repeat.json');repeat_new=read('equivalence-optimized-repeat.json')
assert repeat_old['core_identity']==a['core_identity'] and repeat_new['core_identity']==b['core_identity']
assert not repeat_old['failure'] and not repeat_new['failure']
repeat_before=[];repeat_after=[]
for original,x,y in zip(aa['games'],repeat_old['games'],repeat_new['games']):
 assert original['seed']==x['seed']==y['seed'] and original['scores']==x['scores']==y['scores']
 assert original['deal_sha256']==x['deal_sha256']==y['deal_sha256']
 assert len(original['trace'])==len(x['trace'])==len(y['trace'])
 for u,v,w in zip(original['trace'],x['trace'],y['trace']):
  assert all(u[k]==v[k]==w[k] for k in keys),'repeat full trace'
  if u['phase'] in [5,6]:repeat_before.append(v['ms']);repeat_after.append(w['ms'])
assert not read('kernel-parity.json')['failures']
for n in ['current.json','invariance.json','cash-tests.json','execution.json']:assert not read(n)['failures'],n
formal=read('current.json')['rows'];oldformal=read('../gap-closure-round3-20261030/current.json')['rows']
assert len(formal)==len(oldformal)==4
for x,y in zip(formal,oldformal):
 assert all(x[k]==y[k] for k in ['id','action','tile','child'])
 for u,v in zip(x['values']['candidates'],y['values']['candidates']):
  assert u['Action']==v['Action'] and u['ExpectedNetScore']==v['ExpectedNetScore'],x['id']
actual={x['source']:x for x in read('execution.json')['rows']};assert len(actual)==4
for f in formal:
 g=actual[f['id']];assert g['executed'] and g['action'].lower()==f['action'].lower()
 if f['action']=='Peng':assert g['command']['continuationTile']==f['child']
for manifest in ['source-freeze.json','runner-source-freeze.json','dll-binding.json','runtime-binding.json']:
 for path,h in read(manifest).items():assert sha(ROOT/path)==h,('Source or binary changed',path)
assert len(set(read('dll-binding.json').values()))==1
baseline=read('baseline-binary.json');assert sha(P/baseline['archived_binary'])==baseline['original_sha256']
rootstep=a['steps'][39];newstep=b['steps'][39]
result=dict(kernel=read('kernel-parity.json'),actual_replay=dict(original_reported_ms=22424.867,
 reference_ms=rootstep['ms'],optimized_ms=newstep['ms'],speedup=rootstep['ms']/newstep['ms'],
 reduction_fraction=1-newstep['ms']/rootstep['ms'],all60_steps_exact=True,scores=b['scores']),
 natural_games=dict(deals=8,paired_runs=16,all_steps_exact=steps,
 reference=timing(before),optimized=timing(after),scope='Known cases after first collection, semantic/performance regression only; no strength or new blind claim.'),
 ordinary_opposite_order=dict(known_deals=8,runs=32,reference=timing(before+repeat_before),optimized=timing(after+repeat_after),scope='Same8 known deals repeated in opposite temporal order; no additional independent sources or strength claim.'),
 formal_cases=4,actual_formal_executions=4,source_files=len(read('source-freeze.json')),
 mechanism='Same policies, samples, endpoints, numerical worlds/streams and ordered cash reduction. Bounded up-to4-worker paths/walls only at>=1024. No action or timeout fallback.',
 platform='Single-process desktop true C#/Godot; parallel component clocks overlap; actual step wall time is primary. Phone NativeAOT, heat and rendering contention unverified.',
 open_gaps=['Remaining long-tail cost','6-28 original context and m4 uncertainty','Joint projection live promotion','Phone/human/long-term evidence'])
(P/'final-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['actual_replay','natural_games','formal_cases','actual_formal_executions']},ensure_ascii=False,indent=2))
