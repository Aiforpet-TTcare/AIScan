#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'xcodeproj'

output = File.expand_path(ARGV.fetch(0))
package_root = File.expand_path(ARGV.fetch(1))
app_dir = File.join(output, 'App')
project_path = File.join(output, 'AIScanCompatibilityHost.xcodeproj')

FileUtils.mkdir_p(app_dir)
File.write(
  File.join(app_dir, 'AppDelegate.swift'),
  <<~SWIFT
    import AIScan
    import UIKit

    @main
    final class AppDelegate: UIResponder, UIApplicationDelegate {
        var window: UIWindow?

        func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
        ) -> Bool {
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = UIViewController()
            window.makeKeyAndVisible()
            self.window = window

            Task { @MainActor in
                _ = AIScanManager.self
            }
            return true
        }
    }
  SWIFT
)
File.write(
  File.join(app_dir, 'Info.plist'),
  <<~PLIST
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleDevelopmentRegion</key>
      <string>$(DEVELOPMENT_LANGUAGE)</string>
      <key>CFBundleExecutable</key>
      <string>$(EXECUTABLE_NAME)</string>
      <key>CFBundleIdentifier</key>
      <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
      <key>CFBundleInfoDictionaryVersion</key>
      <string>6.0</string>
      <key>CFBundleName</key>
      <string>$(PRODUCT_NAME)</string>
      <key>CFBundlePackageType</key>
      <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
      <key>CFBundleShortVersionString</key>
      <string>1.0</string>
      <key>CFBundleVersion</key>
      <string>1</string>
      <key>LSRequiresIPhoneOS</key>
      <true/>
      <key>UILaunchScreen</key>
      <dict/>
      <key>UIRequiresFullScreen</key>
      <true/>
    </dict>
    </plist>
  PLIST
)

project = Xcodeproj::Project.new(project_path)
target = project.new_target(:application, 'AIScanCompatibilityHost', :ios, '13.0')
app_group = project.main_group.new_group('App', 'App')
source = app_group.new_file('AppDelegate.swift')
app_group.new_file('Info.plist')
target.add_file_references([source])

relative_package_path = Pathname(package_root).relative_path_from(Pathname(output)).to_s
package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package.relative_path = relative_package_path
project.root_object.package_references << package

product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
product.package = package
product.product_name = 'AIScan'
target.package_product_dependencies << product
build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
build_file.product_ref = product
target.frameworks_build_phase.files << build_file

target.build_configurations.each do |configuration|
  configuration.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
  configuration.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  configuration.build_settings['INFOPLIST_FILE'] = 'App/Info.plist'
  configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
  configuration.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks'
  configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.aiforpet.AIScanCompatibilityHost'
  configuration.build_settings['SWIFT_VERSION'] = '5.0'
  configuration.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
end

project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.save_as(project_path, 'AIScanCompatibilityHost', true)
