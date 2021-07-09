/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKLinearObjectStorage.h"
#import "LogEvent.h"

@implementation DKLinearObjectStorage
dispatch_time_t m_ObjectLockTimeOutSeconds = DISPATCH_TIME_FOREVER; // infinite is DISPATCH_TIME_FOREVER

#pragma mark - as implementor of the DKObjectStorage protocol

- (NSArray*)objectsIntersectingRect:(NSRect)aRect inView:(NSView*)aView options:(DKObjectStorageOptions)options
{
	NSMutableArray* temp = [NSMutableArray array];
	NSEnumerator* iter;

	if (options & kDKReverseOrder)
		iter = [[self objects] reverseObjectEnumerator];
	else
		iter = [[self objects] objectEnumerator];

	for (id<DKStorableObject> obj in iter) {
		if ((options & kDKIncludeInvisible) || [obj visible]) {
			if (options & kDKIgnoreUpdateRect) {
				[temp addObject:obj];
			} else {
				NSRect bounds = [obj bounds];

				// if a view was passed, use -needsToDrawRect, otherwise intersection with <rect>

				if (aView) {
					if ([aView needsToDrawRect:bounds])
						[temp addObject:obj];
				} else if (NSIntersectsRect(bounds, aRect))
					[temp addObject:obj];
			}
		}
	}

	return temp;
}

- (NSArray*)objectsContainingPoint:(NSPoint)aPoint
{
	NSRect pr = NSMakeRect(aPoint.x - 0.0005, aPoint.y - 0.0005, 0.001, 0.001);
	return [self objectsIntersectingRect:pr
								  inView:nil
								 options:0];
}

- (void)setObjects:(NSArray<id<DKStorableObject>>*)objects
{
	dispatch_semaphore_wait(m_ObjectLock, m_ObjectLockTimeOutSeconds);
	
	LogEvent_(kReactiveEvent, @"storage setting %lu objects %@", (unsigned long)[objects count], self);

	mObjects = [objects mutableCopy];

	[mObjects makeObjectsPerformSelector:@selector(setStorage:)
							  withObject:self];
	
	dispatch_semaphore_signal(m_ObjectLock);
}

- (NSArray<id<DKStorableObject>>*)objects
{
	dispatch_semaphore_wait(m_ObjectLock, m_ObjectLockTimeOutSeconds);

	NSArray<id<DKStorableObject>>* ret = [mObjects copy];
	
	dispatch_semaphore_signal(m_ObjectLock);
	
	return ret;
}

- (NSUInteger)countOfObjects
{
	return [mObjects count];
}

- (id<DKStorableObject>)objectInObjectsAtIndex:(NSUInteger)indx
{
	NSAssert(indx < [self countOfObjects], @"error - index is beyond bounds");

	dispatch_semaphore_wait(m_ObjectLock, m_ObjectLockTimeOutSeconds);
	
	id<DKStorableObject> ret = [mObjects objectAtIndex:indx];
	
	dispatch_semaphore_signal(m_ObjectLock);
	
	return ret;
}

- (NSArray*)objectsAtIndexes:(NSIndexSet*)set
{
    dispatch_semaphore_wait(m_ObjectLock, m_ObjectLockTimeOutSeconds);

    NSArray* ret = [mObjects objectsAtIndexes:set];
    
    dispatch_semaphore_signal(m_ObjectLock);
    
    return ret;
}

- (void)insertObject:(id<DKStorableObject>)obj inObjectsAtIndex:(NSUInteger)indx
{
	dispatch_semaphore_wait(m_ObjectLock, m_ObjectLockTimeOutSeconds);
	
	NSAssert(obj != nil, @"attempt to add a nil object to the storage");

	if (![mObjects containsObject:obj]) {
		[mObjects insertObject:obj
					   atIndex:indx];
		[obj setStorage:self];
	}
	
	dispatch_semaphore_signal(m_ObjectLock);
}

- (void)removeObjectFromObjectsAtIndex:(NSUInteger)indx
{
	dispatch_semaphore_wait(m_ObjectLock, m_ObjectLockTimeOutSeconds);
	
	NSAssert(indx < [self countOfObjects], @"error - index is beyond bounds");

	id<DKStorableObject> obj = [mObjects objectAtIndex:indx];
	[obj setStorage:nil];
	[mObjects removeObjectAtIndex:indx];
	
	dispatch_semaphore_signal(m_ObjectLock);
}

- (void)replaceObjectInObjectsAtIndex:(NSUInteger)indx withObject:(id<DKStorableObject>)obj
{
	dispatch_semaphore_wait(m_ObjectLock, m_ObjectLockTimeOutSeconds);
	
	NSAssert(obj != nil, @"attempt to add a nil object to the storage (replace)");
	NSAssert(indx < [self countOfObjects], @"error - index is beyond bounds");
	
	id<DKStorableObject> oldObj = [mObjects objectAtIndex:indx];
	[oldObj setStorage:nil];
	[mObjects replaceObjectAtIndex:indx
						withObject:obj];
	[obj setStorage:self];
	
	dispatch_semaphore_signal(m_ObjectLock);
}

- (void)insertObjects:(NSArray*)objs atIndexes:(NSIndexSet*)set
{
	dispatch_semaphore_wait(m_ObjectLock, m_ObjectLockTimeOutSeconds);
	
	NSAssert(objs != nil, @"can't insert a nil array");
	NSAssert(set != nil, @"can't insert - index set was nil");
	NSAssert([objs count] == [set count], @"number of objects does not match number of indexes");

	if ([set count] > 0) {
		[objs makeObjectsPerformSelector:@selector(setStorage:)
							  withObject:self];
		[mObjects insertObjects:objs
					  atIndexes:set];
	}
	
	dispatch_semaphore_signal(m_ObjectLock);
}

- (void)removeObjectsAtIndexes:(NSIndexSet*)set
{
	dispatch_semaphore_wait(m_ObjectLock, m_ObjectLockTimeOutSeconds);
	
	NSAssert(set != nil, @"can't remove objects - index set is nil");

	// sanity check that the count of indexes is less than the list length but not zero

	if ([set count] <= [self countOfObjects] && [set count] > 0) {
		NSArray* objs = [mObjects objectsAtIndexes:set];
		[objs makeObjectsPerformSelector:@selector(setStorage:)
							  withObject:nil];
		[mObjects removeObjectsAtIndexes:set];
	}
	
	dispatch_semaphore_signal(m_ObjectLock);
}

- (BOOL)containsObject:(id<DKStorableObject>)object
{
	dispatch_semaphore_wait(m_ObjectLock, m_ObjectLockTimeOutSeconds);
	
	BOOL ret = [mObjects containsObject:object];
	
	dispatch_semaphore_signal(m_ObjectLock);
	
	return ret;
}

- (NSUInteger)indexOfObject:(id<DKStorableObject>)object
{
	dispatch_semaphore_wait(m_ObjectLock, m_ObjectLockTimeOutSeconds);
	
	NSUInteger ret = [mObjects indexOfObjectIdenticalTo:object];
	
	dispatch_semaphore_signal(m_ObjectLock);
	
	return ret;
}

- (void)moveObject:(id<DKStorableObject>)obj toIndex:(NSUInteger)indx
{
	dispatch_semaphore_wait(m_ObjectLock, m_ObjectLockTimeOutSeconds);
	
	NSAssert(obj != nil, @"cannot move nil object");
	NSAssert([obj storage] == self, @"error - storage doesn't own the object being moved");

	indx = MIN(indx, [self countOfObjects] - 1);

	NSUInteger old = [mObjects indexOfObjectIdenticalTo:obj];

	if (old != indx) {
		[mObjects removeObject:obj];
		[mObjects insertObject:obj
					   atIndex:indx];
	}
	
	dispatch_semaphore_signal(m_ObjectLock);
}

- (void)object:(id<DKStorableObject>)obj didChangeBoundsFrom:(NSRect)oldBounds
{
#pragma unused(obj, oldBounds)

	// linear storage does't care about an object's bounds, but other spatially-partitioned storage may do. This method
	// can be used to re-store the object when it is resized or moved

	//NSLog(@"bounds change from: %@, old = %@, new = %@", obj, NSStringFromRect( oldBounds ), NSStringFromRect([obj bounds]));
}

- (void)objectDidChangeVisibility:(id<DKStorableObject>)obj
{
#pragma unused(obj)
}

- (void)setCanvasSize:(NSSize)size
{
#pragma unused(size)
}

#pragma mark -
#pragma mark - as implementor of the NSCoding protocol

- (instancetype)initWithCoder:(NSCoder*)aCoder
{
	// b6: for backward comptibility only

	[self setObjects:[aCoder decodeObjectForKey:@"DKLinearStorage_objects"]];
	return self;
}

- (void)encodeWithCoder:(NSCoder*)aCoder
{
#pragma unused(aCoder)

	// this shouldn't occur, but just in case

	[NSException raise:NSInternalInconsistencyException
				format:@"Archiving of a layer's storage is no longer supported (or done) - please revise your code"];

	//[aCoder encodeObject:[self objects] forKey:@"DKLinearStorage_objects"];
}

#pragma mark -
#pragma mark - as a NSObject

- (instancetype)init
{
	self = [super init];
	if (self) {
		mObjects = [[NSMutableArray alloc] init];
		m_ObjectLock = dispatch_semaphore_create(1);
	}

	return self;
}

- (void)dealloc
{
    dispatch_semaphore_wait(m_ObjectLock, m_ObjectLockTimeOutSeconds);
    
    [mObjects makeObjectsPerformSelector:@selector(setStorage:)
							  withObject:nil];

    dispatch_semaphore_signal(m_ObjectLock);
}

@end
