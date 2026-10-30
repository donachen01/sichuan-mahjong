"""This task's frozen-source evidence audit, not a future regression suite.
No score analysis runs until every preregistered game has settled.
"""
from pathlib import Path
from collections import defaultdict
import hashlib,json
import numpy as np

P=Path(__file__).resolve().parent
ROOT=P.parents[2]
def read(f):return json.loads((P/f).read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def ci(values,seed=20261129):
 a=np.asarray(values,dtype=float);rng=np.random.default_rng(seed)
 return np.quantile(rng.choice(a,(10000,len(a))).mean(axis=1),[.025,.975]).tolist()

benchmark=read('benchmark-final.json')
assert not benchmark.get('failure')
games=benchmark['complete_games']
assert len(games)==160,'Do not inspect incomplete strength outcomes'
full=read('full-claims-final-corrected-32.json')
assert len(full['rows'])==128 and not full['failures']
freeze=read('final-source-freeze.json')
for path,h in freeze.items():assert sha(ROOT/path)==h,('changed source',path)
binaries=read('final-dll-binding.json')
for path,h in binaries.items():assert sha(ROOT/path)==h,('changed binary',path)
assert len(set(binaries.values()))==1

execution=[]
for section in ['claims','gangs']:
 f=read(section+'/formal.json');g=read(section+'/execution.json')
 assert not f['failures'] and not g['failures']
 formal={r['id']:r for r in f['rows']};actual={r['source']:r for r in g['rows']}
 assert set(formal)==set(actual)
 for name,a in formal.items():
  b=actual[name];action=a['action'].lower()
  if action=='hu' and b['action']=='self_hu':action='self_hu'
  assert action==b['action'] and a['tile']==b['command']['tile'],name
  if action=='peng':assert a['child']==b['command']['continuationTile'],name
  assert b['executed'] and b['command'],name
 execution.append(dict(section=section,formal=len(formal),actual=len(actual)))
matrix=read('precision/matrix.json');assert not matrix['failures'] and len(matrix['rows'])==24
invariants=read('invariance-expanded/invariance.json');assert invariants['checks']==25 and not invariants['failures']
maxdiff=max(abs(r['difference']) for r in invariants['rows']);assert maxdiff<1e-9
graphs=read('graphs-independent.json');assert not graphs['failures']

byseed=defaultdict(dict)
for g in games:
 assert g['fully_settled'] and g['physical_conservation'] and sum(g['scores'].values())==0
 assert g['controlled'] not in byseed[g['seed']]
 byseed[g['seed']][g['controlled']]=g
assert set(byseed)=={72611031+1009*i for i in range(32)}
deltas=[];seedmeans=[];latency=[]
for seed,rs in sorted(byseed.items()):
 assert set(rs)=={-1,0,1,2,3}
 assert len({r['deal_sha256'] for r in rs.values()})==1
 ds=[]
 for seat in range(4):
  d=rs[seat]['scores'][str(seat)]-rs[-1]['scores'][str(seat)]
  ds.append(d);deltas.append(d);latency.extend(rs[seat]['decision_ms'])
 seedmeans.append(np.mean(ds))
strength=dict(games=160,pairs=128,independent_deals=32,mean_paired_net=float(np.mean(deltas)),
 seed_cluster_95=ci(seedmeans),all_deals_matched=True,all_fully_settled=True,
 decision_ms=dict(n=len(latency),median=float(np.median(latency)),p95=float(np.quantile(latency,.95)),maximum=max(latency)),
 scope='Four seats share one deal cluster. Desktop concurrent-process timings are not phone performance. No parameter tuning on this cohort.')
strength['improvement_confirmed']=strength['seed_cluster_95'][0]>0
strength['significant_regression']=strength['seed_cluster_95'][1]<0

fit=read('frozen-fit.json');OLD=np.array(fit['old_weights']);NEW=np.array(fit['selected']['weights'])
obs=benchmark['observations'];assert all(o['prediction_before_label'] for o in obs)
features=np.array([o['features'] for o in obs]);raw=np.clip(features[:,0],.001,.999)
X=np.column_stack([np.ones(len(obs)),np.log(raw/(1-raw)),(60-features[:,1])/60,features[:,2]/4,
 features[:,3]/12,features[:,5]/4,features[:,6]/4,features[:,7]/4,features[:,8],features[:,9]])
sig=lambda v:1/(1+np.exp(-np.clip(v,-35,35)))
new=sig(X@NEW);old=sig(X@OLD)
isnew=np.array([o['observer_policy'] in ['current','adaptive_search_v1'] for o in obs])
actual=np.array([o['actual'] for o in obs]);truth=np.array([o['truth'] for o in obs])
error=float(np.max(np.abs(actual-np.where(isnew,new,old))));assert error<3e-12
probabilities=dict(observations=len(obs),current_observations=int(isnew.sum()),formula_max_error=error,
 current_brier=float(np.mean((new[isnew]-truth[isnew])**2)),
 old_formula_on_same_current_states_brier=float(np.mean((old[isnew]-truth[isnew])**2)),
 independent_holdout=read('holdout-evaluation.json'),scope='Independent self-play labels; no human-opponent calibration claim.')

paired=defaultdict(dict)
for r in full['rows']:
 assert r['fully_settled'] and sum(r['scores'].values())==0
 assert r['root'] not in paired[r['id']]
 paired[r['id']][r['root']]=r
sources=defaultdict(list)
for name,rs in paired.items():
 assert set(rs)=={'pass','peng'}
 a,b=rs['pass'],rs['peng'];assert a['source']==b['source'] and a['weight']==b['weight']
 sources[a['source']].append((a,b))
claims=[]
for source,pairs in sorted(sources.items()):
 assert len(pairs)==32
 w=np.array([a['weight'] for a,b in pairs]);assert np.all(w>=0) and w.sum()>0
 w/=w.sum();pa=np.array([a['scores']['1'] for a,b in pairs]);pe=np.array([b['scores']['1'] for a,b in pairs]);d=pe-pa
 rng=np.random.default_rng(20261123);indices=rng.integers(0,32,(10000,32));ww=w[indices]
 bootstrap=np.sum(ww*d[indices],axis=1)/np.sum(ww,axis=1)
 claims.append(dict(source=source,public_hypotheses=32,actual_terminal_games=64,
  effective_sample_size=float(1/np.sum(w*w)),pass_net=float(w@pa),peng_net=float(w@pe),
  peng_minus_pass=float(w@d),descriptive_weighted_pair_bootstrap_95=np.quantile(bootstrap,[.025,.975]).tolist(),
  scope='Hypotheses share one reconstructed public background, not32 independent real deals. Other root responders are assumed already passed. Initial legal action and priced first discard are declared counterfactual interventions. All later actions actual native policy. No claim of optimality or true hidden-state posterior.'))

artifacts=['preregistration.json','final-source-freeze.json','final-dll-binding.json','benchmark-final.json',
 'full-claims-final-corrected-32.json','frozen-fit.json','train.json','validation.json','holdout.json',
 'holdout-evaluation.json','graphs-independent.json','invariance-expanded/invariance.json',
 'claims/formal.json','claims/execution.json','gangs/formal.json','gangs/execution.json','precision/matrix.json',
 'precision/current.json','independent-claim-shapes.json','input-control/formal.json',
 'original-source-binding.json','source-6-28-public-detail.png','原页76-77.txt',
 '讨论.md','结论.md','执行.md','学习反思.md','来源纠偏.md','补缺报告.md']
report=dict(source_files=len(freeze),core_sources=sum(k.startswith('dotnet/AI.Core/') for k in freeze),
 same_binaries=len(binaries),execution=execution,protocol_and_seat_chains=24,
 invariants=dict(checks=25,max_difference=maxdiff),independent_graphs=graphs,
 benchmark=strength,readiness=probabilities,complete_claims=claims,
 artifacts={f:sha(P/f) for f in artifacts})
(P/'验收证据.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(dict(games=160,pairs=128,delta=strength['mean_paired_net'],ci=strength['seed_cluster_95'],
 actual_chains=sum(r['actual'] for r in execution)+24,graphs=graphs['checks'],invariants=maxdiff,
 formula_error=error,claims=[dict(source=r['source'],delta=r['peng_minus_pass'],ess=r['effective_sample_size'],ci=r['descriptive_weighted_pair_bootstrap_95']) for r in claims]),ensure_ascii=False))
