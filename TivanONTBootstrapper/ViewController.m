#import "ViewController.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#import <sys/socket.h>
#import <sys/time.h>
#import <unistd.h>

#define ONT_HOST_DEFAULT @"192.168.100.1"
#define WEB_USER @"telecomadmin"
#define WEB_PASS @"admintelecom"
#define PPP_USER @"yaraacs"
#define PPP_PASS @"yaraacs"
#define VLAN_ID @"800"
#define ACS_URL @"https://yaraacs.tci.ir"
#define ACS_USER @"yaraacs"
#define ACS_PASS @"yaraacs"
#define ACS_INTERVAL @"30"

typedef NS_ENUM(NSInteger, ProvisionStage) {
    ProvisionStageIdle = 0,
    ProvisionStageLogin,
    ProvisionStageWAN1,
    ProvisionStageWAN2,
    ProvisionStageACS,
    ProvisionStageTelnetEnable,
    ProvisionStageDone
};

@interface ViewController ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *stageLabel;
@property (nonatomic, strong) UILabel *hostLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, strong) UIButton *exportButton;
@property (nonatomic, strong) UISwitch *cleanupSwitch;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) NSString *ontHost;
@property (nonatomic, assign) ProvisionStage webStage;
@property (nonatomic, assign) BOOL running;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.ontHost = ONT_HOST_DEFAULT;
    [self buildUI];
    [self setupWebView];
    [self appendLog:@"Tivan ONT Bootstrapper آماده است." level:@"INFO"];
    [self appendLog:@"مدل این نسخه: ONT Direct؛ بخش Switch Mode حذف شده است." level:@"INFO"];
}

- (void)buildUI {
    UIImageView *logo = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"TivanLogo"]];
    logo.translatesAutoresizingMaskIntoConstraints = NO;
    logo.contentMode = UIViewContentModeScaleAspectFit;
    logo.layer.cornerRadius = 18;
    logo.clipsToBounds = YES;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"Tivan ONT Bootstrapper";
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.font = [UIFont systemFontOfSize:25 weight:UIFontWeightBold];
    self.titleLabel.numberOfLines = 0;

    self.stageLabel = [[UILabel alloc] init];
    self.stageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.stageLabel.text = @"آماده شروع";
    self.stageLabel.textAlignment = NSTextAlignmentCenter;
    self.stageLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    self.stageLabel.textColor = [UIColor secondaryLabelColor];

    self.hostLabel = [[UILabel alloc] init];
    self.hostLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.hostLabel.text = @"ONT: در انتظار شناسایی";
    self.hostLabel.textAlignment = NSTextAlignmentCenter;
    self.hostLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.hostLabel.textColor = [UIColor tertiaryLabelColor];

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressView.progress = 0.0;

    UILabel *cleanupLabel = [[UILabel alloc] init];
    cleanupLabel.text = @"پاک‌سازی WAN/ACS تکراری قبل از افزودن";
    cleanupLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    cleanupLabel.numberOfLines = 0;

    self.cleanupSwitch = [[UISwitch alloc] init];
    self.cleanupSwitch.on = YES;

    UIStackView *cleanupRow = [[UIStackView alloc] initWithArrangedSubviews:@[self.cleanupSwitch, cleanupLabel]];
    cleanupRow.axis = UILayoutConstraintAxisHorizontal;
    cleanupRow.alignment = UIStackViewAlignmentCenter;
    cleanupRow.spacing = 10;
    cleanupRow.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;

    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.startButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.startButton setTitle:@"شروع Provisioning" forState:UIControlStateNormal];
    self.startButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    self.startButton.backgroundColor = [UIColor systemBlueColor];
    [self.startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.startButton.layer.cornerRadius = 16;
    self.startButton.contentEdgeInsets = UIEdgeInsetsMake(14, 18, 14, 18);
    [self.startButton addTarget:self action:@selector(startTapped) forControlEvents:UIControlEventTouchUpInside];

    self.exportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.exportButton setTitle:@"اشتراک‌گذاری لاگ" forState:UIControlStateNormal];
    self.exportButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [self.exportButton addTarget:self action:@selector(exportLogs) forControlEvents:UIControlEventTouchUpInside];

    self.logView = [[UITextView alloc] init];
    self.logView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logView.editable = NO;
    self.logView.selectable = YES;
    self.logView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.logView.textColor = [UIColor labelColor];
    self.logView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.logView.layer.cornerRadius = 16;
    self.logView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);

    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[logo, self.titleLabel, self.stageLabel, self.hostLabel, self.progressView, cleanupRow, self.startButton, self.exportButton]];
    header.axis = UILayoutConstraintAxisVertical;
    header.alignment = UIStackViewAlignmentFill;
    header.spacing = 12;
    header.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:header];
    [self.view addSubview:self.logView];

    [NSLayoutConstraint activateConstraints:@[
        [logo.heightAnchor constraintEqualToConstant:86],
        [logo.widthAnchor constraintEqualToConstant:86],
        [logo.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],
        [header.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:18],
        [header.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:20],
        [header.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-20],
        [self.startButton.heightAnchor constraintGreaterThanOrEqualToConstant:54],
        [self.logView.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:16],
        [self.logView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.logView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.logView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16]
    ]];
}

- (void)setupWebView {
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.preferences.javaScriptEnabled = YES;
    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 1, 1) configuration:config];
    self.webView.navigationDelegate = self;
    self.webView.hidden = YES;
    [self.view addSubview:self.webView];
}

- (void)startTapped {
    if (self.running) { return; }
    self.running = YES;
    self.logView.text = @"";
    [self updateStage:@"شروع عملیات" progress:0.02];
    self.startButton.enabled = NO;
    self.startButton.alpha = 0.55;
    [self appendLog:@"شروع شناسایی ONT..." level:@"RUN"];
    [self discoverONT];
}

- (void)finishRun:(BOOL)success message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.running = NO;
        self.startButton.enabled = YES;
        self.startButton.alpha = 1.0;
        [self.startButton setTitle:@"اجرای دوباره" forState:UIControlStateNormal];
        [self updateStage:success ? @"پایان موفق" : @"نیاز به بررسی" progress:success ? 1.0 : self.progressView.progress];
        [self appendLog:message level:success ? @"OK" : @"ERR"];
    });
}

- (NSArray<NSString *> *)candidateHosts {
    NSMutableOrderedSet<NSString *> *set = [NSMutableOrderedSet orderedSet];
    [set addObject:ONT_HOST_DEFAULT];
    [set addObject:@"192.168.1.1"];
    [set addObject:@"192.168.0.1"];
    struct ifaddrs *ifaddr = NULL;
    if (getifaddrs(&ifaddr) == 0) {
        for (struct ifaddrs *ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
            if (!ifa->ifa_addr || ifa->ifa_addr->sa_family != AF_INET) { continue; }
            if (!(ifa->ifa_flags & IFF_UP) || (ifa->ifa_flags & IFF_LOOPBACK)) { continue; }
            char ip[INET_ADDRSTRLEN];
            struct sockaddr_in *addr = (struct sockaddr_in *)ifa->ifa_addr;
            inet_ntop(AF_INET, &(addr->sin_addr), ip, sizeof(ip));
            NSString *ipString = [NSString stringWithUTF8String:ip];
            NSArray *parts = [ipString componentsSeparatedByString:@"."];
            if (parts.count == 4) {
                NSString *gateway = [NSString stringWithFormat:@"%@.%@.%@.1", parts[0], parts[1], parts[2]];
                [set addObject:gateway];
            }
        }
        freeifaddrs(ifaddr);
    }
    return set.array;
}

- (void)discoverONT {
    NSArray<NSString *> *hosts = [self candidateHosts];
    [self tryProbeHosts:hosts index:0];
}

- (void)tryProbeHosts:(NSArray<NSString *> *)hosts index:(NSUInteger)index {
    if (index >= hosts.count) {
        [self finishRun:NO message:@"ONT پیدا نشد. آیفون باید به WiFi/LAN خود ONT وصل باشد و Local Network Allow شده باشد."];
        return;
    }
    NSString *host = hosts[index];
    [self updateStage:[NSString stringWithFormat:@"تست %@", host] progress:0.08 + (float)index/(float)MAX(hosts.count, 1) * 0.12];
    [self appendLog:[NSString stringWithFormat:@"Probe: http://%@/", host] level:@"NET"];
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    cfg.timeoutIntervalForRequest = 2.8;
    cfg.timeoutIntervalForResource = 3.0;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/", host]];
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        NSString *body = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
        BOOL huawei = [body.lowercaseString containsString:@"huawei"] || [body.lowercaseString containsString:@"ont"] || [body.lowercaseString containsString:@"telecomadmin"];
        BOOL reachable = (http.statusCode > 0 && http.statusCode < 600) || data.length > 0;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (reachable || huawei) {
                self.ontHost = host;
                self.hostLabel.text = [NSString stringWithFormat:@"ONT: %@", host];
                [self appendLog:[NSString stringWithFormat:@"ONT/Web reachable: %@ status=%ld", host, (long)http.statusCode] level:@"OK"];
                [self beginWebProvisioning];
            } else {
                [self appendLog:[NSString stringWithFormat:@"No response from %@ (%@)", host, error.localizedDescription ?: @"timeout"] level:@"NET"];
                [self tryProbeHosts:hosts index:index+1];
            }
        });
    }];
    [task resume];
}

- (void)beginWebProvisioning {
    [self updateStage:@"Login به ONT" progress:0.22];
    self.webStage = ProvisionStageLogin;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/", self.ontHost]];
    [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    switch (self.webStage) {
        case ProvisionStageLogin:
            [self runLoginScript];
            break;
        case ProvisionStageWAN1:
            [self runWANScriptPass:1];
            break;
        case ProvisionStageWAN2:
            [self runWANScriptPass:2];
            break;
        case ProvisionStageACS:
            [self runACSScript];
            break;
        case ProvisionStageTelnetEnable:
            [self runTelnetEnableScript];
            break;
        default:
            break;
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self appendLog:[NSString stringWithFormat:@"Web navigation failed: %@", error.localizedDescription] level:@"WEB"];
}

- (NSString *)scriptNamed:(NSString *)name replacements:(NSDictionary<NSString *, NSString *> *)replacements {
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"js" inDirectory:@"Scripts"];
    NSString *s = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] ?: @"";
    for (NSString *k in replacements) {
        s = [s stringByReplacingOccurrencesOfString:k withString:replacements[k]];
    }
    return s;
}

- (void)evaluateScript:(NSString *)script label:(NSString *)label completion:(void (^)(NSString *result, NSError *error))completion {
    [self.webView evaluateJavaScript:script completionHandler:^(id value, NSError *error) {
        NSString *text = nil;
        if ([value isKindOfClass:NSString.class]) { text = value; }
        else if (value) { text = [value description]; }
        if (error) { [self appendLog:[NSString stringWithFormat:@"%@ error: %@", label, error.localizedDescription] level:@"JS"]; }
        else { [self appendLog:[NSString stringWithFormat:@"%@ result: %@", label, text ?: @"<nil>"] level:@"JS"]; }
        if (completion) { completion(text, error); }
    }];
}

- (void)runLoginScript {
    [self updateStage:@"ورود telecomadmin" progress:0.28];
    NSString *script = [self scriptNamed:@"login" replacements:@{@"__WEB_USER__":WEB_USER, @"__WEB_PASS__":WEB_PASS}];
    [self evaluateScript:script label:@"login" completion:^(NSString *result, NSError *error) {
        [self delayed:3.0 block:^{
            [self updateStage:@"تنظیم WAN VLAN 800" progress:0.38];
            self.webStage = ProvisionStageWAN1;
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/html/bbsp/wan/wan.asp", self.ontHost]];
            [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
        }];
    }];
}

- (void)runWANScriptPass:(NSInteger)pass {
    [self updateStage:pass == 1 ? @"WAN: آماده‌سازی فرم" : @"WAN: ثبت نهایی" progress:pass == 1 ? 0.48 : 0.58];
    NSString *cleanup = self.cleanupSwitch.isOn ? @"true" : @"false";
    NSString *script = [self scriptNamed:@"wan" replacements:@{
        @"__PPPOE_USER__":PPP_USER,
        @"__PPPOE_PASS__":PPP_PASS,
        @"__VLAN__":VLAN_ID,
        @"__CLEANUP__":cleanup
    }];
    [self evaluateScript:script label:[NSString stringWithFormat:@"wan-pass-%ld", (long)pass] completion:^(NSString *result, NSError *error) {
        [self delayed:2.0 block:^{
            if (pass == 1) {
                self.webStage = ProvisionStageWAN2;
                NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/html/bbsp/wan/wan.asp", self.ontHost]];
                [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
            } else {
                [self updateStage:@"تنظیم ACS/TR-069" progress:0.68];
                self.webStage = ProvisionStageACS;
                NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/html/ssmp/tr069/tr069.asp", self.ontHost]];
                [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
            }
        }];
    }];
}

- (void)runACSScript {
    NSString *script = [self scriptNamed:@"acs" replacements:@{
        @"__ACS_URL__":ACS_URL,
        @"__ACS_USER__":ACS_USER,
        @"__ACS_PASS__":ACS_PASS,
        @"__ACS_INTERVAL__":ACS_INTERVAL
    }];
    [self evaluateScript:script label:@"acs" completion:^(NSString *result, NSError *error) {
        [self delayed:2.0 block:^{
            [self updateStage:@"فعال‌سازی Telnet" progress:0.78];
            self.webStage = ProvisionStageTelnetEnable;
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/html/ssmp/servicecontrol/servicecontrol.asp", self.ontHost]];
            [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
        }];
    }];
}

- (void)runTelnetEnableScript {
    NSString *script = [self scriptNamed:@"telnet_enable" replacements:@{}];
    [self evaluateScript:script label:@"telnet-enable" completion:^(NSString *result, NSError *error) {
        [self delayed:1.2 block:^{
            [self updateStage:@"Telnet و ذخیره hw_default_ctree" progress:0.86];
            [self runTelnetFinalScript];
        }];
    }];
}

- (void)runTelnetFinalScript {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<NSArray<NSString *> *> *creds = @[@[@"root", @"admin"], @[@"root", @"adminHW"]];
        NSString *last = @"";
        for (NSArray<NSString *> *c in creds) {
            NSString *out = [self telnetRunHost:self.ontHost user:c[0] pass:c[1]];
            last = out ?: @"";
            [self appendLogThreadSafe:[NSString stringWithFormat:@"Telnet credential %@/%@: %@", c[0], @"******", [last stringByReplacingOccurrencesOfString:@"\n" withString:@" "]] level:@"TEL"];
            if ([self telnetOutputLooksSuccessful:last]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self finishRun:YES message:@"Provisioning کامل شد. خروجی cmp برابر 0 تشخیص داده شد."];
                });
                return;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishRun:NO message:[NSString stringWithFormat:@"Telnet نهایی تأیید نشد. آخرین خروجی: %@", last ?: @""]];
        });
    });
}

- (NSString *)telnetRunHost:(NSString *)host user:(NSString *)user pass:(NSString *)pass {
    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) return @"socket failed";
    struct timeval tv; tv.tv_sec = 4; tv.tv_usec = 0;
    setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    setsockopt(sockfd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
    struct sockaddr_in servaddr;
    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons(23);
    inet_pton(AF_INET, host.UTF8String, &servaddr.sin_addr);
    if (connect(sockfd, (struct sockaddr *)&servaddr, sizeof(servaddr)) < 0) {
        close(sockfd); return @"connect failed";
    }
    NSMutableString *log = [NSMutableString string];
    [log appendString:[self readTelnet:sockfd timeoutReads:2]];
    [self sendLine:user socket:sockfd];
    [log appendString:[self readTelnet:sockfd timeoutReads:2]];
    [self sendLine:pass socket:sockfd];
    [log appendString:[self readTelnet:sockfd timeoutReads:3]];
    if ([log.lowercaseString containsString:@"incorrect"] || [log.lowercaseString containsString:@"failed"]) { close(sockfd); return log; }
    NSArray<NSString *> *commands = @[
        @"su",
        @"shell",
        @"cd /mnt/jffs2",
        @"cp -f hw_ctree.xml hw_default_ctree.xml",
        @"chmod 644 hw_default_ctree.xml",
        @"sync",
        @"cmp /mnt/jffs2/hw_ctree.xml /mnt/jffs2/hw_default_ctree.xml",
        @"echo $?"];
    for (NSString *cmd in commands) {
        [self sendLine:cmd socket:sockfd];
        usleep(420000);
        NSString *chunk = [self readTelnet:sockfd timeoutReads:2];
        [log appendFormat:@"\n$ %@\n%@", cmd, chunk];
    }
    close(sockfd);
    return log;
}

- (BOOL)telnetOutputLooksSuccessful:(NSString *)output {
    if (!output.length) { return NO; }
    NSString *lower = output.lowercaseString;
    if ([lower containsString:@"no such file"] || [lower containsString:@"permission denied"] || [lower containsString:@"not found"]) { return NO; }
    NSArray<NSString *> *lines = [output componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        NSString *trim = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([trim isEqualToString:@"0"]) { return YES; }
    }
    return NO;
}

- (void)sendLine:(NSString *)line socket:(int)sockfd {
    NSString *s = [line stringByAppendingString:@"\r\n"];
    send(sockfd, s.UTF8String, strlen(s.UTF8String), 0);
}

- (NSString *)readTelnet:(int)sockfd timeoutReads:(int)count {
    NSMutableData *data = [NSMutableData data];
    unsigned char buf[1024];
    for (int i = 0; i < count; i++) {
        ssize_t n = recv(sockfd, buf, sizeof(buf), 0);
        if (n <= 0) { break; }
        NSMutableData *clean = [NSMutableData dataWithCapacity:n];
        for (ssize_t j = 0; j < n; j++) {
            unsigned char b = buf[j];
            if (b == 255) { j += 2; continue; }
            [clean appendBytes:&b length:1];
        }
        [data appendData:clean];
        if (n < (ssize_t)sizeof(buf)) { usleep(120000); }
    }
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!s) { s = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding]; }
    return s ?: @"";
}

- (void)updateStage:(NSString *)stage progress:(float)progress {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.stageLabel.text = stage;
        [self.progressView setProgress:progress animated:YES];
    });
}

- (void)appendLog:(NSString *)message level:(NSString *)level {
    NSString *line = [NSString stringWithFormat:@"[%@] %@  %@\n", [self timeString], level, message];
    self.logView.text = [self.logView.text stringByAppendingString:line];
    NSRange bottom = NSMakeRange(self.logView.text.length, 0);
    [self.logView scrollRangeToVisible:bottom];
}

- (void)appendLogThreadSafe:(NSString *)message level:(NSString *)level {
    dispatch_async(dispatch_get_main_queue(), ^{ [self appendLog:message level:level]; });
}

- (NSString *)timeString {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm:ss";
    return [fmt stringFromDate:[NSDate date]];
}

- (void)delayed:(NSTimeInterval)seconds block:(dispatch_block_t)block {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

- (void)exportLogs {
    NSString *text = self.logView.text ?: @"";
    UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil];
    [self presentViewController:vc animated:YES completion:nil];
}

@end
