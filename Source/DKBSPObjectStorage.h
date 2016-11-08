/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKLinearObjectStorage.h"

@class DKBSPIndexTree;

/// node types

typedef enum {
	kNodeHorizontal,
	kNodeVertical,
	kNodeLeaf
} DKLeafType;

/// tree operations

typedef enum {
	kDKOperationInsert,
	kDKOperationDelete,
	kDKOperationAccumulate
} DKBSPOperation;

/** @brief The actual storage object.

 The actual storage object. This inherits the linear array which actually stores the objects, but maintains a BSP tree in parallel, which
 stores indexes that refer to this array. Thus the objects' Z-order is strictly maintained by the array as for the linear case, but objects can
 be extracted very rapidly when performing a spatial query.
*/
@interface DKBSPObjectStorage : DKLinearObjectStorage {
@private
	DKBSPIndexTree* mTree;
	NSUInteger mTreeDepth;
	NSUInteger mLastItemCount;
}

- (void)setTreeDepth:(NSUInteger)aDepth;
- (id)tree;

@end

#pragma mark -

/** @brief tree object; this stores indexes in mutable index sets.

 this stores indexes in mutable index sets. The indexes refer to the index of the object within the linear array. Given a rect query, this returns an index set which
 is the indexes of all objects that intersect the rect. Using -objectsAtIndexes: on the linear array then returns the relevant objects sorted by Z-order. The tree only
 stores the indexes of visible objects, thus it doesn't need to test for visibility - the storage will manage adding and removing indexes as object visibility changes.

 note that this is equivalent to a binary search in 2 dimensions. The purpose is to weed out as many irrelevant objects as possible in advance of returning them to the
 client for drawing. Internally it is tuned for speed but it relies heavily on the performance of Cocoa's NSIndexSet class, and -addIndexes: in particular. If these turn
 out to be slow, this may be detrimental to drawing performance.
*/
@interface DKBSPIndexTree : NSObject {
@protected
	NSMutableArray* mLeaves;
	NSMutableArray* mNodes;
	NSMutableIndexSet* mResults;
	NSSize mCanvasSize;
	DKBSPOperation mOp;
	NSUInteger mOpIndex;
	NSBezierPath* mDebugPath;
}

+ (Class)leafClass;

- (id)initWithCanvasSize:(NSSize)size depth:(NSUInteger)depth;
- (NSSize)canvasSize;

- (void)setDepth:(NSUInteger)depth;
- (NSUInteger)countOfLeaves;

- (void)insertItemIndex:(NSUInteger)idx withRect:(NSRect)rect;
- (void)removeItemIndex:(NSUInteger)idx withRect:(NSRect)rect;

- (NSIndexSet*)itemsIntersectingRects:(const NSRect*)rects count:(NSUInteger)count;
- (NSIndexSet*)itemsIntersectingRect:(NSRect)rect;
- (NSIndexSet*)itemsIntersectingPoint:(NSPoint)point;

- (void)shiftIndexesStartingAtIndex:(NSUInteger)startIndex by:(NSInteger)delta;

- (NSBezierPath*)debugStorageDivisions;

@end

#define kDKBSPSlack 48
#define kDKMinimumDepth 10U
#define kDKMaximumDepth 0U // set 0 for no limit
