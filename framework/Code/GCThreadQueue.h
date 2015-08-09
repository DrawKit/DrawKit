/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

@interface GCThreadQueue : NSObject {
@private
	NSMutableArray* mQueue;
	NSConditionLock* mLock;
}

/**  */
- (void)enqueue:(id)object;
- (id)dequeue; // Blocks until there is an object to return
- (id)tryDequeue; // Returns NULL if the queue is empty

@end
