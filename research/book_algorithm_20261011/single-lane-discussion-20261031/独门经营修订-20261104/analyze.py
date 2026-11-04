import collections,gzip,hashlib,json,pathlib,random,statistics,sys
p=pathlib.Path(__file__).parent
sys.path.insert(0,str(pathlib.Path.cwd()/'research/book_algorithm_20261011/single-lane-phased-20261102'))
import independent_audit as audit
jobs=json.loads((p/'jobs.json').read_text())
variants=['current','before_round2_v1']
status=dict(x.split() for x in (p/'paired.log').read_text().splitlines())
rows=[]
mechanism=collections.Counter()
for idx,(cohort,seat,seeds) in enumerate(jobs):
    for rival in variants:
        data={}
        for arm in ('old','new'):
            tag=f'{idx}-{arm}-{rival}'
            assert status[tag]=='0',tag
            d=json.loads((p/tag/'rounds.json').read_text())
            assert [(r['seed'],r['seat']) for r in d['rows']]==[(s,seat) for s in seeds]
            for row in d['rows']:
                evidence=row['arm']['native_replay_path']
                row['arm']['native_replay_path']=str(p/tag/'audits'/pathlib.Path(evidence).name)
            data[arm]=(d['core_identity'],d['rows'])
        assert data['old'][0]!=data['new'][0]
        for old,new in zip(data['old'][1],data['new'][1]):
            a,b=old['arm'],new['arm']
            for k in ('initial_wall_hash','initial_world_hash','opening_declared_wall_sha256','opening_missing_suits'):assert a[k]==b[k],(k,old['seed'])
            for r in (a,b):
                assert r['completed'] and r['physical_checks']['passed'] and r['checkpoint_legality']['passed']
                assert r['ledger_balanced'] and not r['step_error'] and not r['native_replay_error'] and not r['uses_hidden_information']
                audit.ledger(r)
            oldtrace,oldinfo=audit.trace(a,seat,'old')
            newtrace,newinfo=audit.trace(b,seat,'new')
            first=audit.first_change(oldtrace,newtrace,seat)
            rows.append(dict(cohort=cohort,seat=seat,seed=old['seed'],rival=rival,old=a['seat_delta'],new=b['seat_delta'],
                 old_hu=a['hu'],new_hu=b['hu'],old_lane_ready=oldinfo['first_public_live_lane_wait_wall']>=0,
                 new_lane_ready=newinfo['first_public_live_lane_wait_wall']>=0,first_change=first))
            with gzip.open(b['native_replay_path']+'.gz','rb') as stream:
                for e in audit.prefix_entries(stream,hashlib.sha256(),b['native_replay_sha256']):
                    response=e['response']
                    for code in ('PHASED_SINGLE_LANE_PREFER_AUXILIARY','PHASED_SINGLE_LANE_PREFER_READY_WAIT'):
                        if code in response:
                            assert json.loads(e['request']).get('seatIndex')==seat
                            mechanism[code+'_responses']+=1
rng=random.Random(20261104)
summary={}
for cohort in ('general','conditional'):
    subset=[r for r in rows if r['cohort']==cohort]
    by_seed=collections.defaultdict(list)
    for r in subset:by_seed[r['seed']].append(r['new']-r['old'])
    sample=[statistics.mean(v) for v in by_seed.values()]
    assert all(len(v)==2 for v in by_seed.values())
    if cohort=='general':
        # 160 natural deals, seat sampled uniformly, verified opening has at most one eligible seat.
        sample=[v/4 for v in sample]+[0]*(160-len(sample))
    boot=sorted(statistics.mean(rng.choices(sample,k=len(sample))) for _ in range(10000))
    summary[cohort]=dict(pairs=len(subset),deals=len(sample),mean=statistics.mean(sample),ci95=[boot[250],boot[9749]],
       changed=sum(r['first_change'] is not None for r in subset),positive=sum(r['new']>r['old'] for r in subset),
       negative=sum(r['new']<r['old'] for r in subset),
       old_hu=sum(r['old_hu'] for r in subset),new_hu=sum(r['new_hu'] for r in subset),
       old_lane_ready=sum(r['old_lane_ready'] for r in subset),new_lane_ready=sum(r['new_lane_ready'] for r in subset),
       rivals={v:statistics.mean([r['new']-r['old'] for r in subset if r['rival']==v]) for v in variants})
result=dict(summary=summary,mechanism=mechanism,rows=rows)
(p/'paired-analysis.json').write_text(json.dumps(result,indent=2))
print(json.dumps(dict(summary=summary,mechanism=mechanism),indent=2))
