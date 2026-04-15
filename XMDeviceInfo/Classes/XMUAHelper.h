//
//  XMUAHelper.h
//  XMDeviceInfo_Example
//
//  Created by chi on 2026/4/15.
//  Copyright © 2026 chixm. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol XMUAHelperProtocol <NSObject>

@optional
+ (NSString *)xm_uaCustomAppName;

@end

@interface XMUAHelper : NSObject <XMUAHelperProtocol>

@property (nonatomic, copy, readonly) NSString *appUA;

+ (instancetype)helper;

- (void)preload:(nullable dispatch_block_t)completion;

- (NSString *)rawWebViewUA;

- (NSString *)webUAByAppendingString:(NSString *)aString;

@end

NS_ASSUME_NONNULL_END
