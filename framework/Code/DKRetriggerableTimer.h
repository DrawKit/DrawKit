/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

/** @brief Implements a one-shot timer that can be repeatedly extended (retriggered) preventing it timing out.

Implements a one-shot timer that can be repeatedly extended (retriggered) preventing it timing out. When it does time out, it calls the
 target/action. It can be retriggered to start a new cycle after timing out.
 
 This is analogous to a retriggerable monostable in electronics - useful for detecting when a series of rapid events ceases if there is no
 other way to detect them. Each event calls -retrigger, extending the timeout until no more retriggers + the period elapses.
*/
@interface DKRetriggerableTimer : NSObject {
@private
	NSTimer* mTimer;
	NSTimeInterval mPeriod;
	SEL mAction;
	id mTarget;
}

+ (DKRetriggerableTimer*)retriggerableTimerWithPeriod:(NSTimeInterval)period target:(id)target selector:(SEL)action;

- (id)initWithPeriod:(NSTimeInterval)period;
- (NSTimeInterval)period;

- (void)retrigger;

- (void)setAction:(SEL)action;
- (SEL)action;
- (void)setTarget:(id)target;
- (id)target;

@end
