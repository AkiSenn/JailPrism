"""Launch simulator build, check that the process survives, and capture the UI."""
from pathlib import Path
import json, os, subprocess, time

def run(*args):
    return subprocess.check_output(args,text=True).strip()

devices = json.loads(run('xcrun','simctl','list','devices','available','--json'))['devices']
choices = [d for runtime,items in devices.items() if 'iOS' in runtime for d in items if d['name'].startswith('iPhone')]
assert choices, 'No iPhone simulator is available'
device = choices[0]['udid']
try:
    subprocess.run(['xcrun','simctl','boot',device],check=False)
    subprocess.run(['xcrun','simctl','bootstatus',device,'-b'],check=True,timeout=240)
    run('xcrun','simctl','install',device,'build/simulator/Build/Products/Release-iphonesimulator/IOSGuard.app')
    launch = run('xcrun','simctl','launch',device,'com.akisen.iosguard')
    pid = launch.rsplit(':',1)[1].strip()
    time.sleep(15)
    run('xcrun','simctl','spawn',device,'launchctl','procinfo',pid)
    run('xcrun','simctl','io',device,'screenshot','dist/simulator.png')
    Path('dist/simulator-smoke.txt').write_text(f'{launch}\nDevice: {device}\nProcess alive 15 seconds after launch. Simulator cannot validate physical jailbreak detection.\n',encoding='utf-8')
finally:
    subprocess.run(['xcrun','simctl','shutdown',device],check=False)
