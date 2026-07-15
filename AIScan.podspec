Pod::Spec.new do |spec|
  spec.name         = "AIScan"
  spec.version      = "2.2.4"
  spec.summary      = "AI module for diagnosing dogs (eyes, teeth, skin, joints) and cats (eyes, teeth)."
  spec.description  = <<-DESC
AIScan is a powerful AI module designed to assist veterinarians and pet owners in diagnosing common health issues in dogs and cats. The module specializes in:

- Dogs: Eyes, Teeth, Skin, Joints
- Cats: Eyes, Teeth

By leveraging advanced machine learning algorithms, AIScan provides accurate and fast diagnostics to help ensure the health and well-being of pets. 
                   DESC
  spec.homepage     = "https://www.aiforpet.com/"
  spec.license      = { :type => 'Data and API Subscription License', :text => 'This library requires a subscription license to access the AIScan service. Please refer to the service documentation for more details.' }
  spec.author       = { "hjlee" => "hjlee@aiforpet.com" }
  spec.platform     = :ios, "15.0"
  spec.source       = { :git => "https://github.com/Aiforpet-TTcare/AIScan.git", :tag => "2.2.4" }
  spec.swift_versions = ['5.9', '5.10', '6.0']
  spec.default_subspec = 'UI'
  spec.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  spec.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }

  spec.subspec 'Core' do |core|
    core.vendored_frameworks = 'AIScanCore.xcframework'
  end

  spec.subspec 'UI' do |ui|
    ui.source_files = 'Sources/AIScanCameraUI/**/*.swift', 'Sources/AIScanReferenceUI/**/*.swift'
    ui.dependency 'AIScan/Core'
  end

  spec.subspec 'CameraUI' do |ui|
    ui.source_files = 'Sources/AIScanCameraUI/**/*.swift'
    ui.dependency 'AIScan/Core'
  end

  spec.subspec 'ReferenceUI' do |ui|
    ui.source_files = 'Sources/AIScanReferenceUI/**/*.swift'
    ui.dependency 'AIScan/Core'
  end
end
