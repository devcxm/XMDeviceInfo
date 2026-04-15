//
//  XMUAHelper.m
//  XMDeviceInfo_Example
//
//  Created by chi on 2026/4/15.
//  Copyright © 2026 chixm. All rights reserved.
//

#import "XMUAHelper.h"

#import "XMDeviceInfo.h"

#import <WebKit/WebKit.h>

@interface XMUAHelper ()

@property (nonatomic, copy, readwrite) NSString *appUA;

@property (nonatomic, copy) NSString *originalUA;
@property (nonatomic, strong) WKWebView *tempWebView;
@property (nonatomic, assign) BOOL isFetching;
@property (nonatomic, assign) BOOL isFinished;

@end

@implementation XMUAHelper


+ (instancetype)helper {
    static XMUAHelper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)preload:(dispatch_block_t)completion {
    @synchronized (self) {
        if (self.isFinished || self.isFetching) {
            if (completion) {
                completion();
            }
            return;
        }
        self.isFetching = YES;
    }
    
    // 确保在主线程操作 WKWebView
    dispatch_async(dispatch_get_main_queue(), ^{
        self.tempWebView = [[WKWebView alloc] initWithFrame:CGRectZero];
        __weak typeof(self) weakSelf = self;
        
        [self.tempWebView evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id result, NSError *error) {
            @synchronized (weakSelf) {
                if (!error && [result isKindOfClass:[NSString class]]) {
                    weakSelf.originalUA = result;
                }
                weakSelf.isFinished = YES;
                weakSelf.isFetching = NO;
                weakSelf.tempWebView = nil; // 释放内存
            }
            if (completion) {
                completion();
            }
        }];
    });
}

- (NSString *)rawWebViewUA {
    // 1. 状态自检
    if (!self.isFinished && !self.isFetching) {
        [self preload:nil];
    }
    
    // 2. 如果还在加载，开启 RunLoop 等待（方案二）
    if (!self.isFinished) {
        // 设置 1 秒硬超时，防止极端情况下卡死主线程
        NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:1.5];
        
        while (!self.isFinished && [[NSDate date] compare:timeoutDate] == NSOrderedAscending) {
            // 驱动 RunLoop 处理回调事件
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        }
    }
    
    return self.originalUA ?: @"";
}

- (NSString *)appUA {
    if (!_appUA) {
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        
        // 1. 获取 App 名称和版本号 (例如: AppName/1.0.0)
        NSString *appName = nil;
        if ([self.class respondsToSelector:@selector(xm_uaCustomAppName)]) {
            appName = [self.class xm_uaCustomAppName];
        }
        if (!appName.length) {
            appName = [XMDeviceInfo appName] ?: @"App";
        }
        
        NSString *appVersion = info[@"CFBundleShortVersionString"] ?: @"1.0.0";
        
        // 2. 获取设备型号 (例如: iPhone)
        NSString *deviceModel = [NSString stringWithFormat:@"%@/%@", [XMDeviceInfo deviceId], [XMDeviceInfo model]];
        
        // 3. 获取系统版本 (例如: iOS 26.1)
        NSString *osName = [[UIDevice currentDevice] systemName]; // "iOS"
        NSString *osVersion = [[UIDevice currentDevice] systemVersion]; // "26.1"
        
        // 4. 获取屏幕倍率 (例如: Scale/3.00)
        CGFloat screenScale = [UIScreen mainScreen].scale;
        
        // 5. 格式：AppName/Version (Device; OS Version; Scale/ScaleValue)
        _appUA = [NSString stringWithFormat:@"%@/%@ (%@; %@ %@; Scale/%.2f)",
                                appName,
                                appVersion,
                                deviceModel,
                                osName,
                                osVersion,
                                screenScale];
        
    }
    return _appUA;
}

- (NSString *)webUAByAppendingString:(NSString *)aString {
    NSString *wUA = [self rawWebViewUA];
    if (!aString.length) {
        return wUA;
    }
    
    if (![aString hasPrefix:@" "]) {
        aString = [NSString stringWithFormat:@" %@", aString];
    }
    NSString *retUA = [NSString stringWithFormat:@"%@%@", wUA, aString];
    return retUA;
}


@end
