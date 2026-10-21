#import "InputMethodBridge.h"
#import <Carbon/Carbon.h>

static __weak id<TBInputEventSink> eventSink;

@implementation TBInputController {
    BOOL _sessionActive;
}

+ (void)setEventSink:(id<TBInputEventSink>)sink { eventSink = sink; }

- (void)activateServer:(id)sender {
    [super activateServer:sender];
    _sessionActive = YES;
    [eventSink sessionActivated:self];
}

- (void)deactivateServer:(id)sender {
    _sessionActive = NO;
    [eventSink sessionDeactivated:self];
    [super deactivateServer:sender];
}

- (void)inputControllerWillClose {
    _sessionActive = NO;
    [eventSink sessionDeactivated:self];
    [super inputControllerWillClose];
}

- (NSUInteger)recognizedEvents:(id)sender { return NSEventMaskKeyDown; }

- (BOOL)handleEvent:(NSEvent *)event client:(id)sender {
    return _sessionActive && [eventSink handleInputEvent:event controller:self];
}

- (NSMenu *)menu { return [eventSink inputMenu]; }

- (BOOL)commitText:(NSString *)text {
    if (!_sessionActive || text.length == 0) { return NO; }
    // IMK owns the client lifetime. Resolve it immediately before insertion,
    // never from the OCR worker, and let IMK replace the current selection.
    @try {
        id client = [self client];
        if (![client respondsToSelector:@selector(insertText:replacementRange:)]) { return NO; }
        [client insertText:text replacementRange:NSMakeRange(NSNotFound, 0)];
        return YES;
    } @catch (NSException *exception) {
        // No ink or recognized text is written to the system log.
        NSLog(@"Trackboard: the input session ended before text could be inserted.");
        return NO;
    }
}
@end

int32_t TBRegisterInputSource(NSString *bundlePath) {
    NSURL *url = [NSURL fileURLWithPath:bundlePath];
    OSStatus status = TISRegisterInputSource((__bridge CFURLRef)url);
    if (status != noErr) { return status; }
    NSString *identifier = [[NSBundle bundleWithPath:bundlePath] bundleIdentifier];
    if (!identifier) { return paramErr; }
    NSDictionary *filter = @{(__bridge NSString *)kTISPropertyBundleID: identifier};
    CFArrayRef sources = TISCreateInputSourceList((__bridge CFDictionaryRef)filter, true);
    if (!sources) { return -1; }
    if (CFArrayGetCount(sources) == 0) { CFRelease(sources); return -1; }
    for (CFIndex i = 0; i < CFArrayGetCount(sources); i++) {
        TISInputSourceRef source = (TISInputSourceRef)CFArrayGetValueAtIndex(sources, i);
        OSStatus enabled = TISEnableInputSource(source);
        if (enabled != noErr) { status = enabled; }
    }
    CFRelease(sources);
    return status;
}
