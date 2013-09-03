///**********************************************************************************************************************************
///  DKUndoManager.m
///  DrawKit
///
///  Created by graham on 22/06/2007, originally based on code by Will Thimbleby in the public domain
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKUndoManager.h"

#import "LogEvent.h"


@implementation DKUndoManager
#pragma mark As a DKUndoManager


- (void)			enableUndoTaskCoalescing:(BOOL) enable
{
	mCoalescingEnabled = enable;
}


- (BOOL)			isUndoTaskCoalescingEnabled
{
	return mCoalescingEnabled;
}


- (unsigned)		changeCount
{
	return mChangeCount;
}


- (void)			resetChangeCount
{
	mChangeCount = 0;
}


- (void)			enableGroupDeferral:(BOOL)	defer
{
	mDeferGroupsEnabled = defer;
}


- (BOOL)			isGroupDeferralEnabled
{
	return mDeferGroupsEnabled;
}



- (BOOL)			isGroupBeingDeferred
{
	return mGroupDeferred;
}







#pragma mark -
#pragma mark As an NSUndoManager


- (void)			beginUndoGrouping
{
	mSkipTask = NO;
	mLastSelector = 0;
	
	if([self isGroupDeferralEnabled] && !mInPrivateMethod)
	{
		mGroupDeferred = YES;
		NSLog(@"deferred undo group, count = %d, level = %d", mGroupOpenCount, [self groupingLevel]);
	}
	else
		[super beginUndoGrouping];
}


- (void)			endUndoGrouping
{
	mSkipTask = NO;
	mLastSelector = 0;
	
	if([self isGroupDeferralEnabled])
	{
		if( mGroupOpenCount > 0 )
		{
			--mGroupOpenCount;
			[super endUndoGrouping];
			
			NSLog(@"closed undo group, count = %d, level = %d", mGroupOpenCount, [self groupingLevel]);
		}
	}
	else
		[super endUndoGrouping];
}


- (id)				prepareWithInvocationTarget:(id)target
{
	if([self isGroupBeingDeferred])
	{
		[super beginUndoGrouping];
		++mGroupOpenCount;
		mGroupDeferred = NO;
		
		NSLog(@"opened undo group (inv), count = %d, level = %d", mGroupOpenCount, [self groupingLevel]);
	}

	if([self isUndoRegistrationEnabled])
	{
		mSkipTargetRef = target;
		mSkipTask = YES;

		return [super prepareWithInvocationTarget:target];
	}
	else
		return nil;
}


- (void)			registerUndoWithTarget:(id)target selector:(SEL)sel object:(id)parameter
{
	// if a deferred group is flagged, open it for real now as we have a task to put in it
	
	if([self isGroupBeingDeferred])
	{
		[super beginUndoGrouping];
		++mGroupOpenCount;
		mGroupDeferred = NO;

		NSLog(@"opened undo group (reg), count = %d, level = %d", mGroupOpenCount, [self groupingLevel]);
	}

	if([self isUndoRegistrationEnabled])
	{
		if ( mCoalescingEnabled )
		{
			if( mSkipTask && mLastSelector != 0)
			{
				//if the target and selector are the same return

				if( target == mSkipTargetRef && mLastSelector == sel )
				{
					//NSLog(@"undo '%@' (discarded) group %d", NSStringFromSelector( sel ), [self groupingLevel]);
					
					return;
				}
			}
			
			//NSLog(@"undo '%@' (accepted) group %d", NSStringFromSelector( sel ), [self groupingLevel]);

			mSkipTargetRef = target;
			mSkipTask = YES;
			mLastSelector = sel;
		}
		
		++mChangeCount;
		mInPrivateMethod = YES;
		[super registerUndoWithTarget:target selector:sel object:parameter];
		mInPrivateMethod = NO;
	}
}


- (void)	undo
{
	mInPrivateMethod = YES;
	[super undo];
	mInPrivateMethod = NO;
}


- (void)	redo
{
	mInPrivateMethod = YES;
	[super redo];
	mInPrivateMethod = NO;
}


#pragma mark -
#pragma mark As an NSObject

- (id)		init
{
	self = [super init];
	if( self != nil )
	{
		[self enableUndoTaskCoalescing:YES];
		[self enableGroupDeferral:NO];
	}
	
	return self;
}

- (void)	forwardInvocation:(id)invocation;
{
	if( mCoalescingEnabled )
	{
		if(mSkipTask && mLastSelector != 0)
		{
			mSkipTask = NO;
			
			//if the target and selector are the same return
			
			if(mLastTargetRef == mSkipTargetRef && mLastSelector == [invocation selector])
			{
				//NSLog(@"undo invocation: %@ (discarded) group %d", NSStringFromSelector([invocation selector]), [self groupingLevel]);
				
				return;
			}
		}
		
		//NSLog(@"undo invocation: %@ (accepted) group %d", NSStringFromSelector([invocation selector]), [self groupingLevel]);
		
		mLastTargetRef = mSkipTargetRef;
		mLastSelector = [invocation selector];
	}

	++mChangeCount;
	mInPrivateMethod = YES;
	[super forwardInvocation: invocation];
	mInPrivateMethod = NO;
}


@end
