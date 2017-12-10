# YPAVAssetResourceLoader

[![CI Status](http://img.shields.io/travis/yiplee/YPAVAssetResourceLoader.svg?style=flat)](https://travis-ci.org/yiplee/YPAVAssetResourceLoader)
[![Version](https://img.shields.io/cocoapods/v/YPAVAssetResourceLoader.svg?style=flat)](http://cocoapods.org/pods/YPAVAssetResourceLoader)
[![License](https://img.shields.io/cocoapods/l/YPAVAssetResourceLoader.svg?style=flat)](http://cocoapods.org/pods/YPAVAssetResourceLoader)
[![Platform](https://img.shields.io/cocoapods/p/YPAVAssetResourceLoader.svg?style=flat)](http://cocoapods.org/pods/YPAVAssetResourceLoader)

```YPAVAssetResourceLoader``` A lightweight AVAssetResourceLoaderDelegate implementation for short streaming media.
It will cache all receiving data when playing and reuse the data next time.

- [x] cache media data
- [ ] seek support (todo)

## Requirements

Xcode 9 & iOS 8

## Installation

YPAVAssetResourceLoader is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'YPAVAssetResourceLoader'
```

## Usage

```objc
#import <YPAVAssetResourceLoader/YPAVPlayerResourceLoader.h>

NSURL *url = [NSURL URLWithString:@"http://www.yiplee.com/example.mp4"];
AVAsset *asset = [AVURLAsset assetWithYPResourceURL:url];
AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
```

## License

YPAVAssetResourceLoader is available under the MIT license. See the LICENSE file for more info.
