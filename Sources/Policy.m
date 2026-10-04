#import "Policy.h"
#import "Localization.h"

BOOL IGIsTrollStoreIdentifier(NSString *identifier) {
    NSString *s = identifier.lowercaseString;
    return [@[@"com.opa334.trollstore", @"com.opa334.trollstorelite"] containsObject:s];
}

NSString *IGURLHandlerKind(NSArray<NSString *> *identifiers) {
    for (NSString *s in identifiers) if (IGIsTrollStoreIdentifier(s)) return @"trollstore";
    if (!identifiers.count) return @"unknown";
    for (NSString *s in identifiers) {
        if (![s.lowercaseString isEqualToString:@"com.apple.magnifier"]) return @"other";
    }
    return @"magnifier";
}

NSDictionary *IGScore(NSArray<NSDictionary *> *findings) {
    NSDictionary *caps = @{@"rootful":@45, @"rootless":@45, @"roothide":@45,
                          @"injection":@35, @"identity":@40, @"runtime":@25,
                          @"trollstore":@15, @"visibility":@0, @"observer":@0};
    NSMutableDictionary *totals = [NSMutableDictionary new];
    NSMutableArray *contributions = [NSMutableArray new];
    NSMutableSet *seen = [NSMutableSet new];
    NSInteger risk = 0, unknown = 0, hits = 0, skipped = 0;
    BOOL jailbreak = NO;
    for (NSDictionary *f in findings) {
        NSString *key = f[@"id"];
        if (!key.length || [seen containsObject:key]) continue;
        [seen addObject:key];
        if ([f[@"status"] isEqual:@"skipped"]) { skipped++; continue; }
        if ([f[@"status"] isEqual:@"unknown"]) { unknown++; continue; }
        if (![f[@"status"] isEqual:@"hit"]) continue;
        hits++;
        NSString *group = f[@"group"];
        NSInteger cap = [caps[group] integerValue];
        NSInteger used = [totals[group] integerValue];
        NSInteger applied = MIN(MAX(0, [f[@"weight"] integerValue]), MAX(0, cap-used));
        totals[group] = @(used+applied);
        risk += applied;
        if ([f[@"jailbreakEvidence"] boolValue]) jailbreak = YES;
        [contributions addObject:@{@"id":key, @"applied":@(applied)}];
    }
    // Correlated filesystem families share a cap: translated paths are not three jailbreaks.
    NSInteger filesystem = [totals[@"rootful"] integerValue]+[totals[@"rootless"] integerValue]+[totals[@"roothide"] integerValue];
    NSInteger correlationDiscount = MAX(0, filesystem-45);
    risk = MIN(100, risk-correlationDiscount);
    NSString *code = risk >= 30 ? @"abnormal" : ((risk > 0 || unknown > 0) ? @"suspected" : @"perfect");
    NSString *level = IGText(@{@"abnormal":@"Abnormal environment",@"suspected":@"Suspected",@"perfect":@"Perfect"}[code]);
    return @{@"score":@(100-risk), @"risk":@(risk), @"level":level,
             @"levelCode":code,@"unknownCount":@(unknown), @"hitCount":@(hits),@"skippedCount":@(skipped), @"groupDeductions":totals,
             @"correlationDiscount":@(correlationDiscount), @"contributions":contributions,
             @"jailbreakEvidence":@(jailbreak)};
}

NSString *IGFamilyForPath(NSString *path) {
    NSString *p = path.lowercaseString;
    if ([p containsString:@".jbroot"] || [p containsString:@"libroothide"]) return @"roothide";
    if ([p hasPrefix:@"/var/jb/"] || [p isEqual:@"/var/jb"] || [p hasPrefix:@"/private/var/jb/"] || [p hasPrefix:@"/private/preboot/"]) return @"rootless";
    if ([p hasPrefix:@"/taurine/"] || [p isEqual:@"/usr/lib/libhooker.dylib"] || [p isEqual:@"/usr/lib/libellekit.dylib"] || [p hasPrefix:@"/usr/lib/ellekit/"] || [p hasPrefix:@"/library/mobilesubstrate/"] || [p hasPrefix:@"/usr/lib/tweakinject/"] ||
        [p hasPrefix:@"/usr/lib/substitute"] || [p hasPrefix:@"/usr/libexec/substrate"] || [p hasPrefix:@"/usr/libexec/substitute"]) return @"rootful";
    return @"";
}

NSDictionary *IGClassification(NSArray<NSDictionary *> *findings) {
    NSMutableDictionary *counts = [@{@"rootful":@0,@"rootless":@0,@"roothide":@0} mutableCopy];
    NSMutableDictionary *evidence = [NSMutableDictionary new];
    NSMutableSet *seen = [NSMutableSet new];
    BOOL generic = NO, troll = NO; NSUInteger unknown = 0;
    for (NSDictionary *f in findings) {
        NSString *key = f[@"id"];
        if (!key.length || [seen containsObject:key]) continue;
        [seen addObject:key];
        if ([f[@"status"] isEqual:@"unknown"]) unknown++;
        if (![f[@"status"] isEqual:@"hit"]) continue;
        troll |= [f[@"group"] isEqual:@"trollstore"];
        generic |= [f[@"jailbreakEvidence"] boolValue];
        NSString *family = f[@"familyHint"] ?: f[@"group"];
        if (!counts[family] || [f[@"weight"] integerValue] <= 0) continue;
        counts[family] = @([counts[family] integerValue]+1);
        if (!evidence[family]) evidence[family] = [NSMutableArray new];
        [evidence[family] addObject:key];
    }
    NSDictionary *names = @{@"rootful":@"Suspected rootful jailbreak (rootful)",@"rootless":@"Suspected rootless jailbreak (rootless)",@"roothide":@"Suspected hidden-root jailbreak (roothide)"};
    NSMutableArray *types = [NSMutableArray new], *labels = [NSMutableArray new];
    for (NSString *family in @[@"rootful",@"rootless",@"roothide"]) {
        if ([counts[family] integerValue]) { [types addObject:family]; [labels addObject:IGT(names[family])]; }
    }
    NSString *primary = types.count == 1 ? types.firstObject : (types.count > 1 ? @"mixed" : (generic ? @"unspecified" : (troll ? @"trollstore" : (unknown ? @"unknown" : @"none"))));
    NSString *summary = labels.count ? [labels componentsJoinedByString:@" / "] :
        IGText(@{@"unspecified":@"Jailbreak traces detected; type undetermined",@"trollstore":@"TrollStore detected; no specific jailbreak type identified",@"unknown":@"Insufficient evidence to determine the environment",@"none":@"No visible jailbreak traces in enabled checks"}[primary]);
    return @{@"types":types,@"primary":primary,@"summary":summary,@"evidenceCounts":counts,@"evidenceIDs":evidence,@"mixed":@((BOOL)(types.count>1)),@"trollStoreDetected":@(troll)};
}
