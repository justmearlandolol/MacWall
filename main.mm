#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, WKNavigationDelegate>
@end

@implementation AppDelegate

- (void)webView:(WKWebView *)webView
didFinishNavigation:(WKNavigation *)navigation {
    NSLog(@"MacWall TEST: Test.html berhasil dimuat.");
}

- (void)webView:(WKWebView *)webView
didFailProvisionalNavigation:(WKNavigation *)navigation
      withError:(NSError *)error {
    NSLog(@"MacWall TEST ERROR: %@", error);
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {

        NSApplication *app = [NSApplication sharedApplication];

        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];

        NSScreen *screen = [NSScreen mainScreen];
        NSRect screenRect = [screen frame];

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

        [window setTitle:@"MacWall Test"];

        WKWebViewConfiguration *config =
            [[WKWebViewConfiguration alloc] init];

        WKWebView *webView =
            [[WKWebView alloc]
                initWithFrame:[[window contentView] bounds]
                configuration:config];

        [webView setAutoresizingMask:
            NSViewWidthSizable | NSViewHeightSizable];

        webView.navigationDelegate = delegate;

        NSString *htmlFileName = @"Test.html";

        NSString *exeDirectory =
            [[[NSBundle mainBundle] executablePath]
                stringByDeletingLastPathComponent];

        NSString *htmlPath =
            [exeDirectory
                stringByAppendingPathComponent:htmlFileName];

        if (![[NSFileManager defaultManager]
                fileExistsAtPath:htmlPath]) {

            NSLog(@"MacWall TEST ERROR:");
            NSLog(@"Test.html tidak ditemukan:");
            NSLog(@"%@", htmlPath);

            return 1;
        }

        NSLog(@"MacWall TEST:");
        NSLog(@"Test.html ditemukan:");
        NSLog(@"%@", htmlPath);

        NSURL *htmlURL =
            [NSURL fileURLWithPath:htmlPath];

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
