//
//  ResourceLoaderDelegate.m
//  VideoCache
//
//  Created by Eric Wang on 2021/7/6.
//

#import "ResourceLoaderDelegate.h"

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>

#define SCHEME_SUFFIX  @"-ts"

@interface ResourceLoaderDelegate ()<NSURLSessionDataDelegate, NSURLSessionTaskDelegate>

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSURL *cacheFileUrl;

@property (nonatomic, strong) NSURLSession * urlSession;              //会话对象
@property (nonatomic, strong) NSURLSessionDataTask *urlTask;
@property (nonatomic, strong) NSURLResponse *infoResponse;

@property (nonatomic, strong) NSMutableArray<AVAssetResourceLoadingRequest *> *loadingRequests;

@property (nonatomic, strong) NSFileHandle *fileHandle;


@property (nonatomic, strong, readwrite) dispatch_queue_t rlQueue;

@end

@implementation ResourceLoaderDelegate

#pragma mark -  Public Method

- (instancetype)init
{
    self = [super init];
    if (self) {
        _rlQueue = dispatch_queue_create("com.ResourceLoaderDelegate.videocache", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (NSURL *)streamingAssetUrl {
    
    NSURLComponents *com = [[NSURLComponents alloc] initWithURL:self.url resolvingAgainstBaseURL:NO];
    com.scheme = [NSString stringWithFormat:@"%@%@",(com.scheme ?: @""),SCHEME_SUFFIX];
    return com.URL;
}

/// 返回播放的URL，如果存在文件，直接返回文件路径URL；不存在，返回自定义加载的URL
- (NSURL *)loaderUrl:(NSURL *)url {
    [self closePreReq];
    
    _url = url;
    
    NSURL *fileUrl = [self cacheUrl];
    
    
    // 如果存在文件，直接返回文件路径URL
    NSURL *localFileUrl = [fileUrl URLByAppendingPathExtension:self.url.pathExtension];
    if ([NSFileManager.defaultManager fileExistsAtPath:localFileUrl.path]) {
        return fileUrl;
    }
    
    _cacheFileUrl = [fileUrl URLByAppendingPathExtension:@"tmp"];
    
    [self createUrlSession];
    
    [self createFileHandle];
    // 不存在，返回自定义加载的URL
    return [self streamingAssetUrl];
}

/// 关闭上一步的请求
- (void)closePreReq {
    if (_urlTask) {
        [_urlTask cancel];
        _urlTask = nil;
    }
    
    dispatch_async(self.rlQueue, ^{
        // 移除上次所有的loadinRequests
        [self.loadingRequests removeAllObjects];
    
        // 关闭上次的文件Handle
        if (self.fileHandle) {
            [self.fileHandle closeFile];
            self.fileHandle = nil;
            NSLog(@"#### file handle close ######");
        }
    });
    
    // 删除上次的缓存文件
    if (_cacheFileUrl) {
        [NSFileManager.defaultManager removeItemAtURL:_cacheFileUrl error:nil];
    }
}

- (void)close {
    [self closePreReq];
    
    // 取消上次的请求
    [self.urlSession invalidateAndCancel];
    self.urlSession = nil;
}

- (void)dealloc {
    NSLog(@"Running %@ '%@'", self.class, NSStringFromSelector(_cmd));
}

#pragma mark -  Net

- (void)createUrlSession {
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    _urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:queue];
}


#pragma mark -  File Method

- (NSURL *)cacheUrl {
    NSURL *docFolderUrl = [NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
//    NSString *fileName = [self SHA1Encrypt:self.url.path];
    static int i = 0;
    NSString *fileName = [NSString stringWithFormat:@"%@",@(i++)];
    NSURL *fileUrl = [docFolderUrl URLByAppendingPathComponent:fileName];
    
    return fileUrl;
}


/** SHA1加密 */
- (NSString *)SHA1Encrypt:(NSString *)url {
    
    NSData *data = [url dataUsingEncoding:NSUTF8StringEncoding];
    
    //使用对应的CC_SHA1,CC_SHA256,CC_SHA384,CC_SHA512的长度分别是20,32,48,64
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    //使用对应的CC_SHA256,CC_SHA384,CC_SHA512
    CC_SHA1(data.bytes, (unsigned int)data.length, digest);
    
    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    return output;
}

- (void)createFileHandle {
    dispatch_async(self.rlQueue, ^{
        if (self.fileHandle) {
            [self.fileHandle closeFile];
            self.fileHandle = nil;
            NSLog(@"#### file handle close ######");
        }
        if ([NSFileManager.defaultManager fileExistsAtPath:self.cacheFileUrl.path]) {
            [NSFileManager.defaultManager removeItemAtURL:self.cacheFileUrl error:nil];
        }
        [NSFileManager.defaultManager createFileAtPath:self.cacheFileUrl.path contents:nil attributes:nil];
        
        self.fileHandle = [NSFileHandle fileHandleForUpdatingURL:self.cacheFileUrl error:nil];
        NSLog(@"#### file handle connect ######");
    });
}


#pragma mark -  ResourceLoading Request


- (void)fillInfoRequest:(AVAssetResourceLoadingRequest *)requset response:(NSURLResponse *)response {
    if (!response) {
        return;
    }
    AVAssetResourceLoadingContentInformationRequest *req = requset.contentInformationRequest;
    if (!req) {
        return;
    }
    NSHTTPURLResponse *HTTPURLResponse = (NSHTTPURLResponse *)response;
    NSString *acceptRange = HTTPURLResponse.allHeaderFields[@"Accept-Ranges"];
    req.byteRangeAccessSupported = [acceptRange isEqualToString:@"bytes"];
    //考虑到绝大部分服务器都支持bytes,这里就全部设置为支持
    // req.byteRangeAccessSupported = YES;
    req.contentLength = response.expectedContentLength;
    req.contentType = response.MIMEType;
}

- (void)processRequests {
    NSMutableArray * finishRequestList = [NSMutableArray array];
    NSArray *tempArr = [self.loadingRequests copy];
    for (AVAssetResourceLoadingRequest * loadingRequest in tempArr) {
        [self fillInfoRequest:loadingRequest response:self.infoResponse];
        if ([self checkAndRespond:loadingRequest.dataRequest]) {
            [finishRequestList addObject:loadingRequest];
            [loadingRequest finishLoading];
        }
    }
    [self.loadingRequests removeObjectsInArray:finishRequestList];
}

- (BOOL)checkAndRespond:(AVAssetResourceLoadingDataRequest *)dataRequest {
    [self.fileHandle seekToFileOffset:0];
    NSUInteger downloadedDataLength = [self.fileHandle seekToEndOfFile];
    
    long long requestRequestedOffset = dataRequest.requestedOffset;
    long long requestRequestedLength = dataRequest.requestedLength;
    long long requestCurrentOffset = dataRequest.currentOffset;
    
    if (downloadedDataLength < requestCurrentOffset) {
        return NO;
    }
    
    long long downloadedUnreadDataLength = downloadedDataLength - requestCurrentOffset;
    long long requestUnreadDataLength = requestRequestedOffset + requestRequestedLength - requestCurrentOffset;
    long long respondDataLength = MIN(requestUnreadDataLength, downloadedUnreadDataLength);
    
    [self.fileHandle seekToFileOffset:requestCurrentOffset];
    NSData * data = [self.fileHandle readDataOfLength:respondDataLength];

    [dataRequest respondWithData:data];
    
    long long requestEndOffset = requestRequestedOffset + requestRequestedLength;
    return requestCurrentOffset >= requestEndOffset;
    
}


#pragma mark -  Getter

- (NSMutableArray<AVAssetResourceLoadingRequest *> *)loadingRequests {
    if (!_loadingRequests) {
        _loadingRequests = [NSMutableArray array];
    }
    return _loadingRequests;
}


#pragma mark -  AVAssetResourceLoaderDelegate

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSLog(@"shouldWaitForLoadingOfRequestedResource %@",loadingRequest);
    
    if (!_urlTask) {
        _urlTask = [_urlSession dataTaskWithURL:self.url];
        [_urlTask resume];
    }
    [self.loadingRequests addObject:loadingRequest];
    return YES;
}

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForRenewalOfRequestedResource:(AVAssetResourceRenewalRequest *)renewalRequest {
    NSLog(@"shouldWaitForRenewalOfRequestedResource %@",renewalRequest);
    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest {
    NSLog(@"didCancelLoadingRequest %@",loadingRequest);
    [self.loadingRequests removeObject:loadingRequest];
}


#pragma mark -  NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler{
    NSLog(@"#### response #####");
    self.infoResponse = response;
    [self processRequests];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data{
    
    dispatch_async(self.rlQueue, ^{
        [self.fileHandle seekToEndOfFile];
        [self.fileHandle writeData:data];
        
        [self processRequests];
    });
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSLog(@"didCompleteWithError %@",error);
    if (error) {
        return;
    }

    NSURL *toFileUrl = [[_cacheFileUrl URLByDeletingPathExtension] URLByAppendingPathExtension:self.url.pathExtension];
    
    [NSFileManager.defaultManager copyItemAtURL:_cacheFileUrl toURL:toFileUrl error:nil];
}



@end
