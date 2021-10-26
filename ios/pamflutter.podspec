#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint pamflutter.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'pamflutter'
  s.version          = '0.0.1'
  s.summary          = 'PAM Flutter plugin.'
  s.description      = <<-DESC
PAM Flutter SDK
                       DESC
  s.homepage         = 'http://pams.ai'
  s.license          = { :file => '../LICENSE' }
  s.author           = { '3DS Interactive' => 'contact@3dsinteractive.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.5'
end