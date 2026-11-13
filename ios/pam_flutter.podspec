#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint pam_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'pam_flutter'
  s.version          = '3.1.2'
  s.summary          = 'PAM Flutter plugin.'
  s.description      = <<-DESC
     The PAM Flutter plugin allows you to integrate the PAM SDK with your Flutter application, providing seamless access to PAM features and functionalities.
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

  # Bundle the privacy manifest with the plugin.
  s.resource_bundles = {'pam_flutter_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
