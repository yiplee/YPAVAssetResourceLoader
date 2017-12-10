//
//  YPAssetResourceContentInfo.m
//  YPAVPlayerResourceLoader
//
//  Created by Li Guoyin on 2017/12/7.
//  Copyright © 2017年 Li Guoyin. All rights reserved.
//

#import "YPAssetResourceContentInfo.h"
#import <MobileCoreServices/MobileCoreServices.h>

@implementation YPAssetResourceContentInfo

- (instancetype) initWithHTTPResponse:(NSHTTPURLResponse *)response {
    self = [super init];
    if (self) {
        NSString *mimeType = [response MIMEType];
        CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
        _contentType = CFBridgingRelease(contentType);
        
        NSDictionary *headers = response.allHeaderFields;
        NSString *contentRange = [headers objectForKey:@"Content-Range"];
        
        _byteRangeAccessSupported = contentRange.length > 0;
        
        long long contentLength = 0;
        NSArray<NSString *> *ranges = [contentRange componentsSeparatedByString:@"/"];
        if (ranges.count > 1) {
            NSString *contentLengthString = [ranges.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            contentLength = [contentLengthString longLongValue];
        }
        
        _contentLength = contentLength ?: response.expectedContentLength;
    }
    
    return self;
}

- (instancetype) initWithLocalFilePath:(NSString *)filePath {
    self = [super init];
    if (self) {
        NSFileManager *manager = [NSFileManager defaultManager];
        
        BOOL isDir = NO;
        BOOL fileExist = [manager fileExistsAtPath:filePath isDirectory:&isDir];
        NSParameterAssert(fileExist && !isDir);
        
        if (fileExist && !isDir) {
            NSString *extension = filePath.pathExtension;
            if (extension.length == 0) extension = @"mp4";
            
            NSString *mimeType = [NSString stringWithFormat:@"video/%@",extension];
            CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);
            _contentType = CFBridgingRelease(contentType);
            
            _byteRangeAccessSupported = YES;
            _contentLength = [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
        }
    }
    
    return self;
}

- (NSString *) description {
    return [NSString stringWithFormat:@"<%@-%p> contentType : %@ contentLength : %zd rangeSupport : %zd",NSStringFromClass(self.class),self,self.contentType,self.contentLength,self.byteRangeAccessSupported];
}

@end
