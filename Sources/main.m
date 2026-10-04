#import <UIKit/UIKit.h>
#import "Detector.h"

static UIColor *Accent(void) { return [UIColor colorWithRed:0.22 green:0.70 blue:0.91 alpha:1]; }
static NSString *GroupTitle(NSString *key) {
    return @{@"rootful":@"有根 · Rootful",@"rootless":@"无根 · Rootless",@"roothide":@"隐根 · RootHide",
             @"trollstore":@"巨魔 · TrollStore",@"identity":@"用户与用户组",@"injection":@"动态库与函数来源",
             @"runtime":@"运行环境",@"visibility":@"检测可见性",@"observer":@"检测器权限与说明"}[key] ?: key;
}

@interface IGController : UITableViewController
@property(nonatomic,strong) NSDictionary *report;
@property(nonatomic,strong) NSArray<NSString *> *groups;
@property(nonatomic,strong) NSDictionary<NSString *,NSArray *> *sections;
@property(nonatomic,strong) UISegmentedControl *filter;
@property(nonatomic,assign) BOOL scanning;
@end

@implementation IGController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"环境哨兵";
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"重新检测" style:UIBarButtonItemStylePlain target:self action:@selector(scan)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"] style:UIBarButtonItemStylePlain target:self action:@selector(exportReport:)];
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.tableView.estimatedRowHeight = 96;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.filter = [[UISegmentedControl alloc] initWithItems:@[@"全部",@"命中",@"不可判定",@"用户组"]];
    self.filter.selectedSegmentIndex = 0;
    [self.filter addTarget:self action:@selector(rebuild) forControlEvents:UIControlEventValueChanged];
    [self updateHeader];
    [self scan];
}
- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color {
    UILabel *label = [UILabel new]; label.text = text; label.numberOfLines = 0;
    label.font = [UIFont systemFontOfSize:size weight:weight]; label.textColor = color;
    label.adjustsFontForContentSizeCategory = YES;
    label.font = [[UIFontMetrics defaultMetrics] scaledFontForFont:label.font];
    return label;
}
- (void)updateHeader {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.tableView.bounds.size.width,400)];
    UIStackView *stack = [UIStackView new]; stack.axis = UILayoutConstraintAxisVertical; stack.spacing = 14;
    stack.translatesAutoresizingMaskIntoConstraints = NO; [header addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:22],
        [stack.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-22],
        [stack.topAnchor constraintEqualToAnchor:header.topAnchor constant:24],
        [stack.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-20]]];
    NSDictionary *score = self.report[@"score"];
    NSString *level = score[@"level"] ?: @"正在检查";
    UIColor *color = [level isEqual:@"异常环境"] ? UIColor.systemRedColor : ([level isEqual:@"疑似"] ? UIColor.systemOrangeColor : Accent());
    [stack addArrangedSubview:[self label:@"IOS GUARD  /  LOCAL INSPECTION" size:12 weight:UIFontWeightSemibold color:UIColor.secondaryLabelColor]];
    [stack addArrangedSubview:[self label:self.scanning ? @"检测中…" : [NSString stringWithFormat:@"%@  /  100",score[@"score"] ?: @"—"] size:44 weight:UIFontWeightBold color:color]];
    [stack addArrangedSubview:[self label:level size:26 weight:UIFontWeightBold color:UIColor.labelColor]];
    NSString *subtitle = self.report ? [NSString stringWithFormat:@"%lu 项检查 · %@ 项命中 · %@ 项不可判定\n越狱结论：%@",
        (unsigned long)[self.report[@"findings"] count],score[@"hitCount"],score[@"unknownCount"],
        [self.report[@"device"][@"simulator"] boolValue] ? @"模拟器不判定真机环境" : ([score[@"jailbreakEvidence"] boolValue] ? @"已见越狱／引导／注入痕迹" : @"当前可见范围未见明确越狱痕迹")] : @"正在汇总路径、URL、用户组与运行环境。";
    [stack addArrangedSubview:[self label:subtitle size:14 weight:UIFontWeightRegular color:UIColor.secondaryLabelColor]];
    [stack addArrangedSubview:[self label:@"完美：100 分且无不可判定项\n疑似：71–99 分，或存在不可判定项\n异常环境：0–70 分\n巨魔证据最多扣 15 分，不单独认定越狱。" size:13 weight:UIFontWeightRegular color:UIColor.secondaryLabelColor]];
    [stack addArrangedSubview:self.filter];
    CGFloat width = MAX(240,self.tableView.bounds.size.width);
    CGFloat height = [header systemLayoutSizeFittingSize:CGSizeMake(width,UILayoutFittingCompressedSize.height)
                         withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    header.frame = CGRectMake(0,0,width,height);
    self.tableView.tableHeaderView = header;
}
- (void)scan {
    if (self.scanning) return;
    self.scanning = YES; self.navigationItem.leftBarButtonItem.enabled = NO;
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self updateHeader];
    NSMutableDictionary *publicURLs = [NSMutableDictionary new];
    for (NSString *s in @[@"apple-magnifier",@"trollstore"]) publicURLs[s] = @([UIApplication.sharedApplication canOpenURL:[NSURL URLWithString:[s stringByAppendingString:@"://"]]]);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{
        @autoreleasepool {
            NSDictionary *report = [IGDetector scanWithPublicURLs:publicURLs];
            dispatch_async(dispatch_get_main_queue(),^{
                self.report = report; self.scanning = NO;
                self.navigationItem.leftBarButtonItem.enabled = YES; self.navigationItem.rightBarButtonItem.enabled = YES;
                [self rebuild];
#if TARGET_OS_SIMULATOR
                if ([NSProcessInfo.processInfo.arguments containsObject:@"--smoke-report"]) {
                    NSData *data = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:NULL];
                    [data writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/smoke-report.json"] atomically:YES];
                }
#endif
            });
        }
    });
}
- (void)rebuild {
    NSMutableDictionary *sections = [NSMutableDictionary new];
    NSInteger filter = self.filter.selectedSegmentIndex;
    for (NSDictionary *f in self.report[@"findings"]) {
        if (filter == 1 && ![f[@"status"] isEqual:@"hit"]) continue;
        if (filter == 2 && ![f[@"status"] isEqual:@"unknown"]) continue;
        if (filter == 3 && ![f[@"group"] isEqual:@"identity"]) continue;
        NSString *g = f[@"group"];
        if (!sections[g]) sections[g] = [NSMutableArray new];
        [sections[g] addObject:f];
    }
    NSMutableArray *order = [NSMutableArray new];
    for (NSString *g in @[@"rootful",@"rootless",@"roothide",@"trollstore",@"identity",@"injection",@"runtime",@"visibility",@"observer"]) if (sections[g]) [order addObject:g];
    self.groups = order; self.sections = sections;
    [self updateHeader]; [self.tableView reloadData];
    if (!order.count && self.report) {
        UILabel *empty = [self label:@"当前筛选没有检测项" size:16 weight:UIFontWeightRegular color:UIColor.secondaryLabelColor];
        empty.textAlignment = NSTextAlignmentCenter; self.tableView.backgroundView = empty;
    } else self.tableView.backgroundView = nil;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.groups.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.sections[self.groups[section]].count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return GroupTitle(self.groups[section]); }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSString *g = self.groups[section];
    NSNumber *points = self.report[@"score"][@"groupDeductions"][g] ?: @0;
    NSString *footer = [NSString stringWithFormat:@"该组扣分 %@；单项显示权重，实际按分组上限合并。",points];
    if ([g isEqual:@"roothide"]) footer = [footer stringByAppendingFormat:@" 文件系统三组还共享 45 分上限，本次相关性抵扣 %@ 分。",self.report[@"score"][@"correlationDiscount"]];
    return footer;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"finding"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"finding"];
    NSDictionary *f = self.sections[self.groups[indexPath.section]][indexPath.row];
    NSString *state = f[@"status"];
    NSString *badge = @{@"hit":@"命中",@"clear":@"未命中",@"unknown":@"不可判定",@"info":@"说明"}[state];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ · %@",badge,f[@"title"]];
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"权重 %@ 分\n%@",f[@"weight"],f[@"detail"]];
    cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor; cell.detailTextLabel.numberOfLines = 0;
    cell.textLabel.adjustsFontForContentSizeCategory = YES; cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
    cell.imageView.image = [UIImage systemImageNamed:[state isEqual:@"hit"] ? @"exclamationmark.shield.fill" : ([state isEqual:@"unknown"] ? @"questionmark.circle" : @"checkmark.shield")];
    cell.imageView.tintColor = [state isEqual:@"hit"] ? UIColor.systemOrangeColor : ([state isEqual:@"unknown"] ? UIColor.secondaryLabelColor : Accent());
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessibilityLabel = [NSString stringWithFormat:@"%@，%@，权重%@，%@",badge,f[@"title"],f[@"weight"],f[@"detail"]];
    return cell;
}
- (void)exportReport:(UIBarButtonItem *)sender {
    if (!self.report || self.scanning) return;
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.report options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:&error];
    NSURL *file = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:@"IOSGuard-report.json"];
    if (!data || ![data writeToURL:file options:NSDataWritingAtomic error:&error]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导出失败" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil]; return;
    }
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];
    share.popoverPresentationController.barButtonItem = sender;
    [self presentViewController:share animated:YES completion:nil];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (fabs(self.tableView.tableHeaderView.bounds.size.width-self.tableView.bounds.size.width)>1) [self updateHeader];
}
@end

@interface IGAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation IGAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.tintColor = Accent();
    IGController *controller = [[IGController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:controller];
    nav.navigationBar.prefersLargeTitles = YES;
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc,char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(IGAppDelegate.class)); }
}
