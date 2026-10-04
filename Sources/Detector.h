#import <Foundation/Foundation.h>

@interface IGDetector : NSObject
+ (NSDictionary *)scanWithPublicURLs:(NSDictionary<NSString *, NSNumber *> *)publicURLs;
@end
