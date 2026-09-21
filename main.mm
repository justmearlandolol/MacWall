#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, WKNavigationDelegate>
@end

@implementation AppDelegate

- (void)webView:(WKWebView *)webView
didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"MacWall TEST: HTML berhasil dimuat.");
}

- (void)webView:(WKWebView *)webView
didFailProvisionalNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    NSLog(@"MacWall TEST: Gagal membuka HTML: %@", error);
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {

        NSApplication *app = [NSApplication sharedApplication];

        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];

        // Screen
        NSScreen *screen = [NSScreen mainScreen];
        NSRect screenRect = [screen frame];

        // TEST WINDOW
        // Sengaja BUKAN desktop-level dulu.
        NSRect windowRect = NSMakeRect(
            100,
            100,
            screenRect.size.width - 200,
            screenRect.size.height - 200
        );

        NSWindow *window =
            [[NSWindow alloc]
                initWithContentRect:windowRect
                styleMask:NSWindowStyleMaskTitled |
                          NSWindowStyleMaskClosable |
                          NSWindowStyleMaskResizable
                backing:NSBackingStoreBuffered
                defer:NO];

        [window setTitle:@"MacWall WebKit Test"];
        [window setHasShadow:YES];

        // WebView
        WKWebViewConfiguration *config =
            [[WKWebViewConfiguration alloc] init];

        WKWebView *webView =
            [[WKWebView alloc]
                initWithFrame:[[window contentView] bounds]
                configuration:config];

        [webView setAutoresizingMask:
            NSViewWidthSizable | NSViewHeightSizable];

        webView.navigationDelegate = delegate;

        // HTML filename — HARUS sama persis
        NSString *htmlFileName =
            @"Bliss-Cat-4K-Wallpaper.html";

        NSString *exeDirectory =
            [[[NSBundle mainBundle] executablePath]
                stringByDeletingLastPathComponent];

        NSString *htmlPath =
            [exeDirectory
                stringByAppendingPathComponent:htmlFileName];

        // Check file
        if (![[NSFileManager defaultManager]
                fileExistsAtPath:htmlPath]) {

            NSLog(@"MacWall TEST ERROR:");
            NSLog(@"HTML tidak ditemukan:");
            NSLog(@"%@", htmlPath);

            return 1;
        }

        NSLog(@"MacWall TEST:");
        NSLog(@"HTML ditemukan:");
        NSLog(@"%@", htmlPath);

        NSURL *htmlURL =
            [NSURL fileURLWithPath:htmlPath];

        // Load HTML
        [webView
            loadFileURL:htmlURL
            allowingReadAccessToURL:
                [htmlURL URLByDeletingLastPathComponent]];

        [window setContentView:webView];

        [window center];
        [window makeKeyAndOrderFront:nil];

        [app activateIgnoringOtherApps:YES];

        [app run];
    }

    return 0;
}
