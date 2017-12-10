//
//  YPAVPlayerResourceLoader.m
//  YPAVPlayerResourceLoader
//
//  Created by Li Guoyin on 2017/12/3.
//  Copyright © 2017年 Li Guoyin. All rights reserved.
//

#import "YPAVPlayerResourceLoader.h"
#import <CommonCrypto/CommonDigest.h>

#import "YPAssetResourceContentInfo.h"

static NSString *const YPAVPlayerResourceLoaderDomain = @"com.yiplee.YPAVPlayerResourceLoader";

@interface YPRemoteSourceLodingOperation : NSObject

@property (nonatomic, strong) NSURLSessionDataTask *task;
@property (nonatomic, assign) NSInteger requestOffset;
@property (nonatomic, assign) NSInteger currentOffset;
@property (nonatomic, assign) NSInteger requestLength;

- (BOOL) isAtEnd;

@property (nonatomic, strong) AVAssetResourceLoadingRequest *loadingRequest;

- (void) respondWithData:(NSData *)data;

@end

@implementation YPRemoteSourceLodingOperation

- (void) respondWithData:(NSData *)data
{
    [_loadingRequest respondWithData:data dataOffset:_currentOffset];
    _currentOffset += data.length;
}

- (BOOL) isAtEnd
{
    return _currentOffset >= _requestOffset + _requestLength;
}

@end

@interface YPAVPlayerResourceLoader ()<NSURLSessionTaskDelegate,NSURLSessionDataDelegate>

@property (nonatomic, strong) YPRemoteSourceLodingOperation *rootOperation;
@property (nonatomic, strong) NSMutableArray<YPRemoteSourceLodingOperation *> *loadingOperations;

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSOperationQueue *responseQueue;

@property (nonatomic, strong) YPAssetResourceContentInfo *contentInfo;

@end

@implementation YPAVPlayerResourceLoader {
    NSURL *_assetURL;
    
    NSString *_videoFilePath;
    NSString *_downloadFilePath;
    NSString *_temporaryFilePath;
    
    NSFileHandle *_cacheWriter;
    NSFileHandle *_dataReader;
}

- (void) dealloc {
    [_cacheWriter closeFile];
    _cacheWriter = nil;
    
    [_dataReader closeFile];
    _dataReader = nil;
    
    if (_temporaryFilePath) {
        [[NSFileManager defaultManager] removeItemAtPath:_temporaryFilePath
                                                   error:nil];
    }
}

- (instancetype) init {
    return [self initWithRemoteAssetURL:nil];
}

- (instancetype) initWithRemoteAssetURL:(NSURL *)assetURL {
    NSString *cacheDirectory = [self.class defaultCacheDirectory];
    return [self initWithRemoteAssetURL:assetURL diskCacheDirectory:cacheDirectory];
}

- (instancetype) initWithRemoteAssetURL:(NSURL *)assetURL diskCacheDirectory:(NSString *)directory {
    NSParameterAssert(assetURL && assetURL.pathExtension && directory);
    
    self = [super init];
    if (!self) return nil;
    
    NSFileManager *manager = [NSFileManager defaultManager];
    directory = [self.class makeDiskCachePath:directory];
    if (![manager fileExistsAtPath:directory]) {
        [manager createDirectoryAtPath:[directory stringByAppendingPathComponent:@"download"]
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:nil];
    }
    
    NSString *videoFileName = [self.class cachedFileNameForAssetURL:assetURL];
    _videoFilePath = [directory stringByAppendingPathComponent:videoFileName];
    _downloadFilePath = [[directory stringByAppendingPathComponent:@"download"] stringByAppendingPathComponent:videoFileName];
    
    const BOOL videoFileExist = [manager fileExistsAtPath:_videoFilePath];
    if (videoFileExist) {
        _contentInfo = [[YPAssetResourceContentInfo alloc] initWithLocalFilePath:_videoFilePath];
        _rootOperation = [YPRemoteSourceLodingOperation new];
        _rootOperation.requestLength = _contentInfo.contentLength;
        _rootOperation.currentOffset = _contentInfo.contentLength;
        _dataReader = [NSFileHandle fileHandleForReadingAtPath:_videoFilePath];
    }
    
    // then check dowload folder
    if (!_contentInfo) {
        _temporaryFilePath = [self.class makeTemporaryCacheDiskPath];
        const BOOL dowloadFileExist = [manager fileExistsAtPath:_downloadFilePath];
        if (dowloadFileExist) {
            NSError *copyFileError = nil;
            
            [manager copyItemAtPath:_downloadFilePath
                             toPath:_temporaryFilePath
                              error:&copyFileError];
            
            if (copyFileError) {
                [manager createFileAtPath:_temporaryFilePath
                                 contents:nil
                               attributes:nil];
            }
        } else {
            [manager createFileAtPath:_temporaryFilePath
                             contents:nil
                           attributes:nil];
        }
        
        const long long temporaryFileSize = [[manager attributesOfItemAtPath:_temporaryFilePath error:nil] fileSize];
        _rootOperation = [YPRemoteSourceLodingOperation new];
        _rootOperation.requestLength = NSNotFound;
        _rootOperation.currentOffset = temporaryFileSize;
        
        _dataReader = [NSFileHandle fileHandleForReadingAtPath:_temporaryFilePath];
        _cacheWriter = [NSFileHandle fileHandleForWritingAtPath:_temporaryFilePath];
        [_cacheWriter seekToEndOfFile];
    }
    
    _assetURL = assetURL;
    _loadingOperations = [NSMutableArray new];
    
    _responseQueue = [NSOperationQueue new];
//    _responseQueue.maxConcurrentOperationCount = 1;
    _responseQueue.name = YPAVPlayerResourceLoaderDomain;
    
    NSURLSessionConfiguration *configure = [NSURLSessionConfiguration defaultSessionConfiguration];
    _session = [NSURLSession sessionWithConfiguration:configure
                                             delegate:self
                                        delegateQueue:_responseQueue];
    
    return self;
}

- (void) invalidateAndSaveCache:(BOOL)cache {
    [self.loadingOperations removeAllObjects];
    [self.session invalidateAndCancel];
    self.session = nil;
    self.responseQueue = nil;
    
    if (cache) {
        [self saveCache];
    }
}

- (void) saveCache {
    if (_cacheWriter) {
        [_cacheWriter synchronizeFile];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (_rootOperation.isAtEnd) {
            [fileManager moveItemAtPath:_temporaryFilePath
                                 toPath:_videoFilePath
                                  error:nil];
        } else {
            [fileManager removeItemAtPath:_downloadFilePath error:nil];
            [fileManager moveItemAtPath:_temporaryFilePath
                                 toPath:_downloadFilePath
                                  error:nil];
        }
    }
}

#pragma mark - configure

+ (NSString *) defaultCacheDirectory {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return paths.firstObject;
}

+ (NSString *) makeDiskCachePath:(NSString *)cacheDirectory {
    return [cacheDirectory stringByAppendingPathComponent:YPAVPlayerResourceLoaderDomain];
}

+ (NSString *) makeTemporaryCacheDiskPath {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
}

+ (NSString *)cachedFileNameForAssetURL:(NSURL *)url {
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    components.query = nil;
    const char *str = components.string.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *ext = url.pathExtension;
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], ext.length == 0 ? @"" : [NSString stringWithFormat:@".%@", ext]];
    return filename;
}

#pragma mark -

- (NSURL *) streamingAssetURL {
    if (!_assetURL) return nil;
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:_assetURL resolvingAgainstBaseURL:NO];
    NSString *scheme = components.scheme;
    NSString *suffix = YPAVPlayerResourceLoaderStreamingSchemeSuffix;
    components.scheme = [scheme stringByAppendingString:suffix];
    
    return components.URL;
}

- (NSURL *) originalURLFromStreamingURL:(NSURL *)url {
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSString *scheme = components.scheme;
    NSString *suffix = YPAVPlayerResourceLoaderStreamingSchemeSuffix;
    if ([scheme hasSuffix:suffix]) {
        scheme = [scheme substringToIndex:scheme.length - suffix.length];
    }
    
    components.scheme = scheme;
    return components.URL;
}

#pragma mark - tasks

- (void) fullfilLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
                   contentInfo:(YPAssetResourceContentInfo *)contentInfo {
    NSParameterAssert(contentInfo);
    
    loadingRequest.contentInformationRequest.contentType = contentInfo.contentType;
    loadingRequest.contentInformationRequest.contentLength = contentInfo.contentLength;
    loadingRequest.contentInformationRequest.byteRangeAccessSupported = contentInfo.byteRangeAccessSupported;
}

- (NSString *) makeRangeStringWithBytesRange:(NSRange)byteRange isToEnd:(BOOL)isToEnd {
    if (isToEnd) {
        return [NSString stringWithFormat:@"bytes=%zd-",byteRange.location];
    } else {
        return [NSString stringWithFormat:@"bytes=%zd-%zd",byteRange.location,NSMaxRange(byteRange) - 1];
    }
}

- (void) handleRootOperationWithRequest:(NSURLRequest *)request {
    NSParameterAssert(_rootOperation && (!_rootOperation.task || _rootOperation.task.error) && self.contentInfo);
    
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    mutableRequest.URL = [self originalURLFromStreamingURL:request.URL];
    NSString *range = [self makeRangeStringWithBytesRange:NSMakeRange(_rootOperation.currentOffset, NSNotFound) isToEnd:YES];
    [mutableRequest setValue:range forHTTPHeaderField:@"Range"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:mutableRequest];
    [task resume];
    
    _rootOperation.requestLength = self.contentInfo.contentLength;
    _rootOperation.task = task;
}

- (void) handleLoadingOperation:(YPRemoteSourceLodingOperation *)operation {
    NSParameterAssert(!operation.task && operation.loadingRequest);
    
    AVAssetResourceLoadingRequest *loadingRequest = operation.loadingRequest;
    AVAssetResourceLoadingDataRequest *dataRequest = loadingRequest.dataRequest;
    NSInteger offset = dataRequest.currentOffset;
    NSInteger length = dataRequest.requestedLength - (offset - dataRequest.requestedOffset);
    BOOL isToEnd = NO;
    if (@available(iOS 9,*)) {
        isToEnd = dataRequest.requestsAllDataToEndOfResource;
    }
    
    NSString *byteRange = [self makeRangeStringWithBytesRange:NSMakeRange(offset, length) isToEnd:isToEnd];
    
    NSMutableURLRequest *request = [loadingRequest.request mutableCopy];
    [request setValue:byteRange forHTTPHeaderField:@"Range"];
    
    request.URL = [self originalURLFromStreamingURL:request.URL];
    
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request];
    [dataTask resume];
    
    operation.task = dataTask;
    operation.requestOffset = dataRequest.requestedOffset;
    operation.currentOffset = offset;
    operation.requestLength = dataRequest.requestedLength;
}

- (void) handleContentInfoRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    if (_contentInfo) {
        [self fullfilLoadingRequest:loadingRequest contentInfo:_contentInfo];
        [loadingRequest finishLoading];
        return;
    }
    
    YPRemoteSourceLodingOperation *operation = [YPRemoteSourceLodingOperation new];
    operation.loadingRequest = loadingRequest;
    [self handleLoadingOperation:operation];
    
    [self.loadingOperations addObject:operation];
}

- (void) handleContentDataRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    AVAssetResourceLoadingDataRequest *dataRequest = loadingRequest.dataRequest;
    NSInteger offset = dataRequest.currentOffset;
    NSInteger length = dataRequest.requestedLength - (offset - dataRequest.requestedOffset);
    
    NSInteger cachedContentLength = _rootOperation.currentOffset;
    if (cachedContentLength > offset) {
        NSInteger cachedLength = MIN(cachedContentLength - offset, length);
        [_dataReader seekToFileOffset:offset];
        NSData *data = [_dataReader readDataOfLength:cachedLength];
        [dataRequest respondWithData:data];
        
        if (cachedLength >= length) {
            [loadingRequest finishLoading];
            return;
        }
    }
    
    YPRemoteSourceLodingOperation *operation = [YPRemoteSourceLodingOperation new];
    operation.loadingRequest = loadingRequest;
    
    // if the request data offset is less 200KB then cached file offset
    // don't handle it and wait the root operation
    if (dataRequest.currentOffset - cachedContentLength > 200 * 1024) {
        [self handleLoadingOperation:operation];
    }
    
    [self.loadingOperations addObject:operation];
}

- (void) cacheData:(NSData *)data byteRange:(NSRange)byteRange {
    NSParameterAssert(_cacheWriter.offsetInFile == byteRange.location && data.length == byteRange.length);
    if (_cacheWriter.offsetInFile== byteRange.location) {
        [_cacheWriter writeData:data];
    }
}

- (void) cancelOperation:(YPRemoteSourceLodingOperation *)operation error:(NSError *)error {
    [self.loadingOperations removeObject:operation];
    
    NSParameterAssert(!operation.loadingRequest.isFinished);
    if (error) [operation.loadingRequest finishLoadingWithError:error];
    [operation.task cancel];
}

- (void) finishOperation:(YPRemoteSourceLodingOperation *)operation {
    [self.loadingOperations removeObject:operation];
    
    NSParameterAssert(!operation.loadingRequest.isFinished);
    [operation.loadingRequest finishLoading];
    [operation.task cancel];
}

#pragma mark - AVAssetResourceLoaderDelegate

- (BOOL) resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSParameterAssert([loadingRequest.request.URL.path isEqualToString:_assetURL.path]);
    
    if (self.contentInfo &&
        _rootOperation.task.error &&
        _rootOperation.task.error.code != NSURLErrorCancelled) {
        [self handleRootOperationWithRequest:_rootOperation.task.originalRequest];
    }
    
    BOOL shouldWaite = YES;
    if ([loadingRequest isContentInfoRequest]) {
        [self handleContentInfoRequest:loadingRequest];
    } else if ([loadingRequest isContentDataRequest]) {
        [self handleContentDataRequest:loadingRequest];
    } else {
        shouldWaite = NO;
    }
    
    return shouldWaite;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    for (YPRemoteSourceLodingOperation *operation in self.loadingOperations.copy) {
        if (operation.loadingRequest == loadingRequest) {
            [self cancelOperation:operation error:nil];
            break;
        }
    }
}

#pragma mark NSURLSessionDataDelegate

- (YPRemoteSourceLodingOperation *) operationWithTask:(NSURLSessionTask *)task isRoot:(BOOL *)isRoot {
    if (_rootOperation.task && task.taskIdentifier == _rootOperation.task.taskIdentifier) {
        if (isRoot) *isRoot = YES;
        return _rootOperation;
    }
    
    if (isRoot) *isRoot = NO;
    
    for (YPRemoteSourceLodingOperation *operation in self.loadingOperations.copy) {
        if (operation.task.taskIdentifier == task.taskIdentifier) {
            return operation;
        }
    }
    
    return nil;
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSInteger statusCode = 0;
    if ([response isKindOfClass:NSHTTPURLResponse.class]) {
        statusCode = [(NSHTTPURLResponse*)response statusCode];
    }
    
    if (statusCode > 0 && statusCode < 400 && !self.contentInfo) {
        self.contentInfo = [[YPAssetResourceContentInfo alloc] initWithHTTPResponse:(NSHTTPURLResponse*)response];
        
        BOOL isRoot = NO;
        YPRemoteSourceLodingOperation *operation = [self operationWithTask:dataTask isRoot:&isRoot];
        AVAssetResourceLoadingRequest *request = operation.loadingRequest;
        if (request.isContentInfoRequest) {
            [self fullfilLoadingRequest:request contentInfo:self.contentInfo];
            request.response = response;
            [self finishOperation:operation];
        }
        
        // did get the content info, make the root operation run
        [self handleRootOperationWithRequest:dataTask.originalRequest];
    }
    
    if (completionHandler) completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler {
    BOOL isRoot = NO;
    YPRemoteSourceLodingOperation *operation = [self operationWithTask:task isRoot:&isRoot];
    AVAssetResourceLoadingRequest *loadingRequest = operation.loadingRequest;
    loadingRequest.redirect = request;
    
    if (completionHandler) completionHandler(request);
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    BOOL isRoot = NO;
    YPRemoteSourceLodingOperation *operation = [self operationWithTask:dataTask isRoot:&isRoot];
    const NSInteger dataOffset = operation.currentOffset;
    NSRange dataRange = NSMakeRange(dataOffset, data.length);
    [operation respondWithData:data];
    
    if (isRoot) {
        [self cacheData:data byteRange:dataRange];
        
        // update all other loading requests
        const NSInteger cachedOffset = _rootOperation.currentOffset;
        for (YPRemoteSourceLodingOperation *op in self.loadingOperations.copy) {
            if (op.loadingRequest.isContentDataRequest) {
                AVAssetResourceLoadingDataRequest *dataRequest = op.loadingRequest.dataRequest;
                NSRange requestRange = NSMakeRange(dataRequest.currentOffset, dataRequest.requestedLength - (dataRequest.currentOffset - dataRequest.requestedOffset));
                NSRange cacheRange = NSMakeRange(0, cachedOffset);
                NSRange range = NSIntersectionRange(requestRange, cacheRange);
                if (range.location != NSNotFound && range.length > 0) {
                    [_dataReader seekToFileOffset:range.location];
                    NSData *data = [_dataReader readDataOfLength:range.length];
                    [dataRequest respondWithData:data];
                    
                    if (dataRequest.currentOffset - dataRequest.requestedOffset >= dataRequest.requestedLength) {
                        [self finishOperation:op];
                    }
                }
            }
        }
    } else if (operation) {
        AVAssetResourceLoadingRequest *loadingRequest = operation.loadingRequest;
        if (loadingRequest.isContentDataRequest) {
            AVAssetResourceLoadingDataRequest *dataRequest = loadingRequest.dataRequest;
            if (dataRequest.currentOffset - dataRequest.requestedOffset >= dataRequest.requestedLength) {
                [self finishOperation:operation];
            }
        }
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {
    if (completionHandler) completionHandler(nil);
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    BOOL isRoot = NO;
    YPRemoteSourceLodingOperation *operation = [self operationWithTask:task isRoot:&isRoot];
    
    if (isRoot) {
        if (error) {
            // root operation get error, finish all loading request with this error
            for (YPRemoteSourceLodingOperation *op in self.loadingOperations.copy) {
                [self cancelOperation:op error:error];
            }
        } else {
            [self saveCache];
            [_cacheWriter closeFile];
            _cacheWriter = nil;
        }
    } else if (operation) {
        if (error) [self cancelOperation:operation error:error];
        else [self finishOperation:operation];
    }
}


@end

@interface YPAVURLAsset : AVURLAsset
@end

@implementation YPAVURLAsset

- (void) dealloc
{
    YPAVPlayerResourceLoader *resourceLoader = (YPAVPlayerResourceLoader*)self.resourceLoader.delegate;
    [resourceLoader invalidateAndSaveCache:YES];
}

@end

@implementation AVURLAsset (YPAVPlayerResourceLoader)

+ (instancetype) assetWithYPResourceURL:(NSURL *)resourceURL
{
    YPAVPlayerResourceLoader *resourceLoader = [[YPAVPlayerResourceLoader alloc] initWithRemoteAssetURL:resourceURL];
    AVURLAsset *asset = [YPAVURLAsset assetWithURL:resourceLoader.streamingAssetURL];
    [asset.resourceLoader setDelegate:resourceLoader queue:dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL)];
    return asset;
}

@end

@implementation AVPlayerItem (YPResourceLoader)

+ (instancetype) playerItemWithYPResourceURL:(NSURL *)resourceURL
{
    AVURLAsset *asset = [AVURLAsset assetWithYPResourceURL:resourceURL];
    return [self playerItemWithAsset:asset];
}

@end

@implementation AVAssetResourceLoadingRequest (YPResourceLoader)

- (BOOL) isContentInfoRequest
{
    return self.contentInformationRequest != nil;
}

- (BOOL) isContentDataRequest
{
    return !self.isContentInfoRequest && self.dataRequest != nil;
}

- (void) respondWithData:(NSData *)data dataOffset:(NSInteger)dataOffset
{
    NSParameterAssert([self isContentDataRequest]);
    
    NSInteger dataLength = data.length;
    NSRange dataRange = NSMakeRange(dataOffset, dataLength);
    AVAssetResourceLoadingDataRequest *dataRequest = self.dataRequest;
    
    if (dataLength > 0 && dataRequest && NSLocationInRange(dataRequest.currentOffset, dataRange)) {
        NSRange appendDataRange;
        appendDataRange.location = dataRequest.currentOffset - dataOffset;
        appendDataRange.length = dataLength - appendDataRange.location;
        NSData *appendData = [data subdataWithRange:appendDataRange];
        [dataRequest respondWithData:appendData];
    }
}

@end

NSString *const YPAVPlayerResourceLoaderStreamingSchemeSuffix = @"-ypstreaming";
