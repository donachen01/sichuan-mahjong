from pathlib import Path
from collections import defaultdict
import json,math,statistics,sys
P=Path(__file__).resolve().parent
name=sys.argv[1] if len(sys.argv)>1 else 'natural-accepted'
j=json.loads((P/(name+'.json')).read_text())
assert 'failure' not in j
rows=j['complete_games'];pairs=defaultdict(dict);byseed=defaultdict(list);timings=defaultdict(list)
for r in rows:
 assert r['fully_settled'] and r['physical_conservation'] and sum(r['scores'].values())==0
 pairs[r['seed'],r['seat']][r['variant']]=r['scores'][str(r['seat'])]
 timings[r['variant']]+=r['decision_ms']
for (seed,seat),v in pairs.items():
 assert set(v)=={'current','pre_learning_closure_v1'}
 byseed[seed].append(v['current']-v['pre_learning_closure_v1'])
clusters=[statistics.mean(x) for x in byseed.values()]
mean=statistics.mean(clusters);se=statistics.stdev(clusters)/math.sqrt(len(clusters))
cal=[]
for variant in ['pre_learning_closure_v1','current']:
 rr=[r for r in j['readiness'] if r['variant']==variant];bins=[]
 for lo,hi in [(0,.2),(.2,.4),(.4,.6),(.6,.8),(.8,1.00000001)]:
  b=[r for r in rr if lo<=r['prediction']<hi]
  if b:bins.append(dict(range=[lo,min(1,hi)],n=len(b),prediction=statistics.mean(r['prediction'] for r in b),truth=statistics.mean(r['truth'] for r in b)))
 cal.append(dict(variant=variant,n=len(rr),prevalence=statistics.mean(r['truth'] for r in rr),brier=statistics.mean((r['prediction']-r['truth'])**2 for r in rr),reliability=bins))
lat={}
for k,a in timings.items():
 a.sort();lat[k]=dict(n=len(a),median=a[len(a)//2],p95=a[math.floor(.95*(len(a)-1))],max=max(a))
baseline_repeats={str(seed):len({json.dumps(r['scores'],sort_keys=True) for r in rows if r['seed']==seed and r['variant']=='pre_learning_closure_v1'}) for seed in byseed}
report=dict(games=len(rows),pairs=len(pairs),independent_seed_clusters=len(clusters),mean_paired_gain=mean,seed_cluster_standard_error=se,descriptive_95_percent_interval=[mean-2.365*se,mean+2.365*se],per_seed_gain={str(k):statistics.mean(v) for k,v in byseed.items()},baseline_score_vectors_per_seed=baseline_repeats,readiness=cal,latency_ms=lat,interpretation='Small predeclared self-play pilot. Confidence interval clustered by 8 original deals. No human-opponent calibration or universal strength claim; no fitting on these labels. CPU-concurrent timings are not device benchmarks.')
(P/(name+'-summary.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['games','pairs','mean_paired_gain','descriptive_95_percent_interval']},ensure_ascii=False))
print('readiness',[(r['variant'],r['n'],round(r['brier'],4)) for r in cal])
