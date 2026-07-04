#!/usr/bin/env python3
"""Extract all method channel names invoked from Dart imclient layer."""

import re
from pathlib import Path

DART_FILE = Path('/Users/rain/Workspace/wfc_flutter_plugins/imclient/lib/imclient_method_channel.dart')
text = DART_FILE.read_text()

# Match invokeMethod("name", ...)
names = set(re.findall(r'invokeMethod\s*\(\s*["\']([a-zA-Z0-9_]+)["\']', text))

for n in sorted(names):
    print(n)

print(f"\nTotal: {len(names)}")
Path('/Users/rain/Workspace/wfc_flutter_plugins/imclient/scripts/dart_methods.txt').write_text('\n'.join(sorted(names)))
