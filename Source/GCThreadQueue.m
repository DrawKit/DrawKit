/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "GCThreadQueue.h"

@implementation GCThreadQueue

/**  */
- (void)enqueue:(id)object
{
	[mLock lock];
	[mQueue addObject:object];
	[mLock unlockWithCondition:1];
}

- (id)dequeue
{
	[mLock lockWhenCondition:1];
	id element = [mQueue objectAtIndex:0];
	[mQueue removeObjectAtIndex:0];
	NSInteger count = [mQueue count];
	[mLock unlockWithCondition:(count > 0) ? 1 : 0];

	return element;
}

- (id)tryDequeue
{
	id element = NULL;
	if ([mLock tryLock]) {
		if ([mLock condition] == 1) {
			element = [mQueue objectAtIndex:0];
			[mQueue removeObjectAtIndex:0];
		}
		NSInteger count = [mQueue count];
		[mLock unlockWithCondition:(count > 0) ? 1 : 0];
	}
	return element;
}

- (id)init
{
	self = [super init];
	if (self != nil) {
		mQueue = [[NSMutableArray alloc] init];
		mLock = [[NSConditionLock alloc] initWithCondition:0];
	}
	return self;
}

@end
