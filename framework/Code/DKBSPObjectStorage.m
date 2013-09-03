///**********************************************************************************************************************************
///  DKBSPObjectStorage.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 03/01/2009.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKBSPObjectStorage.h"
#import "LogEvent.h"


// utility functions:

static inline NSUInteger depthForObjectCount( NSUInteger n )
{
    return  ( n > 0? MAX((NSUInteger) _CGFloatCeil(_CGFloatLog((CGFloat) n)) / _CGFloatLog(2.0f), kDKMinimumDepth ) : 0 );
}

static inline NSUInteger childNodeAtIndex( NSUInteger nodeIndex )
{
	return (nodeIndex << 1) + 1;
}

@interface DKBSPObjectStorage (Private)

- (void)			setDepthAndLoadTree:(NSUInteger) aDepth;
- (void)			loadBSPTree;
- (BOOL)			checkForTreeRebuild;

@end

#pragma mark -

@implementation DKBSPObjectStorage


- (void)					setTreeDepth:(NSUInteger) aDepth
{
	// intended to be set when the storage is created. Defaults to 0, meaning that the tree is dynamically rebuilt when needed
	// as the number of objects changes. If this is set to a value other than 0, the tree is rebuilt immediately, otherwise it
	// is rebuilt if needed when objects are added/removed.
	
	if( aDepth != mTreeDepth )
	{
		mTreeDepth = aDepth;
		
		if( mTreeDepth > 0 )
			[self setDepthAndLoadTree:mTreeDepth];
	}
}


- (id)						tree
{
	return mTree;
}


- (NSArray*)				objectsIntersectingRect:(NSRect) aRect inView:(NSView*) aView options:(DKObjectStorageOptions) options
{
#pragma unused(options)
	
	NSIndexSet* indexes;
	
	if( aView )
	{
		const NSRect*	rects;
		NSInteger				count;
		
		[aView getRectsBeingDrawn:&rects count:&count];
		indexes = [mTree itemsIntersectingRects:rects count:count];
	}
	else
		indexes = [mTree itemsIntersectingRect:aRect];
	
	// ignore the options flags for now
	// weed out any false positives which we don't need to draw. This is fairly common when the depth is low and the canvas isn't
	// very finely divided. As depth increases this effect is diminished
	
	NSEnumerator*			iter = [[[self objects] objectsAtIndexes:indexes] objectEnumerator];
	id<DKStorableObject>	obj;
	NSMutableArray*			array = [NSMutableArray array];
	
	while(( obj = [iter nextObject]))
	{
		if( aView )
		{	
			if([aView needsToDrawRect:[obj bounds]])
				[array addObject:obj];
		}
		else if( NSIntersectsRect( aRect, [obj bounds]))
			[array addObject:obj];
	}
	
	//NSLog(@"returning %d object(s)", [array count]);
	
	return array;
}


- (NSArray*)				objectsContainingPoint:(NSPoint) aPoint
{
	NSIndexSet* indexes = [mTree itemsIntersectingPoint:aPoint];
	
	//NSLog(@"indexes returned for hit: %@", indexes );
	
	NSEnumerator*			iter = [[[self objects] objectsAtIndexes:indexes] objectEnumerator];
	id<DKStorableObject>	obj;
	NSMutableArray*			array = [NSMutableArray array];
	
	while(( obj = [iter nextObject]))
	{
		if( NSPointInRect( aPoint, [obj bounds]))
			[array addObject:obj];
	}

	return array;
}



- (void)					setObjects:(NSArray*) objects
{
	[super setObjects:objects];
	[self setDepthAndLoadTree:mTreeDepth];
}



- (void)					insertObject:(id<DKStorableObject>) obj inObjectsAtIndex:(NSUInteger) indx
{
	[super insertObject:obj inObjectsAtIndex:indx];
	
	if([obj visible])
	{
		if(![self checkForTreeRebuild])
		{
			[mTree shiftIndexesStartingAtIndex:indx by:1];
			[mTree insertItemIndex:indx withRect:[obj bounds]];
		}
	}
}



- (void)					removeObjectFromObjectsAtIndex:(NSUInteger) indx
{
	id<DKStorableObject> obj = [self objectInObjectsAtIndex:indx];
	
	if([obj visible])
	{
		if(![self checkForTreeRebuild])
		{
			[mTree removeItemIndex:indx withRect:[obj bounds]];
			[mTree shiftIndexesStartingAtIndex:indx + 1 by:-1];
		}
	}
	
	[super removeObjectFromObjectsAtIndex:indx];
}



- (void)					replaceObjectInObjectsAtIndex:(NSUInteger) indx withObject:(id<DKStorableObject>) obj
{
	id<DKStorableObject> old = [self objectInObjectsAtIndex:indx];
	if([old visible])
		[mTree removeItemIndex:indx withRect:[old bounds]];
	
	if([obj visible])
		[mTree insertItemIndex:indx withRect:[obj bounds]];
	
	[super replaceObjectInObjectsAtIndex:indx withObject:obj];
}



- (void)					insertObjects:(NSArray*) objs atIndexes:(NSIndexSet*) set
{
	// this may be expensive, as it rebuilds the entire tree due to the extensive renumbering of items
	
	[super insertObjects:objs atIndexes:set];
	
	if(![self checkForTreeRebuild])
		[self setDepthAndLoadTree:mTreeDepth];
}



- (void)					removeObjectsAtIndexes:(NSIndexSet*) set
{
	// this may be expensive, as it rebuilds the entire tree due to the extensive renumbering of items

	[super removeObjectsAtIndexes:set];
	
	if(![self checkForTreeRebuild])
		[self setDepthAndLoadTree:mTreeDepth];
}



- (void)					moveObject:(id<DKStorableObject>) obj toIndex:(NSUInteger) indx
{
	NSUInteger newIdx, oldIdx = [self indexOfObject:obj];
	[super moveObject:obj toIndex:indx];
	
	if([obj visible])
	{
		newIdx = [self indexOfObject:obj];
		
		if( oldIdx != newIdx )
		{
			[mTree removeItemIndex:oldIdx withRect:[obj bounds]];
			[mTree shiftIndexesStartingAtIndex:oldIdx + 1 by:-1];
			[mTree shiftIndexesStartingAtIndex:newIdx by:1];
			[mTree insertItemIndex:newIdx withRect:[obj bounds]];
		}
	}
}



- (void)					object:(id<DKStorableObject>) obj didChangeBoundsFrom:(NSRect) oldBounds
{
	// n.b. only called if the bounds has actually changed, so we don't need to test that again
	
	NSUInteger indx = [self indexOfObject:obj];
	if([obj visible])
	{
		[mTree removeItemIndex:indx withRect:oldBounds];
		[mTree insertItemIndex:indx withRect:[obj bounds]];
	}
}


- (void)					objectDidChangeVisibility:(id<DKStorableObject>) obj
{
	NSUInteger indx = [self indexOfObject:obj];
	
	if([obj visible])
		[mTree insertItemIndex:indx withRect:[obj bounds]];
	else
		[mTree removeItemIndex:indx withRect:[obj bounds]];
}


- (void)					setCanvasSize:(NSSize) size
{
	// rebuilds the BSP tree entirely. Note that this is the only method that creates the tree - it must be called when the storage
	// is first created, and whenever the canvas size changes.
	
	if( !NSEqualSizes( size, [mTree canvasSize]))
	{
		[mTree release];
		
		NSUInteger depth = (mTreeDepth == 0? depthForObjectCount([self countOfObjects]) : mTreeDepth);
		mTree = [[DKBSPIndexTree alloc] initWithCanvasSize:size depth:MAX( depth, kDKMinimumDepth )];
		[self loadBSPTree];
	}
}


- (void)					setDepthAndLoadTree:(NSUInteger) aDepth
{
	NSUInteger depth = (aDepth == 0? MAX(depthForObjectCount([self countOfObjects]), kDKMinimumDepth ) : aDepth);

	[mTree setDepth:MAX( depth, kDKMinimumDepth )];
	[self loadBSPTree];
}


- (void)					loadBSPTree
{
	NSEnumerator*			iter = [[self objects] objectEnumerator];
	id<DKStorableObject>	obj;
	NSUInteger				k = 0;
	
	while(( obj = [iter nextObject]))
	{
		if([obj visible])
			[mTree insertItemIndex:k withRect:[obj bounds]];
		
		++k;
	}
	
	mLastItemCount = k;
	
	//NSLog(@"loaded BSP tree with %d indexes (tree = %@)", k, mTree );
}



- (BOOL)					checkForTreeRebuild
{
	// calculates an optimal tree depth given the current number of items stored. This is done if the depth is
	// initialised to 0. If the depth is different and the item count exceeds the slack value, then the tree is
	// rebuilt with the new depth. If the tree depth is preset to a fixed value, this dynamic resizing is never done.
	// return YES if the tree was rebuilt, NO otherwise
	
	if( mTreeDepth == 0 )
	{
		NSUInteger oldDepth = MAX( depthForObjectCount( mLastItemCount ), kDKMinimumDepth );
		NSUInteger neuDepth = MAX( depthForObjectCount([self countOfObjects]), kDKMinimumDepth );
		
		if([mTree countOfLeaves] == 0 || 
			(oldDepth != neuDepth && ABS((NSInteger) mLastItemCount - (NSInteger)[self countOfObjects]) > kDKBSPSlack ))
		{
			// sufficient cause to rebuild the tree
			
			[mTree setDepth:neuDepth];
			[self loadBSPTree];
			return YES;
		}
	}
	
	return NO;
}



#pragma mark -
#pragma mark - as implementor of the NSCoding protocol

- (id)						initWithCoder:(NSCoder*) aCoder
{
// this method is here solely to support backward compatibility with b5; storage is no longer archived.
	
	[super initWithCoder:aCoder];
	mTreeDepth = [aCoder decodeIntegerForKey:@"DKBSPObjectStorage_treeDepth"];
	[self setCanvasSize:[aCoder decodeSizeForKey:@"DKBSPObjectStorage_canvasSize"]];
	
	return self;
}


#pragma mark -
#pragma mark - as a NSObject

- (void)					dealloc
{
	[mTree release];
	[super dealloc];
}


@end



#pragma mark -

/// node object - only used internally with DKBSPIndexTree

@interface DKBSPNode : NSObject
{
@public
	DKLeafType		mType;
	union
	{
		CGFloat		mOffset;
		NSUInteger	mIndex;
	}u;
}

- (void)			setType:(DKLeafType) aType;
- (DKLeafType)		type;

- (void)			setLeafIndex:(NSUInteger) indx;
- (NSUInteger)		leafIndex;

- (void)			setOffset:(CGFloat) offset;
- (CGFloat)			offset;


@end

#pragma mark -


@implementation DKBSPNode

- (void)			setType:(DKLeafType) aType
{
	mType = aType;
}



- (DKLeafType)		type
{
	return mType;
}




- (void)			setLeafIndex:(NSUInteger) indx
{
	u.mIndex = indx;
}



- (NSUInteger)		leafIndex
{
	return u.mIndex;
}




- (void)			setOffset:(CGFloat) offset
{
	u.mOffset = offset;
}



- (CGFloat)			offset
{
	return u.mOffset;
}






@end

#pragma mark -

@interface DKBSPIndexTree (Private)

- (void)			partition:(NSRect) rect depth:(NSUInteger) depth index:(NSUInteger) indx;
- (void)			recursivelySearchWithRect:(NSRect) rect index:(NSUInteger) indx;
- (void)			recursivelySearchWithPoint:(NSPoint) pt index:(NSUInteger) indx;
- (void)			operateOnLeaf:(id) leaf;
- (void)			removeNodesAndLeaves;
- (void)			allocateLeaves:(NSUInteger) howMany;
- (void)			removeIndex:(NSUInteger) indx;


@end




#pragma mark -


@implementation DKBSPIndexTree


+ (Class)			leafClass
{
	return [NSMutableIndexSet class];
}


- (id)				initWithCanvasSize:(NSSize) size depth:(NSUInteger) depth
{
	self = [super init];
	if( self )
	{
		mCanvasSize = size;
		mNodes = [[NSMutableArray alloc] init];
		mLeaves = [[NSMutableArray alloc] init];
		mResults = [[NSMutableIndexSet alloc] init];
		mDebugPath = [[NSBezierPath alloc] init];
		
		[self setDepth:depth];
	}
	
	return self;
}


- (NSSize)			canvasSize
{
	return mCanvasSize;
}


// a.k.a "initialize"

- (void)			setDepth:(NSUInteger) depth
{
	[self removeNodesAndLeaves];
	
	if( kDKMaximumDepth != 0 )
		depth = MIN( depth, kDKMaximumDepth );
	
	NSUInteger i, nodeCount = (( 1 << ( depth + 1)) - 1);
	
	// prefill the nodes array
	
	for( i = 0; i < nodeCount; ++i )
	{
		DKBSPNode* node = [[DKBSPNode alloc] init];
		[mNodes addObject:node];
		[node release];
	}
	
	[self allocateLeaves:( 1 << depth )];
	
	NSRect canvasRect = NSZeroRect;
	canvasRect.size = [self canvasSize];
	
	[self partition:canvasRect depth:depth index:0];

	LogEvent_( kInfoEvent, @"%@ <%p> (re)inited BSP, size = %@, depth = %d, nodes = %d, leaves = %d", NSStringFromClass([self class]), self, NSStringFromSize( mCanvasSize ), depth, [mNodes count], [mLeaves count] );
}



- (void)			insertItemIndex:(NSUInteger) idx withRect:(NSRect) rect
{
    if ([mNodes count] == 0)
        return;
	
	mOp = kDKOperationInsert;
	mOpIndex = idx;
	[self recursivelySearchWithRect:rect index:0];
	
	//NSLog(@"inserted index = %d, bounds = %@", idx, NSStringFromRect( rect ));
}



- (void)			removeItemIndex:(NSUInteger) idx withRect:(NSRect) rect
{
#pragma unused(rect)
	if ([mNodes count] == 0)
        return;
	/*
	mOp = kDKOperationDelete;
	mOpIndex = idx;
	[self recursivelySearchWithRect:rect index:0];
	 */
	
	[self removeIndex:idx];
}


- (NSIndexSet*)		itemsIntersectingRects:(const NSRect*) rects count:(NSUInteger) count
{
	// this may be used in conjunction with NSView's -getRectsBeingDrawn:count: to find those objects that intersect the non-rectangular update region.
	
    if ([mNodes count] == 0)
        return nil;
	
	mOp = kDKOperationAccumulate;
	[mResults removeAllIndexes];

	NSUInteger i;
	
	for( i = 0; i < count; ++i )
		[self recursivelySearchWithRect:rects[i] index:0];
	
	return mResults;
}


- (NSIndexSet*)		itemsIntersectingRect:(NSRect) rect
{
    if ([mNodes count] == 0)
        return nil;
	
	mOp = kDKOperationAccumulate;
	[mResults removeAllIndexes];

	[self recursivelySearchWithRect:rect index:0];
	return mResults;
}



- (NSIndexSet*)		itemsIntersectingPoint:(NSPoint) point
{
    if ([mNodes count] == 0)
        return nil;
	
	mOp = kDKOperationAccumulate;
	[mResults removeAllIndexes];
	
	[self recursivelySearchWithPoint:point index:0];
	return mResults;
}




- (NSUInteger)		countOfLeaves
{
	return [mLeaves count];
}



- (void)			shiftIndexesStartingAtIndex:(NSUInteger) startIndex by:(NSInteger) delta
{
	// when an item is inserted or removed from the main array, all indexes above it will change. This method keeps the tree in synch by
	// incrementing or decrementing the stored indices to match.
	
	NSEnumerator*		iter = [mLeaves objectEnumerator];
	NSMutableIndexSet*	leafSet;
	
	while(( leafSet = [iter nextObject]))
		[leafSet shiftIndexesStartingAtIndex:startIndex by:delta];
	
}


- (NSBezierPath*)	debugStorageDivisions
{
	// returns a path consisting of all the BSP rect divisions
	
	return mDebugPath;
}






#pragma mark -
#pragma mark - private

static NSUInteger sLeafCount = 0;

- (void)			partition:(NSRect) rect depth:(NSUInteger) depth index:(NSUInteger) indx
{
	// recursively subdivide the total canvas size into equal halves in alternating horizontal and vertical directions.
	// This is done once when the tree is built or rebuilt.
	
	DKBSPNode* node = [mNodes objectAtIndex:indx];
	
	if( indx == 0 )
	{
		[node setType:kNodeHorizontal];
		[node setOffset:NSMidX( rect )];
		sLeafCount = 0;
		
		[mDebugPath removeAllPoints];
	}
	
	[mDebugPath appendBezierPathWithRect:rect];

	if ( depth > 0 )
	{
		DKLeafType	type;
		NSRect		ra, rb;
		CGFloat		oa, ob;
		
		if([node type] == kNodeHorizontal)
		{
			type = kNodeVertical;
			ra = NSMakeRect( NSMinX( rect ), NSMinY( rect ), NSWidth( rect ), NSHeight( rect) * 0.5f);
			rb = NSMakeRect( NSMinX( rect ), NSMaxY( ra ), NSWidth( rect ), NSHeight( rect ) - NSHeight( ra ));
			oa = NSMidX( ra );
			ob = NSMidX( rb );
		}
		else
		{
			type = kNodeHorizontal;
			ra = NSMakeRect( NSMinX( rect ), NSMinY( rect ), NSWidth( rect ) * 0.5f, NSHeight( rect ));
			rb = NSMakeRect( NSMaxX( ra), NSMinY( rect ), NSWidth( rect ) - NSWidth( ra ), NSHeight( rect ));
			oa = NSMidY( ra );
			ob = NSMidY( rb );
		}
		
        NSUInteger chIdx = childNodeAtIndex( indx );
		
        DKBSPNode* child = [mNodes objectAtIndex:chIdx];
		[child setType:type];
		[child setOffset:oa];
		
        child = [mNodes objectAtIndex:chIdx + 1];
        [child setType:type];
		[child setOffset:ob];
		
        [self partition:ra depth:depth - 1 index:chIdx];
        [self partition:rb depth:depth - 1 index:chIdx + 1];
    }
	else
	{
        [node setType:kNodeLeaf];
        [node setLeafIndex:sLeafCount++];
    }
}


// if set to 1, recursive function avoids obj-C message dispatch for slightly more performance

#define qUseImpCaching		1


- (void)			recursivelySearchWithRect:(NSRect) rect index:(NSUInteger) indx
{
#if qUseImpCaching	
	static void(*sfunc)( id, SEL, NSRect, NSUInteger ) = nil;
	
	if ( sfunc == nil )
		sfunc = (void(*)( id, SEL, NSRect, NSUInteger ))[[self class] instanceMethodForSelector:_cmd];
#endif

    DKBSPNode* node = [mNodes objectAtIndex:indx];
    NSUInteger subnode = childNodeAtIndex( indx );
	
    switch ( node->mType )
	{
		case kNodeHorizontal:
			if ( NSMinY( rect ) < node->u.mOffset )
			{
				#if qUseImpCaching	
				sfunc( self, _cmd, rect, subnode );
				#else
				[self recursivelySearchWithRect:rect index:subnode];
				#endif
				if( NSMaxY( rect ) >= node->u.mOffset )
					#if qUseImpCaching	
					sfunc( self, _cmd, rect, subnode + 1 );
					#else
					[self recursivelySearchWithRect:rect index:subnode + 1];
					#endif
			}
			else
				#if qUseImpCaching	
				sfunc( self, _cmd, rect, subnode + 1 );
				#else
				[self recursivelySearchWithRect:rect index:subnode + 1];
				#endif
			break;
			
		case kNodeVertical:
			if ( NSMinX( rect ) < node->u.mOffset )
			{
				#if qUseImpCaching	
				sfunc( self, _cmd, rect, subnode );
				#else
				[self recursivelySearchWithRect:rect index:subnode];
				#endif
				if( NSMaxX( rect ) >= node->u.mOffset )
					#if qUseImpCaching	
					sfunc( self, _cmd, rect, subnode + 1 );
					#else
					[self recursivelySearchWithRect:rect index:subnode + 1];
					#endif
			}
			else
				#if qUseImpCaching	
				sfunc( self, _cmd, rect, subnode + 1 );
				#else
				[self recursivelySearchWithRect:rect index:subnode + 1];
				#endif
			break;
			
		case kNodeLeaf:
			[self operateOnLeaf:[mLeaves objectAtIndex:node->u.mIndex]];
			break;
			
		default:
			break;
    }
}



- (void)			recursivelySearchWithPoint:(NSPoint) pt index:(NSUInteger) indx
{
    DKBSPNode* node = [mNodes objectAtIndex:indx];
    NSUInteger subnode = childNodeAtIndex( indx );
	
    switch ([node type])
	{
		case kNodeLeaf:
			[self operateOnLeaf:[mLeaves objectAtIndex:[node leafIndex]]];
			break;
			
		case kNodeVertical:
			if ( pt.x < [node offset])
				[self recursivelySearchWithPoint:pt index:subnode];
			else
				[self recursivelySearchWithPoint:pt index:subnode + 1];
			break;
			
		case kNodeHorizontal:
			if ( pt.y < [node offset])
				[self recursivelySearchWithPoint:pt index:subnode];
			else
				[self recursivelySearchWithPoint:pt index:subnode + 1];
			break;
			
		default:
			break;
    }
}


- (void)			operateOnLeaf:(id) leaf;
{
	// <leaf> is a pointer to the NSMutableIndexSet at the leaf
	
	switch( mOp )
	{
		case kDKOperationInsert:
			[leaf addIndex:mOpIndex];
			break;
			
		case kDKOperationDelete:
			[leaf removeIndex:mOpIndex];
			break;
			
		case kDKOperationAccumulate:
			[mResults addIndexes:leaf];
			break;
			
		default:
			break;
	}
}


- (void)			removeNodesAndLeaves
{
	[mNodes removeAllObjects];
	[mLeaves removeAllObjects];
}


- (void)			allocateLeaves:(NSUInteger) howMany
{
	// prefill the leaves array, which is an array of whatever is returned by +leafClass
	
	NSUInteger i;
	
	for( i = 0; i < howMany; ++i )
	{
		id leaf = [[[[self class] leafClass] alloc] init];
		[mLeaves addObject:leaf];
		[leaf release];
	}
}


- (void)			removeIndex:(NSUInteger) indx
{
	NSEnumerator* iter = [mLeaves objectEnumerator];
	NSMutableIndexSet* is;
	
	while(( is = [iter nextObject]))
		[is removeIndex:indx];
}


#pragma mark -
#pragma mark - as a NSObject


- (void)			dealloc
{
	[mNodes release];
	[mLeaves release];
	[mResults release];
	[mDebugPath release];
	
	[super dealloc];
}


- (NSString*)		description
{
	// warning: description string can be very large, as it enumerates the leaves
	
	return [NSString stringWithFormat:@"<%@ %p>, %ld leaves = %@", NSStringFromClass([self class]), self, (long)[self countOfLeaves], mLeaves];
}

@end


