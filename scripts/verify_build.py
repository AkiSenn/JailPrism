from pathlib import Path
import json, plistlib, subprocess, sys, re, hashlib, struct
app = Path(sys.argv[1])
info = plistlib.loads((app/'Info.plist').read_bytes())
exe = app/info['CFBundleExecutable']
archs = subprocess.check_output(['lipo','-archs',str(exe)],text=True).strip().split()
assert set(archs) == {'arm64','arm64e'}, archs
assert info['MinimumOSVersion'] == '14.0', info['MinimumOSVersion']
assert info['CFBundleIdentifier'] == 'com.akisenn.JailPrism'
assert info['CFBundleDisplayName'] == 'JailPrism' and info['CFBundleShortVersionString'] == '1.2.2'
assert all((app/f'{locale}.lproj'/'Localizable.strings').exists() for locale in ('en_US','zh_Hans_CN'))
load = subprocess.check_output(['xcrun','vtool','-show-build',str(exe)],text=True)
minimums = re.findall(r'minos\s+([\d.]+)',load)
assert minimums and all(v in ('14.0','14.0.0') for v in minimums), load
binary = exe.read_bytes()
magic, count = struct.unpack_from('>II', binary)
assert magic == 0xcafebabe and count == 2, 'Expected a two-slice fat Mach-O'
for i in range(count):
    cpu, subtype, offset, length, alignment = struct.unpack_from('>IIIII',binary,8+i*20)
    assert offset+length <= len(binary)
    header = struct.unpack_from('<8I',binary,offset)
    assert header[0] == 0xfeedfacf, 'Expected a 64-bit Mach-O slice'
    command_offset = offset+32
    for _ in range(header[4]):
        command, command_size = struct.unpack_from('<II',binary,command_offset)
        assert command_size >= 8 and command_offset+command_size <= offset+32+header[5]
        assert command != 0x1d, 'LC_CODE_SIGNATURE found: IPA must be unsigned'
        command_offset += command_size
    assert command_offset == offset+32+header[5]
assert not (app/'_CodeSignature').exists(), 'Unexpected app signature resources'
assert not (app/'embedded.mobileprovision').exists(), 'Unexpected provisioning profile'
metadata = {'architectures':archs,'minimumOS':info['MinimumOSVersion'],
            'bundleIdentifier':info['CFBundleIdentifier'],'version':info['CFBundleShortVersionString'],
            'executableSHA256':hashlib.sha256(exe.read_bytes()).hexdigest(),
            'signing':'unsigned','embeddedEntitlements':False,
            'machOBuildCommands':load}
Path('dist/build-metadata.json').write_text(json.dumps(metadata,indent=2),encoding='utf-8')
print(json.dumps(metadata,indent=2))
