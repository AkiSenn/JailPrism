#import <UIKit/UIKit.h>
#import <TargetConditionals.h>
#import "Detector.h"
#import "DeviceInfo.h"
#import "Localization.h"
static UIColor *Accent(void) { return UIColor.systemTealColor; }
static NSString *GroupTitle(NSString *g) {
    return IGText(@{@"rootful":@"Rootful jailbreak",@"rootless":@"Rootless jailbreak",@"roothide":@"Hidden-root jailbreak",@"trollstore":@"TrollStore",@"identity":@"User and group anomalies",@"injection":@"Injection and filtering",@"runtime":@"Runtime environment",@"visibility":@"Check visibility",@"observer":@"Detector configuration"}[g] ?: g);
}
@interface IGSettings : UITableViewController
@end
@implementation IGSettings
- (void)viewDidLoad { [super viewDidLoad]; self.title=IGT(@"Settings"); self.tableView.rowHeight=UITableViewAutomaticDimension; self.tableView.estimatedRowHeight=60; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 2; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return s==0 ? 3 : 1; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return s==0 ? IGT(@"Language") : IGT(@"Extended environment checks"); }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s {
    return s==0 ? IGT(@"System: Chinese regions use zh_Hans_CN, including Traditional Chinese. Other languages use en_US.") : IGT(@"Off by default. For certificate or TrollStore installations: attempts private URL handler, registry, sandbox, daemon and kernel checks. The switch grants no privileges and cannot guarantee bypassing jailbreak hiding.");
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.numberOfLines=0; cell.detailTextLabel.numberOfLines=0;
    if (p.section==0) {
        NSArray *codes=@[@"system",@"en_US",@"zh_Hans_CN"];
        cell.textLabel.text=@[IGT(@"Follow system"),@"English (en_US)",@"简体中文 (zh_Hans_CN)"][p.row];
        cell.accessoryType=[codes[p.row] isEqual:[NSUserDefaults.standardUserDefaults stringForKey:@"IGLanguage"]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    } else {
        cell.textLabel.text=IGT(@"Use private APIs"); cell.detailTextLabel.text=IGT(@"Comprehensive read-only inspection");
        UISwitch *toggle=[UISwitch new]; toggle.on=IGPrivateAPIEnabled(); toggle.accessibilityIdentifier=@"privateAPI.switch";
        [toggle addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=toggle;
        cell.selectionStyle=UITableViewCellSelectionStyleNone;
    } return cell;
}
- (void)toggle:(UISwitch *)sender { [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:@"IGPrivateAPIEnabled"]; }
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p {
    if (p.section==0) { [NSUserDefaults.standardUserDefaults setObject:@[@"system",@"en_US",@"zh_Hans_CN"][p.row] forKey:@"IGLanguage"]; self.title=IGT(@"Settings"); [t reloadData]; }
}
@end

@interface IGController : UITableViewController
@property(nonatomic,strong) NSDictionary *report;
@property(nonatomic,strong) NSDictionary *device;
@property(nonatomic,strong) NSDictionary *sections;
@property(nonatomic,strong) NSArray *groups;
@property(nonatomic,strong) UISegmentedControl *filter;
@property(nonatomic,copy) NSString *scanLanguage;
@property(nonatomic) BOOL scanPrivate;
@property(nonatomic) BOOL scanning;
@end
@implementation IGController
- (void)viewDidLoad {
    [super viewDidLoad]; self.device=IGDeviceInfo();
    self.tableView.rowHeight=UITableViewAutomaticDimension; self.tableView.estimatedRowHeight=100;
    self.filter=[[UISegmentedControl alloc] initWithItems:@[@"",@"",@"",@""]]; self.filter.selectedSegmentIndex=0;
    [self.filter addTarget:self action:@selector(rebuild) forControlEvents:UIControlEventValueChanged];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshSettings) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self refreshTitles]; [self scan];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self refreshSettings]; }
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)refreshSettings {
    if (!self.scanning && (![self.scanLanguage isEqual:IGCurrentLanguage()] || self.scanPrivate!=IGPrivateAPIEnabled())) { [self refreshTitles]; [self scan]; }
}
- (void)refreshTitles {
    self.title=IGT(@"Environment Guard");
    self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:IGT(@"Recheck") style:UIBarButtonItemStylePlain target:self action:@selector(scan)];
    UIBarButtonItem *gear=[[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"] style:UIBarButtonItemStylePlain target:self action:@selector(settings)]; gear.accessibilityLabel=IGT(@"Settings");
    UIBarButtonItem *share=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(exportReport:)];
    self.navigationItem.rightBarButtonItems=@[gear,share];
    NSArray *names=@[IGT(@"All"),IGT(@"Hits"),IGT(@"Unknown"),IGT(@"Groups")]; for (NSUInteger i=0;i<4;i++) [self.filter setTitle:names[i] forSegmentAtIndex:i];
}
- (void)settings { [self.navigationController pushViewController:[[IGSettings alloc] initWithStyle:UITableViewStyleInsetGrouped] animated:YES]; }
- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color {
    UILabel *l=[UILabel new]; l.text=text; l.numberOfLines=0; l.font=[UIFont systemFontOfSize:size weight:weight]; l.textColor=color; return l;
}
- (void)updateHeader {
    UIView *header=[UIView new]; UIStackView *stack=[UIStackView new]; stack.axis=UILayoutConstraintAxisVertical; stack.spacing=10;
    stack.translatesAutoresizingMaskIntoConstraints=NO; [header addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:22],[stack.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-22],[stack.topAnchor constraintEqualToAnchor:header.topAnchor constant:16],[stack.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-20]]];
    NSDictionary *score=self.report[@"score"], *device=self.report[@"device"] ?: self.device;
    NSString *level=score[@"level"] ?: IGT(@"Checking");
    UIColor *color=[score[@"levelCode"] isEqual:@"abnormal"] ? UIColor.systemRedColor : ([score[@"levelCode"] isEqual:@"suspected"] ? UIColor.systemOrangeColor : Accent());
    [stack addArrangedSubview:[self label:IGF(@"Device status · %@ (%@)\niOS %@ (%@)",device[@"model"],device[@"hardwareIdentifier"],device[@"system"],device[@"osBuild"]) size:16 weight:UIFontWeightSemibold color:UIColor.labelColor]];
    [stack addArrangedSubview:[self label:self.scanning ? IGT(@"Detection time: scanning…") : IGF(@"Detection time: %@ · %.2f s",self.report[@"scanTime"] ?: @"—",[self.report[@"scanDuration"] doubleValue]) size:12 weight:UIFontWeightRegular color:UIColor.secondaryLabelColor]];
    [stack addArrangedSubview:[self label:self.scanning ? IGT(@"Checking…") : IGF(@"%@ / 100",score[@"score"] ?: @"—") size:40 weight:UIFontWeightBold color:color]];
    [stack addArrangedSubview:[self label:self.scanning ? IGT(@"Checking") : level size:24 weight:UIFontWeightBold color:color]];
    if (self.report && !self.scanning) {
        [stack addArrangedSubview:[self label:self.report[@"classification"][@"summary"] size:17 weight:UIFontWeightSemibold color:UIColor.labelColor]];
        [stack addArrangedSubview:[self label:IGF(@"%lu checks · %@ hits · %@ unknown · %@ skipped",(unsigned long)[self.report[@"findings"] count],score[@"hitCount"],score[@"unknownCount"],score[@"skippedCount"]) size:13 weight:UIFontWeightRegular color:UIColor.secondaryLabelColor]];
    }
    [stack addArrangedSubview:[self label:self.scanPrivate ? IGT(@"Private APIs: on · extended inspection") : IGT(@"Private APIs: off · standard inspection") size:13 weight:UIFontWeightMedium color:UIColor.secondaryLabelColor]];
    [stack addArrangedSubview:[self label:IGT(@"Perfect: 100 with no unknown enabled checks\nSuspected: 71–99, or unknown checks\nAbnormal environment: 0–70\nTrollStore alone deducts at most 15 points.") size:12 weight:UIFontWeightRegular color:UIColor.secondaryLabelColor]];
    [stack addArrangedSubview:self.filter]; CGFloat width=MAX(240,self.tableView.bounds.size.width);
    CGFloat height=[header systemLayoutSizeFittingSize:CGSizeMake(width,UILayoutFittingCompressedSize.height) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
    header.frame=CGRectMake(0,0,width,height); self.tableView.tableHeaderView=header;
}
- (void)scan {
    if (self.scanning) return; self.scanning=YES; self.scanLanguage=IGCurrentLanguage(); self.scanPrivate=IGPrivateAPIEnabled();
    self.navigationItem.leftBarButtonItem.enabled=NO; for (UIBarButtonItem *b in self.navigationItem.rightBarButtonItems) b.enabled=NO;
    [self updateHeader]; NSMutableDictionary *urls=[NSMutableDictionary new];
    for (NSString *s in @[@"apple-magnifier",@"trollstore",@"cydia",@"sileo",@"zbra",@"undecimus",@"taurine",@"filza"]) urls[s]=@([UIApplication.sharedApplication canOpenURL:[NSURL URLWithString:[s stringByAppendingString:@"://"]]]);
    BOOL privateAPI=self.scanPrivate; NSDictionary *device=self.device;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{ @autoreleasepool {
        NSDictionary *report=[IGDetector scanWithPublicURLs:urls privateAPI:privateAPI device:device];
        dispatch_async(dispatch_get_main_queue(),^{
            self.report=report; self.scanning=NO; self.navigationItem.leftBarButtonItem.enabled=YES; for (UIBarButtonItem *b in self.navigationItem.rightBarButtonItems) b.enabled=YES;
            [self rebuild];
#if TARGET_OS_SIMULATOR
            if ([NSProcessInfo.processInfo.arguments containsObject:@"--smoke-report"]) {
                NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:NULL];
                [data writeToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/smoke-report.json"] atomically:YES];
                if ([NSProcessInfo.processInfo.arguments containsObject:@"--smoke-settings"]) [self settings];
            }
#endif
        });
    }});
}
- (void)rebuild {
    NSMutableDictionary *sections=[NSMutableDictionary new]; NSInteger filter=self.filter.selectedSegmentIndex;
    for (NSDictionary *f in self.report[@"findings"]) {
        if (filter==1 && ![f[@"status"] isEqual:@"hit"]) continue;
        if (filter==2 && ![f[@"status"] isEqual:@"unknown"]) continue;
        if (filter==3 && ![f[@"group"] isEqual:@"identity"]) continue;
        NSString *g=f[@"group"]; if (!sections[g]) sections[g]=[NSMutableArray new]; [sections[g] addObject:f];
    }
    NSMutableArray *order=[NSMutableArray new]; for (NSString *g in @[@"rootful",@"rootless",@"roothide",@"trollstore",@"identity",@"injection",@"runtime",@"visibility",@"observer"]) if (sections[g]) [order addObject:g];
    self.groups=order; self.sections=sections; [self updateHeader]; [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return self.groups.count; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return [self.sections[self.groups[s]] count]; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return GroupTitle(self.groups[s]); }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s { return IGF(@"Group deduction: %@. Displayed weights are combined using group caps; filesystem families share a 45-point cap.",self.report[@"score"][@"groupDeductions"][self.groups[s]] ?: @0); }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    UITableViewCell *cell=[t dequeueReusableCellWithIdentifier:@"finding"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"finding"];
    NSDictionary *f=self.sections[self.groups[p.section]][p.row]; NSString *state=f[@"status"];
    cell.textLabel.text=IGF(@"%@ · %@",IGText(state),f[@"title"]); cell.textLabel.numberOfLines=0; cell.textLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    cell.detailTextLabel.text=IGF(@"Weight: %@ points\n%@",f[@"weight"],f[@"detail"]); cell.detailTextLabel.numberOfLines=0;
    cell.detailTextLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]; cell.detailTextLabel.textColor=UIColor.secondaryLabelColor;
    cell.textLabel.adjustsFontForContentSizeCategory=YES; cell.detailTextLabel.adjustsFontForContentSizeCategory=YES;
    cell.imageView.image=[UIImage systemImageNamed:[state isEqual:@"hit"] ? @"exclamationmark.shield.fill" : ([state isEqual:@"unknown"] ? @"questionmark.circle" : ([state isEqual:@"skipped"] ? @"minus.circle" : @"checkmark.shield"))];
    cell.imageView.tintColor=[state isEqual:@"hit"] ? UIColor.systemOrangeColor : UIColor.secondaryLabelColor;
    cell.selectionStyle=UITableViewCellSelectionStyleNone; return cell;
}
- (void)exportReport:(UIBarButtonItem *)sender {
    if (!self.report || self.scanning) return; NSError *error=nil;
    NSData *data=[NSJSONSerialization dataWithJSONObject:self.report options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:&error];
    NSURL *file=[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:@"IOSGuard-report.json"];
    if (!data || ![data writeToURL:file options:NSDataWritingAtomic error:&error]) {
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:IGT(@"Export failed") message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:IGT(@"OK") style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:alert animated:YES completion:nil]; return;
    }
    UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil]; share.popoverPresentationController.barButtonItem=sender; [self presentViewController:share animated:YES completion:nil];
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; if (fabs(self.tableView.tableHeaderView.bounds.size.width-self.tableView.bounds.size.width)>1) [self updateHeader]; }
@end
@interface IGAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation IGAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    IGRegisterSettings(); self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds]; self.window.tintColor=Accent();
    UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:[[IGController alloc] initWithStyle:UITableViewStyleInsetGrouped]]; nav.navigationBar.prefersLargeTitles=YES;
    self.window.rootViewController=nav; [self.window makeKeyAndVisible]; return YES;
}
@end
int main(int argc,char *argv[]) { @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(IGAppDelegate.class)); } }
