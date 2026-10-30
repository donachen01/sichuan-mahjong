"""Task-local split calibration. Held-out games never select parameters."""
from pathlib import Path
from collections import defaultdict
import json,math,re,hashlib,sys
import numpy as np
P=Path(__file__).resolve().parent
block=(P/'before/SichuanReadinessCalibration.cs').read_text().split('Weights = {',1)[1].split('};',1)[0]
OLD=np.array([float(x) for x in re.findall(r'-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?',block)])
assert len(OLD)==10

def load(part):
 j=json.loads((P/(part+'.json')).read_text());assert not j.get('failure');assert all(g['fully_settled'] and g['physical_conservation'] and sum(g['scores'].values())==0 for g in j['complete_games'])
 r=j['observations'];f=np.array([x['features'] for x in r]);p=np.clip(f[:,0],.001,.999)
 X=np.column_stack([np.ones(len(r)),np.log(p/(1-p)),(60-f[:,1])/60,f[:,2]/4,f[:,3]/12,f[:,5]/4,f[:,6]/4,f[:,7]/4,f[:,8],f[:,9]])
 y=np.array([x['truth'] for x in r]);actual=np.array([x['actual_deployed_probability'] for x in r]);ids=np.array([x['seed'] for x in r]);old=sig(X@OLD)
 error=float(np.max(np.abs(actual-old)));assert error<2e-12,('V2 actual posterior/formula mismatch',error)
 assert all(x['prediction_before_label'] for x in r)
 return dict(rows=r,X=X,y=y,raw=f[:,0],old=old,ids=ids,formula_maximum_error=error,games=len(j['complete_games']))
def sig(z):return 1/(1+np.exp(-np.clip(z,-35,35)))
def per_game(v,ids):return np.array([np.mean(v[ids==i]) for i in np.unique(ids)])
def metrics(data,p,reference=None):
 y=data['y'];loss=(p-y)**2;ll=-y*np.log(np.clip(p,1e-12,1))-(1-y)*np.log(np.clip(1-p,1e-12,1));out=dict(n=len(y),games=data['games'],brier=float(loss.mean()),game_mean_brier=float(per_game(loss,data['ids']).mean()),log_loss=float(ll.mean()),bins=[])
 for lo in np.arange(0,1,.2):
  m=(p>=lo)&(p<min(1.0000000001,lo+.2))
  if m.any():out['bins'].append(dict(lower=round(float(lo),1),n=int(m.sum()),prediction=float(p[m].mean()),truth=float(y[m].mean())))
 if reference is not None:
  d=per_game(loss-(reference-y)**2,data['ids']);rng=np.random.default_rng(20261101);boot=np.mean(rng.choice(d,(5000,len(d))),axis=1)
  out.update(game_paired_brier_delta=float(d.mean()),cluster_bootstrap_95=[float(x) for x in np.quantile(boot,[.025,.975])])
  oldll=-y*np.log(np.clip(reference,1e-12,1))-(1-y)*np.log(np.clip(1-reference,1e-12,1));out['game_paired_log_loss_delta']=float(per_game(ll-oldll,data['ids']).mean())
  m=reference>=.55
  out['old_high_threat_subset']=dict(n=int(m.sum()),brier_delta=float(np.mean(loss[m]-(reference[m]-y[m])**2)) if m.any() else None)
 return out

def fit(d,penalty):
 X=d['X'];y=d['y'];ids=d['ids'];unique=np.unique(ids);w=np.array([1/(len(unique)*np.sum(ids==g)) for g in ids]);theta=OLD.copy();ridge=np.full(10,penalty);ridge[0]=0
 def objective(t):
  z=X@t;return float(np.sum(w*(np.logaddexp(0,z)-y*z))+.5*np.sum(ridge*(t-OLD)**2))
 for iteration in range(60):
  pr=sig(X@theta);g=X.T@(w*(pr-y))+ridge*(theta-OLD);h=X.T@((w*pr*(1-pr))[:,None]*X)+np.diag(ridge)+np.eye(10)*1e-10
  step=np.linalg.solve(h,g);rate=1;prior=objective(theta)
  while objective(theta-rate*step)>prior and rate>1e-7:rate*=.5
  theta-=rate*step
  if np.max(np.abs(rate*step))<1e-9:break
 return theta

def training():
 t=load('train');v=load('validation');assert not set(t['ids'])&set(v['ids'])
 fitted=[]
 for penalty in [.01,.1,1.0]:
  w=fit(t,penalty);fitted.append(dict(penalty=penalty,weights=w.tolist(),validation=metrics(v,sig(v['X']@w),v['old'])))
 selected=min(fitted,key=lambda c:c['validation']['game_mean_brier'])
 report=dict(old_weights=OLD.tolist(),selected=selected,all_candidates=fitted,train=dict(raw=metrics(t,t['raw']),actual=metrics(t,t['old'])),validation=dict(raw=metrics(v,v['raw']),actual=metrics(v,v['old'])),formula_checks={'train':t['formula_maximum_error'],'validation':v['formula_maximum_error']},train_sha256=hashlib.sha256((P/'train.json').read_bytes()).hexdigest(),validation_sha256=hashlib.sha256((P/'validation.json').read_bytes()).hexdigest(),holdout_used=False)
 (P/'frozen-fit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'penalty':selected['penalty'],'validation_delta':selected['validation']['game_paired_brier_delta'],'train_n':len(t['y']),'validation_n':len(v['y'])}))
def holdout():
 f=json.loads((P/'frozen-fit.json').read_text());d=load('holdout');w=np.array(f['selected']['weights']);p=sig(d['X']@w);m=metrics(d,p,d['old']);passed=m['cluster_bootstrap_95'][1]<0 and m['game_paired_log_loss_delta']<=.005 and m['old_high_threat_subset']['n']>=30 and m['old_high_threat_subset']['brier_delta']<=.005
 report=dict(raw=metrics(d,d['raw']),actual=metrics(d,d['old']),candidate=m,formula_maximum_error=d['formula_maximum_error'],promotion_gate_passed=bool(passed),fit_sha256=hashlib.sha256((P/'frozen-fit.json').read_bytes()).hexdigest(),scope='Independent complete self-play games. No human calibration claim; previous round raw scores are not deployed-posterior metrics.')
 (P/'holdout-evaluation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'actual_brier':report['actual']['brier'],'candidate_brier':m['brier'],'delta_ci':m['cluster_bootstrap_95'],'promotion_gate_passed':bool(passed)}))
if __name__=='__main__':training() if sys.argv[1]=='fit' else holdout()
