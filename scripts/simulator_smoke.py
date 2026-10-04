"""Validate languages, independent display/API modes, and multiline summary previews."""
from pathlib import Path
import json, subprocess, time
def run(*args):
    return subprocess.check_output(args,text=True,timeout=120).strip()
devices=json.loads(run('xcrun','simctl','list','devices','available','--json'))['devices']
choices=[d for runtime,items in devices.items() if 'iOS' in runtime for d in items if d['name'].startswith('iPhone')]
assert choices, 'No iPhone simulator available'
device=choices[0]['udid']; app='com.akisenn.JailPrism'
# name, system languages, manual selection, private, professional, settings, preview, credits
cases=[
    ('normal-english','(en-US)','system',False,False,False,False,False),
    ('normal-chinese','(zh-Hant-TW)','system',False,False,False,False,False),
    ('professional-chinese','(en-US)','zh_Hans_CN',False,True,False,False,False),
    ('settings-english','(zh-Hant-HK)','en_US',False,False,True,False,False),
    ('extended-chinese','(en-US)','zh_Hans_CN',True,True,False,False,False),
    ('normal-preview','(zh-Hant-HK)','system',False,False,False,True,False),
    ('professional-preview','(zh-Hans-CN)','system',False,True,False,True,False),
    ('credits-chinese','(zh-Hant-TW)','system',False,False,True,False,True)
]
results=[]
try:
    subprocess.run(['xcrun','simctl','boot',device],check=False)
    subprocess.run(['xcrun','simctl','bootstatus',device,'-b'],check=True,timeout=240)
    run('xcrun','simctl','install',device,'build/simulator/Build/Products/Release-iphonesimulator/JailPrism.app')
    container=Path(run('xcrun','simctl','get_app_container',device,app,'data'))
    report_path=container/'Documents'/'smoke-report.json'
    for name,languages,selection,private,professional,settings,preview,credits in cases:
        subprocess.run(['xcrun','simctl','terminate',device,app],check=False,timeout=30)
        report_path.unlink(missing_ok=True)
        args=['--smoke-report','-AppleLanguages',languages,'-IGLanguage',selection]
        if private: args+=['-IGPrivateAPIEnabled','YES']
        if professional: args+=['-IGProfessionalMode','YES']
        if settings: args+=['--smoke-settings']
        if preview: args+=['--smoke-fixture']
        if credits: args+=['--smoke-credits']
        launch=run('xcrun','simctl','launch',device,app,*args); pid=launch.rsplit(':',1)[1].strip()
        deadline=time.monotonic()+90
        while not report_path.exists() and time.monotonic()<deadline: time.sleep(1)
        assert report_path.exists(), f'{name}: no report written'
        time.sleep(3)
        run('xcrun','simctl','spawn',device,'launchctl','procinfo',pid)
        report=json.loads(report_path.read_text())
        Path(f'dist/simulator-{name}-report.json').write_bytes(report_path.read_bytes())
        expected='en_US' if name in ('normal-english','settings-english') else 'zh_Hans_CN'
        assert report['appVersion']=='1.2.0' and report['schema']==2
        assert report['appName']=='JailPrism' and report['bundleIdentifier']==app
        assert report['language']==expected
        assert report['presentationMode']==('professional' if professional else 'normal')
        assert report['device']['simulator'] is True and report['device']['model']
        assert report['device']['hardwareIdentifier'].startswith('iPhone') and report['device']['system']
        assert report['scanTime'] and report['timestamp']>0 and report['scanDuration']>=0
        assert report['identity']['groups'] is not None
        config=report['scanConfiguration']
        assert config['privateAPIEnabled'] is private
        assert bool(config['privateOperationsAttempted']) is private
        if preview:
            assert report['previewFixture'] is True, 'Illustrative UI data must be explicitly marked'
            summaries={r['kind']:r for r in report['simpleSummary']}
            assert summaries['stores']['values']==['Cydia','Sileo']
            assert summaries['libraries']['values']==['Choicy.dylib','ShadowCore.dylib']
            assert summaries['trollstore']['values']==['TrollStore巨魔']
            assert report['classification']['types']==['rootful']
        else:
            assert not report.get('previewFixture')
            assert report['score']['score']==100 and report['score']['levelCode']=='suspected'
            assert report['score']['level']==('Suspected' if expected=='en_US' else '疑似')
            assert report['score']['jailbreakEvidence'] is False and report['score']['hitCount']==0
            assert report['score']['skippedCount']==(0 if private else 1)
            assert all(f['status']=='unknown' for f in report['findings'] if f['group']!='observer')
            assert not report['simpleSummary']
            assert report['classification']['primary']=='unknown' and not report['classification']['types']
        run('xcrun','simctl','io',device,'screenshot',f'dist/simulator-{name}.png')
        results.append(f'{name}: process alive, language={expected}, private={private}, professional={professional}, fixture={preview}; validations passed')
    Path('dist/simulator-smoke.txt').write_text('\n'.join(results)+'\nPreview fixtures only illustrate UI. Simulator cannot validate physical jailbreak detection.\n',encoding='utf-8')
finally:
    subprocess.run(['xcrun','simctl','shutdown',device],check=False,timeout=60)
