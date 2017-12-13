/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

@protocol GCOneShotDelegate;

/** @brief This class wraps up a very simple piece of timer functionality.

This class wraps up a very simple piece of timer functionality. It sets up a timer that will call the
	delegate frequently with a value from 0..1. Once 1 is reached, it stops. The total time interval to
	complete the action is set by the caller.
	
	This is useful for one-shot type animations such as fading out a window or similar.
	
	The timer starts as soon as it is created.
	
	The timer attempts to maintain a 60fps rate, and is capped at this value. On slower systems, it will drop
	frames as needed.
	
	The oneshot effectively retains and releases itself, so there is nothing to do - just call the class
	method. You can generally ignore the return value. The oneshot retains the delegate, and releases it when
	it releases itself at the end of the effect, so the caller can happily release the delegate if it wishes
	after setting up the timer without worrying about what happens during the effect. It is also an error to
	release self (the delegate) when the completion method is called. Short version: it just works - don't
	try and retain/release anything in any different way from usual.
*/
@interface GCOneShotEffectTimer : NSObject {
@private
	NSTimer* mTimer;
	NSTimeInterval mStart;
	NSTimeInterval mTotal;
	// delegate is retained and released when one-shot completes. This allows some effects to work even
	// though the original delegate might be released by the caller.
	id<GCOneShotDelegate> mDelegate;
}

+ (GCOneShotEffectTimer*)oneShotWithStandardFadeTimeForDelegate:(id<GCOneShotDelegate>)del;
+ (GCOneShotEffectTimer*)oneShotWithTime:(NSTimeInterval)t forDelegate:(id<GCOneShotDelegate>)del;

@end

@protocol GCOneShotDelegate <NSObject>
@optional

- (void)oneShotWillBegin;
- (void)oneShotHasReached:(CGFloat)relpos;
- (void)oneShotComplete;

@end

#define kDKStandardFadeTime 0.15
