from pathlib import Path
import json, plistlib, subprocess, sys, re, hashlib
app = Path(sys.argv[1])
info = plistlib.loads((app/'Info.plist').read_bytes())
exe = app/info['CFBundleExecutable']
archs = subprocess.check_output(['lipo','-archs',str(exe)],text=True).strip().split()
assert set(archs) == {'arm64','arm64e'}, archs
assert info['MinimumOSVersion'] == '14.0', info['MinimumOSVersion']
load = subprocess.check_output(['xcrun','vtool','-show-build',str(exe)],text=True)
minimums = re.findall(r'minos\s+([\d.]+)',load)
assert minimums and all(v in ('14.0','14.0.0') for v in minimums), load
signed = subprocess.run(['codesign','-d','--entitlements',':-',str(app)],capture_output=True,check=True).stdout
ents = plistlib.loads(signed)
assert ents['com.apple.private.security.no-sandbox'] is True
assert ents['com.apple.private.security.container-required'] is False
assert ents['get-task-allow'] is False
metadata = {'architectures':archs,'minimumOS':info['MinimumOSVersion'],
            'bundleIdentifier':info['CFBundleIdentifier'],'version':info['CFBundleShortVersionString'],
            'executableSHA256':hashlib.sha256(exe.read_bytes()).hexdigest(),
            'entitlements':ents,'machOBuildCommands':load}
Path('dist/build-metadata.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
print(json.dumps(metadata,indent=2))
