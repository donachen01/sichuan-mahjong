"""One-off audit of this round's declared experiments, never a default suite.
No aggregate outcome analysis until all declared cohorts have settled.
"""
from pathlib import Path
from collections import defaultdict, Counter
import hashlib, json
import numpy as np

P = Path(__file__).resolve().parent
ROOT = P.parents[2]
def read(name): return json.loads((P/name).read_text())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def ci(values, seed=20261230):
    a=np.asarray(values, dtype=float)
    rng=np.random.default_rng(seed)
    return np.quantile(rng.choice(a,(20000,len(a))).mean(axis=1),[.025,.975]).tolist()

bench=read('benchmark-final.json'); forecast=read('forecast-holdout.json'); full=read('full-claims.json')
assert len(bench['complete_games'])==160 and not bench.get('failure'), 'Incomplete strength cohort'
assert len(forecast['complete_games'])==48 and not forecast.get('failure'), 'Incomplete forecast cohort'
assert len(full['rows'])==512 and not full['failures'], 'Incomplete conditional comparison'
for name in ['source-freeze.json','runner-source-freeze.json','dll-binding.json','runtime-binding.json']:
    for path,expected in read(name).items(): assert sha(ROOT/path)==expected, ('Source/binary drift',path)
assert len(set(read('dll-binding.json').values()))==1
for name in ['cash-tests.json','cash-baseline-parity.json','joint-fit-current.json',
             'ready-density-current.json','joint-privacy.json','invariance.json','execution.json']:
    assert not read(name)['failures'],name

# Formal native command -> GameState action and priced first discard.
formal={r['id']:r for r in read('current.json')['rows']}
executions=read('execution.json')['rows']; assert len(executions)==4
for r in executions:
    f=formal[r['source']]
    assert r['executed'] and r['action'].lower()==f['action'].lower()
    if f['action']=='Peng': assert r['command']['continuationTile']==f['child']
for name,expected in [('priority-cash-actual-proof.json','hu'),('priority-cash-pass-proof.json','peng')]:
    p=read(name); assert not p['failures'] and len(p['checks'])==2
    assert p['checks'][0]['phase']=='defer' and p['checks'][0]['all_options_and_locks_preserved']
    assert p['checks'][1]['action']==expected

byseed=defaultdict(dict)
for g in bench['complete_games']:
    assert g['fully_settled'] and g['physical_conservation'] and set(g['scores'])=={'0','1','2','3'} and sum(g['scores'].values())==0
    assert g['controlled'] not in byseed[g['seed']]
    byseed[g['seed']][g['controlled']]=g
assert set(byseed)=={92611031+1009*i for i in range(32)}
clusters=[];deltas=[];latencies=[]
for seed,g in sorted(byseed.items()):
    assert set(g)=={-1,0,1,2,3} and len({r['deal_sha256'] for r in g.values()})==1
    values=[g[s]['scores'][str(s)]-g[-1]['scores'][str(s)] for s in range(4)]
    clusters.append(float(np.mean(values)));deltas.extend(values)
    for s in range(4): latencies.extend(g[s]['decision_ms'])
strength=dict(games=160,pairs=128,independent_deals=32,mean_paired_net=float(np.mean(deltas)),
    deal_cluster_95=ci(clusters),fully_settled=True,matched_initial_deals=True,
    current_decision_ms=dict(n=len(latencies),median=float(np.median(latencies)),
                            p95=float(np.quantile(latencies,.95)),maximum=max(latencies)),
    scope='One current seat against the old cash arithmetic; shared current mechanisms and queue fix. Self-play desktop; 4 seats share each original deal. No fitting on these scores.')
strength['improvement_confirmed']=strength['deal_cluster_95'][0]>0
strength['significant_regression']=strength['deal_cluster_95'][1]<0

for game in forecast['complete_games']:
    assert game['fully_settled'] and game['physical_conservation'] and set(game['scores'])=={'0','1','2','3'} and sum(game['scores'].values())==0
assert {g['seed'] for g in forecast['complete_games']}=={82611031+1009*i for i in range(48)}
observations=forecast['observations']; assert len({r['seed'] for r in observations})==len(observations)
good=[r for r in observations if r['status']=='joint_ready_projection_supported']
assert good and all(r['predictions_before_labels'] for r in observations)
wall_old=[];wall_new=[];pres_old=[];pres_new=[];ready_old=[];ready_new=[];marginal_error=[]
for r in good:
    assert r['ess']>=max(16,r['samples']/32) and r['residual']<=1e-8
    assert abs(sum(r['wall_copies'])-r['wall'])<1e-7
    assert abs(sum(r['prior_wall'])-r['wall'])<1e-7
    truth=np.asarray(r['truth_wall']); actual=(truth>0).astype(float)
    wall_old.append(float(np.mean((np.asarray(r['prior_wall'])-truth)**2)))
    wall_new.append(float(np.mean((np.asarray(r['wall_copies'])-truth)**2)))
    pres_old.append(float(np.mean((np.asarray(r['prior_presence'])-actual)**2)))
    pres_new.append(float(np.mean((np.asarray(r['presence'])-actual)**2)))
    seats=[s for s in range(4) if r['eligible'][s]]
    if seats:
        ready_old.append(float(np.mean([(r['prior_ready'][s]-r['truth_ready'][s])**2 for s in seats])))
        ready_new.append(float(np.mean([(r['ready'][s]-r['truth_ready'][s])**2 for s in seats])))
        marginal_error.extend(abs(r['ready'][s]-r['target'][s]) for s in seats)
def paired(before,after):
    return dict(before=float(np.mean(before)),after=float(np.mean(after)),
                difference=float(np.mean(np.subtract(after,before))),
                game_cluster_difference_95=ci(np.subtract(after,before)))
probabilities=dict(games=48,observations=len(observations),supported=len(good),
    refusals=dict(Counter(r['status'] for r in observations if r not in good)),
    ended_before_snapshot=sum(not r['predicted'] for r in forecast['complete_games']),
    wall_copy_mse=paired(wall_old,wall_new),wall_presence_brier=paired(pres_old,pres_new),
    ready_brier_per_game=paired(ready_old,ready_new),maximum_marginal_error=max(marginal_error,default=0),
    diagnostic_ms=dict(median=float(np.median([r['ms'] for r in good])),
                       p95=float(np.quantile([r['ms'] for r in good],.95))),
    scope='Fresh current-policy self-play states, one snapshot per game; public prediction precedes hidden evaluation labels. Paired metrics cover supported predictions only; refusals retained. Numerical marginal fit is not empirical calibration or live-ranking promotion.')

binding=read('claim-world-binding-final.json')
assert binding['matched_current_projected_hypotheses']==256
assert sha(P/'claim-worlds.json')==binding['worlds_sha256']
assert sha(P/'joint-audit-large-fixtures.json')==binding['current_pools_sha256']
worlds={r['id']:r for r in read('claim-worlds.json')['rows']}
paired_worlds=defaultdict(dict)
for r in full['rows']:
    assert r['fully_settled'] and set(r['scores'])=={'0','1','2','3'} and sum(r['scores'].values())==0
    assert r['root'] not in paired_worlds[r['id']]
    assert r['first_discard']==worlds[r['id']]['pengDiscard'] if r['root']=='peng' and r['root_applied'] else True
    paired_worlds[r['id']][r['root']]=r
assert set(paired_worlds)==set(worlds)
groups=defaultdict(list);all_groups=defaultdict(list);preempted=0
for name,rs in paired_worlds.items():
    assert set(rs)=={'pass','peng'}
    a,b=rs['pass'],rs['peng']; assert a['root_applied']==b['root_applied']
    assert a['weight']==b['weight']==1/128
    if not a['root_applied']:
        preempted+=1; assert a['scores']==b['scores'], 'Unavailable intervention must have identical outcomes'
    groups[(a['source'],a['pool'])].append((a,b));all_groups[a['source']].append((a,b))
def claim_summary(source,pairs,pool):
    pa=[a['scores']['1'] for a,b in pairs]; pe=[b['scores']['1'] for a,b in pairs]
    d=np.subtract(pe,pa)
    interval=ci(d)
    if pool=='both numerical pools':
        rng=np.random.default_rng(20261230);bootstrap=np.zeros(20000)
        strata=defaultdict(list)
        for a,b in pairs: strata[a['pool']].append(b['scores']['1']-a['scores']['1'])
        assert len(strata)==2 and all(len(x)==64 for x in strata.values())
        for values in strata.values(): bootstrap+=rng.choice(values,(20000,64)).mean(axis=1)/2
        interval=np.quantile(bootstrap,[.025,.975]).tolist()
    return dict(source=source,pool=pool,worlds=len(pairs),pass_net=float(np.mean(pa)),
                peng_net=float(np.mean(pe)),peng_minus_pass=float(np.mean(d)),
                conditional_monte_carlo_95=interval,
                preempted=sum(not a['root_applied'] for a,b in pairs))
claims=[claim_summary(source,pairs,pool) for (source,pool),pairs in sorted(groups.items())]
claims += [claim_summary(source,pairs,'both numerical pools') for source,pairs in sorted(all_groups.items())]
assert len(groups)==4 and all(len(g)==64 for g in groups.values())

# The ordinary public sampler must remain bit-identical despite the new opt-in proposal.
a=read('posterior-audit.json'); b=read('before-shape-proposal/posterior-audit.json')
assert a['rows']==b['rows'] and not a['failures']
large=read('joint-audit-large.json'); assert len(large['rows'])==8 and not large['failures']
assert all(r['report']['Supported'] and r['report']['EffectiveSamples']>=512 for r in large['rows'])
report=dict(source_files=len(read('source-freeze.json')),core_files=sum('/AI.Core/' in p for p in read('source-freeze.json')),
    cash_assertions=read('cash-tests.json')['checks'],projection_assertions=read('joint-fit-current.json')['checks'],
    ready_density_assertions=read('ready-density-current.json')['checks'],privacy_assertions=read('joint-privacy.json')['checks'],
    source_joint_ess=[r['report']['EffectiveSamples'] for r in large['rows']],
    raw_public_sampler_bit_identical=True,formal_executions=4,priority_paths=2,
    strength=strength,forecast=probabilities,conditional_claims=claims,
    conditional_games=512,root_preempted_worlds=preempted,
    queue_deferrals=sum(r['deferred_count'] for r in full['rows']),
    provenance='Source, runner and DLL hashes bound. Archived attempts are not counted as completed cohorts. Book cases are controlled reconstructions, not the original unknown hidden game.')
(P/'final-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(dict(strength=strength,forecast=probabilities,claims=claims,queue_deferrals=report['queue_deferrals']),ensure_ascii=False,indent=2))
