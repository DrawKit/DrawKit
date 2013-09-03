//
//  DKBSPDirectObjectStorage.m
//  GCDrawKit
//
//  Created by graham on 15/01/2009.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import "DKBSPDirectObjectStorage.h"


// if this is set to 1, various iterations are done using the much faster CFArrayApplyFunction and CFArraySortValues methods

#define USE_CF_APPLIER		1


// utility functions:

static inline NSUInteger depthForObjectCount( NSUInteger n )
{
    return  ( n > 0? MAX((NSUInteger) _CGFloatCeil(_CGFloatLog((CGFloat) n)) / _CGFloatLog(2.0f), kDKMinimumDepth ) : 0 );
}

static inline NSUInteger childNodeAtIndex( NSUInteger nodeIndex )
{
	return (nodeIndex << 1) + 1;
}


@interface DKBSPDirectObjectStorage (Private)

- (void)					sortObjectsByZ:(NSMutableArray*) objects;
- (void)					renumberObjectsFromIndex:(NSUInteger) indx;
- (void)					unmarkAll:(NSArray*) objects;
- (BOOL)					checkForTreeRebuild;
- (void)					loadBSPTree;
- (void)					setAutoRebuildEnable:(BOOL) enable;

@end

#pragma mark -


@implementation DKBSPDirectObjectStorage

- (void)					setTreeDepth:(NSUInteger) aDepth
{
	// intended to be set when the storage is created. Defaults to 0, meaning that the tree is dynamically rebuilt when needed
	// as the number of objects changes. If this is set to a value other than 0, the tree is rebuilt immediately, otherwise it
	// is rebuilt if needed when objects are added/removed.
	
	if( aDepth != mTreeDepth )
	{
		mTreeDepth = aDepth;
		
		if( mTreeDepth > 0 )
		{
			[mTree setDepth:mTreeDepth];
			[self loadBSPTree];
		}
	}
}

- (id)				tree
{
	return mTree;
}	


- (NSArray*)				objectsIntersectingRect:(NSRect) aRect inView:(NSView*) aView options:(DKObjectStorageOptions) options
{
#pragma unused(options)
	
	NSMutableArray* results;
	
	if( aView )
	{
		const NSRect*	rects;
		NSInteger				count;
		
		[aView getRectsBeingDrawn:&rects count:&count];
		results = [mTree objectsIntersectingRects:rects count:count inView:aView];
	}
	else
		results = [mTree objectsIntersectingRect:aRect];
	
	// the final results need to be sorted into Z-order unless 'relaxed' flag set
	
	if(( options & kDKZOrderMayBeRelaxed ) == 0 )
		[self sortObjectsByZ:results];
	
	[self unmarkAll:results];
	
	//NSLog(@"returning %d object(s)", [results count]);
	
	// warning, the results returned is the actual mutable array owned by the tree. This is for performance reasons. The client should not
	// expect the array content to remain stable across each event loop. The client must make a copy if they wish to keep this list (in practice unlikely).
	
	return results;
}


- (NSArray*)				objectsContainingPoint:(NSPoint) aPoint
{
	NSMutableArray* objects = [mTree objectsIntersectingPoint:aPoint];
		
	[self sortObjectsByZ:objects];
	[self unmarkAll:objects];
	return objects;
}


- (void)					setObjects:(NSArray*) objects
{
	[[self objects] makeObjectsPerformSelector:@selector(setStorage:) withObject:nil];
	[super setObjects:objects];
	[self loadBSPTree];
}


- (void)					insertObject:(id<DKStorableObject>) obj inObjectsAtIndex:(NSUInteger) indx
{
	NSAssert( obj != nil, @"can't insert a nil object");
	
	if([obj conformsToProtocol:@protocol(DKStorableObject)])
	{
		[super insertObject:obj inObjectsAtIndex:indx];
		[self renumberObjectsFromIndex:indx];
		[obj setStorage:self];
		
		if( ![self checkForTreeRebuild])
			[mTree insertItem:obj withRect:[obj bounds]];
		
		//NSLog(@"inserted %@, index = %d", obj, indx );
	}
}


- (void)					removeObjectFromObjectsAtIndex:(NSUInteger) indx
{
	id<DKStorableObject> obj = [self objectInObjectsAtIndex:indx];
	
	if( obj )
	{
		//NSLog(@"will remove %@, index = %d", obj, indx ); 
		
		NSAssert1([obj index] == indx, @"index mismatch when removing object from storage, obj = %@", obj );
		
		[obj retain];
		
		[super removeObjectFromObjectsAtIndex:indx];
		[self renumberObjectsFromIndex:indx];
		[obj setStorage:nil];
		
		if( ![self checkForTreeRebuild])
			[mTree removeItem:obj withRect:[obj bounds]];
		
		[obj release];
	}
}

				
- (void)					replaceObjectInObjectsAtIndex:(NSUInteger) indx withObject:(id<DKStorableObject>) obj
{
	NSAssert( obj != nil, @"cannot replace an object with nil");
	
	id<DKStorableObject> old = [self objectInObjectsAtIndex:indx];
	
	if(( old != obj ) && [obj conformsToProtocol:@protocol(DKStorableObject)])
	{
		if( old )
		{
			NSAssert1([old index] == indx, @"index mismatch when replacing object in storage, obj = %@", old );
			[mTree removeItem:old withRect:[old bounds]];
		}
		
		[obj setIndex:indx];
		[super replaceObjectInObjectsAtIndex:indx withObject:obj];
		[mTree insertItem:obj withRect:[obj bounds]];
	}
}


- (void)					insertObjects:(NSArray*) objs atIndexes:(NSIndexSet*) set
{
	NSAssert(objs != nil, @"objects were nil in insertObjects:atIndexes");
	NSAssert( set != nil, @"set was nil in insertObjects:atIndexes");
	NSAssert([objs count] == [set count], @"objects and set counts do not agree");
	
	// because this could potentially insert a lot of objects, the BSP tree needs to be sized properly in advance, rather than
	// rely on dynamic resizing which can add up.
	
	NSUInteger neededDepth = MAX( depthForObjectCount([self countOfObjects] + [set count]), kDKMinimumDepth );
	[mTree setDepth:neededDepth];
	[self loadBSPTree];
	mLastItemCount = [self countOfObjects] + [set count];
	
	[self setAutoRebuildEnable:NO];
	
	NSUInteger ix, k = 0;
	id<DKStorableObject> obj;
	
	ix = [set firstIndex];
	
	while( ix != NSNotFound )
	{
		obj = [objs objectAtIndex:k++];
		[self insertObject:obj inObjectsAtIndex:ix];
		
		ix = [set indexGreaterThanIndex:ix];
	}
	
	[self setAutoRebuildEnable:YES];
}

								
- (void)					removeObjectsAtIndexes:(NSIndexSet*) set
{
	NSAssert( set != nil, @"indexes were nil");
	
	if([set count] > 0 )
	{
		//NSLog(@"removing objects at indexes: %@", set );
		
		NSUInteger ix = [set firstIndex];
		id<DKStorableObject> obj;
		
		while( ix != NSNotFound )
		{
			obj = [[self objects] objectAtIndex:ix];
			
			[obj setStorage:nil];
			[mTree removeItem:obj withRect:[obj bounds]];
			
			ix = [set indexGreaterThanIndex:ix];
		}
		
		[super removeObjectsAtIndexes:set];
		[self renumberObjectsFromIndex:[set firstIndex]];
	}
}


- (BOOL)					containsObject:(id<DKStorableObject>) object
{
	// for a quick answer, return YES if the storage is set to self
	
	return [object storage] == self;
}


- (void)					moveObject:(id<DKStorableObject>) obj toIndex:(NSUInteger) indx
{
	NSUInteger oldIndex = [obj index];
	
	if( oldIndex != indx )
	{
		[super moveObject:obj toIndex:indx];
		[self renumberObjectsFromIndex:MIN( oldIndex, indx )];
	}
}


- (void)					object:(id<DKStorableObject>) obj didChangeBoundsFrom:(NSRect) oldBounds
{
	[obj retain];
	[mTree removeItem:obj withRect:oldBounds];
	[mTree insertItem:obj withRect:[obj bounds]];
	[obj release];
}


- (void)					setCanvasSize:(NSSize) size
{
	// rebuilds the BSP tree entirely. Note that this is the only method that creates the tree - it must be called when the storage
	// is first created, and whenever the canvas size changes. Because the tree is the sole storage for the objects, we retain them in a list
	// then set them again to reload the tree.
	
	if( !NSEqualSizes( size, [mTree canvasSize]))
	{
		NSArray*	objects = [[self objects] retain];
		NSUInteger depth = (mTreeDepth == 0? depthForObjectCount([objects count]) : mTreeDepth);

		[mTree release];
		mTree = [[DKBSPDirectTree alloc] initWithCanvasSize:size depth:MAX( depth, kDKMinimumDepth )];
		
		[self setObjects:objects];
		[objects release];
	}
}

#pragma mark -

static NSComparisonResult zComparisonFunc( id<DKStorableObject> a, id<DKStorableObject> b, void* context )
{
#pragma unused(context)
	
	NSUInteger ia = [a index];
	NSUInteger ib = [b index];
	
	if( ia < ib )
		return NSOrderedAscending;
	else if( ia > ib )
		return NSOrderedDescending;
	else
		return NSOrderedSame;
}


- (void)					sortObjectsByZ:(NSMutableArray*) objects
{
#if USE_CF_APPLIER
	if( objects )
		CFArraySortValues((CFMutableArrayRef) objects, CFRangeMake( 0, [objects count]), (CFComparatorFunction) zComparisonFunc, NULL );
#else
	[objects sortUsingFunction:zComparisonFunc context:NULL];
#endif
}


static void			renumberFunc( const void* value, void* context )
{
	id<DKStorableObject> obj = (id<DKStorableObject>)value;
	[obj setIndex:*(NSUInteger *) context];
	(*(NSUInteger *) context)++;
}


static void			unmarkFunc( const void* value, void* context )
{
#pragma unused(context)
	[(id<DKStorableObject>) value setMarked:NO];
}


- (void)					renumberObjectsFromIndex:(NSUInteger) indx
{
	// renumbers the index value of objects starting from <indx>
	
	if( indx > [self countOfObjects])
		return;
	
	NSUInteger i = indx;
	
#if USE_CF_APPLIER
	CFArrayApplyFunction((CFArrayRef)[self objects], CFRangeMake( indx, [self countOfObjects] - indx), renumberFunc, &i );
#else
	id<DKStorableObject> obj;
	
	for( i = indx; i < [self countOfObjects]; ++i )
	{
		obj = [[self objects] objectAtIndex:i];
		[obj setIndex:i];
	}
#endif
}


- (void)					unmarkAll:(NSArray*) objects
{
#if USE_CF_APPLIER
	if( objects )
		CFArrayApplyFunction((CFArrayRef)objects, CFRangeMake( 0, [objects count]), unmarkFunc, NULL );
#else
	NSEnumerator* iter = [objects objectEnumerator];
	id<DKStorableObject> obj;
	
	while(( obj = [iter nextObject]))
		[obj setMarked:NO];
#endif
}


- (NSBezierPath*)			debugStorageDivisions
{
	// for debugging purposes, returns a path consisting of the BSP rects
	
	return [mTree debugStorageDivisions];
}



- (BOOL)					checkForTreeRebuild
{
	// calculates an optimal tree depth given the current number of items stored. This is done if the depth is
	// initialised to 0. If the depth is different and the item count exceeds the slack value, then the tree is
	// rebuilt with the new depth. If the tree depth is preset to a fixed value, this dynamic resizing is never done.
	// return YES if the tree was rebuilt, NO otherwise
	
	if( mTreeDepth == 0 && mAutoRebuild )
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


- (void)					loadBSPTree
{
	[mTree removeAllObjects];
	
	// reload the tree
	
	NSUInteger				z = 0;
	NSEnumerator*			iter = [[self objects] objectEnumerator];
	id<DKStorableObject>	obj;
	
	while(( obj = [iter nextObject]))
	{
		if([obj conformsToProtocol:@protocol(DKStorableObject)])
		{
			[obj setIndex:z++];
			[obj setStorage:self];
			[mTree insertItem:obj withRect:[obj bounds]];
		}
	}
	
	mLastItemCount = z;
	
	//NSLog(@"loaded BSP tree with %d indexes (tree = %@)", k, mTree );
}


- (void)					setAutoRebuildEnable:(BOOL) enable
{
	mAutoRebuild = enable;
}

#pragma mark -
#pragma mark - as a NSObject

- (id)						init
{
	self = [super init];
	if( self )
	{
		mAutoRebuild = YES;
	}
	
	return self;
}



- (void)					dealloc
{
	[mTree release];
	[super dealloc];
}


- (id)						initWithCoder:(NSCoder*) coder
{
	// this method is here solely to support backward compatibility with b5; storage is no longer archived.

	mTreeDepth = [coder decodeIntegerForKey:@"DKBSPDirectStorage_treeDepth"];
	[self setCanvasSize:[coder decodeSizeForKey:@"DKBSPDirectStorage_canvasSize"]];
	mAutoRebuild = YES;
	[super initWithCoder:coder];
	
	return self;
}



@end

#pragma mark -


@interface DKBSPDirectTree (Private)

// these are implemented by DKBSPIndexTree as private methods, re-prototyped here so
// we can make use of them in this subclass

- (void)			recursivelySearchWithRect:(NSRect) rect index:(NSUInteger) indx;
- (void)			recursivelySearchWithPoint:(NSPoint) pt index:(NSUInteger) indx;
- (void)			operateOnLeaf:(id) leaf;
- (void)			removeObject:(id<DKStorableObject>) obj;


@end

#pragma mark -

@implementation DKBSPDirectTree

- (void)			insertItem:(id<DKStorableObject>) obj withRect:(NSRect) rect
{
    if ([mNodes count] == 0)
        return;
	
	if( obj && !NSIsEmptyRect( rect ))
	{
		mOp = kDKOperationInsert;
		mObj = obj;
		[self recursivelySearchWithRect:rect index:0];
		
		++mObjectCount;
	}
	else
		NSLog(@"didn't insert object '%@' - bad rect (%@)", obj, NSStringFromRect( rect ));
	
	//NSLog(@"inserted obj = %@, bounds = %@", obj, NSStringFromRect( rect ));
}


- (void)			removeItem:(id<DKStorableObject>) obj withRect:(NSRect) rect
{
#pragma unused( rect )
/*
 if ([mNodes count] == 0)
        return;

	if( obj && !NSIsEmptyRect( rect ))
	{
		[obj setMarked:NO];
		mOp = kDKOperationDelete;
		mObj = obj;
		[self recursivelySearchWithRect:rect index:0];
		
		if( mObjectCount > 0 )
			--mObjectCount;
	}
	 */
	
	[self removeObject:obj];
	
	//NSLog(@"removed %@", obj );
}


- (void)			removeAllObjects
{
	NSEnumerator* iter = [mLeaves objectEnumerator];
	NSMutableArray*	leaf;
	
	while(( leaf = [iter nextObject]))
		[leaf removeAllObjects];
	
	mObjectCount = 0;
}


- (NSMutableArray*)	objectsIntersectingRects:(const NSRect*) rects count:(NSUInteger) count inView:aView
{
	// this may be used in conjunction with NSView's -getRectsBeingDrawn:count: to find those objects that intersect the non-rectangular update region.
	
    if ([mNodes count] == 0)
        return nil;
	
	mViewRef = aView;
	mOp = kDKOperationAccumulate;
	[mFoundObjects removeAllObjects];
	
	NSUInteger i;
	
	for( i = 0; i < count; ++i )
		[self recursivelySearchWithRect:rects[i] index:0];
	
	return mFoundObjects;
}


- (NSMutableArray*)	objectsIntersectingRect:(NSRect) rect
{
    if ([mNodes count] == 0)
        return nil;
	
	mRect = rect;
	mViewRef = nil;
	mOp = kDKOperationAccumulate;
	[mFoundObjects removeAllObjects];
	
	[self recursivelySearchWithRect:rect index:0];
	return mFoundObjects;
}


- (NSMutableArray*)	objectsIntersectingPoint:(NSPoint) point
{
    if ([mNodes count] == 0)
        return nil;
	
	mRect = NSMakeRect( point.x, point.y, 1e-3, 1e-3 );
	mOp = kDKOperationAccumulate;
	[mFoundObjects removeAllObjects];
	
	[self recursivelySearchWithPoint:point index:0];

	return mFoundObjects;
}


- (NSUInteger)		count
{
	// returns the number of unique objects in the tree. Note that this value can be unreliable if the client didn't take care (i.e. calling removeItem with a bad object).
	
	return mObjectCount;
}


#pragma mark -
#pragma mark - as a DKBSPIndexTree

+ (Class)			leafClass
{
	return [NSMutableArray class];
}



- (id)				initWithCanvasSize:(NSSize) size depth:(NSUInteger) depth
{
	self = [super initWithCanvasSize:size depth:depth];
	if( self )
	{
		mFoundObjects = [[NSMutableArray alloc] init];
	}
	
	return self;
}



static void			addValueToFoundObjects( const void* value, void* context )
{
	id<DKStorableObject> obj = (id<DKStorableObject>)value;
	
	if(![obj isMarked] && [obj visible])
	{
		DKBSPDirectTree* tree = (DKBSPDirectTree*)context;
		NSView*	view = tree->mViewRef;
		
		// double-check that the view really needs to draw this
		
		if(( view == nil && NSIntersectsRect([obj bounds], tree->mRect )) || [view needsToDrawRect:[obj bounds]])
		{
			[obj setMarked:YES];
			CFArrayAppendValue((CFMutableArrayRef)tree->mFoundObjects, value );
		}
	}
}



- (void)			operateOnLeaf:(id) leaf;
{
	// <leaf> is a pointer to the NSMutableArray at the leaf
	
	switch( mOp )
	{
		case kDKOperationInsert:
			[leaf addObject:mObj];
			break;
			
		case kDKOperationDelete:
			[leaf removeObject:mObj];
			break;
			
		case kDKOperationAccumulate:
		{
#if USE_CF_APPLIER
			CFArrayApplyFunction((CFArrayRef) leaf, CFRangeMake( 0, [leaf count]), addValueToFoundObjects, self );
#else			
			NSEnumerator* iter = [leaf objectEnumerator];
			id<DKStorableObject> anObject;
			
			while(( anObject = [iter nextObject]))
			{
				if(![anObject isMarked] && [anObject visible])
				{
					if(( mViewRef == nil && NSIntersectsRect([anObject bounds], mRect )) || [mViewRef needsToDrawRect:[anObject bounds]])
					{
						[anObject setMarked:YES];
						[mFoundObjects addObject:anObject];
					}
				}
			}
#endif
		}
		break;
			
		default:
			break;
	}
}


- (void)			removeObject:(id<DKStorableObject>) obj;
{
	// removes all references to <obj> from the tree. Ignores its bounds and simply iterates over the leaves removing the object.
	
	NSEnumerator* iter = [mLeaves objectEnumerator];
	NSMutableArray*	leaf;
	
	while(( leaf = [iter nextObject]))
		[leaf removeObject:obj];
	
	if( mObjectCount > 0 )
		mObjectCount--;
}


#pragma mark -
#pragma mark - as a NSObject


- (void)			dealloc
{
	[mFoundObjects release];
	[super dealloc];
}


- (NSString*)		description
{
	return [NSString stringWithFormat:@"<%@ %p>, %ld leaves = %@", NSStringFromClass([self class]), self, (long)[self countOfLeaves], mLeaves];
}


@end
