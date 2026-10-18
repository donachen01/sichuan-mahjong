#!/usr/bin/env python3
"""Bind isolated full-game runs to frozen strategy/rules sources and preserve counterexamples."""
import argparse, gzip, hashlib, json, shutil, sys, os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def sources(root):
    paths = list((root/'dotnet/AI.Core').rglob('*.cs')) + list((root/'scripts').rglob('*.gd')) + list((root/'autoload').rglob('*.gd'))
    paths += [root/'scripts/ai/SichuanCSharpRuntime.cs',root/'scripts/ai/SichuanDecisionAuditRuntime.cs',root/'SichuanMahjong.Godot.csproj']
    return {str(p.relative_to(root)): sha(p) for p in sorted(paths) if not {'bin','obj'}.intersection(p.relative_to(root).parts)}
def binding(root):
    files=sources(root)
    return {'files':files,'sha256':hashlib.sha256(json.dumps(files,sort_keys=True).encode()).hexdigest()}
def strategy_identity(source_sha256, policy_variant):
    return hashlib.sha256(json.dumps({'source_sha256':source_sha256,'policy_variant':policy_variant},sort_keys=True).encode()).hexdigest()
def validate(plan_path, baseline_path, candidate_path, output):
    plan=json.loads(plan_path.read_text()); old=json.loads(baseline_path.read_text()); new=json.loads(candidate_path.read_text())
    candidate_source=plan.get('candidate_source_sha256',plan['candidate_version'])
    baseline_source=plan.get('baseline_source_sha256',plan['baseline_version'])
    if binding(ROOT)['sha256'] != candidate_source: raise ValueError('candidate sources changed during measurement')
    if binding(Path(plan['baseline_project']))['sha256'] != baseline_source: raise ValueError('baseline sources changed during measurement')
    for name,source,variant in [('baseline',baseline_source,'current'),('candidate',candidate_source,plan.get('candidate_policy_variant','bucket_local_candidate_v1'))]:
        if name+'_source_sha256' in plan and plan[name+'_version']!=strategy_identity(source,variant):
            raise ValueError('strategy version does not bind the actual source and runtime policy variant')
    if old['opponent'] != plan['opponent_version'] or new['opponent'] != plan['opponent_version']: raise ValueError('opponent changed')
    pairs={}; rows=[]; failures=[]; bucket=0; arbitration=0; archives={}; replay_index=[]; previous_triggers={}
    mechanism=plan.get('mechanism_reason_code','BUCKET_LOCAL_DOMINANCE')
    markers=[mechanism]
    if mechanism=='GANG_RULE_CASHFLOW': markers.append('GANG_IMMEDIATE_RULE_GAIN_')
    archive_root=os.environ.get('SICHUAN_RESEARCH_ARCHIVE_DIR')
    outdir=Path(archive_root) if archive_root else output.parent/'replays';outdir.mkdir(parents=True,exist_ok=True)
    for name,report in [('baseline',old),('candidate',new)]:
        for item in report['rows']:
            seed,seat=item['seed'],item['seat'];arm=item['arm'];key=(seed,seat)
            expected_variant=plan.get('candidate_policy_variant','bucket_local_candidate_v1') if name=='candidate' else 'current'
            if arm['policy']!=expected_variant: raise ValueError('runtime policy variant changed')
            if name in pairs.setdefault(key,{}): raise ValueError('duplicate arm')
            pairs[key][name]=arm
            if not (arm['completed'] and not arm['forced_stop'] and arm['ledger_balanced'] and arm['checkpoint_legality']['passed'] and arm['game_origin']=='natural_full_round'):
                failures.append(f'{name}:{seed}:{seat}:game_integrity')
            replay=Path(arm.get('native_replay_path',''))
            if not replay.is_file() or arm.get('native_replay_error'): raise ValueError(f'invalid full native replay: {name}:{key}')
            # A shared native host appends multiple rounds to one file. Each arm
            # committed a SHA256 of its complete prefix at settlement. Preserve
            # the full immutable file once and verify every committed prefix.
            if str(replay) not in archives:
                dest=outdir/f'{plan_path.stem}-{name}-full.jsonl.gz'
                expected={x['arm']['native_replay_sha256'] for x in report['rows'] if x['arm']['native_replay_path']==str(replay)}
                prefixes={};digest=hashlib.sha256();length=0;trigger_counts=[0,0,0,0]
                with replay.open('rb') as stream, gzip.open(dest,'wb',compresslevel=6) as compressed:
                    for line in stream:
                        compressed.write(line)
                        digest.update(line);length+=len(line);h=digest.hexdigest()
                        if any(marker.encode() in line for marker in markers):
                            entry=json.loads(line)
                            if entry.get('method','').startswith('Analyze') and any(marker in entry.get('response','') for marker in markers):
                                request=json.loads(entry['request']);seat_index=request.get('seatIndex',-1)
                                eligible=mechanism!='GANG_BRANCH_READY_VALUE_WEIGHTED_BEFORE_ROUNDING' or request.get('wallCount',0)<=8
                                if eligible and 0<=seat_index<4:trigger_counts[seat_index]+=1
                        if h in expected: prefixes[h]=(length,trigger_counts.copy())
                archives[str(replay)]=(dest,prefixes)
            dest,prefixes=archives[str(replay)];prefix_sha=arm['native_replay_sha256']
            if prefix_sha not in prefixes: raise ValueError(f'replay prefix changed: {name}:{key}')
            replay_index.append({'seed':seed,'seat':seat,'arm':name,'path':str(dest.absolute().relative_to(ROOT)) if dest.absolute().is_relative_to(ROOT) else str(dest.absolute()),
                                 'compression':'gzip','prefix_unit':'uncompressed_bytes','prefix_bytes':prefixes[prefix_sha][0],'prefix_sha256':prefix_sha})
            reasons=[e for e in arm.get('ai_mechanism_events',[]) if e.get('seat')==seat]
            b=sum(e['reason_code']==mechanism for e in reasons)
            if mechanism!='BUCKET_LOCAL_DOMINANCE':
                counts=prefixes[prefix_sha][1];prior_counts=previous_triggers.get(str(replay),[0,0,0,0]);b=counts[seat]-prior_counts[seat];previous_triggers[str(replay)]=counts
            a=sum(e['reason_code']=='ARBITRATION_LEGALITY_SAFETY_PLAN_VALUE' for e in reasons)
            if name=='candidate': bucket+=b;arbitration+=a
            rows.append({'group_id':f'natural-seed-{seed}','seed':seed,'seat':seat,'arm':name,'version':plan[name+'_version'],
                'rules_sha256':plan['rules_sha256'],'opponent_version':plan['opponent_version'],'game_origin':arm['game_origin'],
                'completed':arm['completed'],'uses_hidden_information':arm['uses_hidden_information'],
                'initial_wall_sha256':arm['initial_wall_hash'],'replay_sha256':prefix_sha,'net_score':arm['seat_delta'],
                'deal_in_rate':arm['deal_in_rate'],'latency_p95_ms':arm['mechanism_decision_latency_p95_ms'],
                'mechanism_trigger_count':b if name=='candidate' else 0})
    expected={(seed,seat) for seed in plan['seeds'] for seat in range(4)}
    if set(pairs)!=expected or any(set(p)!= {'baseline','candidate'} for p in pairs.values()): raise ValueError('missing frozen arm/seed/seat')
    for key,p in pairs.items():
        if p['baseline']['initial_wall_hash']!=p['candidate']['initial_wall_hash'] or p['baseline']['initial_world_hash']!=p['candidate']['initial_world_hash']: failures.append(f'{key}:different_initial_world')
    sys.path.insert(0,str(ROOT/'.codex/skills/sichuan-mahjong-video-deep-learning/scripts'))
    from evaluate_paired_strength import plan_hash,evaluate
    runs={'plan_sha256':plan_hash(plan),'started_at':min(old['started_at'],new['started_at']),'measurement_kind':'full_game_settlement',
          'rows':rows,'integrity':{'complete_arms':len(rows),'failures':len(failures)}}
    result=evaluate(plan,runs)
    diffs=[{'seed':k[0],'seat':k[1],'delta':p['candidate']['seat_delta']-p['baseline']['seat_delta']} for k,p in pairs.items()]
    report={'candidate_source_sha256':candidate_source,'baseline_source_sha256':baseline_source,
            'candidate_policy_variant':new['rows'][0]['arm']['policy'],'opponent_version':plan['opponent_version'],
            'integrity_passed':not failures,'failures':failures,'mechanism_reason_code':mechanism,'candidate_mechanism_decisions':bucket,'candidate_bucket_final_decisions':bucket if mechanism=='BUCKET_LOCAL_DOMINANCE' else 0,'candidate_arbitrated_decisions':arbitration,
            'strength':result,'counterexamples':sorted((d for d in diffs if d['delta']<0),key=lambda d:d['delta']), 'paired_deltas':diffs,'replay_index':replay_index,
            'interpretation':'limited heldout full-game experiment; no expert mastery claim; unpromoted mechanisms stay research-only'}
    output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    output.with_suffix('.runs.json').write_text(json.dumps(runs,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ['paired_deltas','counterexamples','replay_index']},ensure_ascii=False))
    return 0 if not failures else 1
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('plan',type=Path);p.add_argument('baseline',type=Path);p.add_argument('candidate',type=Path);p.add_argument('output',type=Path);a=p.parse_args()
    try: sys.exit(validate(a.plan,a.baseline,a.candidate,a.output))
    except (ValueError,KeyError,OSError) as e: sys.exit(str(e))
