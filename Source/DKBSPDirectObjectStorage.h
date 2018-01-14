/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKBSPObjectStorage.h"

NS_ASSUME_NONNULL_BEGIN

@class DKBSPDirectTree;

/**
 This uses a similar algorithm to DKBSPObjectStorage but instead of indexing the objects it stores them directly by retaining them in additional arrays
 within the BSP tree. This is likely to be faster than the indexing approach though profiling is needed to confirm this.
 
 To facilitate correct z-ordering, each object stores its own Z-position and the objects are sorted on this property when necessary. Objects need to be
 renumbered when indexes change.

 The trade-off here is that drawing speed should be faster but object insertion, deletion and changing of Z-position may be slower.
*/
@interface DKBSPDirectObjectStorage : DKLinearObjectStorage {
@private
	DKBSPDirectTree* mTree;
	NSUInteger mTreeDepth;
	NSUInteger mLastItemCount;
	BOOL mAutoRebuild;
}

- (void)setTreeDepth:(NSUInteger)aDepth;
- (DKBSPDirectTree*)tree;
- (NSBezierPath*)debugStorageDivisions;

@end

#pragma mark -

/// tree object

@interface DKBSPDirectTree : DKBSPIndexTree {
@public
	id<DKStorableObject> mObj;
	NSMutableArray* mFoundObjects;
	NSUInteger mObjectCount;
	__weak NSView* mViewRef;
	NSRect mRect;
}

- (void)insertItem:(id<DKStorableObject>)obj withRect:(NSRect)rect;
- (void)removeItem:(id<DKStorableObject>)obj withRect:(NSRect)rect;
- (void)removeAllObjects;
@property (readonly) NSUInteger count;

// tree returns mutable results so that they can be sorted in place without needing to be copied

- (nullable NSMutableArray*)objectsIntersectingRects:(const NSRect*)rects count:(NSUInteger)count inView:(NSView*)aView;
- (nullable NSMutableArray*)objectsIntersectingRect:(NSRect)rect;
- (nullable NSMutableArray*)objectsIntersectingPoint:(NSPoint)point;

@end

NS_ASSUME_NONNULL_END
