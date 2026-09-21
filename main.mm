#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, WKNavigationDelegate>
@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

#pragma mark - WebKit Debugging

- (void)webView:(WKWebView *)webView
didFinishNavigation:(WKNavigation *)navigation {

    NSLog(@"MacWall: HTML berhasil dimuat.");
}

- (void)webView:(WKWebView *)webView
didFailNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {

    NSLog(@"MacWall: Gagal load HTML: %@", error);
}

- (void)webView:(WKWebView *)webView
didFailProvisionalNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {

    NSLog(@"MacWall: Gagal membuka HTML: %@", error);
}

@end


int main(int argc, const char * argv[]) {

    @autoreleasepool {

        NSApplication *app = [NSApplication sharedApplication];

        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];


        // ==========================================
        // SCREEN
        // ==========================================

        NSScreen *screen = [NSScreen mainScreen];
        NSRect screenRect = [screen frame];


        // ==========================================
        // WINDOW
        // ==========================================

        NSWindow *window =
            [[NSWindow alloc]
                initWithContentRect:screenRect
                styleMask:NSWindowStyleMaskBorderless
                backing:NSBackingStoreBuffered
                defer:NO];

        // Jadikan window sebagai desktop-level window
        [window setLevel:kCGDesktopWindowLevel];

        // Tetap berada di semua Space
        [window setCollectionBehavior:
            NSWindowCollectionBehaviorCanJoinAllSpaces |
            NSWindowCollectionBehaviorStationary |
            NSWindowCollectionBehaviorIgnoresCycle];

        // Wallpaper tidak menerima klik mouse
        [window setIgnoresMouseEvents:YES];

        // Hilangkan shadow
        [window setHasShadow:NO];

        // Jangan muncul di Dock / Mission Control
        [window setHidesOnDeactivate:NO];


        // ==========================================
        // WEBVIEW
        // ==========================================

        WKWebViewConfiguration *config =
            [[WKWebViewConfiguration alloc] init];

        WKWebView *webView =
            [[WKWebView alloc]
                initWithFrame:screenRect
                configuration:config];

        webView.navigationDelegate = delegate;

        [webView setValue:@(NO) forKey:@"drawsBackground"];


        // ==========================================
        // HTML FILE
        // ==========================================

        NSString *htmlFileName =
            @"Bliss-Cat-4K-Wallpaper.html";

        NSString *exeDirectory =
            [[[NSBundle mainBundle] executablePath]
                stringByDeletingLastPathComponent];

        NSString *htmlPath =
            [exeDirectory
                stringByAppendingPathComponent:htmlFileName];

        NSURL *htmlURL =
            [NSURL fileURLWithPath:htmlPath];


        // ==========================================
        // CHECK FILE
        // ==========================================

        if (![[NSFileManager defaultManager]
                fileExistsAtPath:htmlPath]) {

            NSLog(@"====================================");
            NSLog(@"MacWall ERROR");
            NSLog(@"HTML tidak ditemukan!");
            NSLog(@"Expected path:");
            NSLog(@"%@", htmlPath);
            NSLog(@"====================================");

            return 1;
        }

        NSLog(@"MacWall: HTML ditemukan:");
        NSLog(@"%@", htmlPath);


        // ==========================================
        // LOAD HTML
        // ==========================================

        [webView
            loadFileURL:htmlURL
            allowingReadAccessToURL:
                [htmlURL URLByDeletingLastPathComponent]];


        // ==========================================
        // PUT WEBVIEW INTO WINDOW
        // ==========================================

        [window setContentView:webView];

        [window makeKeyAndOrderFront:nil];

        [app run];
    }

    return 0;
}
