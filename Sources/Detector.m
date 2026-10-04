#import "Detector.h"
#import "Policy.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <sys/mount.h>
#import <unistd.h>
#import <pwd.h>
#import <grp.h>
#import <errno.h>
#if __has_feature(ptrauth_calls)
#import <ptrauth.h>
#endif

static NSDictionary *Finding(NSString *key, NSString *group, NSString *title, NSString *status,
                             NSInteger weight, NSString *detail, BOOL jailbreak) {
    return @{@"id":key, @"group":group, @"title":title, @"status":status,
             @"weight":@(weight), @"detail":detail ?: @"", @"jailbreakEvidence":@(jailbreak)};
}

// Do not treat a denied/failed lookup as a clean result. Even ENOENT may be hidden by a hook.
static NSDictionary *Probe(NSString *path) {
    struct stat info;
    int rc = lstat(path.fileSystemRepresentation, &info);
    int err = rc ? errno : 0;
    NSString *state = rc == 0 ? @"hit" : ((err == ENOENT || err == ENOTDIR) ? @"clear" : @"unknown");
    NSString *detail = rc ? [NSString stringWithFormat:@"%@\nlstat: %s (%d)",path,strerror(err),err]
                         : [NSString stringWithFormat:@"%@\nuid=%u gid=%u mode=%04o%@",path,info.st_uid,info.st_gid,
                            info.st_mode & 07777, S_ISLNK(info.st_mode) ? @" · 符号链接" : @""];
    if (!rc && S_ISLNK(info.st_mode)) {
        char target[PATH_MAX+1];
        ssize_t len = readlink(path.fileSystemRepresentation, target, PATH_MAX);
        if (len >= 0) { target[len] = 0; detail = [detail stringByAppendingFormat:@"\n→ %s",target]; }
    }
    return @{@"status":state, @"detail":detail};
}

// Calling IMP with the exact object-return signature preserves arm64e pointer authentication.
static id Call0(id object, NSString *name) {
    SEL sel = NSSelectorFromString(name);
    if (![object respondsToSelector:sel]) return nil;
    return ((id (*)(id,SEL))objc_msgSend)(object,sel);
}
static id Call1(id object, NSString *name, id argument) {
    SEL sel = NSSelectorFromString(name);
    if (![object respondsToSelector:sel]) return nil;
    return ((id (*)(id,SEL,id))objc_msgSend)(object,sel,argument);
}

static NSString *UserName(uid_t uid) {
    struct passwd *p = getpwuid(uid);
    return p && p->pw_name ? [NSString stringWithUTF8String:p->pw_name] : @"未解析";
}
static NSString *GroupName(gid_t gid) {
    struct group *g = getgrgid(gid);
    return g && g->gr_name ? [NSString stringWithUTF8String:g->gr_name] : @"未解析";
}
static BOOL InjectedPath(NSString *path) {
    NSString *p = path.lowercaseString;
    for (NSString *s in @[@"/var/jb/", @".jbroot", @"mobilesubstrate", @"substitute", @"libhooker",
                         @"ellekit", @"frida", @"libroothide", @"/tweakinject/", @"/tweakloader", @"/shadow.dylib"]) {
        if ([p containsString:s]) return YES;
    }
    return NO;
}

@implementation IGDetector
+ (NSDictionary *)scanWithPublicURLs:(NSDictionary<NSString *,NSNumber *> *)publicURLs {
    NSMutableArray *rows = [NSMutableArray new];
    NSDictionary *paths = @{
        @"rootful":@[@"/Applications/Cydia.app", @"/Applications/Sileo.app", @"/Library/MobileSubstrate/MobileSubstrate.dylib",
                      @"/Library/MobileSubstrate/DynamicLibraries", @"/usr/lib/libsubstitute.dylib", @"/usr/lib/libhooker.dylib",
                      @"/usr/bin/apt", @"/usr/bin/dpkg", @"/bin/bash", @"/etc/apt", @"/var/lib/dpkg/status", @"/.installed_unc0ver", @"/.bootstrapped_electra"],
        @"rootless":@[@"/var/jb", @"/var/jb/usr/bin/dpkg", @"/var/jb/usr/lib/libellekit.dylib", @"/var/jb/Applications/Sileo.app", @"/var/jb/basebin", @"/private/preboot/jb"],
        @"roothide":@[[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@".jbroot"], @"/usr/lib/libroothide.dylib"]
    };
    for (NSString *group in @[@"rootful", @"rootless", @"roothide"]) {
        for (NSString *path in paths[group]) {
            NSDictionary *p = Probe(path);
            // A standalone rootless link or shell can be stale. Bootstrap-specific artifacts are stronger.
            NSInteger weight = ([path isEqual:@"/var/jb"] || [path isEqual:@"/bin/bash"]) ? 20 : 35;
            [rows addObject:Finding([@"path:" stringByAppendingString:path],group,path.lastPathComponent,p[@"status"],weight,p[@"detail"],YES)];
        }
    }

    // Bounded single-level enumeration; no traversal into users' documents.
    NSArray *parents = @[@"/var/containers/Bundle/Application", @"/var/mobile/Containers/Shared/AppGroup", @"/private/preboot"];
    for (NSString *parent in parents) {
        NSError *error = nil;
        NSArray *children = [NSFileManager.defaultManager contentsOfDirectoryAtPath:parent error:&error];
        NSString *group = [parent containsString:@"preboot"] ? @"rootless" : @"roothide";
        if (!children) {
            [rows addObject:Finding([@"enumerate:" stringByAppendingString:parent],group,@"根目录枚举",@"unknown",0,
                                   [NSString stringWithFormat:@"%@\n%@",parent,error.localizedDescription ?: @"读取失败"],NO)];
            continue;
        }
        NSUInteger matches = 0;
        for (NSString *child in children) {
            NSString *path = [parent stringByAppendingPathComponent:child];
            if ([child hasPrefix:@".jbroot-"]) {
                matches++;
                NSDictionary *p = Probe(path);
                // Require bootstrap corroboration, not the folder name alone.
                BOOL bootstrap = [Probe([path stringByAppendingPathComponent:@"usr/bin/dpkg"])[@"status"] isEqual:@"hit"] ||
                                 [Probe([path stringByAppendingPathComponent:@"basebin"])[@"status"] isEqual:@"hit"];
                [rows addObject:Finding([@"jbroot:" stringByAppendingString:path],@"roothide",@"随机 jbroot 目录",@"hit",bootstrap ? 40 : 15,
                                       [p[@"detail"] stringByAppendingFormat:@"\n引导目录佐证：%@",bootstrap ? @"有" : @"未取得；可能是残留"],bootstrap)];
            }
            if (![parent containsString:@"preboot"] && ![parent containsString:@"AppGroup"]) {
                for (NSString *marker in @[@"_TrollStore", @"_TrollStoreLite"]) {
                    NSString *mp = [path stringByAppendingPathComponent:marker];
                    if ([Probe(mp)[@"status"] isEqual:@"hit"]) {
                        [rows addObject:Finding([@"marker:" stringByAppendingString:mp],@"trollstore",@"巨魔安装标记",@"hit",12,mp,NO)];
                    }
                }
                NSString *ts = [path stringByAppendingPathComponent:@"TrollStore.app"];
                if ([Probe(ts)[@"status"] isEqual:@"hit"]) [rows addObject:Finding([@"tsbundle:" stringByAppendingString:ts],@"trollstore",@"巨魔 App 目录",@"hit",12,ts,NO)];
            }
            if ([parent containsString:@"preboot"]) {
                NSDictionary *p = Probe([path stringByAppendingPathComponent:@"jb"]);
                if ([p[@"status"] isEqual:@"hit"]) [rows addObject:Finding([@"preboot:" stringByAppendingString:path],@"rootless",@"Preboot 越狱引导目录",@"hit",35,p[@"detail"],YES)];
            }
        }
        [rows addObject:Finding([@"enumerate:" stringByAppendingString:parent],group,@"根目录枚举",@"clear",0,
                               [NSString stringWithFormat:@"%@\n读取 %lu 个目录项；随机 jbroot 匹配 %lu 个",parent,(unsigned long)children.count,(unsigned long)matches],NO)];
    }

    // LaunchServices lookup identifies the handler instead of trusting canOpenURL alone.
    dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY);
    dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_LAZY);
    id workspace = nil;
    NSArray *apps = nil;
    @try {
        workspace = Call0(NSClassFromString(@"LSApplicationWorkspace"), @"defaultWorkspace");
        apps = Call0(workspace,@"allInstalledApplications");
        if (![apps isKindOfClass:NSArray.class]) apps = Call0(workspace,@"allApplications");
        for (NSString *scheme in @[@"apple-magnifier", @"trollstore"]) {
            id handlers = Call1(workspace,@"applicationsAvailableForHandlingURLScheme:",scheme);
            NSMutableArray *ids = [NSMutableArray new];
            if ([handlers isKindOfClass:NSArray.class]) {
                for (id proxy in handlers) {
                    id identifier = Call0(proxy,@"applicationIdentifier");
                    if ([identifier isKindOfClass:NSString.class]) [ids addObject:identifier];
                }
            }
            NSString *kind = IGURLHandlerKind(ids);
            NSString *state = [kind isEqual:@"trollstore"] ? @"hit" : ([kind isEqual:@"magnifier"] ? @"clear" : @"unknown");
            if ([scheme isEqual:@"trollstore"] && [kind isEqual:@"unknown"] && [handlers isKindOfClass:NSArray.class] && ![publicURLs[scheme] boolValue]) state = @"clear";
            NSString *detail = [NSString stringWithFormat:@"%@://\n公开 API 可打开：%@\n私有 API 处理者：%@\n%@",scheme,
                                [publicURLs[scheme] boolValue] ? @"是" : @"否",ids.count ? [ids componentsJoinedByString:@", "] : @"未取得",
                                [kind isEqual:@"magnifier"] ? @"苹果放大镜，未计为巨魔。" : @"只查询注册信息，不打开 URL，不触发安装。"];
            [rows addObject:Finding([@"url:" stringByAppendingString:scheme],@"trollstore",@"巨魔 URL 处理者",state,12,detail,NO)];
        }
    } @catch (NSException *exception) {
        [rows addObject:Finding(@"ls:exception",@"visibility",@"LaunchServices 私有 API",@"unknown",0,exception.reason,NO)];
    }
    if ([apps isKindOfClass:NSArray.class] && apps.count) {
        NSUInteger relevant = 0;
        @try {
            NSDictionary *jbIDs = @{@"com.saurik.Cydia":@"rootful", @"org.coolstar.SileoStore":@"rootless", @"xyz.willy.Zebra":@"rootless",
                                    @"com.opa334.Dopamine":@"rootless", @"com.roothide.Bootstrap":@"roothide"};
            for (id proxy in apps) {
                NSString *identifier = Call0(proxy,@"applicationIdentifier");
                if (![identifier isKindOfClass:NSString.class]) continue;
                if (IGIsTrollStoreIdentifier(identifier) || jbIDs[identifier]) {
                    relevant++;
                    NSString *g = IGIsTrollStoreIdentifier(identifier) ? @"trollstore" : jbIDs[identifier];
                    id bundleURL = Call0(proxy,@"bundleURL");
                    [rows addObject:Finding([@"app:" stringByAppendingString:identifier],g,@"已注册环境工具",@"hit",IGIsTrollStoreIdentifier(identifier) ? 12 : 15,
                                           [NSString stringWithFormat:@"%@\n%@\n已安装工具不代表越狱正在运行。",identifier,bundleURL ?: @"路径不可用"],NO)];
                }
            }
            [rows addObject:Finding(@"ls:apps",@"visibility",@"应用注册查询",@"clear",0,[NSString stringWithFormat:@"返回 %lu 个注册应用；相关工具 %lu 个。",(unsigned long)apps.count,(unsigned long)relevant],NO)];
        } @catch (NSException *ex) {
            [rows addObject:Finding(@"ls:apps",@"visibility",@"应用注册查询",@"unknown",0,ex.reason,NO)];
        }
    } else [rows addObject:Finding(@"ls:apps",@"visibility",@"应用注册查询",@"unknown",0,@"未取得有效应用列表；不能据此判定无巨魔或无越狱。",NO)];

    NSString *ownContainer = NSBundle.mainBundle.bundlePath.stringByDeletingLastPathComponent;
    for (NSString *marker in @[@"_TrollStore", @"_TrollStoreLite"]) {
        NSString *path = [ownContainer stringByAppendingPathComponent:marker];
        NSDictionary *p = Probe(path);
        [rows addObject:Finding([@"selfmarker:" stringByAppendingString:marker],@"trollstore",@"本 App 巨魔安装来源",p[@"status"],12,p[@"detail"],NO)];
    }

    uid_t uid = getuid(), euid = geteuid();
    gid_t gid = getgid(), egid = getegid();
    NSString *identity = [NSString stringWithFormat:@"UID %u (%@) / EUID %u (%@)\nGID %u (%@) / EGID %u (%@)\n普通 App 基线为 mobile (501)；系统账户本身存在是正常的。",uid,UserName(uid),euid,UserName(euid),gid,GroupName(gid),egid,GroupName(egid)];
    [rows addObject:Finding(@"identity:credentials",@"identity",@"当前进程用户与主组",(uid != 501 || euid != 501 || gid != 501 || egid != 501) ? @"hit" : @"clear",
                           (uid == 0 || euid == 0 || gid == 0 || egid == 0) ? 40 : 20,identity,NO)];
    [rows addObject:Finding(@"identity:effective",@"identity",@"真实身份与有效身份差异",(uid != euid || gid != egid) ? @"hit" : @"clear",20,
                           @"身份不一致可能表示 setuid/setgid 或宿主启动配置；此检测不会尝试提权。",NO)];
    int count = getgroups(0,NULL);
    NSMutableArray *groupData = [NSMutableArray new];
    if (count >= 0 && count <= 1024) {
        gid_t *groups = calloc(MAX(1,count),sizeof(gid_t));
        int actual = groups ? getgroups(count,groups) : -1;
        if (actual < 0) [rows addObject:Finding(@"identity:groups",@"identity",@"附加用户组",@"unknown",0,@"getgroups 读取失败。",NO)];
        else {
            for (int i=0;i<actual;i++) {
                gid_t value = groups[i];
                BOOL privilege = value == 0 || value == 1 || value == 80;
                NSString *name = GroupName(value);
                [groupData addObject:@{@"gid":@(value),@"name":name,@"privileged":@(privilege)}];
                [rows addObject:Finding([NSString stringWithFormat:@"identity:group:%u",value],@"identity",[NSString stringWithFormat:@"附加组 %@ (%u)",name,value],
                                       privilege ? @"hit" : @"clear",value == 80 ? 20 : 40,
                                       privilege ? @"当前 App 加入 wheel/root、daemon 或 admin 权限组，偏离 mobile App 基线。" : @"记录当前进程组成员关系；不以未知组名直接判定越狱。",NO)];
            }
            if (!actual) [rows addObject:Finding(@"identity:groups",@"identity",@"附加用户组",@"clear",0,@"当前进程没有附加组。",NO)];
        }
        free(groups);
    } else [rows addObject:Finding(@"identity:groups",@"identity",@"附加用户组",@"unknown",0,@"组数量读取失败或超出合理范围。",NO)];

    // Entitlements are observation context: this build intentionally requests an unsandboxed reader.
    typedef CFTypeRef (*TaskCreate)(CFAllocatorRef);
    typedef CFTypeRef (*TaskValue)(CFTypeRef,CFStringRef,CFErrorRef *);
    TaskCreate create = (TaskCreate)dlsym(RTLD_DEFAULT,"SecTaskCreateFromSelf");
    TaskValue value = (TaskValue)dlsym(RTLD_DEFAULT,"SecTaskCopyValueForEntitlement");
    if (create && value) {
        CFTypeRef task = create(kCFAllocatorDefault);
        NSMutableDictionary *ents = [NSMutableDictionary new];
        if (task) {
            for (NSString *key in @[@"platform-application", @"com.apple.private.security.no-sandbox", @"com.apple.private.security.no-container", @"com.apple.private.security.container-required", @"get-task-allow"]) {
                CFErrorRef error = NULL;
                CFTypeRef v = value(task,(__bridge CFStringRef)key,&error);
                if (v) ents[key] = CFBridgingRelease(v);
                else if (error) ents[key] = @"读取失败";
                else ents[key] = @"未声明";
                if (error) CFRelease(error);
            }
            CFRelease(task);
        }
        NSData *data = [NSJSONSerialization dataWithJSONObject:ents options:NSJSONWritingPrettyPrinted error:NULL];
        [rows addObject:Finding(@"observer:entitlements",@"observer",@"检测器自身权限",task ? @"info" : @"unknown",0,
                               [NSString stringWithFormat:@"%@\n本构建为巨魔安装设计，主动声明的读取权限计 0 分，避免自测污染。",data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"不可用"],NO)];
    } else [rows addObject:Finding(@"observer:entitlements",@"observer",@"检测器自身权限",@"unknown",0,@"SecTask 私有函数不可用。",NO)];

    NSMutableArray *loaded = [NSMutableArray new];
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i=0;i<imageCount;i++) {
        const char *c = _dyld_get_image_name(i);
        if (!c) continue;
        NSString *path = [NSString stringWithUTF8String:c];
        if (InjectedPath(path)) {
            [loaded addObject:path];
            [rows addObject:Finding([@"image:" stringByAppendingString:path],@"injection",@"加载的注入库",@"hit",35,path,YES)];
        }
    }
    if (!loaded.count) [rows addObject:Finding(@"images:summary",@"injection",@"动态库注入",@"clear",0,[NSString stringWithFormat:@"检查 %u 个已加载镜像；未见已知注入路径。",imageCount],NO)];
    for (NSString *symbol in @[@"lstat",@"stat",@"getuid",@"objc_msgSend"]) {
        void *address = dlsym(RTLD_DEFAULT,symbol.UTF8String);
#if __has_feature(ptrauth_calls)
        address = ptrauth_strip(address,ptrauth_key_function_pointer);
#endif
        Dl_info info = {0};
        BOOL ok = address && dladdr(address,&info) && info.dli_fname;
        NSString *path = ok ? [NSString stringWithUTF8String:info.dli_fname] : @"无法解析";
        [rows addObject:Finding([@"symbol:" stringByAppendingString:symbol],@"injection",[NSString stringWithFormat:@"函数来源 %@",symbol],
                               !ok ? @"unknown" : (InjectedPath(path) ? @"hit" : @"clear"),35,path,ok && InjectedPath(path))];
    }
    const char *dyld = getenv("DYLD_INSERT_LIBRARIES");
    [rows addObject:Finding(@"runtime:dyldenv",@"runtime",@"DYLD 注入环境变量",dyld && strlen(dyld) ? @"hit" : @"clear",20,dyld ? [NSString stringWithUTF8String:dyld] : @"未设置",NO)];
    int mib[4] = {CTL_KERN,KERN_PROC,KERN_PROC_PID,getpid()};
    struct kinfo_proc process = {0}; size_t size = sizeof(process);
    BOOL ok = sysctl(mib,4,&process,&size,NULL,0) == 0 && size == sizeof(process);
    [rows addObject:Finding(@"runtime:debugger",@"runtime",@"调试器附加",!ok ? @"unknown" : ((process.kp_proc.p_flag & P_TRACED) ? @"hit" : @"clear"),15,
                           !ok ? @"无法读取本进程状态。" : @"P_TRACED 为调试上下文证据，不能单独证明越狱。",NO)];
    struct statfs mount;
    BOOL mounted = statfs("/",&mount)==0;
    [rows addObject:Finding(@"runtime:rootfs",@"runtime",@"根文件系统挂载",!mounted ? @"unknown" : ((mount.f_flags & MNT_RDONLY) ? @"clear" : @"hit"),20,
                           !mounted ? @"statfs 读取失败。" : [NSString stringWithFormat:@"文件系统 %s；根挂载%@。只读根不能排除 rootless/roothide。",mount.f_fstypename,(mount.f_flags & MNT_RDONLY) ? @"只读" : @"可写"],NO)];
    // Historical behaviour cannot be inferred from credential snapshots.
    [rows addObject:Finding(@"identity:scope",@"observer",@"用户组异常行为范围",@"info",0,@"显示本进程的 root 身份、有效身份差异和特权附加组，以及路径拥有者。不是系统历史审计，不把 root/mobile 系统账户的正常存在当异常。",NO)];
    // Architecture is reported from our Mach-O slice, not device marketing names.
    const struct mach_header *header = _dyld_get_image_header(0);
    NSString *arch = header && (header->cpusubtype & ~CPU_SUBTYPE_MASK) == CPU_SUBTYPE_ARM64E ? @"arm64e" : @"arm64";
    NSDictionary *score = IGScore(rows);
    return @{@"schemaVersion":@1,@"appVersion":@"1.0.0",@"timestamp":@([[NSDate date] timeIntervalSince1970]),
             @"device":@{@"model":UIDevice.currentDevice.model,@"system":UIDevice.currentDevice.systemVersion,@"binaryArchitecture":arch},
             @"identity":@{@"uid":@(uid),@"euid":@(euid),@"gid":@(gid),@"egid":@(egid),@"supplementaryGroups":groupData},
             @"score":score,@"findings":rows,
             @"limitations":@[@"隐藏层可拦截文件/注册/动态库查询；未命中不保证未越狱。",@"私有 API 在未来系统可能不可用；不可判定项阻止完美评级。",@"巨魔检测不等同越狱；本 App 主动声明的权限不扣分。",@"证据可表示残留，不能仅凭工具安装状态判断当前越狱运行状态。"]};
}
@end
