#import <AppKit/AppKit.h>
#import <InputMethodKit/InputMethodKit.h>

NS_ASSUME_NONNULL_BEGIN
@class TBInputController;

__attribute__((swift_attr("@MainActor")))
@protocol TBInputEventSink <NSObject>
- (void)sessionActivated:(TBInputController *)controller;
- (void)sessionDeactivated:(TBInputController *)controller;
- (BOOL)handleInputEvent:(NSEvent *)event controller:(TBInputController *)controller;
- (NSMenu *)inputMenu;
@end

/// Keep IMK client proxies in Objective-C. Do not retain or cast the remote
/// IMKTextInput object through Swift ARC across asynchronous recognition work.
@interface TBInputController : IMKInputController
+ (void)setEventSink:(id<TBInputEventSink>)sink;
- (BOOL)commitText:(NSString *)text;
@end

/// Registers and enables this bundle without changing the user's selected source.
FOUNDATION_EXPORT int32_t TBRegisterInputSource(NSString *bundlePath);
NS_ASSUME_NONNULL_END
