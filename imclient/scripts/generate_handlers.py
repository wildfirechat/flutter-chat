#!/usr/bin/env python3
"""Generate desktop plugin handlers for missing imclient methods.

Reads WFClient.h signatures and existing plugin patterns to emit:
- macOS handler (.mm)
- Linux handler (.cpp)
- Windows handler (.cpp)
- dispatch table additions
"""

import re
import json
from pathlib import Path

ROOT = Path('/Users/rain/Workspace/wfc_flutter_plugins/imclient')
METHODS_FILE = ROOT / 'scripts' / 'dart_methods.txt'
FUNC_FILE = ROOT / 'scripts' / 'wfc_functions.json'

macos_out = ROOT / 'scripts' / 'gen_macos.mm'
linux_out = ROOT / 'scripts' / 'gen_linux.cpp'
windows_out = ROOT / 'scripts' / 'gen_windows.cpp'
dispatch_out = ROOT / 'scripts' / 'gen_dispatch.txt'

methods = set(METHODS_FILE.read_text().splitlines())
functions = json.loads(FUNC_FILE.read_text())
by_name = {f['name']: f for f in functions}

# Helpers to parse C types
def param_name_from_arg(arg):
    # Strip type qualifiers and pointer markers to get parameter name.
    a = re.sub(r'\b(const|char|int|bool|int64_t|long|size_t|void)\b', '', arg)
    a = a.replace('*', '').replace('&', '').replace('[', '').replace(']', '')
    a = a.replace('(', '').replace(')', '')
    a = a.strip()
    # If there are callback typedef names, drop them too.
    a = re.sub(r'fun_\w+', '', a)
    a = a.strip()
    return a or 'arg'

MAP_TYPES = {
    'int': 'GetInt',
    'bool': 'GetBool',
    'int64_t': 'GetInt',
    'long': 'GetInt',
    'size_t': 'GetInt',
    'String': 'GetString',
    'List<int>': 'GetIntList',
    'List<String>': 'GetStringList',
}

def arg_to_extractor(arg, platform):
    name = param_name_from_arg(arg)
    if 'fun_' in arg:
        return None, name
    if 'size_t' in arg and '*' in arg:
        # output param
        return None, name
    if arg.strip().startswith('const char *'):
        return 'string', name
    if arg.strip().startswith('const int ') and '[' in arg:
        return 'int_list', name
    if re.search(r'\bconst char\s*\*\*', arg):
        return 'string_list_c', name
    if re.search(r'\bconst size_t\s*\*', arg):
        return 'size_list', name
    if 'bool' in arg:
        return 'bool', name
    if 'int64_t' in arg or 'long' in arg:
        return 'int64', name
    if 'int' in arg:
        return 'int', name
    return 'unknown', name

def snake_to_camel(name):
    parts = name.split('_')
    return ''.join(p.capitalize() for p in parts)

def gen_macos(fn):
    name = fn['name']
    args = fn['args']
    ret = fn['return']
    if args.strip():
        arglist = [a.strip() for a in args.split(',')]
    else:
        arglist = []

    body = []
    call_args = []
    needs_request_id = False
    has_callback = False

    for arg in arglist:
        typ, pname = arg_to_extractor(arg, 'macos')
        if typ == 'string':
            body.append(f'  std::string {pname} = GetString(args, @"{pname}");')
            call_args.append(f'{pname}.c_str()')
            call_args.append(f'{pname}.size()')
        elif typ == 'int_list':
            body.append(f'  std::vector<int> {pname} = GetIntList(args, @"{pname}");')
            call_args.append(f'{pname}.data()')
            call_args.append(f'static_cast<int>({pname}.size())')
        elif typ == 'string_list_c':
            body.append(f'  std::vector<std::string> {pname} = GetStringList(args, @"{pname}");')
            body.append(f'  std::vector<const char*> {pname}_ptrs;')
            body.append(f'  std::vector<size_t> {pname}_lens;')
            body.append(f'  for (auto& s : {pname}) {{ {pname}_ptrs.push_back(s.c_str()); {pname}_lens.push_back(s.size()); }}')
            call_args.append(f'{pname}_ptrs.data()')
            call_args.append(f'{pname}_lens.data()')
            call_args.append(f'{pname}.size()')
        elif typ == 'size_list':
            body.append(f'  // TODO size_list param {pname}')
        elif typ == 'bool':
            body.append(f'  bool {pname} = GetBool(args, @"{pname}", false);')
            call_args.append(pname)
        elif typ == 'int64':
            body.append(f'  int64_t {pname} = GetInt(args, @"{pname}", 0);')
            call_args.append(pname)
        elif typ == 'int':
            body.append(f'  int {pname} = static_cast<int>(GetInt(args, @"{pname}", 0));')
            call_args.append(pname)
        elif typ is None and 'successCallback' in arg:
            has_callback = True
            if 'void' in ret:
                body.append(f'  int64_t request_id = GetInt(args, @"requestId", 0);')
                call_args.append('OnGeneralVoidSuccess')
                call_args.append('OnGeneralError')
                call_args.append(f'reinterpret_cast<void*>(request_id)')
                call_args.append('0')
            else:
                body.append(f'  int64_t request_id = GetInt(args, @"requestId", 0);')
                call_args.append('OnGeneralStringSuccess')
                call_args.append('OnGeneralError')
                call_args.append(f'reinterpret_cast<void*>(request_id)')
                call_args.append('0')
        elif typ is None and 'pObject' in arg:
            pass  # handled above
        elif typ is None and 'objectDataType' in arg:
            pass

    sig = f'- (void)handle{snake_to_camel(name)}:(NSDictionary *)args result:(FlutterResult)result'
    if 'const char*' in ret:
        body.append('  size_t len = 0;')
        call = f'WFClient::{name}(' + ', '.join(call_args) + ', &len)'
        body.append(f'  const char *str = {call};')
        body.append('  std::string json_str = ConvertDllStringAndRelease(str, len);')
        body.append('  result(ObjectFromJsonString(json_str));')
    elif ret == 'bool':
        call = f'WFClient::{name}(' + ', '.join(call_args) + ')'
        body.append(f'  bool ret = {call};')
        body.append('  result(@(ret));')
    elif ret == 'int' or ret == 'int64_t':
        call = f'WFClient::{name}(' + ', '.join(call_args) + ')'
        body.append(f'  int64_t ret = {call};')
        body.append('  result(@(ret));')
    elif ret == 'void':
        call = f'WFClient::{name}(' + ', '.join(call_args) + ')'
        body.append(f'  {call};')
        if not has_callback:
            body.append('  result(nil);')
    else:
        body.append(f'  // TODO unhandled return type {ret}')

    return sig + ' {\n' + '\n'.join('  ' + b for b in body) + '\n}'


def gen_linux_windows(fn, platform):
    name = fn['name']
    args = fn['args']
    ret = fn['return']
    arglist = [a.strip() for a in args.split(',')] if args.strip() else []

    body = []
    call_args = []
    has_callback = False

    for arg in arglist:
        typ, pname = arg_to_extractor(arg, platform)
        if typ == 'string':
            body.append(f'  std::string {pname} = GetString(args, "{pname}");')
            call_args.append(f'{pname}.c_str()')
            call_args.append(f'{pname}.size()')
        elif typ == 'int_list':
            body.append(f'  std::vector<int> {pname} = GetIntList(args, "{pname}");')
            call_args.append(f'{pname}.data()')
            call_args.append(f'static_cast<int>({pname}.size())')
        elif typ == 'string_list_c':
            body.append(f'  std::vector<std::string> {pname} = GetStringList(args, "{pname}");')
            body.append(f'  std::vector<const char*> {pname}_ptrs;')
            body.append(f'  std::vector<size_t> {pname}_lens;')
            body.append(f'  for (auto& s : {pname}) {{ {pname}_ptrs.push_back(s.c_str()); {pname}_lens.push_back(s.size()); }}')
            call_args.append(f'{pname}_ptrs.data()')
            call_args.append(f'{pname}_lens.data()')
            call_args.append(f'{pname}.size()')
        elif typ == 'size_list':
            body.append(f'  // TODO size_list param {pname}')
        elif typ == 'bool':
            body.append(f'  bool {pname} = GetBool(args, "{pname}", false);')
            call_args.append(pname)
        elif typ == 'int64':
            body.append(f'  int64_t {pname} = GetInt(args, "{pname}", 0);')
            call_args.append(pname)
        elif typ == 'int':
            body.append(f'  int {pname} = static_cast<int>(GetInt(args, "{pname}", 0));')
            call_args.append(pname)
        elif typ is None and 'successCallback' in arg:
            has_callback = True
            body.append(f'  int64_t request_id = GetInt(args, "requestId", 0);')
            if 'void' in ret:
                call_args.append('OnGeneralVoidSuccess')
                call_args.append('OnGeneralError')
            else:
                call_args.append('OnGeneralStringSuccess')
                call_args.append('OnGeneralError')
            call_args.append(f'reinterpret_cast<void*>(request_id)')
            call_args.append('0')
        elif typ is None and ('pObject' in arg or 'objectDataType' in arg):
            pass

    sig = f'void Handle{snake_to_camel(name)}(const flutter::EncodableMap *args,\n                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)'
    if 'const char*' in ret:
        body.append('  size_t len = 0;')
        call = f'WFClient::{name}(' + ', '.join(call_args) + ', &len)'
        body.append(f'  const char *str = {call};')
        body.append('  std::string json_str = ConvertDllStringAndRelease(str, len);')
        body.append('  result->Success(JsonToEncodable(json_str));')
    elif ret == 'bool':
        call = f'WFClient::{name}(' + ', '.join(call_args) + ')'
        body.append(f'  bool ret = {call};')
        body.append('  result->Success(flutter::EncodableValue(ret));')
    elif ret == 'int' or ret == 'int64_t':
        call = f'WFClient::{name}(' + ', '.join(call_args) + ')'
        body.append(f'  int64_t ret = {call};')
        body.append('  result->Success(flutter::EncodableValue(ret));')
    elif ret == 'void':
        call = f'WFClient::{name}(' + ', '.join(call_args) + ')'
        body.append(f'  {call};')
        if not has_callback:
            body.append('  result->Success();')
    else:
        body.append(f'  // TODO unhandled return type {ret}')

    return sig + ' {\n' + '\n'.join('  ' + b for b in body) + '\n}'


# Select methods to generate: all methods that are in dart_methods.txt but not yet implemented in desktop.
# For this generator we produce for the list passed as argument.
def generate(method_names):
    macos_blocks = []
    linux_blocks = []
    windows_blocks = []
    dispatch = []
    for m in method_names:
        fn = by_name.get(m)
        if not fn:
            print(f'WARN: no SDK signature for {m}')
            continue
        macos_blocks.append(gen_macos(fn))
        linux_blocks.append(gen_linux_windows(fn, 'linux'))
        windows_blocks.append(gen_linux_windows(fn, 'windows'))
        dispatch.append(f'  }} else if (method == "{m}") {{')
        dispatch.append(f'    Handle{snake_to_camel(m)}(args, std::move(result));')

    macos_out.write_text('\n\n'.join(macos_blocks))
    linux_out.write_text('\n\n'.join(linux_blocks))
    windows_out.write_text('\n\n'.join(windows_blocks))
    dispatch_out.write_text('\n'.join(dispatch))
    print(f'Generated {len(macos_blocks)} handlers')

if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1:
        generate(sys.argv[1:])
    else:
        # default first batch: message/conversation related
        batch1 = [
            'batchDeleteMessages', 'clearMessagesKeepLatest', 'clearRemoteConversationMessage',
            'deleteRemoteMessage', 'updateRemoteMessageContent', 'getRemoteMessage',
            'getMessageCount', 'searchConversationsMessages'
        ]
        generate(batch1)
