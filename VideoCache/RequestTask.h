//
//  RequestTask.h
//  VideoCache
//
//  Created by Eric Wang on 2021/7/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RequestTask : NSObject

- (NSURLSessionDataTask *)requestWithUrl:(NSURL *)url
                                  offset:(NSInteger)offset
                                  length:(NSInteger)length;

@end

NS_ASSUME_NONNULL_END
