//
//  RequestTask.m
//  VideoCache
//
//  Created by Eric Wang on 2021/7/1.
//

#import "RequestTask.h"

@interface RequestTask ()<NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSession * session;              //会话对象

@end

@implementation RequestTask

- (instancetype)init
{
    self = [super init];
    if (self) {
        _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}


- (NSURLSessionDataTask *)requestWithUrl:(NSURL *)url
                                  offset:(NSInteger)offset
                                  length:(NSInteger)length {
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
    if (offset > 0) {
        [request addValue:[NSString stringWithFormat:@"bytes=%ld-%ld", offset, length] forHTTPHeaderField:@"Range"];
    }
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
    return task;
}


- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler{
    
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data{
    
}

@end
