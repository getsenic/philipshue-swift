Pod::Spec.new do |s|
  s.name         = "PhilipsHue"
  s.version      = "0.0.1"
  s.summary      = "Library for interacting with Philips Hue lighting systems."
  s.homepage     = "https://github.com/getsenic/philipshue-swift"
  s.license      = "MIT"
  s.authors      = { "Lars Alexander Blumberg" => "lars@senic.com" }
  s.source       = { :git => "https://github.com/getsenic/philipshue-swift.git", :tag => s.version }
  s.source_files = '*.swift'
  s.dependency 'Alamofire', '4.2.0'
  s.ios.deployment_target  = '9.0'
  s.osx.deployment_target  = '10.11'
  s.tvos.deployment_target = '9.0'
end
