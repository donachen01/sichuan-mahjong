from pathlib import Path
import hashlib,json
P=Path(__file__).resolve().parent
J=lambda p:json.loads(p.read_text())
freeze=J(P/'source-freeze.json')
for group in ['core_sources','runtime_sources','binaries']:
 for f,h in freeze[group].items():assert hashlib.sha256(Path(f).read_bytes()).hexdigest()==h,('source changed',f)
sections=['6.2','6.3','6.4.1','6.4.2','6.5.1','6.5.2','6.5.2-dynamic','7.1-tables','7.2','conditional-claims']
rows=[];mismatches=[];guard_failures=[];paired_claim_gates=[];changes=[]
for section in sections:
 p=P/section;a=J(p/'formal.json');b=J(p/'execution.json');f=J(p/'formal-fixtures.json')
 assert not a['failures'] and not b['failures'],section
 formal={r['id']:r for r in a['rows']};actual={r['source']:r for r in b['rows']}
 assert set(formal)==set(actual)==set(f),section
 before=J(p/'pre-closure.json') if (p/'pre-closure.json').exists() else None
 old={r['id']:r for r in before['rows']} if before else {}
 for id,x in formal.items():
  r=actual[id];expected=x['action'].lower()
  if expected=='hu' and f[id].get('offered',-1)<0:expected='self_hu'
  if expected!=r['action'] or x['tile']!=r['command']['tile'] or expected=='peng' and x['child']!=r['command']['continuationTile']:mismatches.append((section,id))
  v=x.get('values',{})
  if isinstance(v,dict):
   for c in v.get('candidates',[]):
    reasons=[s for s in c['ReasonCodes'] if s.startswith('PUBLIC_CLAIM_PAIRED_')]
    if reasons:paired_claim_gates.append(dict(section=section,id=id,mean=c['ExpectedNetScore'],admissible=c['IsAdmissible'],reason=reasons))
    if reasons and not c['IsAdmissible'] and x['action']=='Peng':guard_failures.append(id)
  if id in old:
   prior=old[id];pick=lambda y:[y['action'],y['tile'],y['child']]
   if pick(prior)!=pick(x):changes.append(dict(section=section,id=id,before=pick(prior),after=pick(x)))
 rows.append(dict(section=section,formal=len(formal),physical=len(actual),failures=0))
assert not mismatches and not guard_failures
stopping=J(P/'stopping-executable/formal.json');assert not stopping['failures']
for f in ['stopping-execution/execution.json','protocol-controls/matrix.json']:
 x=J(P/f);assert not x['failures'],f
natural=J(P/'natural-unified-summary.json');assert natural['games']==64 and natural['pairs']==32
independent={f:J(P/f) for f in ['stopping-current.json','joint-acquisition-current.json','graphs-independent.json','retention-independent.json']}
assert all(not x['failures'] for x in independent.values())
artifacts=['source-freeze.json','natural-preregistration.json','natural-unified.json','natural-unified-summary.json','stopping-executable/formal.json','stopping-execution/execution.json','protocol-controls/matrix.json']
artifacts+=list(independent)
artifacts+=[str(Path(sec)/f) for sec in sections for f in ['formal.json','formal-fixtures.json','execution.json']]
audit=dict(scope='task-local evidence, not a future regression list',core_sources=len(freeze['core_sources']),binaries_equal=len(set(freeze['binaries'].values()))==1,sections=rows,additional_Csharp_reactions=len(stopping['rows']),new_stopping_assessments=sum('PUBLIC_READY_STOPPING_WITH_PASS_HU_LOCK' in r['reasons'] for r in stopping['rows']),physical_total=sum(r['physical'] for r in rows)+len(J(P/'stopping-execution/execution.json')['rows'])+len(J(P/'protocol-controls/matrix.json')['rows']),independent_checks=sum(x['checks'] for x in independent.values()),policy_execution_mismatches=mismatches,claim_gate_failures=guard_failures,paired_claim_gate_count=len(paired_claim_gates),natural=natural,artifacts={f:hashlib.sha256((P/f).read_bytes()).hexdigest() for f in artifacts})
(P/'evidence-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
(P/'paired-claim-gates.json').write_text(json.dumps(paired_claim_gates,ensure_ascii=False,indent=2)+'\n')
(P/'same-input-policy-changes.json').write_text(json.dumps(changes,ensure_ascii=False,indent=2)+'\n')
print('FINAL AUDIT',json.dumps({k:audit[k] for k in ['core_sources','binaries_equal','additional_Csharp_reactions','new_stopping_assessments','physical_total','independent_checks','policy_execution_mismatches','claim_gate_failures','paired_claim_gate_count']},ensure_ascii=False))
