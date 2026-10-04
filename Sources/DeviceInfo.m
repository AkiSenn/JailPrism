#import "DeviceInfo.h"
#import <UIKit/UIKit.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <TargetConditionals.h>
NSDictionary *IGDeviceInfo(void) {
    struct utsname u = {0}; uname(&u);
    NSString *identifier = [NSString stringWithUTF8String:u.machine];
#if TARGET_OS_SIMULATOR
    identifier = NSProcessInfo.processInfo.environment[@"SIMULATOR_MODEL_IDENTIFIER"] ?: identifier;
#endif
    NSDictionary *models = @{
        @"iPhone8,1":@"iPhone 6s",@"iPhone8,2":@"iPhone 6s Plus",@"iPhone8,4":@"iPhone SE",
        @"iPhone9,1":@"iPhone 7",@"iPhone9,3":@"iPhone 7",@"iPhone9,2":@"iPhone 7 Plus",@"iPhone9,4":@"iPhone 7 Plus",
        @"iPhone10,1":@"iPhone 8",@"iPhone10,4":@"iPhone 8",@"iPhone10,2":@"iPhone 8 Plus",@"iPhone10,5":@"iPhone 8 Plus",@"iPhone10,3":@"iPhone X",@"iPhone10,6":@"iPhone X",
        @"iPhone11,2":@"iPhone XS",@"iPhone11,4":@"iPhone XS Max",@"iPhone11,6":@"iPhone XS Max",@"iPhone11,8":@"iPhone XR",
        @"iPhone12,1":@"iPhone 11",@"iPhone12,3":@"iPhone 11 Pro",@"iPhone12,5":@"iPhone 11 Pro Max",@"iPhone12,8":@"iPhone SE (2nd generation)",
        @"iPhone13,1":@"iPhone 12 mini",@"iPhone13,2":@"iPhone 12",@"iPhone13,3":@"iPhone 12 Pro",@"iPhone13,4":@"iPhone 12 Pro Max",
        @"iPhone14,4":@"iPhone 13 mini",@"iPhone14,5":@"iPhone 13",@"iPhone14,2":@"iPhone 13 Pro",@"iPhone14,3":@"iPhone 13 Pro Max",@"iPhone14,6":@"iPhone SE (3rd generation)",
        @"iPhone14,7":@"iPhone 14",@"iPhone14,8":@"iPhone 14 Plus",@"iPhone15,2":@"iPhone 14 Pro",@"iPhone15,3":@"iPhone 14 Pro Max",
        @"iPhone15,4":@"iPhone 15",@"iPhone15,5":@"iPhone 15 Plus",@"iPhone16,1":@"iPhone 15 Pro",@"iPhone16,2":@"iPhone 15 Pro Max",
        @"iPhone17,3":@"iPhone 16",@"iPhone17,4":@"iPhone 16 Plus",@"iPhone17,1":@"iPhone 16 Pro",@"iPhone17,2":@"iPhone 16 Pro Max",@"iPhone17,5":@"iPhone 16e",
        @"iPhone18,3":@"iPhone 17",@"iPhone18,1":@"iPhone 17 Pro",@"iPhone18,2":@"iPhone 17 Pro Max",@"iPhone18,4":@"iPhone Air",@"iPhone18,5":@"iPhone 17e",
        @"iPhone19,2":@"iPhone 18 Pro",@"iPhone19,3":@"iPhone 18 Pro Max",@"iPhone19,7":@"iPhone 18 Pro Max"};
    char build[256] = {0}; size_t size = sizeof(build); sysctlbyname("kern.osversion",build,&size,NULL,0);
    return @{@"model":models[identifier] ?: identifier,@"hardwareIdentifier":identifier,@"system":UIDevice.currentDevice.systemVersion,
             @"osBuild":[NSString stringWithUTF8String:build],@"simulator":@((BOOL)TARGET_OS_SIMULATOR)};
}
