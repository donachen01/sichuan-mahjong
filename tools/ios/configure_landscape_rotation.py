#!/usr/bin/env python3
"""Add the project-owned orientation bridge to a generated Godot iOS project."""
import plistlib
import sys
from pathlib import Path

root = Path(sys.argv[1])
project = Path(__file__).resolve().parents[2]
app = root / 'SichuanMahjongIOS'
for plist in [app / 'SichuanMahjongIOS-Info.plist']:
    data = plistlib.loads(plist.read_bytes())
    for key in ['UISupportedInterfaceOrientations', 'UISupportedInterfaceOrientations~ipad']:
        data[key] = ['UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight']
    plist.write_bytes(plistlib.dumps(data, sort_keys=False))
stub = app / 'dummy.cpp'
content = stub.read_text() if stub.exists() else (app / 'dummy.mm').read_text().split('// Sichuan native landscape bridge')[0]
marker = 'void godot_apple_embedded_plugins_initialize() {'
if '    sichuan_landscape_rotation_initialize();' not in content:
    content = content.replace(marker,
        'void sichuan_landscape_rotation_initialize(void);\n' + marker + '\n    sichuan_landscape_rotation_initialize();')
content += '\n// Sichuan native landscape bridge\n' + (project / 'tools/ios/landscape_rotation.mm').read_text()
(app / 'dummy.mm').write_text(content)
stub.unlink(missing_ok=True)
pbx = root / 'SichuanMahjongIOS.xcodeproj/project.pbxproj'
s = pbx.read_text().replace('dummy.cpp', 'dummy.mm').replace('lastKnownFileType = sourcecode.cpp.cpp;', 'lastKnownFileType = sourcecode.cpp.objcpp;')
# The bridge owns its CoreMotion link; do not rely on transitive engine links.
if '-framework CoreMotion' not in s:
    s = s.replace('OTHER_LDFLAGS = "', 'OTHER_LDFLAGS = "-framework CoreMotion ')
if '-framework CoreMotion' not in s:
    raise SystemExit('Could not configure CoreMotion link')
s = s.replace('CODE_SIGN_IDENTITY = "Apple Distribution";', 'CODE_SIGN_IDENTITY = "Apple Development";')
pbx.write_text(s)
print('Configured native landscape-only gravity rotation and Apple Development signing.')
