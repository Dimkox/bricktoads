"""Replay the frozen project regressions and retain a compact course-prop receipt."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/2026-11-11-course-traps/validation.json'
PRIOR=ROOT/'reports/2026-11-11-full-campaign-cast-audio/validation-clinger-final.json'
PYTHON='.tools/python-3.13.9/python.exe'
LUAU='.tools/luau-0.745/luau.exe'
COMPILER='.tools/luau-0.745/luau-compile.exe'
STARTER_SHA='1974f25e1af043f3d4a1fe581b5ec9ac818394ac4bc7a747e6fe0ca1f7b5c353'


def stamp():return datetime.now(timezone.utc).isoformat()
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory():
    files={p.relative_to(ROOT).as_posix():sha(p)
           for directory in ('src','tests','tools') for p in (ROOT/directory).rglob('*')
           if p.is_file() and p.suffix in ('.lua','.luau','.py')}
    return {'count':len(files),'sha256':hashlib.sha256(json.dumps(files,sort_keys=True,separators=(',',':')).encode()).hexdigest(),
            'files':files}


def source_receipt(path):
    root=ET.fromstring(path.read_bytes());sources=[];build_info=[]
    def collect(parent,prefix):
        for child in parent.findall('Item'):
            name=child.findtext("Properties/string[@name='Name']")
            current=prefix+'/'+name
            text=child.findtext("Properties/ProtectedString[@name='Source']")
            if text is not None:
                if name=='BuildInfo':build_info.append(text)
                else:sources.append({'path':current,'class':child.attrib['class'],'source':text})
            collect(child,current)
    collect(root,'')
    assert len(build_info)==1,'Expected one BuildInfo'
    declared=re.search("sourceSha256='([a-f0-9]{64})'",build_info[0]).group(1)
    actual=hashlib.sha256(json.dumps(sources,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()).hexdigest()
    return {'source_sha256':declared,'derived_embedded_source_sha256':actual,
            'embedded_sources':len(sources),'production_scripts_including_receipt':len(sources)+1,
            'matches':declared==actual}


def main():
    OUT.parent.mkdir(parents=True,exist_ok=True)
    before=inventory();starter=ROOT/'places/BrickToads.rbxlx';playable=ROOT/'places/BrickToadsPlayable.rbxlx'
    prior=json.loads(PRIOR.read_bytes())
    assert len(prior['commands'])==77,'Prior regression command receipt changed'
    report={'schema':1,'started':stamp(),'scope':'Frozen course-prop regression replay; Studio and genuine-client evidence are separate.',
            'prior_command_receipt':PRIOR.relative_to(ROOT).as_posix(),'source_inventory_before':before,
            'starter_before':sha(starter),'commands':[],'compiler':{'files':[],'commands':[]},
            'artifacts_written_by_validation':['places/BrickToadsPlayable.rbxlx',OUT.relative_to(ROOT).as_posix()],
            'limits':['Native Luau runners use service doubles unless their individual scope says otherwise.',
                      'Native Studio and asset loading results are recorded separately by the root agent.']}
    assert report['starter_before']==STARTER_SHA,'Protected starter hash changed before validation'

    def save():OUT.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    def run(args,label,number=None):
        start=time.monotonic()
        result=subprocess.run(args,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=240)
        output=result.stdout+result.stderr
        row={'label':label,'args':args,'exit_code':result.returncode,'seconds':round(time.monotonic()-start,3),
             'stdout_stderr_tail':output[-2000:],'output_characters':len(output)}
        if number is not None:row['prior_command_number']=number
        if result.returncode:
            path=OUT.parent/(re.sub('[^A-Za-z0-9_-]','_',label)+'-failed.log')
            path.write_text(output,encoding='utf-8');row['failed_log']=path.relative_to(ROOT).as_posix()
        print(f"{label}: exit={result.returncode} seconds={row['seconds']}",flush=True)
        return row

    report['preflight_build']=run([PYTHON,'tools/build_bricktoads_place.py'],'preflight-build')
    if report['preflight_build']['exit_code']:
        report.update(status='FAIL',finished=stamp());save();return 1
    report['source_receipt_before']=source_receipt(playable)
    report['playable_before']={'sha256':sha(playable),'bytes':playable.stat().st_size}
    paths=sorted(p.relative_to(ROOT).as_posix() for directory in ('src','tests','tools')
                 for p in (ROOT/directory).rglob('*') if p.is_file()and p.suffix in ('.lua','.luau'))
    report['compiler']['files']=paths
    for index in range(0,len(paths),50):
        report['compiler']['commands'].append(run([COMPILER,'--null',*paths[index:index+50]],'compile-'+str(index//50+1)))
    for entry in prior['commands']:
        report['commands'].append(run(entry['args'],'prior-'+str(entry['number']),entry['number']))
        save()
    for label,args in [
        ('course-props-lifecycle',[PYTHON,'tests/course_props/run.py','--luau',LUAU]),
        ('course-prop-packaging',[PYTHON,'tools/test_course_prop_packaging.py']),
        ('all-tools-discovery',[PYTHON,'-c',
            "import sys,unittest;sys.path.insert(0,'tools');import test_walker_acceptance;"
            "test_walker_acceptance.LUAU='.tools/luau-0.745/luau.exe';"
            "suite=unittest.defaultTestLoader.discover('tools',pattern='test_*.py');"
            "result=unittest.TextTestRunner(verbosity=1).run(suite);"
            "print('DISCOVERY tests='+str(result.testsRun)+' skipped='+str(len(result.skipped)));"
            "sys.exit(not result.wasSuccessful())"]),
    ]:
        report['commands'].append(run(args,label));save()
    after=inventory()
    changes=sorted(path for path in set(before['files'])|set(after['files'])
                   if before['files'].get(path)!=after['files'].get(path))
    report['source_inventory_after']={'count':after['count'],'sha256':after['sha256'],'changed_files':changes}
    report['sources_preserved']=not changes
    report['source_receipt_after']=source_receipt(playable)
    report['starter_after']=sha(starter);report['starter_preserved']=report['starter_after']==STARTER_SHA
    report['playable_after']={'sha256':sha(playable),'bytes':playable.stat().st_size}
    report['playable_preserved_after_preflight']=report['playable_before']==report['playable_after']
    report['prop_resources']={name:{'sha256':sha(ROOT/'assets/props/canonical-course'/name),
                                  'bytes':(ROOT/'assets/props/canonical-course'/name).stat().st_size}
        for name in ('canonical-course-props.glb','canonical-course-props-pack.json','roblox-course-props.json')}
    report['total']=len(report['commands'])
    report['passed']=sum(row['exit_code']==0 for row in report['commands'])
    report['failed']=report['total']-report['passed']
    checks=[report['failed']==0,all(row['exit_code']==0 for row in report['compiler']['commands']),
            report['sources_preserved'],report['starter_preserved'],report['playable_preserved_after_preflight'],
            report['source_receipt_before']['matches'],report['source_receipt_after']['matches']]
    report['status']='PASS' if all(checks)else'FAIL';report['finished']=stamp();save()
    print(json.dumps({key:report[key]for key in ('status','total','passed','failed','sources_preserved','starter_preserved')}),flush=True)
    return 0 if all(checks)else 1


if __name__=='__main__':raise SystemExit(main())
