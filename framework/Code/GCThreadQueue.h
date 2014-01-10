/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

@interface GCThreadQueue : NSObject {
@private
    NSMutableArray* mQueue;
    NSConditionLock* mLock;
}

/** 
 */
- (void)enqueue:(id)object;
- (id)dequeue; // Blocks until there is an object to return
- (id)tryDequeue; // Returns NULL if the queue is empty

@end
