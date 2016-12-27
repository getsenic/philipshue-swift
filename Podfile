platform :ios, '9.0'

target 'PhilipsHueDemo' do
  use_frameworks!

  pod 'Alamofire'
  pod 'CocoaSSDP',  :git => 'https://github.com/getsenic/ssdp-discovery-objc.git', :tag => '1.0.0'
  pod 'PhilipsHue', :path => '.'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['CONFIGURATION_BUILD_DIR'] = '$PODS_CONFIGURATION_BUILD_DIR'
    end
  end
end
