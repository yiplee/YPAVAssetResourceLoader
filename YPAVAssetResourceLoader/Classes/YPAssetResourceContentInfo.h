//
//  YPAssetResourceContentInfo.h
//  YPAVPlayerResourceLoader
//
//  Created by Li Guoyin on 2017/12/7.
//  Copyright © 2017年 Li Guoyin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YPAssetResourceContentInfo : NSObject

- (instancetype) init NS_UNAVAILABLE;

// make content info from http response
- (instancetype) initWithHTTPResponse:(NSHTTPURLResponse *)response NS_DESIGNATED_INITIALIZER;

// make content info from local file path
- (instancetype) initWithLocalFilePath:(NSString *)filePath NS_DESIGNATED_INITIALIZER;

@property (nonatomic, copy, readonly, nullable) NSString *contentType;
@property (nonatomic, assign, readonly) BOOL byteRangeAccessSupported;
@property (nonatomic, assign, readonly) long long contentLength;

@end

NS_ASSUME_NONNULL_END
