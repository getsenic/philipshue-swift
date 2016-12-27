Pod::Spec.new do |s|
  s.name         = "PhilipsHue"
  s.version      = "1.0.0"
  s.summary      = "Library for interacting with Philips Hue lighting systems."
  s.homepage     = "https://github.com/getsenic/philipshue-swift"
  s.license      = "MIT"
  s.authors      = { "Lars Alexander Blumberg" => "lars@senic.com" }
  s.source       = { :git => "https://github.com/getsenic/philipshue-swift.git", :tag => s.version }
  s.source_files = 'PhilipsHue/*.swift'
  s.dependency 'Alamofire', '~> 4.2'
  s.dependency 'CocoaSSDP' # Needs to be overwritten in your local Podfile with: 'CocoaSSDP', :git => 'https://github.com/getsenic/ssdp-discovery-objc.git', :tag => '1.0.0'
  s.ios.deployment_target  = '9.0'
  s.osx.deployment_target  = '10.10'
  s.tvos.deployment_target = '9.0'
end
