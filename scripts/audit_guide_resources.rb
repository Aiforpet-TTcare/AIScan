#!/usr/bin/env ruby
# Evaluate the actual podspec resource globs rather than searching its text.
require 'json'
require 'pathname'

root = Pathname.new(__dir__).parent
module Pod
  class Spec
    attr_accessor :resource_bundles

    def self.new
      spec = allocate
      yield spec
      spec
    end

    def method_missing(name, *arguments)
      return nil if name.to_s.end_with?('=')
      super
    end
  end
end

spec = eval(root.join('AIScan.podspec').read, binding, 'AIScan.podspec')
packaged = spec.resource_bundles.values.flatten.flat_map { |glob| Dir.glob(root.join(glob).to_s) }
expected = %w[guideDogEye guideDogBody guideDogEar guideDogPaw guideDogTeeth guideCatEye guideCatTeeth]
expected.each do |name|
  path = root.join("Sources/AIScanCameraUI/ReferenceResources/GuideMedia/#{name}.json")
  abort "CocoaPods resource list omits #{path.basename}" unless packaged.include?(path.to_s)
  animation = JSON.parse(path.read)
  unless animation['layers'].is_a?(Array) && animation['fr'].to_f.positive? && animation['op'].to_f > animation['ip'].to_f
    abort "Invalid or non-playable guide animation: #{path.basename}"
  end
end
abort 'SPM no longer processes guide resources' unless root.join('Package.swift').read.include?('.process("ReferenceResources")')
puts 'All seven guide animations are valid and included by CocoaPods and SPM.'
