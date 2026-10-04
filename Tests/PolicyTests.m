#import "Policy.h"
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
    Check([clean[@"score"] intValue]==100 && [clean[@"level"] isEqual:@"完美"] && ![clean[@"jailbreakEvidence"] boolValue],@"clear findings");
    NSDictionary *unknown = IGScore(@[F(@"1",@"visibility",@"unknown",0,NO)]);
    Check([unknown[@"score"] intValue]==100 && [unknown[@"level"] isEqual:@"疑似"],@"unknown prevents perfect without fabricated risk");
    NSArray *ts = @[F(@"1",@"trollstore",@"hit",12,NO),F(@"2",@"trollstore",@"hit",12,NO),F(@"3",@"observer",@"info",40,NO)];
    NSDictionary *troll = IGScore(ts);
    Check([troll[@"score"] intValue]==85 && [troll[@"level"] isEqual:@"疑似"] && ![troll[@"jailbreakEvidence"] boolValue],@"TrollStore alone capped and not jailbreak");
    NSDictionary *duplicate = IGScore(@[F(@"1",@"rootful",@"hit",35,YES),F(@"1",@"rootful",@"hit",35,YES)]);
    Check([duplicate[@"risk"] intValue]==35 && [duplicate[@"hitCount"] intValue]==1,@"deduplicate probe ID");
    NSArray *families = @[F(@"1",@"rootful",@"hit",35,YES),F(@"2",@"rootless",@"hit",35,YES),F(@"3",@"roothide",@"hit",40,YES)];
    NSDictionary *related = IGScore(families);
    Check([related[@"risk"] intValue]==45 && [related[@"correlationDiscount"] intValue]==65,@"correlated files capped together");
    Check([IGScore([[families reverseObjectEnumerator] allObjects])[@"risk"] isEqual:related[@"risk"]],@"score invariant to order");
    NSDictionary *boundary = IGScore(@[F(@"1",@"identity",@"hit",29,NO)]);
    Check([boundary[@"level"] isEqual:@"疑似"],@"risk 29 boundary");
    Check([IGScore(@[F(@"1",@"identity",@"hit",30,NO)])[@"level"] isEqual:@"异常环境"],@"risk 30 boundary");
    NSDictionary *saturated = IGScore([families arrayByAddingObjectsFromArray:@[F(@"4",@"identity",@"hit",40,NO),F(@"5",@"injection",@"hit",35,YES),F(@"6",@"runtime",@"hit",25,NO)]]);
    Check([saturated[@"score"] intValue]==0,@"score floor");
    Check([IGScore(@[F(@"1",@"rootful",@"hit",-5,YES)])[@"risk"] intValue]==0,@"negative weights ignored");
    NSLog(@"All 15 policy regressions passed.");
} return 0; }
