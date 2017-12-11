#
# Be sure to run `pod lib lint YPAVAssetResourceLoader.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'YPAVAssetResourceLoader'
  s.version          = '0.1.2'
  s.summary          = 'A lightweight AVAssetResourceLoaderDelegate implementation for short streaming media.'

  s.description      = <<-DESC
  A lightweight AVAssetResourceLoaderDelegate implementation for short streaming media.
  Cache dowloaded file and reuse automatically!
                       DESC

  s.homepage         = 'https://github.com/yiplee/YPAVAssetResourceLoader'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'yiplee' => 'guoyinl@gmail.com' }
  s.source           = { :git => 'https://github.com/yiplee/YPAVAssetResourceLoader.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/yipleeyin'

  s.ios.deployment_target = '8.0'

  s.source_files = 'YPAVAssetResourceLoader/Classes/**/*'
  
  # s.resource_bundles = {
  #   'YPAVAssetResourceLoader' => ['YPAVAssetResourceLoader/Assets/*.png']
  # }

  s.frameworks = 'AVFoundation'
end
