/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKUndoManager.h"
#import "LogEvent.h"

#if USE_GC_UNDO_MANAGER

@implementation DKUndoManager

- (BOOL)enableUndoTaskCoalescing:(BOOL)enable
{
	BOOL old = [self isUndoTaskCoalescingEnabled];

	if (enable)
		[self enableUndoTaskCoalescing];
	else
		[self disableUndoTaskCoalescing];

	LogEvent_(kInfoEvent, @"undo coalescing is %@", enable ? @"ON" : @"OFF");

	return old;
}

@end

#else

@implementation DKUndoManager
@synthesize undoTaskCoalescingEnabled=mCoalescingEnabled;

- (BOOL)enableUndoTaskCoalescing:(BOOL)enable
{
	BOOL oldState = [self isUndoTaskCoalescingEnabled];
	mCoalescingEnabled = enable;

	LogEvent_(kInfoEvent, @"undo coalescing is %@", mCoalescingEnabled ? @"ON" : @"OFF");

	return oldState;
}

@synthesize changeCount=mChangeCount;

- (void)resetChangeCount
{
	mChangeCount = 0;
}

@synthesize numberOfTasksInLastGroup=mChangePerGroupCount;

- (void)enableSnowLeopardBackwardCompatibility:(BOOL)bcEnable
{
	// if bcEnable is YES, this class emulates 10.5 behaviour. This is also done on 10.5 itself, which is unnecessary and may
	// cause instability. Thus, YES should only be passed on 10.6 If you want backward compatibility.

	mEmulate105Behaviour = bcEnable;
	/*
	if( bcEnable )
		NSLog(@"Enabling 10.4/10.5 Undo Compatibility Mode");
	 */
}

- (void)invokeEmbeddedInvocation:(NSInvocation*)invocation
{
	@try
	{
		LogEvent_(kInfoEvent, @"%@ %@ '%@' target = <%@ %p>", [self isUndoing] ? @"undoing" : @"redoing", [self undoActionName], NSStringFromSelector([invocation selector]), NSStringFromClass([[invocation target] class]), [invocation target]);

		[invocation invoke];
	}
	@catch (NSException* excp)
	{
		NSLog(@"an exception occurred while invoking an undo task - ignored (task = %@, exception = %@)", invocation, excp);
	}
}

- (BOOL)hasStupidIncompatibleSnowLeopardChange
{
	// returns YES if the NSUndoManager returns a proxy from -prepareWithInvocationTarget:

	static BOOL isStupid = NO;
	static BOOL hasTested = NO;

	if (!hasTested) {
		NSUndoManager* umExample = [[NSUndoManager alloc] init];
		id proxy = [umExample prepareWithInvocationTarget:self];

		isStupid = proxy != umExample;
		hasTested = YES;

		/*
		if( isStupid )
			NSLog(@"This version of the OS has the stupid Snow Leopard Undo change");
		 */
	}

	return isStupid;
}

- (void)reset
{
	while ([self groupingLevel] > 0)
		[self endUndoGrouping];

	[self setGroupsByEvent:YES];
}

#pragma mark -
#pragma mark As an NSUndoManager

- (void)beginUndoGrouping
{
	mSkipTask = NO;
	mLastSelector = NULL;
	mChangePerGroupCount = 0;

	NSLog(@"grouping level = %ld", (long)[self groupingLevel]);

	[super beginUndoGrouping];

	LogEvent_(kInfoEvent, @"%@ opened undo group, level = %ld", self, (long)[self groupingLevel]);
}

- (void)endUndoGrouping
{
	mSkipTask = NO;
	mLastSelector = NULL;

	NSLog(@"grouping level = %ld", (long)[self groupingLevel]);

	[super endUndoGrouping];

	LogEvent_(kInfoEvent, @"%@ closed undo group, level = %ld, tasks submitted = %lu", self, (long)[self groupingLevel], (unsigned long)[self numberOfTasksInLastGroup]);
}

- (id)prepareWithInvocationTarget:(id)target
{
	if (mEmulate105Behaviour) {
		mTarget = target;
		mSkipTargetRef = target;
		mSkipTask = YES;
		return self;
	} else {
		if ([self isUndoRegistrationEnabled]) {
			mSkipTargetRef = target;
			mSkipTask = YES;

			return [super prepareWithInvocationTarget:target];
		} else
			return [super prepareWithInvocationTarget:target];
	}
}

#ifndef CONVERT_ALL_TO_NSINVOCATION
#define CONVERT_ALL_TO_NSINVOCATION 1
#endif

- (void)registerUndoWithTarget:(id)target selector:(SEL)sel object:(id)parameter
{
	// if a deferred group is flagged, open it for real now as we have a task to put in it

	mTarget = nil;

	if ([self isUndoRegistrationEnabled]) {
		if (mCoalescingEnabled && target != self) {
			if (mSkipTask && mLastSelector != NULL) {
				//if the target and selector are the same return

				if (target == mSkipTargetRef && mLastSelector == sel) {
					LogEvent_(kInfoEvent, @"undo '%@' (discarded) group %ld", NSStringFromSelector(sel), (long)[self groupingLevel]);

					return;
				}
			}

			LogEvent_(kInfoEvent, @"undo '%@' (accepted) group %ld", NSStringFromSelector(sel), (long)[self groupingLevel]);

			mSkipTargetRef = target;
			mSkipTask = YES;
			mLastSelector = sel;

#if defined(CONVERT_ALL_TO_NSINVOCATION) && CONVERT_ALL_TO_NSINVOCATION
			NSInvocation* inv = [NSInvocation invocationWithMethodSignature:[target methodSignatureForSelector:sel]];
			[inv setSelector:sel];
			[inv setTarget:target];
			[inv setArgument:&parameter
					 atIndex:2];
			[inv retainArguments];

			++mChangeCount;
			++mChangePerGroupCount;

			[super registerUndoWithTarget:self
								 selector:@selector(invokeEmbeddedInvocation:)
								   object:inv];
			return;
#endif
		}

		++mChangeCount;
		++mChangePerGroupCount;

		[super registerUndoWithTarget:target
							 selector:sel
							   object:parameter];
	}
}

#pragma mark -
#pragma mark As an NSObject

- (id)init
{
	self = [super init];
	if (self != nil) {
		[self enableUndoTaskCoalescing:YES];

		if ([self hasStupidIncompatibleSnowLeopardChange])
			[self enableSnowLeopardBackwardCompatibility:YES];
	}

	return self;
}

- (void)forwardInvocation:(NSInvocation*)invocation
{
	if (mCoalescingEnabled && !([self isUndoing] || [self isRedoing])) {
		if (mSkipTask && (mLastSelector != NULL)) {
			mSkipTask = NO;

			//if the target and selector are the same discard the invocation and return

			if ((mLastTargetRef == mSkipTargetRef) && (mLastSelector == [invocation selector])) {
				LogEvent_(kInfoEvent, @"undo invocation: [%@ %@] (discarded) group %ld", NSStringFromClass([mSkipTargetRef class]), NSStringFromSelector([invocation selector]), (long)[self groupingLevel]);

				return;
			}
		}

		LogEvent_(kInfoEvent, @"undo invocation: [%@ %@] (accepted) group %ld", NSStringFromClass([mSkipTargetRef class]), NSStringFromSelector([invocation selector]), (long)[self groupingLevel]);
		mLastTargetRef = mSkipTargetRef;
		mLastSelector = [invocation selector];
	}

	++mChangeCount;

	if (mEmulate105Behaviour) {
		[invocation setTarget:mTarget];
		[invocation retainArguments];
		[self registerUndoWithTarget:self
							selector:@selector(invokeEmbeddedInvocation:)
							  object:invocation];
	} else {
		++mChangePerGroupCount;
		[super forwardInvocation:invocation];
	}
}

- (NSMethodSignature*)methodSignatureForSelector:(SEL)aSelector
{
	NSMethodSignature* sig = [super methodSignatureForSelector:aSelector];

	if (mEmulate105Behaviour) {
		if (sig == nil)
			sig = [mTarget methodSignatureForSelector:aSelector];
	}
	return sig;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
	BOOL rSel = [super respondsToSelector:aSelector];

	if (mEmulate105Behaviour) {
		if (!rSel)
			rSel = [mTarget respondsToSelector:aSelector];
	}

	return rSel;
}

@end

#endif
