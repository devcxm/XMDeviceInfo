//
//  XMDeviceInfo.m
//  XMDeviceInfo_Example
//
//  Created by chi on 2026/4/15.
//  Copyright © 2026 chixm. All rights reserved.
//

#import "XMDeviceInfo.h"

#include <ifaddrs.h>
#include <arpa/inet.h>
#import <mach/mach.h>
#import <mach-o/arch.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <Security/Security.h>
#import <DeviceCheck/DeviceCheck.h>

#if !(TARGET_OS_TV)
#import <WebKit/WebKit.h>
#import <LocalAuthentication/LocalAuthentication.h>
#endif

#if (!(TARGET_OS_TV || TARGET_OS_VISION))
@import CoreTelephony;
#endif

static NSString * const XMUIDKey = @"deviceUID";

@interface XMDeviceUIDStorage : NSObject
@end

@interface XMDeviceUIDStorage ()
@property (nonatomic, strong, readonly) NSString *uid;
@end

@implementation XMDeviceUIDStorage

@synthesize uid = _uid;

+ (NSString *)uid {
  return [[[XMDeviceUIDStorage alloc] init] uid];
}

+ (NSString *)syncUid {
  return [[[XMDeviceUIDStorage alloc] init] syncUid];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _uid = nil;
  }
  return self;
}

- (NSString *)uid {
  if (!_uid) _uid = [[self class] valueForKeychainKey:XMUIDKey service:XMUIDKey];
  if (!_uid) _uid = [[self class] valueForUserDefaultsKey:XMUIDKey];
  if (!_uid) _uid = [[self class] appleIFV];
  if (!_uid) _uid = [[self class] randomUUID];
  [self saveIfNeed];
  return _uid;
}

- (NSString *)syncUid {
  _uid = [[self class] appleIFV];
  if (!_uid) _uid = [[self class] randomUUID];
  [self save];
  return _uid;
}

- (void)save {
  [XMDeviceUIDStorage setValue:_uid forUserDefaultsKey:XMUIDKey];
  [XMDeviceUIDStorage updateValue:_uid forKeychainKey:XMUIDKey inService:XMUIDKey];
}

- (void)saveIfNeed {
  if (![XMDeviceUIDStorage valueForUserDefaultsKey:XMUIDKey]) {
    [XMDeviceUIDStorage setValue:_uid forUserDefaultsKey:XMUIDKey];
  }
  if (![XMDeviceUIDStorage valueForKeychainKey:XMUIDKey service:XMUIDKey]) {
    [XMDeviceUIDStorage setValue:_uid forKeychainKey:XMUIDKey inService:XMUIDKey];
  }
}

+ (NSMutableDictionary *)keychainItemForKey:(NSString *)key service:(NSString *)service {
  NSMutableDictionary *keychainItem = [[NSMutableDictionary alloc] init];
  keychainItem[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
  keychainItem[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
  keychainItem[(__bridge id)kSecAttrAccount] = key;
  keychainItem[(__bridge id)kSecAttrService] = service;
  return keychainItem;
}

+ (OSStatus)setValue:(NSString *)value forKeychainKey:(NSString *)key inService:(NSString *)service {
  NSMutableDictionary *keychainItem = [[self class] keychainItemForKey:key service:service];
  keychainItem[(__bridge id)kSecValueData] = [value dataUsingEncoding:NSUTF8StringEncoding];
  OSStatus status = SecItemAdd((__bridge CFDictionaryRef)keychainItem, NULL);
  if (status == errSecDuplicateItem) {
    [XMDeviceUIDStorage deleteValue:key inService:service];
    status = SecItemAdd((__bridge CFDictionaryRef)keychainItem, NULL);
  }
  return status;
}

+ (OSStatus)updateValue:(NSString *)value forKeychainKey:(NSString *)key inService:(NSString *)service {
  NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
      (__bridge id)kSecClassGenericPassword, kSecClass,
      key, kSecAttrAccount,
      service, kSecAttrService,
      nil];
  NSDictionary *attributesToUpdate = [NSDictionary dictionaryWithObjectsAndKeys:
      [value dataUsingEncoding:NSUTF8StringEncoding], kSecValueData,
      nil];
  return SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributesToUpdate);
}

+ (OSStatus)deleteValue:(NSString *)key inService:(NSString *)service {
  NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
      (__bridge id)kSecClassGenericPassword, kSecClass,
      key, kSecAttrAccount,
      service, kSecAttrService,
      nil];
  return SecItemDelete((__bridge CFDictionaryRef)query);
}

+ (NSString *)valueForKeychainKey:(NSString *)key service:(NSString *)service {
  OSStatus status;
  NSMutableDictionary *keychainItem = [[self class] keychainItemForKey:key service:service];
  keychainItem[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
  keychainItem[(__bridge id)kSecReturnAttributes] = (__bridge id)kCFBooleanTrue;
  CFDictionaryRef result = nil;
  status = SecItemCopyMatching((__bridge CFDictionaryRef)keychainItem, (CFTypeRef *)&result);
  if (status != noErr) {
    return nil;
  }
  NSDictionary *resultDict = (__bridge_transfer NSDictionary *)result;
  NSData *data = resultDict[(__bridge id)kSecValueData];
  if (!data) {
    return nil;
  }
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (BOOL)setValue:(NSString *)value forUserDefaultsKey:(NSString *)key {
  [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
  return [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)valueForUserDefaultsKey:(NSString *)key {
  return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

+ (NSString *)appleIFV {
  if (NSClassFromString(@"UIDevice") && [UIDevice instancesRespondToSelector:@selector(identifierForVendor)]) {
    return [[UIDevice currentDevice].identifierForVendor UUIDString];
  }
  return nil;
}

+ (NSString *)randomUUID {
  if (NSClassFromString(@"NSUUID")) {
    return [[NSUUID UUID] UUIDString];
  }
  CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
  CFStringRef cfuuid = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
  CFRelease(uuidRef);
  NSString *uuid = [((__bridge NSString *)cfuuid) copy];
  CFRelease(cfuuid);
  return uuid;
}

@end

@implementation XMDeviceInfo

#pragma mark - App channel

+ (XMAppChannel)currentAppChannel {
#if TARGET_OS_SIMULATOR || TARGET_OS_OSX || TARGET_OS_MACCATALYST
  return XMAppChannelOther;
#else
  if ([self hasEmbeddedMobileProvision]) {
    return XMAppChannelOther;
  }
  if ([self isAppStoreReceiptSandbox]) {
    return XMAppChannelTestFlight;
  }
  return XMAppChannelAppStore;
#endif
}

+ (BOOL)hasEmbeddedMobileProvision {
  return !![[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"];
}

+ (BOOL)isAppStoreReceiptSandbox {
#if TARGET_OS_SIMULATOR
  return NO;
#else
  if (![NSBundle.mainBundle respondsToSelector:@selector(appStoreReceiptURL)]) {
    return NO;
  }
  NSURL *appStoreReceiptURL = NSBundle.mainBundle.appStoreReceiptURL;
  NSString *appStoreReceiptLastComponent = appStoreReceiptURL.lastPathComponent;
  return [appStoreReceiptLastComponent isEqualToString:@"sandboxReceipt"];
#endif
}

#pragma mark - Device UID

+ (NSString *)uid {
  return [XMDeviceUIDStorage uid];
}

+ (NSString *)syncUid {
  return [XMDeviceUIDStorage syncUid];
}

#pragma mark - Storage helper

+ (NSDictionary *)storageDictionary {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  return [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error:nil];
}

#pragma mark - Device names

// 参考同步
// https://github.com/react-native-device-info/react-native-device-info/blob/06a9ed6d700cab9c55b363e6fa944ee8e5605745/ios/RNDeviceInfo/RNDeviceInfo.m
+ (NSDictionary *)deviceNamesByCode {
    return @{
        @"iPhone1,1": @"iPhone", // (Original)
        @"iPhone1,2": @"iPhone 3G", // (3G)
        @"iPhone2,1": @"iPhone 3GS", // (3GS)
        @"iPhone3,1": @"iPhone 4", // (GSM)
        @"iPhone3,2": @"iPhone 4", // iPhone 4
        @"iPhone3,3": @"iPhone 4", // (CDMA/Verizon/Sprint)
        @"iPhone4,1": @"iPhone 4S", //
        @"iPhone5,1": @"iPhone 5", // (model A1428, AT&T/Canada)
        @"iPhone5,2": @"iPhone 5", // (model A1429, everything else)
        @"iPhone5,3": @"iPhone 5c", // (model A1456, A1532 | GSM)
        @"iPhone5,4": @"iPhone 5c", // (model A1507, A1516, A1526 (China), A1529 | Global)
        @"iPhone6,1": @"iPhone 5s", // (model A1433, A1533 | GSM)
        @"iPhone6,2": @"iPhone 5s", // (model A1457, A1518, A1528 (China), A1530 | Global)
        @"iPhone7,1": @"iPhone 6 Plus", //
        @"iPhone7,2": @"iPhone 6", //
        @"iPhone8,1": @"iPhone 6s", //
        @"iPhone8,2": @"iPhone 6s Plus", //
        @"iPhone8,4": @"iPhone SE", //
        @"iPhone9,1": @"iPhone 7", // (model A1660 | CDMA)
        @"iPhone9,2": @"iPhone 7 Plus", // (model A1661 | CDMA)
        @"iPhone9,3": @"iPhone 7", // (model A1778 | Global)
        @"iPhone9,4": @"iPhone 7 Plus", // (model A1784 | Global)
        @"iPhone10,1": @"iPhone 8", // (model A1863, A1906, A1907)
        @"iPhone10,2": @"iPhone 8 Plus", // (model A1864, A1898, A1899)
        @"iPhone10,3": @"iPhone X", // (model A1865, A1902)
        @"iPhone10,4": @"iPhone 8", // (model A1905)
        @"iPhone10,5": @"iPhone 8 Plus", // (model A1897)
        @"iPhone10,6": @"iPhone X", // (model A1901)
        @"iPhone11,2": @"iPhone XS", // (model A2097, A2098)
        @"iPhone11,4": @"iPhone XS Max", // (model A1921, A2103)
        @"iPhone11,6": @"iPhone XS Max", // (model A2104)
        @"iPhone11,8": @"iPhone XR", // (model A1882, A1719, A2105)
        @"iPhone12,1": @"iPhone 11",
        @"iPhone12,3": @"iPhone 11 Pro",
        @"iPhone12,5": @"iPhone 11 Pro Max",
        @"iPhone12,8": @"iPhone SE", // (2nd Generation iPhone SE),
        @"iPhone13,1": @"iPhone 12 mini",
        @"iPhone13,2": @"iPhone 12",
        @"iPhone13,3": @"iPhone 12 Pro",
        @"iPhone13,4": @"iPhone 12 Pro Max",
        @"iPhone14,2": @"iPhone 13 Pro",
        @"iPhone14,3": @"iPhone 13 Pro Max",
        @"iPhone14,4": @"iPhone 13 mini",
        @"iPhone14,5": @"iPhone 13",
        @"iPhone14,6": @"iPhone SE", // (3nd Generation iPhone SE),
        @"iPhone14,7": @"iPhone 14",
        @"iPhone14,8": @"iPhone 14 Plus",
        @"iPhone15,2": @"iPhone 14 Pro",
        @"iPhone15,3": @"iPhone 14 Pro Max",
        @"iPhone15,4": @"iPhone 15",
        @"iPhone15,5": @"iPhone 15 Plus",
        @"iPhone16,1": @"iPhone 15 Pro",
        @"iPhone16,2": @"iPhone 15 Pro Max",
        @"iPhone17,1": @"iPhone 16 Pro",
        @"iPhone17,2": @"iPhone 16 Pro Max",
        @"iPhone17,3": @"iPhone 16",
        @"iPhone17,4": @"iPhone 16 Plus",
        @"iPhone17,5": @"iPhone 16e",
        @"iPhone18,1": @"iPhone 17 Pro",
        @"iPhone18,2": @"iPhone 17 Pro Max",
        @"iPhone18,3": @"iPhone 17",
        @"iPhone18,4": @"iPhone Air",

        @"iPod1,1": @"iPod Touch", // (Original)
        @"iPod2,1": @"iPod Touch", // (Second Generation)
        @"iPod3,1": @"iPod Touch", // (Third Generation)
        @"iPod4,1": @"iPod Touch", // (Fourth Generation)
        @"iPod5,1": @"iPod Touch", // (Fifth Generation)
        @"iPod7,1": @"iPod Touch", // (Sixth Generation)
        @"iPod9,1": @"iPod Touch", // (Seventh Generation)

        @"iPad1,1": @"iPad",
        @"iPad1,2": @"iPad 3G",
        @"iPad2,1": @"iPad 2",
        @"iPad2,2": @"iPad 2",
        @"iPad2,3": @"iPad 2",
        @"iPad2,4": @"iPad 2",
        @"iPad3,1": @"iPad",
        @"iPad3,2": @"iPad",
        @"iPad3,3": @"iPad",
        @"iPad2,5": @"iPad mini",
        @"iPad2,6": @"iPad mini",
        @"iPad2,7": @"iPad mini",
        @"iPad3,4": @"iPad",
        @"iPad3,5": @"iPad",
        @"iPad3,6": @"iPad",
        @"iPad4,1": @"iPad Air",
        @"iPad4,2": @"iPad Air",
        @"iPad4,3": @"iPad Air",
        @"iPad4,4": @"iPad Mini 2",
        @"iPad4,5": @"iPad Mini 2",
        @"iPad4,6": @"iPad Mini 2",
        @"iPad4,7": @"iPad Mini 3",
        @"iPad4,8": @"iPad Mini 3",
        @"iPad4,9": @"iPad Mini 3",
        @"iPad5,1": @"iPad Mini 4",
        @"iPad5,2": @"iPad Mini 4",
        @"iPad5,3": @"iPad Air 2",
        @"iPad5,4": @"iPad Air 2",
        @"iPad6,3": @"iPad Pro 9.7-inch",
        @"iPad6,4": @"iPad Pro 9.7-inch",
        @"iPad6,7": @"iPad Pro 12.9-inch",
        @"iPad6,8":@"iPad Pro 12.9-inch",
        @"iPad6,11": @"iPad (5th generation)",
        @"iPad6,12": @"iPad (5th generation)",
        @"iPad7,1": @"iPad Pro 12.9-inch",
        @"iPad7,2": @"iPad Pro 12.9-inch",
        @"iPad7,3": @"iPad Pro 10.5-inch",
        @"iPad7,4": @"iPad Pro 10.5-inch",
        @"iPad7,5": @"iPad (6th generation)",
        @"iPad7,6": @"iPad (6th generation)",
        @"iPad7,11": @"iPad (7th generation)",
        @"iPad7,12": @"iPad (7th generation)",
        @"iPad8,1": @"iPad Pro 11-inch (3rd generation)",
        @"iPad8,2": @"iPad Pro 11-inch (3rd generation)",
        @"iPad8,3": @"iPad Pro 11-inch (3rd generation)",
        @"iPad8,4": @"iPad Pro 11-inch (3rd generation)",
        @"iPad8,5": @"iPad Pro 12.9-inch (3rd generation)",
        @"iPad8,6": @"iPad Pro 12.9-inch (3rd generation)",
        @"iPad8,7": @"iPad Pro 12.9-inch (3rd generation)",
        @"iPad8,8": @"iPad Pro 12.9-inch (3rd generation)",
        @"iPad8,9": @"iPad Pro 11-inch (4th generation)",
        @"iPad8,10": @"iPad Pro 11-inch (4th generation)",
        @"iPad8,11": @"iPad Pro 12.9-inch (4th generation)",
        @"iPad8,12": @"iPad Pro 12.9-inch (4th generation)",
        @"iPad11,1": @"iPad Mini 5",
        @"iPad11,2": @"iPad Mini 5",
        @"iPad11,3": @"iPad Air 3rd Gen (WiFi)",
        @"iPad11,4": @"iPad Air (3rd generation)",
        @"iPad11,6": @"iPad Air (3rd generation)",
        @"iPad11,7": @"iPad (8th generation)",
        @"iPad12,1": @"iPad (9th generation)",
        @"iPad12,2": @"iPad (9th generation)",
        @"iPad14,1": @"iPad Mini (6th generation)",
        @"iPad14,2": @"iPad Mini (6th generation)",
        @"iPad13,1": @"iPad Air (4th generation)",
        @"iPad13,2": @"iPad Air (4th generation)",
        @"iPad13,4": @"iPad Pro 11-inch (5th generation)",
        @"iPad13,5": @"iPad Pro 11-inch (5th generation)",
        @"iPad13,6": @"iPad Pro 11-inch (5th generation)",
        @"iPad13,7": @"iPad Pro 11-inch (5th generation)",
        @"iPad13,8": @"iPad Pro 12.9-inch (5th generation)",
        @"iPad13,9": @"iPad Pro 11-inch (5th generation)",
        @"iPad13,10": @"iPad Pro 11-inch (5th generation)",
        @"iPad13,11": @"iPad Pro 11-inch (5th generation)",
        @"iPad13,16": @"iPad Air (5th generation)",
        @"iPad13,17": @"iPad Air (5th generation)",
        @"iPad13,18": @"iPad (10th generation)",
        @"iPad13,19": @"iPad (10th generation)",
        @"iPad14,3": @"iPad Pro 11-inch (4th generation)",
        @"iPad14,4": @"iPad Pro 11-inch (4th generation)",
        @"iPad14,5": @"iPad Pro 12.9-inch (6th generation)",
        @"iPad14,6": @"iPad Pro 12.9-inch (6th generation)",
        @"iPad14,8": @"iPad Air (6th generation)",
        @"iPad14,9": @"iPad Air (6th generation)",
        @"iPad14,10": @"iPad Air (7th generation)",
        @"iPad14,11": @"iPad Air (7th generation)",
        @"iPad16,3": @"iPad Pro 11-inch (5th generation)",
        @"iPad16,4": @"iPad Pro 11-inch (5th generation)",
        @"iPad16,5": @"iPad Pro 12.9-inch (7th generation)",
        @"iPad16,6": @"iPad Pro 12.9-inch (7th generation)",

        @"AppleTV2,1": @"Apple TV", // Apple TV (2nd Generation)
        @"AppleTV3,1": @"Apple TV", // Apple TV (3rd Generation)
        @"AppleTV3,2": @"Apple TV", // Apple TV (3rd Generation - Rev A)
        @"AppleTV5,3": @"Apple TV", // Apple TV (4th Generation)
        @"AppleTV6,2": @"Apple TV 4K", // Apple TV 4K

        @"RealityDevice14,1": @"Apple Vision Pro" // Apple Vision Pro
    };

}

#pragma mark - Identity / model

+ (NSString *)deviceId {
  struct utsname systemInfo;
  uname(&systemInfo);
  NSString *machine = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
#if TARGET_IPHONE_SIMULATOR
  machine = [NSString stringWithFormat:@"%s", getenv("SIMULATOR_MODEL_IDENTIFIER")];
#endif
  return machine;
}

+ (NSString *)model {
  NSString *machine = [self deviceId];
  NSDictionary *map = [self deviceNamesByCode];
  NSString *name = map[machine];
  if (name) {
    return name;
  }
  if ([machine hasPrefix:@"iPod"]) return @"iPod Touch";
  if ([machine hasPrefix:@"iPad"]) return @"iPad";
  if ([machine hasPrefix:@"iPhone"]) return @"iPhone";
  if ([machine hasPrefix:@"AppleTV"]) return @"Apple TV";
  if ([machine hasPrefix:@"RealityDevice"]) return @"Apple Vision";
  return @"unknown";
}

+ (NSString *)uniqueId {
  return [self uid];
}

+ (NSString *)systemName {
  return [UIDevice currentDevice].systemName;
}

+ (NSString *)systemVersion {
  return [UIDevice currentDevice].systemVersion;
}

+ (NSString *)deviceName {
  return [UIDevice currentDevice].name;
}

+ (BOOL)isDisplayZoomed {
#if !TARGET_OS_VISION
  return [UIScreen mainScreen].scale < [UIScreen mainScreen].nativeScale;
#else
  return NO;
#endif
}

+ (NSString *)appName {
  NSString *displayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
  NSString *bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
  return displayName ? displayName : bundleName;
}

+ (NSString *)bundleId {
  return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
}

+ (NSString *)appVersion {
  return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

+ (NSString *)buildNumber {
  return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
}

+ (NSString *)carrier {
#if (TARGET_OS_TV || TARGET_OS_MACCATALYST || TARGET_OS_VISION)
  return @"unknown";
#else
  CTTelephonyNetworkInfo *netinfo = [[CTTelephonyNetworkInfo alloc] init];
  CTCarrier *carrier = [netinfo subscriberCellularProvider];
  if (carrier.carrierName != nil) {
    return carrier.carrierName;
  }
  return @"unknown";
#endif
}

+ (NSString *)buildId {
#if TARGET_OS_TV
  return @"unknown";
#else
  size_t bufferSize = 64;
  NSMutableData *buffer = [[NSMutableData alloc] initWithLength:bufferSize];
  int status = sysctlbyname("kern.osversion", buffer.mutableBytes, &bufferSize, NULL, 0);
  if (status != 0) {
    return @"unknown";
  }
  return [[NSString alloc] initWithCString:buffer.mutableBytes encoding:NSUTF8StringEncoding];
#endif
}

+ (BOOL)isEmulator {
#if TARGET_IPHONE_SIMULATOR
  return YES;
#else
  return NO;
#endif
}

+ (XMDeviceType)deviceType {
  switch ([[UIDevice currentDevice] userInterfaceIdiom]) {
    case UIUserInterfaceIdiomPhone:
      return XMDeviceTypeHandset;
    case UIUserInterfaceIdiomPad:
      if (TARGET_OS_MACCATALYST) {
        return XMDeviceTypeDesktop;
      }
      if (@available(iOS 14.0, *)) {
        if ([NSProcessInfo processInfo].isiOSAppOnMac) {
          return XMDeviceTypeDesktop;
        }
      }
      return XMDeviceTypeTablet;
    case UIUserInterfaceIdiomTV:
      return XMDeviceTypeTv;
    case UIUserInterfaceIdiomMac:
      return XMDeviceTypeDesktop;
#if TARGET_OS_VISION
    case UIUserInterfaceIdiomVision:
      return XMDeviceTypeHeadset;
#endif
    default:
      return XMDeviceTypeUnknown;
  }
}

+ (BOOL)isTablet {
  return [self deviceType] == XMDeviceTypeTablet;
}

+ (NSString *)deviceTypeName {
  return [XMDeviceTypeDisplayNames objectAtIndex:(NSUInteger)[self deviceType]];
}

+ (float)fontScale {
  float fontScale = 1.0f;
#if !TARGET_OS_VISION
  UITraitCollection *traitCollection = [[UIScreen mainScreen] traitCollection];
  if (traitCollection) {
    __block NSString *contentSize = nil;
    void (^readSize)(void) = ^{
      if (@available(iOS 10.0, tvOS 10.0, macCatalyst 13.0, *)) {
        contentSize = traitCollection.preferredContentSizeCategory;
      }
    };
    if ([NSThread isMainThread]) {
      readSize();
    } else {
      dispatch_sync(dispatch_get_main_queue(), readSize);
    }
    if ([contentSize isEqualToString:UIContentSizeCategoryExtraSmall]) fontScale = 0.82f;
    else if ([contentSize isEqualToString:UIContentSizeCategorySmall]) fontScale = 0.88f;
    else if ([contentSize isEqualToString:UIContentSizeCategoryMedium]) fontScale = 0.95f;
    else if ([contentSize isEqualToString:UIContentSizeCategoryLarge]) fontScale = 1.0f;
    else if ([contentSize isEqualToString:UIContentSizeCategoryExtraLarge]) fontScale = 1.12f;
    else if ([contentSize isEqualToString:UIContentSizeCategoryExtraExtraLarge]) fontScale = 1.23f;
    else if ([contentSize isEqualToString:UIContentSizeCategoryExtraExtraExtraLarge]) fontScale = 1.35f;
    else if ([contentSize isEqualToString:UIContentSizeCategoryAccessibilityMedium]) fontScale = 1.64f;
    else if ([contentSize isEqualToString:UIContentSizeCategoryAccessibilityLarge]) fontScale = 1.95f;
    else if ([contentSize isEqualToString:UIContentSizeCategoryAccessibilityExtraLarge]) fontScale = 2.35f;
    else if ([contentSize isEqualToString:UIContentSizeCategoryAccessibilityExtraExtraLarge]) fontScale = 2.76f;
    else if ([contentSize isEqualToString:UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) fontScale = 3.12f;
  }
#endif
  return fontScale;
}

+ (double)totalMemory {
  return (double)[NSProcessInfo processInfo].physicalMemory;
}

+ (double)totalDiskCapacity {
  uint64_t totalSpace = 0;
  NSDictionary *storage = [self storageDictionary];
  if (storage) {
    NSNumber *fileSystemSizeInBytes = [storage objectForKey:NSFileSystemSize];
    totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
  }
  return (double)totalSpace;
}

+ (NSString *)keyForStorageType:(NSString *)storageType {
#if TARGET_OS_TV
  return NSURLVolumeAvailableCapacityKey;
#else
  if ([storageType isEqualToString:@"important"]) {
    return NSURLVolumeAvailableCapacityForImportantUsageKey;
  }
  if ([storageType isEqualToString:@"opportunistic"]) {
    return NSURLVolumeAvailableCapacityForOpportunisticUsageKey;
  }
  return NSURLVolumeAvailableCapacityKey;
#endif
}

+ (double)freeDiskStorageForType:(NSString *)storageType {
  NSError *error = nil;
  if (@available(iOS 11.0, *)) {
    NSURL *fileURL = [NSURL fileURLWithPath:NSHomeDirectory()];
    NSString *capacityKey = [self keyForStorageType:storageType];
    NSDictionary *storageValues = [fileURL resourceValuesForKeys:@[capacityKey] error:&error];
    if (error) {
      NSLog(@"XMDeviceInfo: storage error %@", error);
      return 0;
    }
    NSNumber *availableCapacity = [storageValues objectForKey:capacityKey];
    if (availableCapacity) {
      return (double)[availableCapacity unsignedLongLongValue];
    }
  } else {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error:&error];
    if (error) {
      NSLog(@"XMDeviceInfo: fallback storage error %@", error);
      return 0;
    }
    NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
    if (freeFileSystemSizeInBytes) {
      return (double)[freeFileSystemSizeInBytes unsignedLongLongValue];
    }
  }
  return 0;
}

+ (NSArray<NSString *> *)supportedAbis {
  const NXArchInfo *info = NXGetLocalArchInfo();
  NSString *typeOfCpu = [NSString stringWithUTF8String:info->description];
  return @[typeOfCpu];
}

+ (NSString *)ipAddress {
  NSString *address = @"0.0.0.0";
  struct ifaddrs *interfaces = NULL;
  struct ifaddrs *temp_addr = NULL;
  if (getifaddrs(&interfaces) == 0) {
    temp_addr = interfaces;
    while (temp_addr != NULL) {
      sa_family_t addr_family = temp_addr->ifa_addr->sa_family;
      if (addr_family == AF_INET || addr_family == AF_INET6) {
        NSString *ifname = [NSString stringWithUTF8String:temp_addr->ifa_name];
        if ([ifname isEqualToString:@"en0"] || [ifname isEqualToString:@"en1"]) {
          const struct sockaddr_in *addr = (const struct sockaddr_in *)temp_addr->ifa_addr;
          socklen_t addr_len = addr_family == AF_INET ? INET_ADDRSTRLEN : INET6_ADDRSTRLEN;
          char addr_buffer[addr_len];
          const char *netname = inet_ntop(addr_family, &addr->sin_addr, addr_buffer, addr_len);
          address = [NSString stringWithUTF8String:netname];
        }
      }
      temp_addr = temp_addr->ifa_next;
    }
  }
  freeifaddrs(interfaces);
  return address;
}

+ (BOOL)isPinOrFingerprintSet {
#if TARGET_OS_TV
  return NO;
#else
  LAContext *context = [[LAContext alloc] init];
  return [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:nil];
#endif
}

+ (float)batteryLevel {
#if TARGET_OS_TV
  return 1.0f;
#else
  return (float)[UIDevice currentDevice].batteryLevel;
#endif
}

+ (NSDictionary<NSString *, id> *)powerState {
  float batteryLevel = [self batteryLevel];
#if TARGET_OS_TV
  return @{
    @"batteryLevel": @(batteryLevel),
    @"batteryState": @"full",
  };
#else
  NSArray *states = @[ @"unknown", @"unplugged", @"charging", @"full" ];
  NSString *state = [states objectAtIndex:(NSUInteger)[UIDevice currentDevice].batteryState];
  return @{
    @"batteryLevel": @(batteryLevel),
    @"batteryState": state,
    @"lowPowerMode": @([NSProcessInfo processInfo].isLowPowerModeEnabled),
  };
#endif
}

+ (BOOL)isBatteryCharging {
  return [[self powerState][@"batteryState"] isEqualToString:@"charging"];
}

+ (BOOL)isLocationEnabled {
  return [CLLocationManager locationServicesEnabled];
}

+ (BOOL)isHeadphonesConnected {
  AVAudioSessionRouteDescription *route = [[AVAudioSession sharedInstance] currentRoute];
  for (AVAudioSessionPortDescription *desc in [route outputs]) {
    if ([[desc portType] isEqualToString:AVAudioSessionPortHeadphones]) return YES;
    if ([[desc portType] isEqualToString:AVAudioSessionPortBluetoothA2DP]) return YES;
    if ([[desc portType] isEqualToString:AVAudioSessionPortBluetoothHFP]) return YES;
  }
  return NO;
}

+ (BOOL)isWiredHeadphonesConnected {
  AVAudioSessionRouteDescription *route = [[AVAudioSession sharedInstance] currentRoute];
  for (AVAudioSessionPortDescription *desc in [route outputs]) {
    if ([[desc portType] isEqualToString:AVAudioSessionPortHeadphones]) return YES;
  }
  return NO;
}

+ (BOOL)isBluetoothHeadphonesConnected {
  AVAudioSessionRouteDescription *route = [[AVAudioSession sharedInstance] currentRoute];
  for (AVAudioSessionPortDescription *desc in [route outputs]) {
    if ([[desc portType] isEqualToString:AVAudioSessionPortBluetoothA2DP]) return YES;
    if ([[desc portType] isEqualToString:AVAudioSessionPortBluetoothHFP]) return YES;
  }
  return NO;
}

+ (unsigned long)usedMemory {
  struct task_basic_info info;
  mach_msg_type_number_t size = (mach_msg_type_number_t)sizeof(info);
  kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
  if (kerr != KERN_SUCCESS) {
    return (unsigned long)-1;
  }
  return (unsigned long)info.resident_size;
}

+ (NSDictionary<NSString *, NSNumber *> *)availableLocationProviders {
#if !TARGET_OS_TV
  return @{
    @"locationServicesEnabled": @([CLLocationManager locationServicesEnabled]),
    @"significantLocationChangeMonitoringAvailable": @([CLLocationManager significantLocationChangeMonitoringAvailable]),
    @"headingAvailable": @([CLLocationManager headingAvailable]),
    @"isRangingAvailable": @([CLLocationManager isRangingAvailable]),
  };
#else
  return @{
    @"locationServicesEnabled": @([CLLocationManager locationServicesEnabled]),
  };
#endif
}

+ (NSString *)installerPackageName {
  return [XMAppChannelDisplayNames objectAtIndex:(NSUInteger)[self currentAppChannel]];
}

+ (NSNumber *)brightness {
#if !TARGET_OS_TV && !TARGET_OS_VISION
  return @([UIScreen mainScreen].brightness);
#else
  return @(-1);
#endif
}

+ (long long)firstInstallTime {
  NSURL *urlToDocumentsFolder = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
  NSError *error;
  NSDate *installDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:urlToDocumentsFolder.path error:&error] objectForKey:NSFileCreationDate];
  return (long long)floor([installDate timeIntervalSince1970] * 1000.0);
}

+ (long long)startupTime {
  size_t len = 4;
  int mib[4];
  struct kinfo_proc kp;
  sysctlnametomib("kern.proc.pid", mib, &len);
  mib[3] = getpid();
  len = sizeof(kp);
  sysctl(mib, 4, &kp, &len, NULL, 0);
  struct timeval startTime = kp.kp_proc.p_un.__p_starttime;
  double startTimeMilliSeconds = startTime.tv_sec * 1e3 + startTime.tv_usec / 1e3;
  return (long long)floor(startTimeMilliSeconds);
}

+ (void)fetchUserAgentWithCompletion:(void (^)(NSString *_Nullable, NSError *_Nullable))completion {
#if TARGET_OS_TV
  if (completion) {
    completion(nil, [NSError errorWithDomain:@"XMDeviceInfo" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Unavailable on tvOS"}]);
  }
#else
  dispatch_async(dispatch_get_main_queue(), ^{
    __block WKWebView *webView = [[WKWebView alloc] init];
    [webView evaluateJavaScript:@"window.navigator.userAgent;" completionHandler:^(id _Nullable result, NSError *_Nullable error) {
      if (completion) {
        if (error) {
          completion(nil, error);
        } else {
          completion([NSString stringWithFormat:@"%@", result], nil);
        }
      }
      webView = nil;
    }];
  });
#endif
}

+ (void)generateDeviceCheckTokenWithCompletion:(void (^)(NSString *_Nullable, NSError *_Nullable))completion {
  if (!completion) {
    return;
  }
  if (@available(iOS 11.0, *)) {
#if TARGET_IPHONE_SIMULATOR
    completion(nil, [NSError errorWithDomain:@"XMDeviceInfo" code:2 userInfo:@{NSLocalizedDescriptionKey: @"DeviceCheck requires a physical device"}]);
#else
    DCDevice *device = DCDevice.currentDevice;
    if (![device isSupported]) {
      completion(nil, [NSError errorWithDomain:@"XMDeviceInfo" code:3 userInfo:@{NSLocalizedDescriptionKey: @"DeviceCheck not supported"}]);
      return;
    }
    [device generateTokenWithCompletionHandler:^(NSData *_Nullable token, NSError *_Nullable error) {
      if (error) {
        completion(nil, error);
        return;
      }
      completion([token base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed], nil);
    }];
#endif
  } else {
    completion(nil, [NSError errorWithDomain:@"XMDeviceInfo" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Requires iOS 11+"}]);
  }
}

+ (NSDictionary<NSString *, id> *)bridgeStyleConstants {
  return @{
    @"deviceId": [self deviceId],
    @"bundleId": [self bundleId],
    @"systemName": [self systemName],
    @"systemVersion": [self systemVersion],
    @"appVersion": [self appVersion],
    @"buildNumber": [self buildNumber],
    @"isTablet": @([self isTablet]),
    @"appName": [self appName],
    @"brand": @"Apple",
    @"model": [self model],
    @"deviceType": [self deviceTypeName],
    @"isDisplayZoomed": @([self isDisplayZoomed]),
  };
}

@end
