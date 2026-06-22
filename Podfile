# Uncomment the next line to define a global platform for your project
platform :ios, '18.0'

target 'SmartGlassesVision' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # MobileVLCKit - 低延迟 RTSP/RTMP 硬件解码
  pod 'MobileVLCKit', '~> 3.6'

  # RxSwift 和 Alamofire 通过 SPM 管理 (在 Package.swift 中)
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
      # 禁用 bitcode (VLCKit 不支持 bitcode)
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end
