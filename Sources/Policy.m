#import "Policy.h"

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
    NSInteger risk = 0, unknown = 0, hits = 0;
    BOOL jailbreak = NO;
    for (NSDictionary *f in findings) {
        NSString *key = f[@"id"];
        if (!key.length || [seen containsObject:key]) continue;
        [seen addObject:key];
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
    NSString *level = risk >= 30 ? @"异常环境" : ((risk > 0 || unknown > 0) ? @"疑似" : @"完美");
    return @{@"score":@(100-risk), @"risk":@(risk), @"level":level,
             @"unknownCount":@(unknown), @"hitCount":@(hits), @"groupDeductions":totals,
             @"correlationDiscount":@(correlationDiscount), @"contributions":contributions,
             @"jailbreakEvidence":@(jailbreak)};
}
