//
//  RequeueDataTask.h
//  VideoCache
//
//  Created by Eric Wang on 2021/7/1.
//

#import <Foundation/Foundation.h>


typedef void (^AFURLSessionTaskCompletionHandler)(NSURLResponse *response, id responseObject, NSError *error);

NS_ASSUME_NONNULL_BEGIN

@interface RequeueDataTask : NSURLSessionDataTask

@property (nonatomic, copy) AFURLSessionTaskCompletionHandler completionHandler;

@end

NS_ASSUME_NONNULL_END
