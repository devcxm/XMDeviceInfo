//
//  XMViewController.m
//  XMDeviceInfo
//
//  Created by chixm on 04/15/2026.
//  Copyright (c) 2026 chixm. All rights reserved.
//

#import "XMViewController.h"

#import <XMDeviceInfo/XMUAHelper.h>

@interface XMViewController ()

@end

@implementation XMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    UIButton *app = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.view addSubview:app];
    [app setTitle:@"App UA" forState:UIControlStateNormal];
    [app sizeToFit];
    [app addTarget:self action:@selector(appUA:) forControlEvents:UIControlEventTouchUpInside];
    app.center = self.view.center;
        
    UIButton *web = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.view addSubview:web];
    [web setTitle:@"Web UA" forState:UIControlStateNormal];
    [web sizeToFit];
    [web addTarget:self action:@selector(webUA:) forControlEvents:UIControlEventTouchUpInside];

    web.center = self.view.center;
    CGRect webFrame = web.frame;
    webFrame.origin.y = CGRectGetMaxY(app.frame) + 50.f;
    web.frame = webFrame;
}

- (void)appUA:(id)sender {
    [self showAlert:[XMUAHelper helper].appUA];
}

- (void)webUA:(id)sender {
    [self showAlert:[XMUAHelper helper].rawWebViewUA];
}

- (void)showAlert:(NSString *)msg {
    UIAlertController *vc = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [vc dismissViewControllerAnimated:YES completion:nil];
    }];
    [vc addAction:ok];
    [self presentViewController:vc animated:YES completion:nil];
}

@end
