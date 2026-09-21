#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, WKNavigationDelegate>
@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

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

        // ==============================
        // SCREEN
        // ==============================

        NSScreen *screen = [NSScreen mainScreen];
        NSRect screenRect = [screen frame];

        // ==============================
        // WINDOW
        // ==============================

        NSWindow *window =
            [[NSWindow alloc]
                initWithContentRect:screenRect
                styleMask:NSWindowStyleMaskBorderless
                backing:NSBackingStoreBuffered
                defer:NO];

        [window setLevel:kCGDesktopWindowLevel];

        [window setCollectionBehavior:
            NSWindowCollectionBehaviorCanJoinAllSpaces |
            NSWindowCollectionBehaviorStationary |
            NSWindowCollectionBehaviorIgnoresCycle];

        [window setIgnoresMouseEvents:YES];
        [window setHasShadow:NO];

        // ==============================
        // WEBVIEW
        // ==============================

        WKWebViewConfiguration *config =
            [[WKWebViewConfiguration alloc] init];

        WKWebView *webView =
            [[WKWebView alloc]
                initWithFrame:screenRect
                configuration:config];

        webView.navigationDelegate = delegate;

        [webView setValue:@(NO) forKey:@"drawsBackground"];

        // ==============================
        // HTML FILE
        // ==============================

        NSString *htmlFileName =
            @"Bliss-Cat-4K-Wallpaper.html";

        NSString *executableDirectory =
            [[[NSBundle mainBundle] executablePath]
                stringByDeletingLastPathComponent];

        NSString *htmlPath =
            [executableDirectory
                stringByAppendingPathComponent:htmlFileName];

        NSURL *htmlURL =
            [NSURL fileURLWithPath:htmlPath];

        // ==============================
        // CHECK HTML
        // ==============================

        if (![[NSFileManager defaultManager]
                fileExistsAtPath:htmlPath]) {

            NSLog(@"========================================");
            NSLog(@"MacWall ERROR");
            NSLog(@"HTML FILE NOT FOUND!");
            NSLog(@"Expected file:");
            NSLog(@"%@", htmlPath);
            NSLog(@"========================================");

            return 1;
        }

        NSLog(@"========================================");
        NSLog(@"MacWall");
        NSLog(@"HTML found:");
        NSLog(@"%@", htmlPath);
        NSLog(@"========================================");

        // ==============================
        // LOAD HTML
        // ==============================

        [webView
            loadFileURL:htmlURL
            allowingReadAccessToURL:
                [htmlURL URLByDeletingLastPathComponent]];

        // ==============================
        // DISPLAY
        // ==============================

        [window setContentView:webView];

        [window makeKeyAndOrderFront:nil];

        // ==============================
        // RUN
        // ==============================

        [app run];
    }

    return 0;
}
