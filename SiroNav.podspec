Pod::Spec.new do |s|
  s.name             = 'SiroNav'
  s.version          = '0.1.0'
  s.summary          = 'Commercial Turn-by-Turn Navigation SDK for iOS on Siro Maps'
  s.homepage         = 'https://github.com/Hamza-Ayed/siro-nav-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Hamza Ayed' => 'hamzaayedflutter@gmail.com' }
  s.source           = { :git => 'https://github.com/Hamza-Ayed/siro-nav-ios.git', :tag => s.version.to_s }
  s.ios.deployment_target = '14.0'
  s.swift_version    = '5.9'
  s.source_files     = 'Sources/SiroNav/**/*.swift'
  s.resources        = 'Sources/SiroNav/Resources/**/*'
  s.frameworks       = 'UIKit', 'CoreLocation', 'AVFoundation'
end
