//
//  WKPageView.h
//  WKPageView
//
//  Created by Pascal Harris on 17/04/2023.
//

#import <Cocoa/Cocoa.h>
#import <Webkit/WebKit.h>


NS_ASSUME_NONNULL_BEGIN

@interface WKPageView : NSWindowController <NSWindowDelegate, WKNavigationDelegate> { 
    IBOutlet WKWebView* bookPages;
    id bookPlugin;
    NSInteger pageCount;
}

- (id)initWithBookPlugin:(id)bookPlug andWindowController:(NSNibName)windowNibName;

@end

NS_ASSUME_NONNULL_END
