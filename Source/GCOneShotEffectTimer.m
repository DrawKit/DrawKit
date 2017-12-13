/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "GCOneShotEffectTimer.h"

#import "LogEvent.h"

@interface GCOneShotEffectTimer ()

- (id)initWithTimeInterval:(NSTimeInterval)t forDelegate:(id<GCOneShotDelegate>)del;
@property (retain) id<GCOneShotDelegate> delegate;
- (void)osfx_callback:(NSTimer*)timer;

@end

@implementation GCOneShotEffectTimer

+ (id)oneShotWithTime:(NSTimeInterval)t forDelegate:(id<GCOneShotDelegate>)del
{
	GCOneShotEffectTimer* ft = [[GCOneShotEffectTimer alloc] initWithTimeInterval:t
																	  forDelegate:del];

	// unlike the usual case, this is returned retained (by self, effectively). The one-shot releases
	// itself when it's complete

	return ft;
}

+ (id)oneShotWithStandardFadeTimeForDelegate:(id<GCOneShotDelegate>)del
{
	return [self oneShotWithTime:kDKStandardFadeTime
					 forDelegate:del];
}

- (id)initWithTimeInterval:(NSTimeInterval)t forDelegate:(id<GCOneShotDelegate>)del
{
	if (self = [super init]) {
	[self setDelegate:del];

	mTotal = t;

	if (mDelegate && [mDelegate respondsToSelector:@selector(oneShotWillBegin)])
		[mDelegate oneShotWillBegin];

	mTimer = [NSTimer scheduledTimerWithTimeInterval:1 / 48.0
											  target:self
											selector:@selector(osfx_callback:)
											userInfo:nil
											 repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:mTimer
								 forMode:NSEventTrackingRunLoopMode];
	mStart = [NSDate timeIntervalSinceReferenceDate];
	}
	
	return self;
}

- (void)dealloc
{
	[mTimer invalidate];
	[mDelegate release];
	[super dealloc];
}

@synthesize delegate=mDelegate;

- (void)osfx_callback:(NSTimer*)timer
{
	NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - mStart;
	CGFloat val = elapsed / mTotal;

	//	LogEvent_(kReactiveEvent, @"t = %f", val );

	if (elapsed > mTotal) {
		[timer invalidate];
		mTimer = nil;

		if (mDelegate && [mDelegate respondsToSelector:@selector(oneShotComplete)])
			[mDelegate oneShotComplete];

		[self release];
	} else {
		if (mDelegate && [mDelegate respondsToSelector:@selector(oneShotHasReached:)])
			[mDelegate oneShotHasReached:val];
	}
}

@end
