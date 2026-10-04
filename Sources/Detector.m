#import "Detector.h"
#import "Policy.h"
#import "Localization.h"
#import "Summary.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <sys/mount.h>
#import <unistd.h>
#import <fcntl.h>
#import <pwd.h>
#import <grp.h>
#import <errno.h>
#import <mach/mach.h>
#import <TargetConditionals.h>
#if __has_feature(ptrauth_calls)
#import <ptrauth.h>
#endif
#if defined(__arm64__) && !TARGET_OS_SIMULATOR
extern long IGKernelReadOpen(const char *path);
extern void IGKernelReadClose(int fd);
#endif

static NSDictionary *Finding(NSString *key, NSString *group, NSString *title, NSString *status,
                             NSInteger weight, NSString *detail, BOOL jailbreak, NSString *family) {
    return @{@"id":key,@"group":group,@"title":title,@"status":status,@"weight":@(weight),
             @"detail":detail ?: @"",@"jailbreakEvidence":@(jailbreak),@"familyHint":family ?: @""};
}
static NSString *ErrorState(int error) { return error == 0 ? @"hit" : ((error == ENOENT || error == ENOTDIR) ? @"clear" : @"unknown"); }
static NSDictionary *Channel(NSString *api,int error) { return @{@"api":api,@"status":ErrorState(error),@"errno":@(error)}; }
static NSDictionary *Probe(NSString *path, BOOL extended) {
    const char *p = path.fileSystemRepresentation;
    struct stat st = {0}; NSMutableArray *channels = [NSMutableArray new];
    int e = lstat(p,&st) == 0 ? 0 : errno; [channels addObject:Channel(@"lstat",e)];
    struct stat other; e = stat(p,&other) == 0 ? 0 : errno; [channels addObject:Channel(@"stat",e)];
    e = access(p,F_OK) == 0 ? 0 : errno; [channels addObject:Channel(@"access",e)];
    int fd = open(p,O_RDONLY|O_NONBLOCK|O_CLOEXEC); e = fd >= 0 ? 0 : errno;
    [channels addObject:Channel(@"open-read",e)]; if (fd >= 0) close(fd);
    BOOL fm = [NSFileManager.defaultManager fileExistsAtPath:path];
    [channels addObject:@{@"api":@"FileManager",@"status":fm ? @"hit" : @"unavailable"}];
    if (extended) {
#if defined(__arm64__) && !TARGET_OS_SIMULATOR
        long raw = IGKernelReadOpen(p);
        [channels addObject:Channel(@"kernel-open-read",raw >= 0 ? 0 : (int)-raw)];
        if (raw >= 0) IGKernelReadClose((int)raw);
#endif
    }
    BOOL hit = NO, unknown = NO;
    NSMutableArray *lines = [NSMutableArray arrayWithObject:path];
    for (NSDictionary *c in channels) {
        hit |= [c[@"status"] isEqual:@"hit"]; unknown |= [c[@"status"] isEqual:@"unknown"];
        [lines addObject:[NSString stringWithFormat:@"%@: %@%@",c[@"api"],IGText(c[@"status"]),c[@"errno"] ? [NSString stringWithFormat:@" (errno=%@)",c[@"errno"]] : @""]];
    }
    if ([channels[0][@"status"] isEqual:@"hit"]) {
        [lines addObject:[NSString stringWithFormat:@"uid=%u gid=%u mode=%04o",st.st_uid,st.st_gid,st.st_mode&07777]];
        if (S_ISLNK(st.st_mode)) { char target[PATH_MAX+1]; ssize_t n = readlink(p,target,PATH_MAX); if (n>=0) { target[n]=0; [lines addObject:[NSString stringWithFormat:@"→ %s",target]]; } }
    }
    return @{@"status":hit ? @"hit" : (unknown ? @"unknown" : @"clear"),@"detail":[lines componentsJoinedByString:@"\n"],@"channels":channels};
}
static void AddPath(NSMutableArray *rows,NSString *path,NSString *group,NSInteger weight,BOOL extended) {
    NSDictionary *p = Probe(path,extended);
    NSMutableDictionary *f = [Finding([@"path:" stringByAppendingString:path],group,path.lastPathComponent,p[@"status"],weight,p[@"detail"],![group isEqual:@"trollstore"],group) mutableCopy];
    f[@"channels"] = p[@"channels"]; [rows addObject:f];
    BOOL kernel = NO, missingStat = NO, missingOpen = NO;
    for (NSDictionary *c in p[@"channels"]) {
        kernel |= [c[@"api"] isEqual:@"kernel-open-read"] && [c[@"status"] isEqual:@"hit"];
        missingStat |= [c[@"api"] isEqual:@"lstat"] && [c[@"errno"] intValue] == ENOENT;
        missingOpen |= [c[@"api"] isEqual:@"open-read"] && [c[@"errno"] intValue] == ENOENT;
    }
    if (kernel && missingStat && missingOpen) [rows addObject:Finding([@"inconsistency:" stringByAppendingString:path],@"injection",IGT(@"Conflicting file visibility"),@"hit",10,IGF(@"Kernel read succeeded while libc reported missing: %@. Filtering or a filesystem race is possible.",path),YES,group)];
}
static id Call0(id object,NSString *name) { SEL s = NSSelectorFromString(name); return [object respondsToSelector:s] ? ((id(*)(id,SEL))objc_msgSend)(object,s) : nil; }
static id Call1(id object,NSString *name,id arg) { SEL s = NSSelectorFromString(name); return [object respondsToSelector:s] ? ((id(*)(id,SEL,id))objc_msgSend)(object,s,arg) : nil; }
static NSString *UserName(uid_t uid) { struct passwd *p = getpwuid(uid); return p && p->pw_name ? @(p->pw_name) : IGT(@"Unresolved"); }
static NSString *GroupName(gid_t gid) { struct group *g = getgrgid(gid); return g && g->gr_name ? @(g->gr_name) : IGT(@"Unresolved"); }
static BOOL InjectedPath(NSString *path) {
    for (NSString *s in @[@"/var/jb/",@".jbroot",@"mobilesubstrate",@"substitute",@"libhooker",@"ellekit",@"frida",@"libroothide",@"/tweakinject/",@"tweakloader",@"shadowcore.dylib",@"shadow.dylib",@"choicy.dylib",@"/taurine/"])
        if ([path.lowercaseString containsString:s]) return YES;
    return NO;
}

static void Enumerate(NSMutableArray *rows) {
    for (NSString *parent in @[@"/var/containers/Bundle/Application",@"/var/mobile/Containers/Shared/AppGroup",@"/private/preboot"]) {
        NSError *error; NSArray *children = [NSFileManager.defaultManager contentsOfDirectoryAtPath:parent error:&error];
        if (!children) { [rows addObject:Finding([@"enumerate:" stringByAppendingString:parent],@"visibility",IGT(@"Bootstrap directory enumeration"),@"unknown",0,[NSString stringWithFormat:@"%@\n%@ (%ld)",parent,error.domain,(long)error.code],NO,@"")]; continue; }
        BOOL preboot = [parent containsString:@"preboot"]; NSUInteger n = 0;
        for (NSString *child in children) {
            if (++n > 1024) break;
            NSString *path = [parent stringByAppendingPathComponent:child];
            if ([child hasPrefix:@".jbroot-"]) {
                BOOL bootstrap = [Probe([path stringByAppendingPathComponent:@"usr/bin/dpkg"],YES)[@"status"] isEqual:@"hit"] || [Probe([path stringByAppendingPathComponent:@"basebin"],YES)[@"status"] isEqual:@"hit"];
                AddPath(rows,path,@"roothide",bootstrap ? 40 : 15,YES);
                if (bootstrap) AddPath(rows,[path stringByAppendingPathComponent:@"basebin"],@"roothide",40,YES);
            }
            if (!preboot && ![parent containsString:@"AppGroup"]) {
                for (NSString *marker in @[@"_TrollStore",@"_TrollStoreLite",@"TrollStore.app"]) {
                    NSString *p = [path stringByAppendingPathComponent:marker]; if ([Probe(p,YES)[@"status"] isEqual:@"hit"]) AddPath(rows,p,@"trollstore",12,YES);
                }
            }
            if (preboot) {
                NSArray *sub = [NSFileManager.defaultManager contentsOfDirectoryAtPath:path error:NULL]; NSUInteger k = 0;
                for (NSString *name in sub) {
                    if (++k > 64) break;
                    if ([name isEqual:@"jb"] || [name hasPrefix:@"jb-"] || [name hasPrefix:@"dopamine-"]) {
                        NSString *base = [path stringByAppendingPathComponent:name];
                        if ([name hasPrefix:@"dopamine-"] || [name hasPrefix:@"jb-"]) base = [base stringByAppendingPathComponent:@"procursus"];
                        AddPath(rows,base,@"rootless",20,YES);
                        AddPath(rows,[base stringByAppendingPathComponent:@"usr/bin/dpkg"],@"rootless",35,YES);
                        AddPath(rows,[base stringByAppendingPathComponent:@"basebin"],@"rootless",35,YES);
                    }
                }
            }
        }
        [rows addObject:Finding([@"enumerate:" stringByAppendingString:parent],@"visibility",IGT(@"Bootstrap directory enumeration"),children.count > 1024 ? @"unknown" : @"info",0,IGF(@"%@; inspected up to %lu entries. An empty match list does not prove absence.",parent,(unsigned long)MIN(children.count,1024)),NO,@"")];
    }
}
static void PrivateChecks(NSMutableArray *rows,NSDictionary *urls,NSMutableArray *operations) {
    [operations addObject:@"LaunchServices"];
    dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices",RTLD_LAZY);
    dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices",RTLD_LAZY);
    @try {
        id workspace = Call0(NSClassFromString(@"LSApplicationWorkspace"),@"defaultWorkspace");
        for (NSString *scheme in @[@"apple-magnifier",@"trollstore"]) {
            id handlers = Call1(workspace,@"applicationsAvailableForHandlingURLScheme:",scheme); NSMutableArray *ids = [NSMutableArray new];
            if ([handlers isKindOfClass:NSArray.class]) for (id proxy in handlers) { id identifier = Call0(proxy,@"applicationIdentifier"); if ([identifier isKindOfClass:NSString.class]) [ids addObject:identifier]; }
            NSString *kind = IGURLHandlerKind(ids);
            NSString *state = [kind isEqual:@"trollstore"] ? @"hit" : ([kind isEqual:@"magnifier"] ? @"clear" : @"unknown");
            if ([handlers isKindOfClass:NSArray.class] && !ids.count && ![urls[scheme] boolValue]) state = @"clear";
            [rows addObject:Finding([@"handler:" stringByAppendingString:scheme],@"trollstore",IGT(@"TrollStore URL handler"),state,12,IGF(@"%@://; handlers: %@. Apple Magnifier alone is not TrollStore. URLs are never opened.",scheme,ids.count ? [ids componentsJoinedByString:@", "] : IGT(@"Unavailable")),NO,@"")];
        }
        id apps = Call0(workspace,@"allInstalledApplications"); if (![apps isKindOfClass:NSArray.class]) apps = Call0(workspace,@"allApplications");
        NSDictionary *tools = @{@"com.saurik.cydia":@"rootful",@"org.coolstar.taurine":@"rootful",@"science.xnu.undecimus":@"rootful",@"org.coolstar.sileostore":@"",@"xyz.willy.zebra":@"",@"com.opa334.dopamine":@"",@"com.roothide.bootstrap":@"roothide",@"com.aapl.relaxin":@"roothide",@"com.aapl.relaxin.lite":@"roothide"};
        NSUInteger n = 0, relevant = 0;
        if ([apps isKindOfClass:NSArray.class]) for (id proxy in apps) {
            if (++n > 2048) break; id identifier = Call0(proxy,@"applicationIdentifier"); if (![identifier isKindOfClass:NSString.class]) continue;
            BOOL ts = IGIsTrollStoreIdentifier(identifier); NSString *hint = tools[[identifier lowercaseString]];
            NSString *store = IGStoreForIdentifier(identifier);
            if (!ts && hint == nil && !store.length) continue; relevant++;
            id url = Call0(proxy,@"bundleURL"); NSString *path = [url isKindOfClass:NSURL.class] ? [url path] : @"";
            NSString *pathHint = IGFamilyForPath(path); if (pathHint.length) hint = pathHint;
            [rows addObject:Finding([@"app:" stringByAppendingString:identifier],ts ? @"trollstore" : @"runtime",IGT(@"Registered environment tool"),@"hit",ts ? 12 : 15,IGF(@"%@\n%@\nAn installed tool does not prove an active jailbreak. Dopamine variants require path evidence.",identifier,path),NO,hint)];
            if (!ts && path.length) AddPath(rows,[path stringByAppendingPathComponent:@".jbroot"],@"roothide",35,YES);
        }
        [rows addObject:Finding(@"ls:apps",@"visibility",IGT(@"Application registry"),![apps isKindOfClass:NSArray.class] || ![apps count] || [apps count]>2048 ? @"unknown" : @"info",0,IGF(@"Relevant registered tools: %lu. Results may be restricted or filtered.",(unsigned long)relevant),NO,@"")];
    } @catch (NSException *ex) { [rows addObject:Finding(@"ls:exception",@"visibility",IGT(@"LaunchServices private API"),@"unknown",0,ex.name,NO,@"")]; }
    [operations addObject:@"SecTask entitlements"];
    typedef CFTypeRef (*TaskCreate)(CFAllocatorRef); typedef CFTypeRef (*TaskValue)(CFTypeRef,CFStringRef,CFErrorRef *);
    TaskCreate create = (TaskCreate)dlsym(RTLD_DEFAULT,"SecTaskCreateFromSelf"); TaskValue value = (TaskValue)dlsym(RTLD_DEFAULT,"SecTaskCopyValueForEntitlement");
    NSMutableArray *ents = [NSMutableArray new]; CFTypeRef task = create && value ? create(kCFAllocatorDefault) : NULL;
    if (task) {
        for (NSString *key in @[@"platform-application",@"com.apple.private.security.no-sandbox",@"com.apple.private.security.no-container",@"get-task-allow"]) {
            CFErrorRef err = NULL; CFTypeRef v = value(task,(__bridge CFStringRef)key,&err);
            [ents addObject:[NSString stringWithFormat:@"%@: %@",key,v ? CFBridgingRelease(v) : (err ? IGT(@"Unavailable") : IGT(@"Not declared"))]]; if (err) CFRelease(err);
        } CFRelease(task);
    }
    [rows addObject:Finding(@"observer:entitlements",@"observer",IGT(@"Detector entitlements"),task ? @"info" : @"unknown",0,[[ents componentsJoinedByString:@"\n"] stringByAppendingFormat:@"\n%@",IGT(@"The switch grants no privileges. Runtime access depends on installer configuration.")],NO,@"")];
    [operations addObject:@"sandbox_check"];
    typedef int (*SandboxCheck)(pid_t,const char *,int,...); SandboxCheck check = (SandboxCheck)dlsym(RTLD_DEFAULT,"sandbox_check");
    if (check) { int rc = check(getpid(),"file-read-data",1,"/var/containers/Bundle/Application"); [rows addObject:Finding(@"observer:sandbox",@"observer",IGT(@"Sandbox read policy"),rc<0 ? @"unknown" : @"info",0,IGF(@"sandbox_check result: %d. Permission does not imply that a jailbreak artifact exists.",rc),NO,@"")]; }
    else [rows addObject:Finding(@"observer:sandbox",@"observer",IGT(@"Sandbox read policy"),@"unknown",0,IGT(@"Unavailable"),NO,@"")];
    [operations addObject:@"KERN_PROC_ALL"];
    int mib[] = {CTL_KERN,KERN_PROC,KERN_PROC_ALL,0}; size_t size = 0;
    BOOL procOK = sysctl(mib,4,NULL,&size,NULL,0)==0 && size>0 && size <= 8*1024*1024;
    struct kinfo_proc *procs = procOK ? calloc(1,size) : NULL;
    procOK = procs && sysctl(mib,4,procs,&size,NULL,0)==0;
    typedef int (*ProcPath)(int,void *,uint32_t); ProcPath procPath = (ProcPath)dlsym(RTLD_DEFAULT,"proc_pidpath");
    if (procOK) for (NSUInteger i=0;i<MIN(size/sizeof(*procs),4096);i++) {
        NSString *name = [NSString stringWithUTF8String:procs[i].kp_proc.p_comm];
        if (![@[@"jailbreakd",@"substrated",@"substituted",@"amfidebilitate",@"tweakloader"] containsObject:name]) continue;
        char path[4096] = {0}; if (procPath) procPath(procs[i].kp_proc.p_pid,path,sizeof(path)); NSString *p = [NSString stringWithUTF8String:path];
        NSString *hint = [p hasPrefix:@"/taurine/"] ? @"rootful" : IGFamilyForPath(p);
        [rows addObject:Finding([NSString stringWithFormat:@"process:%d",procs[i].kp_proc.p_pid],@"injection",IGT(@"Jailbreak daemon"),@"hit",35,[NSString stringWithFormat:@"%@ (%d)\n%@",name,procs[i].kp_proc.p_pid,p],YES,hint)];
    }
    free(procs);
    [rows addObject:Finding(@"process:visibility",@"visibility",IGT(@"Process enumeration"),procOK ? @"info" : @"unknown",0,IGT(@"Only known jailbreak daemon matches are retained. Process lists may be filtered."),NO,@"")];
    [operations addObject:@"bootstrap_look_up"];
    typedef kern_return_t (*BootstrapLookup)(mach_port_t,const char *,mach_port_t *);
    BootstrapLookup lookup = (BootstrapLookup)dlsym(RTLD_DEFAULT,"bootstrap_look_up");
    mach_port_t bootstrap = MACH_PORT_NULL;
    kern_return_t bootstrapResult = task_get_bootstrap_port(mach_task_self(),&bootstrap);
    for (NSString *service in @[@"org.coolstar.jailbreakd",@"com.opa334.jailbreakd"]) {
        mach_port_t port = MACH_PORT_NULL; kern_return_t rc = lookup && bootstrapResult==KERN_SUCCESS ? lookup(bootstrap,service.UTF8String,&port) : KERN_FAILURE;
        if (port != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(),port);
        [rows addObject:Finding([@"service:" stringByAppendingString:service],@"injection",IGT(@"Jailbreak service lookup"),rc==KERN_SUCCESS ? @"hit" : @"unknown",35,[NSString stringWithFormat:@"%@ (Mach=%d)",service,rc],YES,[service hasPrefix:@"org.coolstar"] ? @"rootful" : @"")];
    }
    if (bootstrap != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(),bootstrap);
    [operations addObject:@"Bounded bootstrap enumeration"]; Enumerate(rows);
#if defined(__arm64__) && !TARGET_OS_SIMULATOR
    [operations addObject:@"Read-only ARM64 kernel probes"];
#endif
}

@implementation IGDetector
+ (NSDictionary *)scanWithPublicURLs:(NSDictionary<NSString *,NSNumber *> *)publicURLs privateAPI:(BOOL)enabled device:(NSDictionary *)device {
    NSDate *start = NSDate.date; NSMutableArray *rows = [NSMutableArray new], *operations = [NSMutableArray new];
    NSDictionary *paths = @{
        @"rootful":@[@"/Applications/Cydia.app",@"/Applications/Sileo.app",@"/Applications/Taurine.app",@"/Applications/unc0ver.app",@"/Library/MobileSubstrate/MobileSubstrate.dylib",@"/Library/MobileSubstrate/DynamicLibraries",@"/usr/lib/libhooker.dylib",@"/usr/lib/TweakInject",@"/usr/lib/libsubstitute.dylib",@"/usr/lib/substitute-loader.dylib",@"/usr/lib/substitute-inserter.dylib",@"/usr/libexec/substrated",@"/usr/libexec/substituted",@"/taurine",@"/taurine/jailbreakd",@"/taurine/amfidebilitate",@"/taurine/pspawn_payload.dylib",@"/usr/lib/pspawn_payload-stg2.dylib",@"/var/run/jailbreakd.pid",@"/usr/bin/apt",@"/usr/bin/dpkg",@"/bin/bash",@"/etc/apt",@"/var/lib/dpkg/status",@"/var/lib/cydia",@"/var/mobile/Library/Cydia",@"/var/mobile/Library/Preferences/com.saurik.Cydia.plist",@"/.installed_unc0ver",@"/.bootstrapped_electra",@"/.procursus_strapped",@"/.cydia_no_stash"],
        @"rootless":@[@"/var/jb",@"/private/var/jb/usr/bin/dpkg",@"/var/jb/usr/bin/dpkg",@"/var/jb/usr/lib/libellekit.dylib",@"/var/jb/usr/lib/ellekit",@"/var/jb/Applications/Sileo.app",@"/var/jb/basebin",@"/var/jb/basebin/jailbreakd",@"/var/jb/basebin/libjailbreak.dylib"],
        @"roothide":@[[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@".jbroot"],@"/usr/lib/.jbroot",@"/usr/lib/libroothide.dylib"],
        @"trollstore":@[@"/Applications/TrollStore.app",@"/Applications/TrollStoreLite.app"]};
    for (NSString *g in @[@"rootful",@"rootless",@"roothide",@"trollstore"]) for (NSString *p in paths[g]) AddPath(rows,p,g,[g isEqual:@"trollstore"] ? 12 : (([p isEqual:@"/var/jb"] || [p isEqual:@"/bin/bash"] || [p isEqual:@"/taurine"]) ? 20 : 35),enabled);
    for (NSString *prefix in @[@"/Applications",@"/var/jb/Applications"]) for (NSString *app in @[@"Cydia.app",@"Sileo.app",@"Sileo-Nightly.app",@"Zebra.app"]) {
        NSString *p=[prefix stringByAppendingPathComponent:app]; NSString *g=[prefix hasPrefix:@"/var/jb"] ? @"rootless" : @"rootful";
        if (![paths[g] containsObject:p]) AddPath(rows,p,g,35,enabled);
    }
    // ElleKit ships both rootful/rootless packages and compatibility symlinks.
    for (NSString *prefix in @[@"",@"/var/jb"]) for (NSString *artifact in @[@"/usr/lib/libellekit.dylib",@"/usr/lib/ellekit/libinjector.dylib",@"/usr/lib/ellekit/pspawn.dylib",@"/usr/libexec/ellekit/loader",@"/usr/lib/TweakInject.dylib",@"/usr/lib/TweakLoader.dylib",@"/usr/lib/libblackjack.dylib",@"/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate"]) {
        NSString *p=[prefix stringByAppendingString:artifact];
        if (![paths[prefix.length ? @"rootless" : @"rootful"] containsObject:p]) AddPath(rows,p,prefix.length ? @"rootless" : @"rootful",35,enabled);
    }
    NSString *container = NSBundle.mainBundle.bundlePath.stringByDeletingLastPathComponent;
    for (NSString *m in @[@"_TrollStore",@"_TrollStoreLite"]) AddPath(rows,[container stringByAppendingPathComponent:m],@"trollstore",12,enabled);
    for (NSString *s in @[@"cydia",@"sileo",@"zbra",@"undecimus",@"taurine",@"filza",@"trollstore",@"apple-magnifier"]) {
        BOOL ts = [s isEqual:@"trollstore"], magnifier = [s isEqual:@"apple-magnifier"];
        NSString *hint = [@[@"cydia",@"undecimus",@"taurine"] containsObject:s] ? @"rootful" : @"";
        [rows addObject:Finding([@"publicurl:" stringByAppendingString:s],ts ? @"trollstore" : @"runtime",IGT(@"Public URL availability"),[publicURLs[s] boolValue] ? (magnifier ? @"info" : @"hit") : @"clear",magnifier ? 0 : (ts ? 12 : 10),IGF(@"%@://; availability alone cannot verify the handler or active jailbreak.",s),NO,hint)];
    }
    uid_t uid = getuid(), euid = geteuid(); gid_t gid = getgid(), egid = getegid();
    NSString *identity = IGF(@"UID %u (%@) / EUID %u (%@)\nGID %u (%@) / EGID %u (%@)\nOrdinary apps use mobile (501). Existing system accounts alone are normal.",uid,UserName(uid),euid,UserName(euid),gid,GroupName(gid),egid,GroupName(egid));
    [rows addObject:Finding(@"identity:credentials",@"identity",IGT(@"Process user and primary group"),uid!=501 || euid!=501 || gid!=501 || egid!=501 ? @"hit" : @"clear",uid==0 || euid==0 || gid==0 || egid==0 ? 40 : 20,identity,NO,@"")];
    [rows addObject:Finding(@"identity:effective",@"identity",IGT(@"Real and effective identity mismatch"),uid!=euid || gid!=egid ? @"hit" : @"clear",20,IGT(@"A mismatch may indicate setuid/setgid or a launcher configuration. No privilege escalation is attempted."),NO,@"")];
    NSMutableArray *groupData = [NSMutableArray new]; int count = getgroups(0,NULL);
    gid_t *groups = count>=0 && count<=1024 ? calloc(MAX(1,count),sizeof(gid_t)) : NULL;
    int actual = groups ? getgroups(count,groups) : -1;
    if (actual<0) [rows addObject:Finding(@"identity:groups",@"identity",IGT(@"Supplementary groups"),@"unknown",0,IGT(@"Unable to read group membership."),NO,@"")];
    else {
        for (int i=0;i<actual;i++) {
            gid_t v = groups[i]; BOOL privileged = v==0 || v==1 || v==80; NSString *name = GroupName(v);
            [groupData addObject:@{@"gid":@(v),@"name":name,@"privileged":@(privileged)}];
            [rows addObject:Finding([NSString stringWithFormat:@"identity:group:%u",v],@"identity",IGF(@"Supplementary group %@ (%u)",name,v),privileged ? @"hit" : @"clear",v==80 ? 20 : 40,privileged ? IGT(@"Membership in wheel/root, daemon or admin deviates from the ordinary app baseline.") : IGT(@"Unknown group names alone are not jailbreak evidence."),NO,@"")];
        }
        if (!actual) [rows addObject:Finding(@"identity:groups",@"identity",IGT(@"Supplementary groups"),@"clear",0,IGT(@"No supplementary groups."),NO,@"")];
    } free(groups);
    uint32_t images = _dyld_image_count(); NSUInteger matches = 0;
    for (uint32_t i=0;i<images;i++) {
        const char *c = _dyld_get_image_name(i); if (!c) continue; NSString *p = @(c);
        if (InjectedPath(p)) { matches++; [rows addObject:Finding([@"image:" stringByAppendingString:p],@"injection",IGT(@"Loaded injection library"),@"hit",35,p,YES,IGFamilyForPath(p))]; }
    }
    if (!matches) [rows addObject:Finding(@"images:summary",@"injection",IGT(@"Dynamic library injection"),@"clear",0,IGF(@"Inspected %u loaded images. No known injected path was visible.",images),NO,@"")];
    for (NSString *s in @[@"lstat",@"stat",@"open",@"access",@"getuid",@"objc_msgSend",@"_dyld_get_image_name"]) {
        void *address = dlsym(RTLD_DEFAULT,s.UTF8String);
#if __has_feature(ptrauth_calls)
        address = ptrauth_strip(address,ptrauth_key_function_pointer);
#endif
        Dl_info info = {0}; BOOL ok = address && dladdr(address,&info) && info.dli_fname;
        NSString *p = ok ? @(info.dli_fname) : IGT(@"Unavailable"); BOOL injected = ok && InjectedPath(p);
        [rows addObject:Finding([@"symbol:" stringByAppendingString:s],@"injection",IGF(@"Function origin %@",s),!ok ? @"unknown" : (injected ? @"hit" : @"clear"),35,p,injected,IGFamilyForPath(p))];
    }
    const char *env = getenv("DYLD_INSERT_LIBRARIES");
    [rows addObject:Finding(@"runtime:dyldenv",@"runtime",IGT(@"DYLD injection variable"),env && strlen(env) ? @"hit" : @"clear",20,env ? @(env) : IGT(@"Not set"),NO,@"")];
    struct statfs fs = {0}; BOOL fsOK = statfs("/",&fs)==0;
    [rows addObject:Finding(@"runtime:rootfs",@"runtime",IGT(@"Root filesystem mount"),!fsOK ? @"unknown" : (!(fs.f_flags&MNT_RDONLY) ? @"hit" : @"clear"),20,fsOK ? [NSString stringWithFormat:@"%s; flags=0x%x",fs.f_fstypename,fs.f_flags] : IGT(@"Unavailable"),NO,@"")];
    if (enabled) PrivateChecks(rows,publicURLs,operations);
    else [rows addObject:Finding(@"private:disabled",@"observer",IGT(@"Private API checks"),@"skipped",0,IGT(@"Disabled by default. Enable in Settings for extended checks. Skipped checks are not recorded as clean."),NO,@"")];
    [rows addObject:Finding(@"observer:scope",@"observer",IGT(@"Visibility limits"),@"info",0,IGT(@"Shadow and Choicy can filter paths, URLs, processes and injection. Kernel probes can also be intercepted. Missing traces do not prove a stock system."),NO,@"")];
#if TARGET_OS_SIMULATOR
    for (NSUInteger i=0;i<rows.count;i++) { NSMutableDictionary *f = [rows[i] mutableCopy]; if (![f[@"group"] isEqual:@"observer"]) { f[@"status"]=@"unknown"; f[@"weight"]=@0; f[@"jailbreakEvidence"]=@NO; f[@"detail"]=IGT(@"Simulator observations cannot determine a physical device environment."); } rows[i]=f; }
#endif
    NSDate *finish = NSDate.date; NSDateFormatter *format = [NSDateFormatter new]; format.locale = [NSLocale localeWithLocaleIdentifier:IGCurrentLanguage()]; format.dateFormat=@"yyyy-MM-dd HH:mm:ss ZZZZZ";
    NSMutableDictionary *d = [device mutableCopy];
#if defined(__arm64e__)
    d[@"binaryArchitecture"]=@"arm64e";
#elif defined(__arm64__)
    d[@"binaryArchitecture"]=@"arm64";
#else
    d[@"binaryArchitecture"]=@"x86_64";
#endif
    NSDictionary *classification=IGClassification(rows);
    return @{@"schema":@2,@"appVersion":@"1.2.0",@"appName":@"JailPrism",@"bundleIdentifier":NSBundle.mainBundle.bundleIdentifier ?: @"",@"language":IGCurrentLanguage(),@"timestamp":@([finish timeIntervalSince1970]),@"scanTime":[format stringFromDate:finish],@"scanDuration":@([finish timeIntervalSinceDate:start]),@"device":d,
             @"scanConfiguration":@{@"privateAPIEnabled":@(enabled),@"mode":enabled ? @"extended" : @"standard",@"privateOperationsAttempted":operations},
             @"identity":@{@"uid":@(uid),@"euid":@(euid),@"gid":@(gid),@"egid":@(egid),@"groups":groupData},@"score":IGScore(rows),@"classification":classification,@"simpleSummary":IGSummaryRows(rows,classification),@"findings":rows};
}
@end
