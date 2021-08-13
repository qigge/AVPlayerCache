//
//  ResourceLoaderDelegate.h
//  VideoCache
//
//  Created by Eric Wang on 2021/7/6.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ResourceLoaderDelegate : NSObject<AVAssetResourceLoaderDelegate>


@property (nonatomic, strong, readonly) dispatch_queue_t rlQueue;

- (NSURL *)loaderUrl:(NSURL *)url;

- (void)close;

@end

NS_ASSUME_NONNULL_END
