#import "Policy.h"
#import "Localization.h"
#import "Summary.h"
#include <stdlib.h>
static void Check(BOOL condition,NSString *message) { if (!condition) { NSLog(@"FAIL: %@",message); exit(1); } }
static NSDictionary *F(NSString *key,NSString *group,NSString *status,int weight,BOOL jb) {
    return @{@"id":key,@"group":group,@"status":status,@"weight":@(weight),@"jailbreakEvidence":@(jb)};
}
int main(void) { @autoreleasepool {
    Check([IGURLHandlerKind(@[@"com.apple.Magnifier"]) isEqual:@"magnifier"],@"stock Magnifier is not TrollStore");
    Check([IGURLHandlerKind(@[@"com.apple.Magnifier",@"com.opa334.TrollStore"]) isEqual:@"trollstore"],@"mixed handlers identify TrollStore");
    Check([IGURLHandlerKind(@[@"com.opa334.TrollStoreLite"]) isEqual:@"trollstore"],@"Lite recognized");
    Check([IGURLHandlerKind(@[@"com.example.trollstore.fake"]) isEqual:@"other"],@"no substring false positive");
    Check([IGURLHandlerKind(@[]) isEqual:@"unknown"],@"missing handler is not clean");
    NSDictionary *clean = IGScore(@[F(@"1",@"rootful",@"clear",35,YES)]);
    Check([clean[@"score"] intValue]==100 && [clean[@"levelCode"] isEqual:@"perfect"] && ![clean[@"jailbreakEvidence"] boolValue],@"clear findings");
    NSDictionary *unknown = IGScore(@[F(@"1",@"visibility",@"unknown",0,NO)]);
    Check([unknown[@"score"] intValue]==100 && [unknown[@"levelCode"] isEqual:@"suspected"],@"unknown prevents perfect without fabricated risk");
    NSArray *ts = @[F(@"1",@"trollstore",@"hit",12,NO),F(@"2",@"trollstore",@"hit",12,NO),F(@"3",@"observer",@"info",40,NO)];
    NSDictionary *troll = IGScore(ts);
    Check([troll[@"score"] intValue]==85 && [troll[@"levelCode"] isEqual:@"suspected"] && ![troll[@"jailbreakEvidence"] boolValue],@"TrollStore alone capped and not jailbreak");
    NSDictionary *duplicate = IGScore(@[F(@"1",@"rootful",@"hit",35,YES),F(@"1",@"rootful",@"hit",35,YES)]);
    Check([duplicate[@"risk"] intValue]==35 && [duplicate[@"hitCount"] intValue]==1,@"deduplicate probe ID");
    NSArray *families = @[F(@"1",@"rootful",@"hit",35,YES),F(@"2",@"rootless",@"hit",35,YES),F(@"3",@"roothide",@"hit",40,YES)];
    NSDictionary *related = IGScore(families);
    Check([related[@"risk"] intValue]==45 && [related[@"correlationDiscount"] intValue]==65,@"correlated files capped together");
    Check([IGScore([[families reverseObjectEnumerator] allObjects])[@"risk"] isEqual:related[@"risk"]],@"score invariant to order");
    NSDictionary *boundary = IGScore(@[F(@"1",@"identity",@"hit",29,NO)]);
    Check([boundary[@"levelCode"] isEqual:@"suspected"],@"risk 29 boundary");
    Check([IGScore(@[F(@"1",@"identity",@"hit",30,NO)])[@"levelCode"] isEqual:@"abnormal"],@"risk 30 boundary");
    NSDictionary *saturated = IGScore([families arrayByAddingObjectsFromArray:@[F(@"4",@"identity",@"hit",40,NO),F(@"5",@"injection",@"hit",35,YES),F(@"6",@"runtime",@"hit",25,NO)]]);
    Check([saturated[@"score"] intValue]==0,@"score floor");
    Check([IGScore(@[F(@"1",@"rootful",@"hit",-5,YES)])[@"risk"] intValue]==0,@"negative weights ignored");
    Check([IGClassification(ts)[@"primary"] isEqual:@"trollstore"] && [IGClassification(ts)[@"types"] count]==0,@"TrollStore is not a jailbreak family");
    Check([IGClassification(families)[@"types"] count]==3 && [IGClassification(families)[@"mixed"] boolValue],@"multiple families preserved without guessing one");
    Check([IGClassification(@[F(@"1",@"rootful",@"unknown",35,YES)])[@"types"] count]==0,@"denied/unknown does not classify");
    Check([IGClassification(@[F(@"1",@"runtime",@"hit",15,NO)])[@"types"] count]==0,@"installed Sileo or Dopamine without a family path is ambiguous");
    Check([IGClassification(@[F(@"1",@"injection",@"hit",35,YES)])[@"primary"] isEqual:@"unspecified"],@"generic injection does not fabricate a family");
    NSMutableDictionary *hint = [F(@"h",@"injection",@"hit",35,YES) mutableCopy]; hint[@"familyHint"]=@"rootful";
    Check([IGClassification(@[hint,hint])[@"evidenceCounts"][@"rootful"] intValue]==1,@"family hint and duplicate evidence");
    Check([IGFamilyForPath(@"/var/jb/usr/lib/libellekit.dylib") isEqual:@"rootless"],@"Dopamine ElleKit rootless path");
    Check([IGFamilyForPath(@"/var/containers/Bundle/Application/.jbroot-123/usr/lib/libellekit.dylib") isEqual:@"roothide"],@"RootHide ElleKit randomized path");
    Check([IGFamilyForPath(@"/usr/lib/libhooker.dylib") isEqual:@"rootful"],@"Taurine libhooker path");
    Check([IGFamilyForPath(@"/usr/lib/substitute-loader.dylib") isEqual:@"rootful"],@"unc0ver Substitute retained");
    Check([IGScore(@[F(@"off",@"observer",@"skipped",35,YES)])[@"skippedCount"] intValue]==1 && [IGScore(@[F(@"off",@"observer",@"skipped",35,YES)])[@"unknownCount"] intValue]==0,@"disabled checks are skipped without score impact");
    Check([IGResolvedLanguage(@[@"zh-Hant-HK"],@"system") isEqual:@"zh_Hans_CN"],@"Traditional Hong Kong maps to simplified resource");
    Check([IGResolvedLanguage(@[@"zh-Hant-TW"],@"system") isEqual:@"zh_Hans_CN"],@"Traditional Taiwan maps to simplified resource");
    Check([IGResolvedLanguage(@[@"zh-Hans-CN"],@"system") isEqual:@"zh_Hans_CN"],@"Simplified Chinese automatic");
    Check([IGResolvedLanguage(@[@"en-GB"],@"system") isEqual:@"en_US"],@"English automatic");
    Check([IGResolvedLanguage(@[@"ja-JP"],@"system") isEqual:@"en_US"],@"unsupported language fallback");
    Check([IGResolvedLanguage(@[@"zh-Hant-TW"],@"en_US") isEqual:@"en_US"],@"manual English override");
    Check([IGResolvedLanguage(@[@"en-US"],@"zh_Hans_CN") isEqual:@"zh_Hans_CN"],@"manual Chinese override");
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"IGPrivateAPIEnabled"]; IGRegisterSettings();
    Check(!IGPrivateAPIEnabled(),@"private APIs default off");
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"IGPrivateAPIEnabled"]; IGRegisterSettings();
    Check(IGPrivateAPIEnabled(),@"registration preserves user preference");
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"IGPrivateAPIEnabled"];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"IGProfessionalMode"]; IGRegisterSettings();
    Check(!IGProfessionalModeEnabled(),@"normal mode is the default");
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"IGProfessionalMode"]; IGRegisterSettings();
    Check(IGProfessionalModeEnabled() && !IGPrivateAPIEnabled(),@"professional preference persists and does not enable private APIs");
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"IGProfessionalMode"];
    Check([IGStoreForIdentifier(@"org.coolstar.SileoStore") isEqual:@"Sileo"],@"store bundle IDs are case insensitive");
    Check(!IGStoreForIdentifier(@"org.coolstar.SileoStore.fake").length,@"no substring store match");
    NSArray *storeFindings=@[F(@"publicurl:sileo",@"runtime",@"hit",10,NO),F(@"path:/var/jb/Applications/Cydia.app",@"rootless",@"hit",35,YES),F(@"app:org.coolstar.SileoStore",@"runtime",@"hit",15,NO),F(@"publicurl:zbra",@"runtime",@"unknown",10,NO)];
    NSArray *summary=IGSummaryRows(storeFindings,IGClassification(storeFindings));
    NSDictionary *storeRow=nil; for (NSDictionary *row in summary) if ([row[@"kind"] isEqual:@"stores"]) storeRow=row;
    Check([storeRow[@"values"] isEqual:@[@"Cydia",@"Sileo"]],@"multiple stores deduplicated in stable order; unknown excluded");
    Check([storeRow[@"evidenceIDs"] count]==3,@"all store evidence retained after name deduplication");
    Check([summary[0][@"kind"] isEqual:@"jailbreak"] && [summary[0][@"values"] count]==1,@"Rootless conclusion independent from installed store names");
    Check([IGSummaryRows(@[F(@"path:/Applications/Cydia.app.backup",@"runtime",@"hit",0,NO)],IGClassification(@[])) count]==1,@"backup path is only generic runtime evidence, not Cydia");
    NSArray *trollSummary=IGSummaryRows(ts,IGClassification(ts));
    Check(trollSummary.count==1 && [trollSummary[0][@"kind"] isEqual:@"trollstore"],@"TrollStore-only summary does not claim jailbreak");
    NSMutableDictionary *image=[F(@"image:/var/jb/usr/lib/ellekit/libinjector.dylib",@"injection",@"hit",35,YES) mutableCopy]; image[@"detail"]=@"/var/jb/usr/lib/ellekit/libinjector.dylib";
    NSMutableDictionary *symbol=[F(@"symbol:open",@"injection",@"hit",35,YES) mutableCopy]; symbol[@"detail"]=@"/var/jb/usr/lib/ellekit/libinjector.dylib";
    NSArray *libFindings=@[image,symbol,F(@"path:/var/jb/usr/lib/libellekit.dylib",@"rootless",@"hit",35,YES)];
    NSDictionary *libRow=nil; for (NSDictionary *row in IGSummaryRows(libFindings,IGClassification(libFindings))) if ([row[@"kind"] isEqual:@"libraries"]) libRow=row;
    Check([libRow[@"values"] isEqual:@[@"libinjector.dylib"]],@"library basenames deduplicated; files merely present excluded");
    Check([libRow[@"evidenceIDs"] count]==2,@"loaded image and symbol evidence retained");
    Check(!IGSummaryRows(@[F(@"image:/var/jb/lib.dylib",@"injection",@"unknown",35,YES)],IGClassification(@[])).count,@"unknown library is not declared detected");
    NSLog(@"All policy, settings and normal-summary regressions passed.");
} return 0; }
