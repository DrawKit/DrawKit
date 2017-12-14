/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface GCThreadQueue : NSObject {
@private
	NSMutableArray* mQueue;
	NSConditionLock* mLock;
}

/**  */
- (void)enqueue:(id)object;
- (id)dequeue; // Blocks until there is an object to return
- (nullable id)tryDequeue; // Returns NULL if the queue is empty

@end

NS_ASSUME_NONNULL_END
