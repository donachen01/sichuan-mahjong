"""One-off, reproducible readiness calibration experiment; no hidden policy inputs."""
import argparse, json, math, random, statistics
from collections import defaultdict
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('input', type=Path)
parser.add_argument('output', type=Path)
parser.add_argument('--frozen-fit', type=Path)
args = parser.parse_args()
rows = json.loads(args.input.read_text())['readiness_observations']

def features(row):
    p, wall, melds, discards, age, hand, draw, central, missing, cleared = row['features']
    p = min(.999, max(.001, p))
    return [1, math.log(p/(1-p)), (60-wall)/60, melds/4, discards/12,
            hand/4, draw/4, central/4, missing, cleared]

def sigmoid(z):
    return 1/(1+math.exp(-min(35, max(-35, z))))

def predict(row, weights):
    return sigmoid(sum(a*b for a,b in zip(features(row), weights)))

def fit(data, penalty):
    w = [0.0, 1.0]+[0.0]*8
    counts = defaultdict(int)
    for r in data: counts[r['round']] += 1
    samples = [(features(r), r['truth'], 1/(len(counts)*counts[r['round']])) for r in data]
    for _ in range(1600):
        grad = [0.0]*len(w)
        for x,y,weight in samples:
            err = (sigmoid(sum(a*b for a,b in zip(x,w)))-y)*weight
            for j in range(len(w)): grad[j] += err*x[j]
        for j in range(len(w)):
            prior = 1.0 if j == 1 else 0.0
            w[j] -= .25*(grad[j]+(penalty*(w[j]-prior) if j else 0))
    return w

def metrics(data, weights=None):
    bins = defaultdict(list)
    errors = defaultdict(list)
    base = defaultdict(list)
    for r in data:
        p = predict(r, weights) if weights is not None else r['features'][0]
        y = r['truth']
        bins[min(9,int(p*10))].append((p,y))
        errors[r['round']].append((p-y)**2)
        base[r['round']].append((r['features'][0]-y)**2)
    per_round = [statistics.mean(v) for v in errors.values()]
    delta = [statistics.mean(errors[g])-statistics.mean(base[g]) for g in errors]
    rng = random.Random(20260928)
    boot = sorted(statistics.mean(rng.choices(delta,k=len(delta))) for _ in range(2000))
    return {'observations':len(data), 'rounds':len(errors),
        'brier': sum(sum(v) for v in errors.values())/len(data),
        'round_mean_brier':statistics.mean(per_round),
        'round_paired_brier_delta_ci95':[boot[49],boot[1949]],
        'bins':[{'lower':k/10,'count':len(v),'predicted':statistics.mean(x[0] for x in v),
                 'observed':statistics.mean(x[1] for x in v)} for k,v in sorted(bins.items())]}

if args.frozen_fit:
    fitted = json.loads(args.frozen_fit.read_text())
    report = {'input':str(args.input), 'frozen_fit':str(args.frozen_fit),
              'baseline':metrics(rows), 'candidate':metrics(rows,fitted['weights']),
              'scope':'Independent complete games; no fitting or parameter selection on these observations.'}
    args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('baseline','candidate')}))
    raise SystemExit(0)

# Entire games are held out; successive turns from the same game never cross splits.
train = [r for r in rows if r['round']<=20]
validation = [r for r in rows if 21<=r['round']<=26]
holdout = [r for r in rows if r['round']>=27]
fits = [(p,fit(train,p)) for p in [.01,.1,1.0]]
penalty, weights = min(fits,key=lambda item:metrics(validation,item[1])['round_mean_brier'])
report = {'input':str(args.input), 'feature_order':['intercept','baseline_logit','wall_elapsed','meld_fraction',
    'discard_fraction','recent_hand_fraction','recent_draw_fraction','recent_central_fraction','last_missing','cleared'],
    'penalty':penalty,'weights':weights,'split':{'training':'rounds 1-20','validation':'21-26','holdout':'27-32'},
    'baseline_holdout':metrics(holdout),'candidate_holdout':metrics(holdout,weights),
    'baseline_validation':metrics(validation),'candidate_validation':metrics(validation,weights),
    'scope':'Self-play diagnostics only; six held-out games are not evidence of general human-opponent calibration.'}
args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['baseline_validation','candidate_validation']},ensure_ascii=False))
