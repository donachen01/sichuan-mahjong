import concurrent.futures as cf, hashlib, json, os, pathlib, subprocess, sys
p=pathlib.Path(__file__).parent
plan=json.load(open(sys.argv[1]))
jobs=[]
for cohort,rows in plan['cohorts'].items():
    rows=([r for r in rows[:160] if r['eligible_target']>=0] if cohort=='general' else rows[:40])
    for seat in range(4):
        seeds=[r['seed'] for r in rows if r['eligible_target']==seat]
        for n in range(0,len(seeds),8):
            jobs.append((cohort,seat,seeds[n:n+8]))
(p/'jobs.json').write_text(json.dumps(jobs))
godot='/Applications/Godot.NET.app/Contents/MacOS/Godot'
def run(job):
    idx,(cohort,seat,seeds),arm,rival=job
    d=p/f'{idx}-{arm}-{rival}'; d.mkdir(exist_ok=True)
    config=d/'config.json'; config.write_text(json.dumps(dict(seeds=seeds,seats=[seat])))
    env=dict(os.environ,DOTNET_ROOT='/opt/homebrew/opt/dotnet/libexec',SICHUAN_STUDY_TARGET_SEAT=str(seat),SICHUAN_STUDY_RAW_AUDIT='1',SICHUAN_RESEARCH_RECORD_ROOT=str(d/'records'),SICHUAN_RESEARCH_AUDIT_DIR=str(d/'audits'))
    with (d/'console.log').open('w') as log:
        result=subprocess.run([godot,'--headless','--path',str(p/arm),'--log-file',str(d/'engine.log'),'--script','res://runner.gd','--','--research-recording=true',f'--config={config}',f'--arm={arm}',f'--opponent-variant={rival}',f'--output={d/"rounds.json"}'],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=1800)
    print(d.name,result.returncode,flush=True)
    return result.returncode
with cf.ThreadPoolExecutor(max_workers=8) as pool:
    status=list(pool.map(run,[(idx,j,arm,rival) for idx,j in enumerate(jobs) for rival in ['current','before_round2_v1'] for arm in ['old','new']]))
sys.exit(any(status))
