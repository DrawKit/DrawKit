# podspec is a work in progress

Pod::Spec.new do |s|
  s.name         = "DrawKit"
  s.version      = "1.0.0b7"
  s.summary      = "Vector drawing and illustration framework."
  s.description  = <<-DESC
DrawKit is a software framework that enables the Mac OS X Cocoa developer to rapidly implement vector drawing and illustration features in a custom application. It is comprehensive, powerful and complete, but it is also highly modular so you can make use of only those parts that you need, or go the whole hog and drop it in as a complete vector drawing solution.
DESC
  s.homepage     = "https://github.com/DrawKit/DrawKit"
  s.screenshots  = "https://raw.github.com/DrawKit/DrawKit/master/documentation/drawkit-sample-capabilities.png"
  s.license      = { :type => 'BSD', :file => 'LICENSE' }
  s.author       = 'Graham Cox', 'Graham Miln'
  s.platform     = :osx,'10.7'
  s.vendored_frameworks = 'DKDrawKit.framework'
  s.source       = { :git => "https://github.com/DrawKit/DrawKit.git", :tag => "v1.0.0-beta.7" }
  s.source_files  = 'framework/**/*.{h,m,mm}'
  s.public_header_files = 'framework/Code/*.h'
end
