#!/usr/bin/env python3
"""Generate the dependency-free Xcode project; source folders synchronize in Xcode."""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'Bloomed.xcodeproj'
PROJECT.mkdir(exist_ok=True)
objects = []

def uid(name):
    return hashlib.sha256(('bloomed.' + name).encode()).hexdigest()[:24].upper()

def obj(name, value):
    objects.append(f'\t\t{uid(name)} = {{ {value} }};')
    return uid(name)

def refs(names):
    return '( ' + ', '.join(uid(name) for name in names) + ', )'

for target, product, kind in [('app','Bloomed.app','application'),('tests','BloomedTests.xctest','bundle.unit-test'),('uitests','BloomedUITests.xctest','bundle.ui-testing')]:
    obj(target+'.product', f'isa = PBXFileReference; explicitFileType = {"wrapper.application" if target=="app" else "wrapper.cfbundle"}; includeInIndex = 0; path = {product}; sourceTree = BUILT_PRODUCTS_DIR;')
    for phase, isa in [('sources','PBXSourcesBuildPhase'),('frameworks','PBXFrameworksBuildPhase'),('resources','PBXResourcesBuildPhase')]:
        obj(target+'.'+phase, f'isa = {isa}; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    path={'app':'Bloomed','tests':'BloomedTests','uitests':'BloomedUITests'}[target]
    obj(target+'.group',f'isa = PBXFileSystemSynchronizedRootGroup; path = {path}; sourceTree = "<group>";')
    dependency='()'
    if target!='app':
        obj(target+'.proxy',f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("app.target")}; remoteInfo = Bloomed;')
        obj(target+'.dependency',f'isa = PBXTargetDependency; target = {uid("app.target")}; targetProxy = {uid(target+".proxy")};')
        dependency=refs([target+'.dependency'])
    targetname={'app':'Bloomed','tests':'BloomedTests','uitests':'BloomedUITests'}[target]
    obj(target+'.target',f'isa = PBXNativeTarget; buildConfigurationList = {uid(target+".configs")}; buildPhases = {refs([target+".sources",target+".frameworks",target+".resources"])}; buildRules = (); dependencies = {dependency}; fileSystemSynchronizedGroups = {refs([target+".group"])}; name = {targetname}; productName = {targetname}; productReference = {uid(target+".product")}; productType = "com.apple.product-type.{kind}";')
    for configuration in ['Debug','Release']:
        base='CODE_SIGN_STYLE = Automatic; DEVELOPMENT_TEAM = J6QD2TR878; GENERATE_INFOPLIST_FILE = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; TARGETED_DEVICE_FAMILY = 1; SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"; MARKETING_VERSION = 0.1.0; CURRENT_PROJECT_VERSION = 2;'
        if target=='app':
            settings=base+' PRODUCT_BUNDLE_IDENTIFIER = com.khanom12.bloomed; PRODUCT_NAME = "$(TARGET_NAME)"; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor; INFOPLIST_KEY_CFBundleDisplayName = Bloomed; INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.healthcare-fitness"; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES; INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait"; SUPPORTS_MACCATALYST = NO; ENABLE_PREVIEWS = YES; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";'
        elif target=='tests':
            settings=base+' PRODUCT_BUNDLE_IDENTIFIER = com.khanom12.bloomed.tests; PRODUCT_NAME = "$(TARGET_NAME)"; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Bloomed.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Bloomed"; BUNDLE_LOADER = "$(TEST_HOST)"; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @loader_path/Frameworks";'
        else:
            settings=base+' PRODUCT_BUNDLE_IDENTIFIER = com.khanom12.bloomed.uitests; PRODUCT_NAME = "$(TARGET_NAME)"; TEST_TARGET_NAME = Bloomed; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @loader_path/Frameworks";'
        obj(target+'.'+configuration,f'isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {configuration};')
    obj(target+'.configs',f'isa = XCConfigurationList; buildConfigurations = {refs([target+".Debug",target+".Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')

obj('products',f'isa = PBXGroup; children = {refs(["app.product","tests.product","uitests.product"])}; name = Products; sourceTree = "<group>";')
obj('main',f'isa = PBXGroup; children = {refs(["app.group","tests.group","uitests.group","products"])}; sourceTree = "<group>";')
for configuration in ['Debug','Release']:
    extra='DEBUG_INFORMATION_FORMAT = dwarf; ENABLE_TESTABILITY = YES; GCC_OPTIMIZATION_LEVEL = 0; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";' if configuration=='Debug' else 'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"; SWIFT_COMPILATION_MODE = wholemodule; VALIDATE_PRODUCT = YES;'
    obj('project.'+configuration,'isa = XCBuildConfiguration; buildSettings = { CLANG_ENABLE_MODULES = YES; CLANG_ENABLE_OBJC_ARC = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; GCC_C_LANGUAGE_STANDARD = gnu17; CLANG_WARN_DOCUMENTATION_COMMENTS = YES; CLANG_WARN_UNREACHABLE_CODE = YES; '+extra+' }; name = '+configuration+';')
obj('project.configs',f'isa = XCConfigurationList; buildConfigurations = {refs(["project.Debug","project.Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
attrs=f'{uid("app.target")} = {{CreatedOnToolsVersion = 26.3; ProvisioningStyle = Automatic; }}; {uid("tests.target")} = {{ CreatedOnToolsVersion = 26.3; TestTargetID = {uid("app.target")}; }}; {uid("uitests.target")} = {{CreatedOnToolsVersion = 26.3; TestTargetID = {uid("app.target")}; }};'
obj('project',f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = 1; LastUpgradeCheck = 2630; TargetAttributes = {{ {attrs} }}; }}; buildConfigurationList = {uid("project.configs")}; compatibilityVersion = "Xcode 16.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {uid("main")}; minimizedProjectReferenceProxies = 1; preferredProjectObjectVersion = 77; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = {refs(["app.target","tests.target","uitests.target"])};')
content='// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 77;\n\tobjects = {\n'+'\n'.join(objects)+'\n\t};\n\trootObject = '+uid('project')+';\n}\n'
(PROJECT/'project.pbxproj').write_text(content)
scheme=PROJECT/'xcshareddata'/'xcschemes'
scheme.mkdir(parents=True,exist_ok=True)
def buildable(target,name,product):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(target+".target")}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:Bloomed.xcodeproj"/>'
app=buildable('app','Bloomed','Bloomed.app')
test=buildable('tests','BloomedTests','BloomedTests.xctest')
ui=buildable('uitests','BloomedUITests','BloomedUITests.xctest')
(scheme/'Bloomed.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2630" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test}</TestableReference><TestableReference skipped="NO">{ui}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print('Generated Bloomed.xcodeproj and shared Bloomed scheme.')
