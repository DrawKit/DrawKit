///**********************************************************************************************************************************
///  GCOneShotEffectTimer.m
///  DrawKit
///
///  Created by graham on 24/04/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "GCOneShotEffectTimer.h"

#import "LogEvent.h"


@interface GCOneShotEffectTimer (Private)

- (id)		initWithTimeInterval:(NSTimeInterval) t forDelegate:(id) del;
- (void)	setDelegate:(id) del;
- (id)		delegate;
- (void)	osfx_callback:(NSTimer*) timer;

@end


@implementation GCOneShotEffectTimer

+ (id)		oneShotWithTime:(NSTimeInterval) t forDelegate:(id) del
{
	GCOneShotEffectTimer* ft = [[GCOneShotEffectTimer alloc] initWithTimeInterval:t forDelegate:del];
	
	// unlike the usual case, this is returned retained (by self, effectively). The one-shot releases
	// itself when it's complete
	
	return ft;
}


+ (id)		oneShotWithStandardFadeTimeForDelegate:(id) del
{
	return [self oneShotWithTime:kGCStandardFadeTime forDelegate:del];
}


- (id)		initWithTimeInterval:(NSTimeInterval) t forDelegate:(id) del
{
	[super init];
	[self setDelegate:del];
	
	mTotal = t;
	
	if ( mDelegate && [mDelegate respondsToSelector:@selector(oneShotWillBegin)])
		[mDelegate oneShotWillBegin];
	
	mTimer = [NSTimer scheduledTimerWithTimeInterval:1/48.0f target:self selector:@selector(osfx_callback:) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:mTimer forMode:NSEventTrackingRunLoopMode];
	mStart = [NSDate timeIntervalSinceReferenceDate];

	return self;
}


- (void)	dealloc
{
	[mTimer invalidate];
	[mDelegate release];
	[super dealloc];
}


- (void)	setDelegate:(id) del
{
	// delegate is retained and released when one-shot completes. This allows some effects to work even
	// though the original delegate might be released by the caller.
	
	[del retain];
	[mDelegate release];
	mDelegate = del;
}


- (id)		delegate
{
	return mDelegate;
}


- (void)	osfx_callback:(NSTimer*) timer
{
	NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - mStart;
	float val = elapsed / mTotal;
	
//	LogEvent_(kReactiveEvent, @"t = %f", val );
	
	if ( elapsed > mTotal )
	{
		[timer invalidate];
		mTimer = nil;

		if ( mDelegate && [mDelegate respondsToSelector:@selector(oneShotComplete)])
			[mDelegate oneShotComplete];
		
		[self release];
	}
	else
	{
		if ( mDelegate && [mDelegate respondsToSelector:@selector(oneShotHasReached:)])
			[mDelegate oneShotHasReached:val];
	}
}


@end
