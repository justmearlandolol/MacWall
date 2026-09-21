#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {

        NSApplication *app = [NSApplication sharedApplication];

        AppDelegate *delegate = [[AppDelegate alloc] init];
        [app setDelegate:delegate];

        NSScreen *screen = [NSScreen mainScreen];
        NSRect screenRect = [screen frame];

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

        WKWebViewConfiguration *config =
            [[WKWebViewConfiguration alloc] init];

        WKWebView *webView =
            [[WKWebView alloc]
                initWithFrame:screenRect
                configuration:config];

        [webView setValue:@(NO) forKey:@"drawsBackground"];

        // Cari wallpaper.html di folder yang sama
        // dengan executable.
        NSString *exePath =
            [[[NSBundle mainBundle] executablePath]
                stringByDeletingLastPathComponent];

        NSString *htmlPath =
            [exePath stringByAppendingPathComponent:@"wallpaper.html"];

        NSURL *fileURL =
            [NSURL fileURLWithPath:htmlPath];

        [webView loadFileURL:fileURL
        allowingReadAccessToURL:
            [fileURL URLByDeletingLastPathComponent]];

        [window setContentView:webView];

        [window makeKeyAndOrderFront:nil];

        [app run];
    }

    return 0;
}
