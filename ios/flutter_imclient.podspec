#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_imclient.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_imclient'
  s.version          = '0.0.1'
  s.summary          = 'Wildfire chat flutter plugin.'
  s.description      = <<-DESC
Wildfire chat flutter plugin.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*', 'Lib/amr/*'
  s.public_header_files = 'Classes/*.h'
  s.frameworks = 'SystemConfiguration','CoreTelephony'
  s.vendored_frameworks = 'Lib/mars.framework'
  s.libraries = 'c++','z','resolv'
  s.dependency 'Flutter'
  s.platform = :ios, '8.0'
  s.vendored_libraries = 'Lib/amr/libopencore-amrnb.a'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
