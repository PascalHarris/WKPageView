//
//  WKPageView.m
//  WKPageView
//
//  Created by Pascal Harris on 17/04/2023.
//

#import "WKPageView.h"
#import "LibrarianFormatPluginInterface.h"

#define WindowSideLeft 0
#define WindowSideRight 1

@interface WKWebView (SynchronousEvaluateJavaScript)
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script;
@end

@implementation WKWebView (SynchronousEvaluateJavaScript)

- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script {
    __block NSString *resultString = nil;
    __block BOOL finished = NO;
    
    [self evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error == nil) {
            if (result != nil) {
                resultString = [NSString stringWithFormat:@"%@", result];
            }
        } else {
            NSLog(@"evaluateJavaScript error : %@", error.localizedDescription);
        }
        finished = YES;
    }];
    
    while (!finished) {
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:NSDate.distantFuture];
    }
    
    return resultString;
}

- (NSRect)adjustScroll:(NSRect)newVisible {
    NSRect modifiedRect=newVisible;
    
    // snap to 72 pixel increments
    modifiedRect.origin.x = (int)(modifiedRect.origin.x/72.0) * 72.0;

    return modifiedRect;
}

@end


@interface NSView ( TouchEvents )

@end

@implementation NSView ( TouchEvents )

float beginX, endX;


- (void)touchesBeganWithEvent:(NSEvent *)event {
    if(event.type == NSEventTypeGesture) {
        NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseAny inView:self];
        if(touches.count == 2) {
            for (NSTouch *touch in touches) {
                beginX = touch.normalizedPosition.x;
            }
        }
    }
}

- (void)touchesEndedWithEvent:(NSEvent *)event {
    
    if(event.type == NSEventTypeGesture){
        NSSet *touches = [event touchesMatchingPhase:NSTouchPhaseAny inView:self];
        NSDictionary* userInfo;
        if(touches.count == 2){
            for (NSTouch *touch in touches) {
                endX = touch.normalizedPosition.x;
            }
            
            if (endX > beginX) {
                userInfo = @{@"direction": @(WindowSideLeft)};
            } else if (endX < beginX) {
                userInfo = @{@"direction": @(WindowSideRight)};
            } 
            
            [NSNotificationCenter.defaultCenter postNotificationName:@"pageScrollEvent" object:nil userInfo:userInfo];
        }
    }
    
}

- (void)scrollWheel:(NSEvent *)event {
    NSLog(@"user scrolled %f horizontally and %f vertically", [event deltaX], [event deltaY]);
}

@end


@interface WKPageView ()

@end

@implementation WKPageView

- (void)createButtonOnSide:(int)side withSelector:(SEL)aSelector {
    int x = 0, y = 100, width = 40, height = 230;
    NSRect framesize = NSMakeRect(x, y, width, height);
    
    NSString* label = side==WindowSideLeft?@"<":@">";
    
    NSButton *myButton = [NSButton.alloc initWithFrame:CGRectZero];
    [myButton setButtonType:NSButtonTypeMomentaryPushIn];
    if (@available(macOS 11.0, *)) {
        NSImage* arrow = side==WindowSideLeft?[NSImage imageWithSystemSymbolName:@"arrowshape.left.fill" accessibilityDescription:label]:[NSImage imageWithSystemSymbolName:@"arrowshape.right.fill" accessibilityDescription:label];
        [myButton setImage:arrow];
    } else {
        [myButton setTitle:label];
    }
    [myButton setBezelStyle:NSBezelStyleTexturedSquare];
    [myButton setTarget:self];
    [myButton setAction:aSelector];
    [myButton setTag:side];
    
    myButton.translatesAutoresizingMaskIntoConstraints = false;
    [self.window.contentView addSubview:myButton];
    [myButton.widthAnchor constraintEqualToConstant:framesize.size.width].active = YES;
    [myButton.heightAnchor constraintEqualToConstant:framesize.size.height].active = YES;
    [myButton.centerYAnchor constraintEqualToAnchor:self.window.contentView.centerYAnchor].active = YES;
    if (side == WindowSideLeft) {
        [myButton.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor constant:0].active = YES;
    } else {
        [myButton.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor constant:0].active = YES;
    }
    
    NSTrackingArea* trackingArea = [NSTrackingArea.alloc
                                    initWithRect:myButton.bounds
                                    options: NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways
                                    owner:self userInfo:nil];
    [self.window.contentView addTrackingArea:trackingArea];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self.window setDelegate:self];
    
    [bookPages setAllowedTouchTypes:(NSTouchTypeMaskDirect | NSTouchTypeMaskIndirect)];
    
    [self.window setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
    
    [bookPages setNavigationDelegate:self];
    pageCount = 0; // might want to load this from preferences
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(loadDidFinish:)
                                               name:@"LoadDidFinishNotification"
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(buttonPressed:)
                                               name:@"PageScrollEvent"
                                             object:nil];
    
    [self createButtonOnSide:WindowSideLeft withSelector:@selector(buttonPressed:)];
    [self createButtonOnSide:WindowSideRight withSelector:@selector(buttonPressed:)];
    
}

- (id)initWithBookPlugin:(id)bookPlug andWindowController:(NSNibName)windowNibName {
    if (bookPlug && ![[bookPlug className] isEqualToString:[NSNull className]] && (self = [super initWithWindowNibName:windowNibName])) {
        bookPlugin = bookPlug;
    }
    return self;
}

- (void)loadDidFinish:(NSNotification*)notification {
    NSURLRequest* thisRequest = [bookPlugin getURLRequestForIndex:8];
    [bookPages loadRequest:thisRequest];
}

- (void)windowWillClose:(NSNotification *)notification {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    if (bookPlugin) { bookPlugin = nil; }
}

-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSString *cssString = @"body { overflow: -webkit-paged-x !important; direction: ltr !important; -webkit-overflow-scrolling: touch; scroll-snap-type: x mandatory;  scroll-snap-align: center; }";
    NSString *javascriptString = @"var style = document.createElement('style'); style.innerHTML = '%@'; document.head.appendChild(style)";
    NSString *javascriptWithCSSString = [NSString stringWithFormat:javascriptString, cssString];
    [webView evaluateJavaScript:javascriptWithCSSString completionHandler:nil];
}

-(NSSize)getViewDimensionsForwebView:(WKWebView *)webView {
    NSString* width = [webView stringByEvaluatingJavaScriptFromString:@"Math.max( document.body.scrollWidth, document.body.offsetWidth, document.documentElement.clientWidth, document.documentElement.scrollWidth, document.documentElement.offsetWidth )"];
    NSString* height = [webView stringByEvaluatingJavaScriptFromString:@"Math.max( document.body.scrollHeight, document.body.offsetHeight, document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight )"];
    
    return NSMakeSize(width.floatValue,height.floatValue);
}

- (void) updateAfterDelay:(id)sender {
    [self buttonPressed:nil];
}

- (void)buttonPressed:(id)sender {
    if ([[sender className] isEqualToString:@"NSButton"]) {
        if ([sender tag] == WindowSideLeft) { pageCount--; } else { pageCount++; }
    } else if ([[sender className] isEqualToString:@"NSConcreteNotification"]) {
        if ([[sender userInfo][@"direction"] isEqualTo: @(WindowSideLeft)]) { pageCount--; } else { pageCount++; }
    }
    
    pageCount = pageCount<0?0:pageCount;
    NSInteger pageWidth = self.window.contentView.frame.size.width;
    
    NSString* jsString = [NSString stringWithFormat:@"window.scrollTo({top: 0, left: %ld, behavior: \"smooth\",});", pageWidth * pageCount];
    [bookPages evaluateJavaScript:jsString completionHandler:nil];

    if (sender != nil) {
        [self performSelector:@selector(updateAfterDelay:) withObject:nil afterDelay:0.75];
    }

}

@end
