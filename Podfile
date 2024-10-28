# Uncomment the next line to define a global platform for your project
platform :ios, '13.3'

target 'Kaltura-Demo' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Kaltura-Demo
  pod "PlayKit"
  pod "PlayKitProviders"
  pod "PlayKitKava"
  pod "Arcane"
end

post_install do |installer|
    installer.generated_projects.each do |project|
        project.targets.each do |target|
            target.build_configurations.each do |config|
                config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
            end
        end
    end
end
