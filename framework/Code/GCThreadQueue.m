//
//  GCThreadQueue.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 03/05/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "GCThreadQueue.h"


@implementation GCThreadQueue

-(void)		enqueue:(id) object
{
	[mLock lock];
	[mQueue addObject:object];
	[mLock unlockWithCondition:1];
}



-(id)		dequeue
{
	[mLock lockWhenCondition:1];
	id element = [[[mQueue objectAtIndex:0] retain] autorelease];
	[mQueue removeObjectAtIndex:0];
	NSInteger count = [mQueue count];
	[mLock unlockWithCondition:(count > 0)? 1 : 0];
	
	return element;
}



-(id)		tryDequeue
{
	id element = NULL;
	if ([mLock tryLock])
	{
		if ([mLock condition] == 1)
		{
			element = [[[mQueue objectAtIndex:0] retain] autorelease];
			[mQueue removeObjectAtIndex:0];
		}
		NSInteger count = [mQueue count];
		[mLock unlockWithCondition:(count > 0)? 1 : 0];
  }
  return element;
}

-(id)		init
{
	self = [super init];
	if( self != nil )
	{
		mQueue = [[NSMutableArray alloc] init];
		mLock = [[NSConditionLock alloc] initWithCondition:0];
	}
	return self;
}



-(void)		dealloc
{
	[mQueue release];
	[mLock release];
	[super dealloc];
}

@end
