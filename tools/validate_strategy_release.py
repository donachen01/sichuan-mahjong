#!/usr/bin/env python3
"""Release provenance gate, not a default regression suite. Does not rerun experiments."""
import argparse, hashlib, json, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/research'))
from strategy_delivery_validation import binding

def validate(path):
    m=json.loads(path.read_text())
    if m.get('schema_version')!=1 or m.get('production_policy_variant')!='current': raise ValueError('invalid production policy identity')
    if m.get('source_sha256')!=binding(ROOT)['sha256']: raise ValueError('strategy/rules/bridge sources changed; new research validation is required')
    if m.get('production_recording') is not False or m.get('production_terminal_rollout') is not False: raise ValueError('production research work enabled')
    if m.get('scope')!='correctness_corrections_only' and m.get('scope')!='strength_promoted': raise ValueError('unreviewed release scope')
    for relative,expected in m.get('release_inputs',{}).items():
        if hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()!=expected: raise ValueError('release tooling/filter changed: '+relative)
    opponents=set()
    for evidence in m['evidence']:
        p=ROOT/evidence['path']
        if hashlib.sha256(p.read_bytes()).hexdigest()!=evidence['sha256']: raise ValueError('release evidence changed: '+str(p))
        if evidence['kind']=='full_game':
            r=json.loads(p.read_text())
            if r.get('candidate_source_sha256')!=m['source_sha256'] or r.get('candidate_policy_variant')!='current' or r.get('opponent_version')!=evidence['opponent']: raise ValueError('release comparison is not the exact current production policy')
            if not r['integrity_passed']: raise ValueError('incomplete or invalid full games')
            opponents.add(evidence['opponent'])
            if m['scope']=='strength_promoted' and not r['strength']['promotable']: raise ValueError('unpromoted strategy')
    if len(opponents)<2: raise ValueError('missing independent declared opponent comparisons')
    if m['scope']=='correctness_corrections_only' and m.get('unpromoted_policy_variants')!=['bucket_local_candidate_v1','gang_branch_candidate_v1']: raise ValueError('experimental bucket and gang selectors must remain isolated')
    print('Strategy release provenance verified; production rollout=off recording=off; scope='+m['scope'])
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--manifest',type=Path,default=ROOT/'research/strategy-release.json');a=p.parse_args()
    try: validate(a.manifest)
    except (ValueError,KeyError,OSError) as e: sys.exit('Strategy release blocked: '+str(e))
