#import "Localization.h"
NSString *IGResolvedLanguage(NSArray<NSString *> *preferred, NSString *selection) {
    if ([@[@"en_US",@"zh_Hans_CN"] containsObject:selection]) return selection;
    NSString *first = preferred.firstObject.lowercaseString ?: @"en";
    return [first hasPrefix:@"zh"] ? @"zh_Hans_CN" : @"en_US";
}
void IGRegisterSettings(void) {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{@"IGLanguage":@"system",@"IGPrivateAPIEnabled":@NO}];
}
NSString *IGCurrentLanguage(void) {
    return IGResolvedLanguage(NSLocale.preferredLanguages,[NSUserDefaults.standardUserDefaults stringForKey:@"IGLanguage"] ?: @"system");
}
BOOL IGPrivateAPIEnabled(void) { return [NSUserDefaults.standardUserDefaults boolForKey:@"IGPrivateAPIEnabled"]; }
NSString *IGText(NSString *key) {
    NSString *path = [NSBundle.mainBundle pathForResource:IGCurrentLanguage() ofType:@"lproj"];
    NSBundle *languageBundle = path ? [NSBundle bundleWithPath:path] : nil;
    return [languageBundle localizedStringForKey:key value:key table:@"Localizable"] ?: key;
}
