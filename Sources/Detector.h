#import <Foundation/Foundation.h>
@interface IGDetector : NSObject
+ (NSDictionary *)scanWithPublicURLs:(NSDictionary<NSString *,NSNumber *> *)publicURLs privateAPI:(BOOL)enabled device:(NSDictionary *)device;
@end
