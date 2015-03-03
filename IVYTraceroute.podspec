#
# Be sure to run `pod lib lint IVYTraceroute.podspec' to ensure this is a
# valid spec and remove all comments before submitting the spec.
#
# Any lines starting with a # are optional, but encouraged
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "IVYTraceroute"
  s.version          = "1.0.0"
  s.summary          = "A simple UDP based traceroute implemention for iOS."
  s.description      = <<-DESC
                       implement traceroute based UDP inspired by [kris92](https://github.com/kris92) and Apple's implemention by DTS, but convert to
                       modern objc syntax.
                       DESC
  s.homepage         = "https://github.com/ivoryxiong/IVYTraceroute"
  s.license          = 'MIT'
  s.author           = { "ivoryxiong" => "ivoryxiong@gmail.com" }
  s.source           = { :git => "https://github.com/ivoryxiong/IVYTraceroute.git", :tag => s.version.to_s }

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes'
  s.resource_bundles = {
    'IVYTraceroute' => ['Pod/Assets/*.png']
  }

end
