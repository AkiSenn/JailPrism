"""Generate a dependency-free Xcode project; works on Windows and macOS."""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]
def ident(s):
    return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def q(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

objects = []
def obj(name, body):
    objects.append(f"{ident(name)} = {{ {body} }};")
    return ident(name)

sources = sorted((ROOT / 'Sources').iterdir())
files, builds, resource_builds = [], [], []
types = {'.m':'sourcecode.c.objc', '.h':'sourcecode.c.h', '.plist':'text.plist.xml', '.xcassets':'folder.assetcatalog'}
for p in sources:
    fid = obj('file:'+p.name, f"isa = PBXFileReference; lastKnownFileType = {types[p.suffix]}; path = {q('Sources/'+p.name)}; sourceTree = SOURCE_ROOT;")
    files.append(fid)
    if p.suffix == '.m':
        builds.append(obj('build:'+p.name, f"isa = PBXBuildFile; fileRef = {fid};"))
    elif p.suffix == '.xcassets':
        resource_builds.append(obj('build:'+p.name, f"isa = PBXBuildFile; fileRef = {fid};"))
product = obj('product', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = IOSGuard.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
root = obj('root', f'isa = PBXGroup; children = ({",".join(files+[products])},); sourceTree = "<group>";')
phase = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
frameworks = obj('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
resources = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(resource_builds)},); runOnlyForDeploymentPostprocessing = 0;')
project_configs, target_configs = [], []
for config in ['Debug','Release']:
    settings = 'CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; IPHONEOS_DEPLOYMENT_TARGET = 14.0; SDKROOT = iphoneos; GCC_WARN_INHIBIT_ALL_WARNINGS = NO; GCC_WARN_64_TO_32_BIT_CONVERSION = YES; CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;'
    settings += ' GCC_OPTIMIZATION_LEVEL = 0; DEBUG_INFORMATION_FORMAT = dwarf;' if config == 'Debug' else ' GCC_OPTIMIZATION_LEVEL = s; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
    project_configs.append(obj('project:'+config, f'isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {config};'))
    target_settings = 'PRODUCT_NAME = IOSGuard; PRODUCT_BUNDLE_IDENTIFIER = com.akisen.iosguard; INFOPLIST_FILE = Sources/Info.plist; CODE_SIGNING_ALLOWED = NO; TARGETED_DEVICE_FAMILY = "1,2"; ARCHS = "arm64 arm64e"; ONLY_ACTIVE_ARCH = NO; ENABLE_BITCODE = NO; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; OTHER_LDFLAGS = "-framework UIKit -framework Foundation -framework Security"; "OTHER_LDFLAGS[sdk=iphoneos*]" = "-framework UIKit -framework Foundation -framework Security -Wl,-no_adhoc_codesign";'
    target_configs.append(obj('target:'+config, f'isa = XCBuildConfiguration; buildSettings = {{ {target_settings} }}; name = {config};'))
pc = obj('project-configs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(project_configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
tc = obj('target-configs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(target_configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {tc}; buildPhases = ({phase},{frameworks},{resources},); buildRules = (); dependencies = (); name = IOSGuard; productName = IOSGuard; productReference = {product}; productType = "com.apple.product-type.application";')
project = obj('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {pc}; compatibilityVersion = "Xcode 14.0"; developmentRegion = "zh-Hans"; hasScannedForEncodings = 0; knownRegions = ("zh-Hans",en,Base,); mainGroup = {root}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
out = ROOT / 'IOSGuard.xcodeproj'
out.mkdir(exist_ok=True)
(out/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n}}; rootObject = {project}; }}\n', encoding='utf-8')
scheme_dir = out/'xcshareddata'/'xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)
(scheme_dir/'IOSGuard.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="IOSGuard.app" BlueprintName="IOSGuard" ReferencedContainer="container:IOSGuard.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="IOSGuard.app" BlueprintName="IOSGuard" ReferencedContainer="container:IOSGuard.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''', encoding='utf-8')
print('Generated IOSGuard.xcodeproj (iOS 14.0, arm64 + arm64e)')
