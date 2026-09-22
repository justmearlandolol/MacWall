#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

// ===========================================================================
#pragma mark - 1. AppConfig : pengaturan yang ke-save antar launch
// ===========================================================================
//  Semua preferensi user (file wallpaper yang dipilih, toggle, dll) disimpan
//  di NSUserDefaults. State milik si HTML-nya sendiri disimpan di file JSON
//  terpisah per layar, di ~/Library/Application Support/LiveHTMLWallpaper/.
// ===========================================================================

@interface AppConfig : NSObject

+ (NSString *)defaultWallpaperPath;
+ (void)setDefaultWallpaperPath:(NSString *)path;

/// YES = klik nembus wallpaper (kayak wallpaper beneran),
/// NO  = wallpaper bisa nerima klik/interaksi (event sampe ke JS).
+ (BOOL)mousePassthrough;
+ (void)setMousePassthrough:(BOOL)flag;

+ (BOOL)wallpaperVisible;
+ (void)setWallpaperVisible:(BOOL)flag;

+ (BOOL)launchAtLogin;
+ (void)setLaunchAtLogin:(BOOL)flag;

/// Wallpaper khusus per layar (key = ID display CGDirectDisplayID).
+ (NSString *)wallpaperPathForDisplay:(uint32_t)displayID;
+ (void)setWallpaperPath:(NSString *)path forDisplay:(uint32_t)displayID;

/// File JSON "state milik si HTML" per layar.
+ (NSString *)stateFilePathForDisplay:(uint32_t)displayID;
+ (NSString *)readStateJSONForDisplay:(uint32_t)displayID;
+ (BOOL)writeStateJSON:(NSString *)json forDisplay:(uint32_t)displayID;

@end

@implementation AppConfig

static NSString *const kDefaultWallpaperKey = @"defaultWallpaperPath";
static NSString *const kMousePassthroughKey = @"mousePassthrough";
static NSString *const kWallpaperVisibleKey = @"wallpaperVisible";
static NSString *const kLaunchAtLoginKey    = @"launchAtLogin";
static NSString *const kPerDisplayKey       = @"perDisplayWallpapers";

+ (NSUserDefaults *)ud
{
    return [NSUserDefaults standardUserDefaults];
}

+ (void)finish
{
    [[self ud] synchronize];
}

#pragma mark Pengaturan umum

+ (NSString *)defaultWallpaperPath
{
    return [[self ud] stringForKey:kDefaultWallpaperKey];
}

+ (void)setDefaultWallpaperPath:(NSString *)path
{
    [[self ud] setObject:path forKey:kDefaultWallpaperKey];
    [self finish];
}

+ (BOOL)mousePassthrough
{
    NSNumber *n = [[self ud] objectForKey:kMousePassthroughKey];
    return n ? n.boolValue : YES; // default: klik nembus, biar desktop kerasa "normal"
}

+ (void)setMousePassthrough:(BOOL)flag
{
    [[self ud] setBool:flag forKey:kMousePassthroughKey];
    [self finish];
}

+ (BOOL)wallpaperVisible
{
    NSNumber *n = [[self ud] objectForKey:kWallpaperVisibleKey];
    return n ? n.boolValue : YES;
}

+ (void)setWallpaperVisible:(BOOL)flag
{
    [[self ud] setBool:flag forKey:kWallpaperVisibleKey];
    [self finish];
}

+ (BOOL)launchAtLogin
{
    return [[self ud] boolForKey:kLaunchAtLoginKey];
}

+ (void)setLaunchAtLogin:(BOOL)flag
{
    [[self ud] setBool:flag forKey:kLaunchAtLoginKey];
    [self finish];
}

#pragma mark Per layar

+ (NSString *)wallpaperPathForDisplay:(uint32_t)displayID
{
    NSDictionary *map = [[self ud] dictionaryForKey:kPerDisplayKey];
    return map[[NSString stringWithFormat:@"%u", displayID]];
}

+ (void)setWallpaperPath:(NSString *)path forDisplay:(uint32_t)displayID
{
    NSString *key = [NSString stringWithFormat:@"%u", displayID];
    NSMutableDictionary *map =
        [NSMutableDictionary dictionaryWithDictionary:[[self ud] dictionaryForKey:kPerDisplayKey] ?: @{}];
    if (path) {
        map[key] = path;
    } else {
        [map removeObjectForKey:key];
    }
    [[self ud] setObject:map forKey:kPerDisplayKey];
    [self finish];
}

#pragma mark File state si HTML

+ (NSString *)appSupportDir
{
    NSArray<NSString *> *dirs =
        NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *base = dirs.firstObject ?: NSTemporaryDirectory();
    NSString *dir = [base stringByAppendingPathComponent:@"LiveHTMLWallpaper"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return dir;
}

+ (NSString *)stateFilePathForDisplay:(uint32_t)displayID
{
    return [[self appSupportDir]
        stringByAppendingPathComponent:[NSString stringWithFormat:@"state-%u.json", displayID]];
}

+ (NSString *)readStateJSONForDisplay:(uint32_t)displayID
{
    return [NSString stringWithContentsOfFile:[self stateFilePathForDisplay:displayID]
                                     encoding:NSUTF8StringEncoding
                                        error:nil];
}

+ (BOOL)writeStateJSON:(NSString *)json forDisplay:(uint32_t)displayID
{
    return [json writeToFile:[self stateFilePathForDisplay:displayID]
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:nil];
}

@end

// ===========================================================================
#pragma mark - 2. LoginItem : "jalan otomatis saat login"
// ===========================================================================
//  Diimplementasi via AppleScript ke System Events. Di 10.13 High Sierra
//  jalan tanpa prompt; di 10.14+ bakal muncul SEKALI permintaan izin
//  "mengontrol System Events" — tinggal klik OK.
// ===========================================================================

@interface LoginItem : NSObject
+ (BOOL)setEnabled:(BOOL)enabled;
@end

@implementation LoginItem

static NSString *EscapedForAppleScript(NSString *s)
{
    return [[s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
            stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
}

+ (BOOL)setEnabled:(BOOL)enabled
{
    NSString *appPath = EscapedForAppleScript([[NSBundle mainBundle] bundlePath]);
    NSString *source;

    if (enabled) {
        source = [NSString stringWithFormat:
            @"tell application \"System Events\"\n"
            @"  if not (exists login item whose path is \"%@\") then\n"
            @"    make login item at end with properties {path:\"%@\", hidden:true}\n"
            @"  end if\n"
            @"end tell", appPath, appPath];
    } else {
        source = [NSString stringWithFormat:
            @"tell application \"System Events\" to delete (login items whose path is \"%@\")",
            appPath];
    }

    NSDictionary *error = nil;
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
    [script executeAndReturnError:&error];
    return (error == nil);
}

@end

// ===========================================================================
#pragma mark - 3 & 4. WallpaperWindowController : satu window per layar
// ===========================================================================
//  Inti aplikasi: NSPanel borderless dengan level window TEPAT DI BAWAH
//  level ikon desktop (kCGDesktopIconWindowLevelKey - 1), tapi di atas
//  gambar wallpaper Finder. Hasilnya: wallpaper HTML keliatan, sementara
//  ikon & file di desktop tetap di atasnya dan tetap bisa diklik/di-drag.
//
//  Di dalemnya: WKWebView yang load file:// wallpaper + jembatan JS
//  (window.wallpaper.saveState / window.__WALLPAPER_STATE__).
// ===========================================================================

@interface WallpaperWindowController : NSObject

- (instancetype)initWithScreen:(NSScreen *)screen;

- (void)show;
- (void)hide;
- (void)teardown;
- (void)setMousePassthrough:(BOOL)flag;

/// Minta si HTML ngebalikin state-nya (window.__getWallpaperState)
/// lalu tulis ke disk. Dipanggil pas app mau quit.
- (void)saveStateNow;

@property (nonatomic, readonly) uint32_t displayID;

@end

// ---- Interface privat -----------------------------------------------------

@interface WallpaperWindowController ()
@property (nonatomic, strong) NSPanel *window;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) NSScreen *screen;
- (void)handleScriptMessage:(WKScriptMessage *)message;
@end

// ---- Jembatan lemah utk message handler ------------------------------------
//  WKUserContentController nahan (retain) message handler-nya. Kalau
//  controller sendiri yang jadi handler, bakal ada retain cycle:
//  controller -> webView -> configuration -> contentController -> controller.
//  Jadi kita selipin "jembatan" yang referensinya weak.
// ---------------------------------------------------------------------------

@interface WallpaperScriptBridge : NSObject <WKScriptMessageHandler>
@property (nonatomic, weak) WallpaperWindowController *owner;
@end

@implementation WallpaperScriptBridge

- (void)userContentController:(WKUserContentController *)userContentController
       didReceiveScriptMessage:(WKScriptMessage *)message
{
    [self.owner handleScriptMessage:message];
}

@end

// ---- Implementasi WallpaperWindowController --------------------------------

@implementation WallpaperWindowController

#pragma mark Init

- (instancetype)initWithScreen:(NSScreen *)screen
{
    self = [super init];
    if (!self) return nil;

    _screen = screen;
    _displayID = (uint32_t)[[screen deviceDescription][@"NSScreenNumber"] unsignedIntValue];

    NSPanel *panel = [[NSPanel alloc] initWithContentRect:screen.frame
                                                styleMask:(NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel)
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];

    // KUNCI TRIKNYA: level tepat di bawah level ikon desktop
    // (kCGDesktopIconWindowLevelKey), tapi di atas gambar wallpaper Finder.
    panel.level = CGWindowLevelForKey(kCGDesktopIconWindowLevelKey) - 1;

    // Nempel di semua Space, "diam" (nggak ikut ekspos Mission Control),
    // dan nggak bisa di-Cmd+`.
    panel.collectionBehavior = (NSWindowCollectionBehaviorCanJoinAllSpaces
                              | NSWindowCollectionBehaviorStationary
                              | NSWindowCollectionBehaviorIgnoresCycle);

    panel.opaque = NO;
    panel.backgroundColor = [NSColor clearColor];
    panel.hasShadow = NO;
    panel.hidesOnDeactivate = NO;
    panel.becomesKeyOnlyIfNeeded = YES;
    panel.animationBehavior = NSWindowAnimationBehaviorNone;
    panel.releasedWhenClosed = NO;
    panel.ignoresMouseEvents = [AppConfig mousePassthrough];
    panel.contentView = [self createWebView];

    _window = panel;
    return self;
}

#pragma mark Bikin webview

- (WKWebView *)createWebView
{
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.preferences.javaScriptEnabled = YES;
    config.preferences.javaScriptCanOpenWindowsAutomatically = NO;

    // Biar video wallpaper <video autoplay muted loop> jalan tanpa interaksi.
    if (@available(macOS 10.12, *)) {
        config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    }

    // Suntik state yang ke-save terakhir kali + API `window.wallpaper`
    // SEBELUM script di halaman jalan (document start).
    NSString *savedJSON = [AppConfig readStateJSONForDisplay:self.displayID];
    NSString *boot = [NSString stringWithFormat:
        @"window.__WALLPAPER_STATE__ = %@;\n"
         "window.wallpaper = {\n"
         "  saveState: function (s) {\n"
         "    try { window.webkit.messageHandlers.wallpaper.postMessage({ kind: 'save', json: JSON.stringify(s) }); } catch (e) {}\n"
         "  }\n"
         "};\n",
        savedJSON.length > 0 ? savedJSON : @"null"];

    WKUserScript *bootScript = [[WKUserScript alloc] initWithSource:boot
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                     forMainFrameOnly:YES];
    [config.userContentController addUserScript:bootScript];

    WallpaperScriptBridge *bridge = [[WallpaperScriptBridge alloc] init];
    bridge.owner = self;
    [config.userContentController addScriptMessageHandler:bridge name:@"wallpaper"];

    WKWebView *webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)
                                            configuration:config];
    webView.autoresizingMask = (NSViewWidthSizable | NSViewHeightSizable);
    webView.allowsBackForwardNavigationGestures = NO;

    // Trick yang umum dipakai biar WKWebView nggak ngegambar background putih
    // (berguna buat wallpaper HTML yang background-nya transparan sebagian).
    @try {
        [webView setValue:@(NO) forKey:@"drawsBackground"];
    } @catch (id ignore) {
    }

    NSURL *url = [self wallpaperURL];
    if (url) {
        // Kasih akses baca ke folder yang sama, biar asset relatif
        // (css/js/img/video) ikut kebaca oleh halaman.
        NSURL *folder = [url URLByDeletingLastPathComponent] ?: url;
        [webView loadFileURL:url allowingReadAccessToURL:folder];
    } else {
        NSString *html = @"<html><body style=\"margin:0;height:100vh;display:flex;align-items:center;"
                         "justify-content:center;background:#101218;color:#e8e8ec;font:16px -apple-system,"
                         "'Helvetica Neue',sans-serif;text-align:center\">Belum ada wallpaper 🌱<br>"
                         "<small style=\"opacity:.6\">Klik ikon di menu bar → \"Pilih File HTML…\"</small>"
                         "</body></html>";
        [webView loadHTMLString:html baseURL:nil];
    }
    return webView;
}

- (NSURL *)wallpaperURL
{
    NSString *path = [AppConfig wallpaperPathForDisplay:self.displayID] ?: [AppConfig defaultWallpaperPath];
    if (path.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return [NSURL fileURLWithPath:path];
    }
    // Belum dipilih user? Pake wallpaper bawaan yang dibundel di dalam .app
    // (wallpapers/wallpaper.html — Bliss Cat 4K, udah dijamin kompatibel WebKit 10.13).
    return [[NSBundle mainBundle] URLForResource:@"wallpaper" withExtension:@"html"];
}

#pragma mark Tampil / sembunyi / bongkar

- (void)show
{
    [self.window orderFrontRegardless];
}

- (void)hide
{
    [self.window orderOut:nil];
}

- (void)teardown
{
    [self saveStateNow];
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"wallpaper"];
    [self.webView stopLoading];
    [self.window orderOut:nil];
    self.window = nil;
    self.webView = nil;
}

- (void)setMousePassthrough:(BOOL)flag
{
    self.window.ignoresMouseEvents = flag;
}

#pragma mark Jembatan state (JS <-> ObjC)

- (void)handleScriptMessage:(WKScriptMessage *)message
{
    NSDictionary *body = [message.body isKindOfClass:[NSDictionary class]] ? message.body : nil;
    if (!body) return;

    if ([body[@"kind"] isEqualToString:@"save"]) {
        NSString *json = [body[@"json"] isKindOfClass:[NSString class]] ? body[@"json"] : nil;
        if (json.length > 0) {
            [AppConfig writeStateJSON:json forDisplay:self.displayID];
        }
    }
}

- (void)saveStateNow
{
    [self.webView evaluateJavaScript:
        @"(typeof window.__getWallpaperState === 'function') ? window.__getWallpaperState() : null"
        completionHandler:^(id result, NSError *error) {
            if ([result isKindOfClass:[NSString class]]) {
                [AppConfig writeStateJSON:result forDisplay:self.displayID];
            }
        }];
}

@end

// ===========================================================================
#pragma mark - 5. AppDelegate : menu bar, siklus hidup, multi-layar
// ===========================================================================

@interface AppDelegate ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMutableArray<WallpaperWindowController *> *controllers;
@end

@implementation AppDelegate

#pragma mark Siklus hidup

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    (void)notification;

    self.controllers = [NSMutableArray array];
    [self rebuildWindows];
    [self buildStatusItem];

    // Colok/proyektor dipasang atau resolusi diganti -> susun ulang window.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(screensChanged:)
                                                 name:NSApplicationDidChangeScreenParametersNotification
                                               object:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    (void)notification;

    // Minta tiap wallpaper ngebalikin state-nya, lalu kasih grace period
    // sebentar: evaluateJavaScript itu asinkron, jadi run loop harus tetap
    // muter dikit biar callback-nya sempat nulis file sebelum proses mati.
    for (WallpaperWindowController *controller in self.controllers) {
        [controller saveStateNow];
    }
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.5];
    while ([deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode
                              beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
}

#pragma mark Manajemen window per layar

- (void)screensChanged:(NSNotification *)notification
{
    (void)notification;
    [self rebuildWindows];
}

- (void)rebuildWindows
{
    for (WallpaperWindowController *controller in self.controllers) {
        [controller teardown];
    }
    [self.controllers removeAllObjects];

    BOOL visible = [AppConfig wallpaperVisible];
    for (NSScreen *screen in [NSScreen screens]) {
        WallpaperWindowController *controller = [[WallpaperWindowController alloc] initWithScreen:screen];
        [self.controllers addObject:controller];
        if (visible) {
            [controller show];
        }
    }
}

#pragma mark Status bar + menu

- (void)buildStatusItem
{
    NSStatusItem *item = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

    // Gambar ikon monitor sendiri (template image) — nggak butuh file .icns.
    NSImage *icon = [NSImage imageWithSize:NSMakeSize(18, 18) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        NSBezierPath *path = [NSBezierPath bezierPath];
        path.lineWidth = 1.6;
        [[NSColor blackColor] setStroke];

        NSRect monitor = NSInsetRect(dstRect, 2, 4.5);
        [path appendBezierPathWithRoundedRect:monitor xRadius:2.5 yRadius:2.5];
        [path moveToPoint:NSMakePoint(NSMidX(monitor) - 3, NSMinY(monitor) - 3.5)];
        [path lineToPoint:NSMakePoint(NSMidX(monitor) + 3, NSMinY(monitor) - 3.5)];
        [path stroke];
        return YES;
    }];
    icon.template = YES;

    item.button.image = icon;
    item.menu = [self buildMenu];
    self.statusItem = item;
}

- (NSMenu *)buildMenu
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Live HTML Wallpaper"];

    [menu addItem:[self item:@"Pilih File HTML…"            action:@selector(chooseWallpaper:)        key:@""]];
    [menu addItem:[self item:@"Muat Ulang"                  action:@selector(reloadAll:)              key:@"r"]];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:[self item:@"Sembunyikan Wallpaper"       action:@selector(toggleVisible:)          key:@""]];
    [menu addItem:[self item:@"Klik Menembus Wallpaper"     action:@selector(toggleMousePassthrough:) key:@""]];
    [menu addItem:[self item:@"Jalan Otomatis Saat Login"   action:@selector(toggleLaunchAtLogin:)    key:@""]];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:[self item:@"Tentang Live HTML Wallpaper" action:@selector(showAbout:)              key:@""]];

    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Keluar"
                                                  action:@selector(terminate:)
                                           keyEquivalent:@"q"];
    quit.target = NSApp;
    [menu addItem:quit];

    return menu;
}

- (NSMenuItem *)item:(NSString *)title action:(SEL)action key:(NSString *)key
{
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];
    item.target = self;
    return item;
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    SEL action = item.action;
    if (action == @selector(toggleVisible:)) {
        item.title = [AppConfig wallpaperVisible] ? @"Sembunyikan Wallpaper" : @"Tampilkan Wallpaper";
    } else if (action == @selector(toggleMousePassthrough:)) {
        item.state = [AppConfig mousePassthrough] ? NSControlStateValueOn : NSControlStateValueOff;
    } else if (action == @selector(toggleLaunchAtLogin:)) {
        item.state = [AppConfig launchAtLogin] ? NSControlStateValueOn : NSControlStateValueOff;
    }
    return YES;
}

#pragma mark Aksi menu

- (void)chooseWallpaper:(id)sender
{
    (void)sender;

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = @"Pilih Wallpaper HTML";
    panel.message = @"Pilih file .html, atau folder yang isinya index.html";
    panel.allowedFileTypes = @[ @"html", @"htm" ];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = YES;
    panel.allowsMultipleSelection = NO;

    [NSApp activateIgnoringOtherApps:YES];
    if ([panel runModal] != NSModalResponseOK) return;

    NSString *path = panel.URL.path;
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm isDirectoryAtPath:path]) {
        NSString *index = [path stringByAppendingPathComponent:@"index.html"];
        path = [fm fileExistsAtPath:index] ? index : nil;
    }
    if (path.length == 0) {
        [self showAlert:@"File HTML nggak ketemu"
                   info:@"Pilih file .html, atau folder yang di dalemnya ada index.html."];
        return;
    }

    [AppConfig setDefaultWallpaperPath:path];
    [self rebuildWindows];
}

- (void)reloadAll:(id)sender
{
    (void)sender;
    [self rebuildWindows];
}

- (void)toggleVisible:(id)sender
{
    (void)sender;
    BOOL visible = ![AppConfig wallpaperVisible];
    [AppConfig setWallpaperVisible:visible];
    [self rebuildWindows];
}

- (void)toggleMousePassthrough:(id)sender
{
    (void)sender;
    BOOL flag = ![AppConfig mousePassthrough];
    [AppConfig setMousePassthrough:flag];
    for (WallpaperWindowController *controller in self.controllers) {
        [controller setMousePassthrough:flag];
    }
}

- (void)toggleLaunchAtLogin:(id)sender
{
    (void)sender;
    BOOL flag = ![AppConfig launchAtLogin];
    if (![LoginItem setEnabled:flag]) {
        [self showAlert:@"Gagal set login item"
                   info:@"macOS nolak AppleScript ke System Events (biasanya soal permission). "
                        @"Coba sekali lagi, terus klik \"OK\" waktu diminta izin."];
        return;
    }
    [AppConfig setLaunchAtLogin:flag];
}

- (void)showAbout:(id)sender
{
    (void)sender;
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:nil];
}

#pragma mark Helper

- (void)showAlert:(NSString *)message info:(NSString *)info
{
    [NSApp activateIgnoringOtherApps:YES];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = message;
    alert.informativeText = info ?: @"";
    alert.alertStyle = NSAlertStyleWarning;
    [alert runModal];
}

@end

// ===========================================================================
#pragma mark - 6. main() : entry point
// ===========================================================================

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];

        // App "agent": nggak ada ikon di Dock, cuma ikon kecil di menu bar.
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];

        [app run];
    }
    return 0;
}
