//
//  YPViewController.m
//  YPAVAssetResourceLoader
//
//  Created by yiplee on 12/08/2017.
//  Copyright (c) 2017 yiplee. All rights reserved.
//

#import "YPViewController.h"
#import <YPAVAssetResourceLoader/YPAVPlayerResourceLoader.h>
#import <AVKit/AVKit.h>

@interface YPViewController ()
@property (strong, nonatomic) IBOutlet UITextView *textView;
@property (strong, nonatomic) IBOutlet UISwitch *resourceLoaderSwitch;

@end

@implementation YPViewController

- (IBAction)playVideo:(id)sender {
    NSString *urlString = self.textView.text;
    NSURL *url = [NSURL URLWithString:urlString];
    NSParameterAssert(url);
    
    BOOL useResourceLoader = self.resourceLoaderSwitch.isOn;
    
    AVPlayerItem *playerItem = nil;
    if (useResourceLoader) {
        AVAsset *asset = [AVURLAsset assetWithYPResourceURL:url];
        playerItem = [AVPlayerItem playerItemWithAsset:asset];
    } else {
        playerItem = [AVPlayerItem playerItemWithURL:url];
    }
    
    AVPlayer *player = [AVPlayer playerWithPlayerItem:playerItem];
    if (useResourceLoader) {
        player.automaticallyWaitsToMinimizeStalling = NO;
    }
    AVPlayerViewController *playerController = [AVPlayerViewController new];
    playerController.player = player;
    [self presentViewController:playerController
                       animated:YES
                     completion:nil];
}

@end
