Pod::Spec.new do |s|
  s.name             = 'imclient'
  s.version          = '0.0.1'
  s.summary          = 'WFC IM Client Plugin'
  s.description      = 'WFC IM Client Flutter plugin for macOS.'
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Wildfire Chat' => 'support@wildfirechat.cn' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{h,m,mm,c,cpp}'
  s.public_header_files = 'Classes/ImclientPlugin.h'
  s.vendored_libraries = 'libMarsWrapper.dylib'
  s.framework = 'FlutterMacOS'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '15.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../marslib/include" "$(inherited)"',
    'LIBRARY_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)" "$(inherited)"'
  }
end
