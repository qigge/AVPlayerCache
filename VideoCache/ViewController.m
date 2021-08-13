//
//  ViewController.m
//  VideoCache
//
//  Created by Eric Wang on 2021/7/1.
//

#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "RequestTask.h"
#import "ResourceLoaderDelegate.h"

@interface ViewController ()

@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayer *player;
@property (weak, nonatomic) IBOutlet UIView *playerView;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;

@property (nonatomic, strong) ResourceLoaderDelegate *loaderDeleaget;

@property (nonatomic, strong) NSArray *videoArr;
@property (nonatomic, assign) NSInteger playIndex;
@end

NSString *url_str3 = @"http://files.acadsoc.com.cn//iesfiles//video//20210630//4ac6ead6-a537-4197-9ced-b48bcad72729.mp4";
NSString *url_str = @"http://video.acadsoc.com.cn/WinfromUploads/video/2021-06-11/2021061117155654.mp4";
NSString *url_str2 = @"http://video.acadsoc.com.cn/WinfromUploads/video/2021-05-29/2021052918320693.mp4";
//NSString *url_str = @"https://files.acadsoc.com.cn/tutor/audio/official/20190816/ff097231-4775-4b17-b390-cd19a303d294.mp3";


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _videoArr = @[url_str3];
    _playIndex = 0;
    
    self.loaderDeleaget = [[ResourceLoaderDelegate alloc] init];
    
    [self play];
}

- (void)play {
    NSURL *url = [NSURL URLWithString:_videoArr[_playIndex]];
    AVURLAsset *asset = [AVURLAsset assetWithURL:[self.loaderDeleaget loaderUrl:url]];
    [asset.resourceLoader setDelegate:self.loaderDeleaget queue:self.loaderDeleaget.rlQueue];
    _playerItem = [AVPlayerItem playerItemWithAsset:asset];
    if (_player) {
        [_player replaceCurrentItemWithPlayerItem:_playerItem];
    }else {
        _player = [AVPlayer playerWithPlayerItem:_playerItem];
        AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:_player];
        layer.frame = self.playerView.bounds;
        [self.playerView.layer addSublayer:layer];
    }

    [_player play];
}

- (IBAction)nextAction:(id)sender {
    _playIndex += 1;
    if (_playIndex >= _videoArr.count) {
        _playIndex = 0;
    }
    [self play];
}

- (void)dealloc {
    NSLog(@"Running %@ '%@'", self.class, NSStringFromSelector(_cmd));
    [self.loaderDeleaget close];
}

@end
