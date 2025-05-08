Pod::Spec.new do |spec|
  spec.name         = "AIScan"
  spec.version      = "1.0.9"
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
  spec.platform     = :ios, "13.0"
  spec.source       = { :git => "https://github.com/Aiforpet-TTcare/AIScan.git", :tag => "1.0.9" }
  spec.vendored_frameworks = 'AIScan.xcframework'
  spec.dependency "TensorFlowLiteSwift", "~> 2.14.0"
  spec.swift_version    = '6.0'
end
