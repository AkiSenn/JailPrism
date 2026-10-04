"""Exercise automatic/manual language selection and both API modes on a live simulator."""
from pathlib import Path
import json, subprocess, time
def run(*args):
    return subprocess.check_output(args,text=True,timeout=120).strip()
devices = json.loads(run('xcrun','simctl','list','devices','available','--json'))['devices']
choices = [d for runtime,items in devices.items() if 'iOS' in runtime for d in items if d['name'].startswith('iPhone')]
assert choices, 'No iPhone simulator available'
device=choices[0]['udid']; app='com.akisen.iosguard'
cases=[('english','(en-US)','system',False,False),('chinese','(zh-Hant-TW)','system',False,False),('override','(zh-Hant-HK)','en_US',False,True),('extended','(en-US)','zh_Hans_CN',True,True)]
results=[]
try:
    subprocess.run(['xcrun','simctl','boot',device],check=False)
    subprocess.run(['xcrun','simctl','bootstatus',device,'-b'],check=True,timeout=240)
    run('xcrun','simctl','install',device,'build/simulator/Build/Products/Release-iphonesimulator/IOSGuard.app')
    container=Path(run('xcrun','simctl','get_app_container',device,app,'data'))
    report_path=container/'Documents'/'smoke-report.json'
    for name,languages,selection,private,settings in cases:
        subprocess.run(['xcrun','simctl','terminate',device,app],check=False,timeout=30)
        report_path.unlink(missing_ok=True)
        args=['--smoke-report','-AppleLanguages',languages,'-IGLanguage',selection]
        # First/default launch deliberately supplies no private API argument.
        if private: args += ['-IGPrivateAPIEnabled','YES']
        if settings: args += ['--smoke-settings']
        launch=run('xcrun','simctl','launch',device,app,*args); pid=launch.rsplit(':',1)[1].strip()
        deadline=time.monotonic()+90
        while not report_path.exists() and time.monotonic()<deadline: time.sleep(1)
        assert report_path.exists(), f'{name}: no report written'
        time.sleep(3)
        run('xcrun','simctl','spawn',device,'launchctl','procinfo',pid)
        report=json.loads(report_path.read_text())
        Path(f'dist/simulator-{name}-report.json').write_bytes(report_path.read_bytes())
        expected='en_US' if name in ('english','override') else 'zh_Hans_CN'
        assert report['appVersion']=='1.1.0' and report['schema']==2
        assert report['language']==expected
        assert report['score']['level'] == ('Suspected' if expected=='en_US' else '疑似'), 'localized score did not load'
        assert report['device']['simulator'] is True and report['device']['model']
        assert report['device']['hardwareIdentifier'].startswith('iPhone') and report['device']['system']
        assert report['scanTime'] and report['timestamp']>0 and report['scanDuration']>=0
        assert report['score']['score']==100 and report['score']['levelCode']=='suspected'
        assert report['score']['jailbreakEvidence'] is False and report['score']['hitCount']==0
        assert report['identity']['groups'] is not None
        assert all(f['status']=='unknown' for f in report['findings'] if f['group']!='observer')
        config=report['scanConfiguration']
        assert config['privateAPIEnabled'] is private
        assert bool(config['privateOperationsAttempted']) is private
        assert report['score']['skippedCount']==(0 if private else 1)
        assert report['classification']['primary']=='unknown' and not report['classification']['types']
        scope=next(f for f in report['findings'] if f['id']=='observer:scope')
        assert ('Shadow 与 Choicy' in scope['detail']) if expected=='zh_Hans_CN' else ('Shadow and Choicy' in scope['detail'])
        run('xcrun','simctl','io',device,'screenshot',f'dist/simulator-{name}.png')
        results.append(f'{name}: process alive, {expected}, private={private}, schema/scoring/device/time/gating validated')
    Path('dist/simulator-smoke.txt').write_text('\n'.join(results)+'\nSimulator does not verify physical jailbreak detection.\n',encoding='utf-8')
finally:
    subprocess.run(['xcrun','simctl','shutdown',device],check=False,timeout=60)
