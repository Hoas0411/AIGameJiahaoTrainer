from pathlib import Path
import os, subprocess, json, re, time

ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'game'
LOG=ROOT/'delivery/checks'
LOG.mkdir(parents=True,exist_ok=True)
env=dict(os.environ)
for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
    p=ROOT/'local-data'/key.lower();p.mkdir(parents=True,exist_ok=True);env[key]=str(p)
gd=ROOT/'runtime/godot/Godot_v4.7.2-stable_win64.exe'

def run(name,args,timeout=600):
    result=subprocess.run([str(gd),*args],cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=timeout,creationflags=0x08000000 if os.name=='nt' else 0)
    output=result.stdout+result.stderr
    (LOG/(name+'.log')).write_text(output,encoding='utf-8')
    errors=re.findall(r'(?m)^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:).+',output)
    step={'name':name,'exit_code':result.returncode,'errors':errors,'passed':result.returncode==0 and not errors}
    print(name,step['passed'],'errors=',len(errors),flush=True)
    return step,output

steps=[]
s,_=run('version',['--version']);steps.append(s)
s,_=run('fresh-import',['--headless','--path',str(GAME),'--editor','--import','--quit'],900);steps.append(s)
s,output=run('all-active-courses',['--headless','--audio-driver','Dummy','--path',str(GAME),'--script','res://scripts/tests/handoff_smoke.gd'],180)
s['passed']=s['passed'] and 'HANDOFF_SMOKE_PASS' in output;steps.append(s)
report={'snapshot_date':'2026-10-08','passed':all(x['passed'] for x in steps),'steps':steps,'user_data':'local-data inside the bundle; original player data untouched','scope':['fresh Godot import','main scene instantiation','sequential session initialization for all nine active course IDs','no private config or archived builds used'],'not_covered':['human play/feel','visual quality approval','online AI/voice','complete existing historical smoke suites','training transfer efficacy']}
(ROOT/'delivery/verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
raise SystemExit(0 if report['passed'] else 1)
