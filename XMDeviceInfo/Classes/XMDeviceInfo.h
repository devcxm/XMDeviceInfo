//
//  XMDeviceInfo.h
//  XMDeviceInfo_Example
//
//  Created by chi on 2026/4/15.
//  Copyright © 2026 chixm. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// App 分发渠道（商店 / TestFlight / 其它）
typedef NS_ENUM(NSInteger, XMAppChannel) {
  XMAppChannelAppStore = 0,
  XMAppChannelTestFlight = 1,
  XMAppChannelOther = 2
};

#define XMAppChannelDisplayNames (@[ @"AppStore", @"TestFlight", @"Other" ])

typedef NS_ENUM(NSInteger, XMDeviceType) {
  XMDeviceTypeHandset,
  XMDeviceTypeTablet,
  XMDeviceTypeTv,
  XMDeviceTypeDesktop,
  XMDeviceTypeHeadset,
  XMDeviceTypeUnknown
};

#define XMDeviceTypeDisplayNames (@[ @"Handset", @"Tablet", @"Tv", @"Desktop", @"Headset", @"unknown" ])

@interface XMDeviceInfo : NSObject

#pragma mark - App channel（安装来源）

+ (XMAppChannel)currentAppChannel;
+ (BOOL)hasEmbeddedMobileProvision;
+ (BOOL)isAppStoreReceiptSandbox;

#pragma mark - 持久化设备 ID（原 DeviceUID，Keychain 键仍为 deviceUID）

+ (NSString *)uid;
+ (NSString *)syncUid;

#pragma mark - 设备与应用信息（原 RNDeviceInfo，无 Bridge / Promise）

+ (NSDictionary<NSString *, NSString *> *)deviceNamesByCode;
+ (NSString *)deviceId;
+ (NSString *)model;
+ (NSString *)systemName;
+ (NSString *)systemVersion;
+ (NSString *)deviceName;
+ (BOOL)isDisplayZoomed;
+ (NSString *)appName;
+ (NSString *)bundleId;
+ (NSString *)appVersion;
+ (NSString *)buildNumber;
+ (NSString *)carrier;
+ (NSString *)buildId;
+ (NSString *)uniqueId;
+ (BOOL)isEmulator;
+ (BOOL)isTablet;
+ (XMDeviceType)deviceType;
+ (NSString *)deviceTypeName;
+ (float)fontScale;
+ (double)totalMemory;
+ (double)totalDiskCapacity;
+ (double)freeDiskStorageForType:(NSString *)storageType;
+ (NSArray<NSString *> *)supportedAbis;
+ (NSString *)ipAddress;
+ (BOOL)isPinOrFingerprintSet;
+ (NSDictionary<NSString *, id> *)powerState;
+ (float)batteryLevel;
+ (BOOL)isBatteryCharging;
+ (BOOL)isLocationEnabled;
+ (BOOL)isHeadphonesConnected;
+ (BOOL)isWiredHeadphonesConnected;
+ (BOOL)isBluetoothHeadphonesConnected;
+ (unsigned long)usedMemory;
+ (NSDictionary<NSString *, NSNumber *> *)availableLocationProviders;
+ (NSString *)installerPackageName;
+ (NSNumber *)brightness;
+ (long long)firstInstallTime;
+ (long long)startupTime;

+ (void)fetchUserAgentWithCompletion:(void (^)(NSString *_Nullable userAgent, NSError *_Nullable error))completion;

+ (void)generateDeviceCheckTokenWithCompletion:(void (^)(NSString *_Nullable token, NSError *_Nullable error))completion;

/// 与 RN `constantsToExport` 常用字段对齐
+ (NSDictionary<NSString *, id> *)bridgeStyleConstants;

@end

NS_ASSUME_NONNULL_END
