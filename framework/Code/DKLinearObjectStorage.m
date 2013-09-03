///**********************************************************************************************************************************
///  DKLinearObjectStorage.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 03/01/2009.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKLinearObjectStorage.h"
#import "LogEvent.h"

@implementation DKLinearObjectStorage

#pragma mark - as implementor of the DKObjectStorage protocol

- (NSArray*)				objectsIntersectingRect:(NSRect) aRect inView:(NSView*) aView options:(DKObjectStorageOptions) options
{
	NSMutableArray*			temp = [NSMutableArray array];
	NSEnumerator*			iter;
	id<DKStorableObject>	obj;
	NSRect					bounds;
	
	if( options & kDKReverseOrder )
		iter = [[self objects] reverseObjectEnumerator];
	else
		iter = [[self objects] objectEnumerator];
	
	while(( obj = [iter nextObject]))
	{
		if(( options & kDKIncludeInvisible ) || [obj visible])
		{
			if( options & kDKIgnoreUpdateRect )
				[temp addObject:obj];
			else
			{
				bounds = [obj bounds];
				
				// if a view was passed, use -needsToDrawRect, otherwise intersection with <rect>
				
				if( aView )
				{
					if([aView needsToDrawRect:bounds])
						[temp addObject:obj];
				}
				else if( NSIntersectsRect( bounds, aRect ))
					[temp addObject:obj];
			}
		}
	}
	
	return temp;
}


- (NSArray*)				objectsContainingPoint:(NSPoint) aPoint
{
	NSRect pr = NSMakeRect( aPoint.x - 0.0005, aPoint.y - 0.0005, 0.001, 0.001 );
	return [self objectsIntersectingRect:pr inView:nil options:0];
}


- (void)					setObjects:(NSArray*) objects
{
	LogEvent_(kReactiveEvent, @"storage setting %d objects %@", [objects count], self);
	
	[objects retain];
	[mObjects release];
	mObjects = [objects mutableCopy];
	[objects release];
	
	[mObjects makeObjectsPerformSelector:@selector(setStorage:) withObject:self];
}


- (NSArray*)				objects
{
	return mObjects;
}


- (NSUInteger)				countOfObjects
{
	return [[self objects] count];
}


- (id<DKStorableObject>)	objectInObjectsAtIndex:(NSUInteger) indx
{
	NSAssert( indx < [self countOfObjects], @"error - index is beyond bounds");
	
	return [[self objects] objectAtIndex:indx];
}


- (NSArray*)				objectsAtIndexes:(NSIndexSet*) set
{
	return [[self objects] objectsAtIndexes:set];
}


- (void)					insertObject:(id<DKStorableObject>) obj inObjectsAtIndex:(NSUInteger) indx
{
	NSAssert( obj != nil, @"attempt to add a nil object to the storage" );
	
	if(![[self objects] containsObject:obj])
	{
		[mObjects insertObject:obj atIndex:indx];
		[obj setStorage:self];
	}
}


- (void)					removeObjectFromObjectsAtIndex:(NSUInteger) indx
{
	NSAssert( indx < [self countOfObjects], @"error - index is beyond bounds");
	
	id<DKStorableObject> obj = [mObjects objectAtIndex:indx];
	[obj setStorage:nil];
	[mObjects removeObjectAtIndex:indx];
}


- (void)					replaceObjectInObjectsAtIndex:(NSUInteger) indx withObject:(id<DKStorableObject>) obj
{
	NSAssert( obj != nil, @"attempt to add a nil object to the storage (replace)" );
	NSAssert( indx < [self countOfObjects], @"error - index is beyond bounds");
	
	id<DKStorableObject> oldObj = [mObjects objectAtIndex:indx];
	[oldObj setStorage:nil];
	[mObjects replaceObjectAtIndex:indx withObject:obj];
	[obj setStorage:self];
}


- (void)					insertObjects:(NSArray*) objs atIndexes:(NSIndexSet*) set
{
	NSAssert( objs != nil, @"can't insert a nil array");
	NSAssert( set != nil, @"can't insert - index set was nil");
	NSAssert([objs count] == [set count], @"number of objects does not match number of indexes");
	
	if ([set count] > 0)
	{
		[objs makeObjectsPerformSelector:@selector(setStorage:) withObject:self];
		[mObjects insertObjects:objs atIndexes:set];
	}
}


- (void)					removeObjectsAtIndexes:(NSIndexSet*) set
{
	NSAssert( set != nil, @"can't remove objects - index set is nil");
	
	// sanity check that the count of indexes is less than the list length but not zero
	
	if ([set count] <= [self countOfObjects] && [set count] > 0)
	{
		NSArray* objs = [mObjects objectsAtIndexes:set];
		[objs makeObjectsPerformSelector:@selector(setStorage:) withObject:nil];
		[mObjects removeObjectsAtIndexes:set];
	}
}


- (BOOL)					containsObject:(id<DKStorableObject>) object
{
	return [mObjects containsObject:object];
}


- (NSUInteger)				indexOfObject:(id<DKStorableObject>) object
{
	return [[self objects] indexOfObjectIdenticalTo:object];
}


- (void)					moveObject:(id<DKStorableObject>) obj toIndex:(NSUInteger) indx
{
	NSAssert( obj != nil, @"cannot move nil object");
	NSAssert([obj storage] == self, @"error - storage doesn't own the object being moved");
	
	indx = MIN(indx, [self countOfObjects] - 1);
	
	NSUInteger old = [self indexOfObject:obj];
	
	if ( old != indx )
	{
		[obj retain];
		[mObjects removeObject:obj];
		[mObjects insertObject:obj atIndex:indx];
		[obj release];
	}
}



- (void)					object:(id<DKStorableObject>) obj didChangeBoundsFrom:(NSRect) oldBounds
{
#pragma unused(obj, oldBounds)
	
	// linear storage does't care about an object's bounds, but other spatially-partitioned storage may do. This method
	// can be used to re-store the object when it is resized or moved 
	
	//NSLog(@"bounds change from: %@, old = %@, new = %@", obj, NSStringFromRect( oldBounds ), NSStringFromRect([obj bounds]));
}


- (void)					objectDidChangeVisibility:(id<DKStorableObject>) obj
{
#pragma unused(obj)	
}


- (void)					setCanvasSize:(NSSize) size
{
#pragma unused(size)	
}



#pragma mark -
#pragma mark - as implementor of the NSCoding protocol

- (id)						initWithCoder:(NSCoder*) aCoder
{
	// b6: for backward comptibility only
	
	[self setObjects:[aCoder decodeObjectForKey:@"DKLinearStorage_objects"]];
	return self;
}


- (void)					encodeWithCoder:(NSCoder*) aCoder
{
#pragma unused(aCoder)
	
	// this shouldn't occur, but just in case
	
	[NSException raise:NSInternalInconsistencyException format:@"Archiving of a layer's storage is no longer supported (or done) - please revise your code"];
	
	//[aCoder encodeObject:[self objects] forKey:@"DKLinearStorage_objects"];
}



#pragma mark -
#pragma mark - as a NSObject

- (id)						init
{
	self = [super init];
	if( self )
	{
		mObjects = [[NSMutableArray alloc] init];
	}
	
	return self;
}


- (void)					dealloc
{
	[[self objects] makeObjectsPerformSelector:@selector(setStorage:) withObject:nil];
	[mObjects release];
	[super dealloc];
}

@end
