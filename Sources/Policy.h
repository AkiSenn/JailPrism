#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
// Shared by the detector and the macOS policy regression executable.
FOUNDATION_EXPORT BOOL IGIsTrollStoreIdentifier(NSString *identifier);
FOUNDATION_EXPORT NSString *IGURLHandlerKind(NSArray<NSString *> *identifiers);
FOUNDATION_EXPORT NSDictionary *IGScore(NSArray<NSDictionary *> *findings);
FOUNDATION_EXPORT NSDictionary *IGClassification(NSArray<NSDictionary *> *findings);
FOUNDATION_EXPORT NSString *IGFamilyForPath(NSString *path);
NS_ASSUME_NONNULL_END
