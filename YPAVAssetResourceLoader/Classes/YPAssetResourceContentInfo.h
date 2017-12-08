//
//  YPAssetResourceContentInfo.h
//  YPAVPlayerResourceLoader
//
//  Created by Li Guoyin on 2017/12/7.
//  Copyright © 2017年 Li Guoyin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface YPAssetResourceContentInfo : NSObject

@property (nonatomic, copy, readonly) NSString *contentType;
@property (nonatomic, assign, readonly) BOOL byteRangeAccessSupported;
@property (nonatomic, assign, readonly) unsigned long long contentLength;

- (instancetype) initWithHTTPResponse:(NSHTTPURLResponse *)response;

- (instancetype) initWithLocalFilePath:(NSString *)filePath;

@end
