//
//  GCThreadQueue.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 03/05/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import <Cocoa/Cocoa.h>


@interface GCThreadQueue : NSObject
{
@private
	NSMutableArray*		mQueue;
	NSConditionLock*	mLock;
}


-(void)		enqueue:(id) object;
-(id)		dequeue;						// Blocks until there is an object to return
-(id)		tryDequeue;						// Returns NULL if the queue is empty


@end


