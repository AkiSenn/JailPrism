#import "Summary.h"
#import "Localization.h"

NSString *IGStoreForIdentifier(NSString *identifier) {
    return @{@"com.saurik.cydia":@"Cydia",@"org.coolstar.sileostore":@"Sileo",@"org.coolstar.sileonightly":@"Sileo",@"xyz.willy.zebra":@"Zebra"}[identifier.lowercaseString] ?: @"";
}
static NSString *StoreForFinding(NSDictionary *finding) {
    NSString *key=finding[@"id"];
    if ([key hasPrefix:@"app:"]) return IGStoreForIdentifier([key substringFromIndex:4]);
    if ([key hasPrefix:@"publicurl:"]) return @{@"publicurl:cydia":@"Cydia",@"publicurl:sileo":@"Sileo",@"publicurl:zbra":@"Zebra"}[key] ?: @"";
    if (![key hasPrefix:@"path:"]) return @"";
    NSString *component=[key substringFromIndex:5].lastPathComponent.lowercaseString;
    return @{@"cydia.app":@"Cydia",@"sileo.app":@"Sileo",@"sileo-nightly.app":@"Sileo",@"zebra.app":@"Zebra"}[component] ?: @"";
}
NSArray<NSDictionary *> *IGSummaryRows(NSArray<NSDictionary *> *findings, NSDictionary *classification) {
    NSMutableArray *rows=[NSMutableArray new], *trollIDs=[NSMutableArray new], *libraryIDs=[NSMutableArray new], *identityIDs=[NSMutableArray new], *otherIDs=[NSMutableArray new];
    NSMutableSet *stores=[NSMutableSet new], *libraries=[NSMutableSet new]; NSMutableArray *storeIDs=[NSMutableArray new];
    for (NSDictionary *f in findings) {
        if (![f[@"status"] isEqual:@"hit"]) continue;
        NSString *key=f[@"id"], *group=f[@"group"];
        if ([group isEqual:@"trollstore"]) [trollIDs addObject:key];
        NSString *store=StoreForFinding(f);
        if (store.length) { [stores addObject:store]; [storeIDs addObject:key]; }
        if ([group isEqual:@"injection"] && ([key hasPrefix:@"image:"] || [key hasPrefix:@"symbol:"])) {
            NSString *path=[key hasPrefix:@"image:"] ? [key substringFromIndex:6] : f[@"detail"];
            if ([path hasPrefix:@"/"] && ![path containsString:@"\n"]) { [libraries addObject:path.lastPathComponent]; [libraryIDs addObject:key]; }
        }
        if ([group isEqual:@"identity"]) [identityIDs addObject:key];
        if (!store.length && ([group isEqual:@"runtime"] || [group isEqual:@"injection"])) [otherIDs addObject:key];
    }
    if (trollIDs.count) [rows addObject:@{@"id":@"summary:trollstore",@"kind":@"trollstore",@"title":IGT(@"Installation environment"),@"values":@[IGT(@"TrollStore")],@"evidenceIDs":trollIDs}];
    NSArray *types=classification[@"types"] ?: @[];
    if (types.count) {
        NSMutableArray *values=[NSMutableArray new], *ids=[NSMutableArray new];
        for (NSString *type in types) {
            NSString *key=@{@"rootful":@"Rootful jailbreak detected",@"rootless":@"Rootless jailbreak detected",@"roothide":@"RootHide jailbreak detected"}[type];
            if (key) [values addObject:IGText(key)]; [ids addObjectsFromArray:classification[@"evidenceIDs"][type] ?: @[]];
        }
        [rows addObject:@{@"id":@"summary:jailbreak",@"kind":@"jailbreak",@"title":IGT(@"Jailbreak type"),@"values":values,@"evidenceIDs":ids}];
    } else if ([classification[@"primary"] isEqual:@"unspecified"]) {
        [rows addObject:@{@"id":@"summary:jailbreak",@"kind":@"jailbreak",@"title":IGT(@"Jailbreak type"),@"values":@[IGT(@"Jailbreak traces (type undetermined)")],@"evidenceIDs":otherIDs}];
    }
    if (stores.count) {
        NSMutableArray *values=[NSMutableArray new]; for (NSString *name in @[@"Cydia",@"Sileo",@"Zebra"]) if ([stores containsObject:name]) [values addObject:name];
        [rows addObject:@{@"id":@"summary:stores",@"kind":@"stores",@"title":IGT(@"Jailbreak stores"),@"values":values,@"evidenceIDs":storeIDs}];
    }
    if (libraries.count) [rows addObject:@{@"id":@"summary:libraries",@"kind":@"libraries",@"title":IGT(@"Injected libraries"),@"values":[libraries.allObjects sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)],@"evidenceIDs":libraryIDs}];
    if (identityIDs.count) [rows addObject:@{@"id":@"summary:identity",@"kind":@"identity",@"title":IGT(@"Process identity"),@"values":@[IGT(@"User or group privilege anomalies")],@"evidenceIDs":identityIDs}];
    if (otherIDs.count && !types.count && !libraries.count && ![classification[@"primary"] isEqual:@"unspecified"]) [rows addObject:@{@"id":@"summary:runtime",@"kind":@"runtime",@"title":IGT(@"Runtime environment"),@"values":@[IGT(@"Runtime environment anomalies")],@"evidenceIDs":otherIDs}];
    return rows;
}
