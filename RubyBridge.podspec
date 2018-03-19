Pod::Spec.new do |s|
  s.name         = "RubyBridge"
  s.version      = "0.2.0"
  s.authors      = { "John Fairhurst" => "johnfairh@gmail.com" }
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.homepage     = "https://github.com/johnfairh/RubyBridge"
  s.source       = { :git => "https://github.com/johnfairh/RubyBridge.git",
#                     :tag => "v#{s.version.to_s}",
                     :branch => "cpod",
                     :submodules => true }
  s.summary      = "Embed Ruby in Swift: load Gems, run scripts, get results."
  s.description = <<-EDESC
                    A Swift framework built on the Ruby C API that lets Swift
                    programs painlessly and safely run and interact with Ruby
                    programs.  It is easy to pass Swift datatypes into Ruby
                    and turn Ruby objects back into Swift types.
                  EDESC
  s.documentation_url = "https://johnfairh.github.io/RubyBridge/"
  s.source_files  = "Sources/RubyBridge/*swift"
  s.platform = :osx, '10.13'
  s.swift_version = "4.0"
  s.frameworks  = "Foundation"
  s.preserve_path = 'CRuby/*', 'RubyBridgeHelpers/*'
  s.pod_target_xcconfig = { 'SWIFT_INCLUDE_PATHS' => '"${PODS_ROOT}/RubyBridge/CRuby" "${PODS_ROOT}/RubyBridge/RubyBridgeHelpers"' }
  s.subspec 'RubyBridgeHelpers' do |ss|
    ss.preserve_path = "CRuby/*"
    ss.source_files = 'Sources/RubyBridgeHelpers/*m', 'Sources/RubyBridgeHelpers/include/*h'
    ss.pod_target_xcconfig = { 'HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/RubyBridge/CRuby"' }
    ss.private_header_files = 'Sources/RubyBridgeHelpers/include/*h'
  end
end
