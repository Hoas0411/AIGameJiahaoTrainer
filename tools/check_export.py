from pathlib import Path
import subprocess,os,json,re
ROOT=Path(__file__).resolve().parents[1]
build=sorted((ROOT/'exports').iterdir())[-1]
logs=ROOT/'delivery/checks/exported';logs.mkdir(parents=True,exist_ok=True)
env=dict(os.environ)
for name in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
    p=ROOT/'local-data/export-check'/name.lower();p.mkdir(parents=True,exist_ok=True);env[name]=str(p)
steps=[]
for id in [12,0,19,15,13,6,7,8,20]:
    r=subprocess.run([str(build/'JiahaoTrainer.exe'),'--headless','--quit-after','20','--','--training-drill='+str(id)],env=env,cwd=build,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120,creationflags=0x08000000)
    output=r.stdout+r.stderr
    (logs/(str(id)+'.log')).write_text(output,encoding='utf-8')
    errors=re.findall(r'(?m)^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:).+',output)
    ok=r.returncode==0 and not errors
    steps.append({'course_id':id,'exit_code':r.returncode,'errors':errors,'passed':ok})
    print('EXPORT_COURSE',id,ok,flush=True)
result={'passed':all(s['passed'] for s in steps),'steps':steps,'build':build.name,'scope':'exported Windows EXE/PCK headless startup with each course requested; 20 frames; no original config/archive paths'}
(ROOT/'delivery/export-verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
raise SystemExit(0 if result['passed'] else 1)
