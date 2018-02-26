/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKRetriggerableTimer.h"

@interface DKRetriggerableTimer ()

- (void)timerCallback:(NSTimer*)timer;

@end

#pragma mark -

@implementation DKRetriggerableTimer

+ (DKRetriggerableTimer*)retriggerableTimerWithPeriod:(NSTimeInterval)period target:(id)target selector:(SEL)action
{
	DKRetriggerableTimer* rt = [[self alloc] initWithPeriod:period];
	rt.action = action;
	rt.target = target;

	return rt;
}

- (id)initWithPeriod:(NSTimeInterval)period
{
	self = [super init];
	if (self) {
		mPeriod = period;
	}

	return self;
}

@synthesize period = mPeriod;

- (void)retrigger
{
	NSDate* fireDate = [NSDate dateWithTimeIntervalSinceNow:[self period]];

	if (mTimer)
		[mTimer setFireDate:fireDate];
	else
		mTimer = [NSTimer scheduledTimerWithTimeInterval:[self period]
												  target:self
												selector:@selector(timerCallback:)
												userInfo:nil
												 repeats:NO];
}

@synthesize action = mAction;
@synthesize target = mTarget;

#pragma mark -

- (void)timerCallback:(NSTimer*)timer
{
#pragma unused(timer)
	mTimer = nil;
	[NSApp sendAction:[self action]
				   to:[self target]
				 from:self];
}

#pragma mark -
#pragma mark - as a NSObject

- (id)init
{
	return [self initWithPeriod:1.0];
}

- (void)dealloc
{
	[mTimer invalidate];
}

@end
