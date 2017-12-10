//
//  YPAVPlayerResourceLoader.h
//  YPAVPlayerResourceLoader
//
//  Created by Li Guoyin on 2017/12/3.
//  Copyright © 2017年 Li Guoyin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YPAVPlayerResourceLoader : NSObject<AVAssetResourceLoaderDelegate>

- (instancetype) initWithRemoteAssetURL:(nullable NSURL *)assetURL;
- (instancetype) initWithRemoteAssetURL:(nullable NSURL *)assetURLd
                     diskCacheDirectory:(nullable NSString *)directory NS_DESIGNATED_INITIALIZER;

@property (nonatomic, copy, readonly, nullable) NSURL *streamingAssetURL;

- (void) invalidateAndSaveCache:(BOOL)cache;

@end

@interface AVPlayerItem (YPResourceLoader)

+ (instancetype) playerItemWithYPResourceURL:(NSURL *)resourceURL;

@end

@interface AVURLAsset (YPAVPlayerResourceLoader)

+ (instancetype) assetWithYPResourceURL:(NSURL *)resourceURL;

@end

@interface AVAssetResourceLoadingRequest (YPResourceLoader)

- (BOOL) isContentInfoRequest;
- (BOOL) isContentDataRequest;

- (void) respondWithData:(NSData *)data dataOffset:(NSInteger)dataOffset;

@end

extern NSString *const YPAVPlayerResourceLoaderStreamingSchemeSuffix;

NS_ASSUME_NONNULL_END
