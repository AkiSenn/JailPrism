#import <Foundation/Foundation.h>
FOUNDATION_EXPORT NSString *IGResolvedLanguage(NSArray<NSString *> *preferred, NSString *selection);
FOUNDATION_EXPORT NSString *IGCurrentLanguage(void);
FOUNDATION_EXPORT NSString *IGText(NSString *key);
FOUNDATION_EXPORT BOOL IGPrivateAPIEnabled(void);
FOUNDATION_EXPORT BOOL IGProfessionalModeEnabled(void);
FOUNDATION_EXPORT void IGRegisterSettings(void);
#define IGT(key) IGText(key)
#define IGF(key, ...) [NSString stringWithFormat:IGText(key), __VA_ARGS__]
