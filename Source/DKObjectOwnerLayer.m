/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKObjectOwnerLayer.h"
#import "DKBSPObjectStorage.h"
#import "DKDrawKitMacros.h"
#import "DKDrawing.h"
#import "DKDrawingView.h"
#import "DKGeometryUtilities.h"
#import "DKGridLayer.h"
#import "DKImageDataManager.h"
#import "DKImageShape.h"
#import "DKLayer+Metadata.h"
#import "DKPasteboardInfo.h"
#import "DKSelectionPDFView.h"
#import "DKStyle.h"
#import "DKTextShape.h"
#import "DKUndoManager.h"
#import "LogEvent.h"

// constants

NSString* const kDKLayerWillAddObject = @"kDKLayerWillAddObject";
NSString* const kDKLayerDidAddObject = @"kDKLayerDidAddObject";
NSString* const kDKLayerWillRemoveObject = @"kDKLayerWillRemoveObject";
NSString* const kDKLayerDidRemoveObject = @"kDKLayerDidRemoveObject";

@interface DKObjectOwnerLayer ()
- (void)updateCache;
- (void)invalidateCache;
@end

static Class sStorageClass = nil;
static DKLayerCacheOption sDefaultCacheOption = kDKLayerCacheNone;

@implementation DKObjectOwnerLayer
#pragma mark As a DKObjectOwnerLayer

+ (void)setDefaultLayerCacheOption:(DKLayerCacheOption)option
{
	sDefaultCacheOption = option;
}

+ (DKLayerCacheOption)defaultLayerCacheOption
{
	return sDefaultCacheOption;
}

+ (void)setStorageClass:(Class)aClass
{
	if ([aClass conformsToProtocol:@protocol(DKObjectStorage)] || aClass == nil)
		sStorageClass = aClass;
}

+ (Class)storageClass
{
	if (sStorageClass == nil)
		return [DKLinearObjectStorage class]; //[DKBSPObjectStorage class];
	else
		return sStorageClass;
}

- (void)setStorage:(id<DKObjectStorage>)storage
{
	if ([storage conformsToProtocol:@protocol(DKObjectStorage)]) {
		LogEvent_(kReactiveEvent, @"owner layer (%@) setting storage = %@", self, storage);

		mStorage = storage;
	}
}

@synthesize storage = mStorage;

#pragma mark - the list of objects

- (void)setObjects:(NSArray*)objs
{
	NSAssert(objs != nil, @"array of objects cannot be nil");

	if (objs != [self objects]) {
		[self setRulerMarkerUpdatesEnabled:NO];
		[[self undoManager] registerUndoWithTarget:self
										  selector:@selector(setObjects:)
											object:[self objects]];
		[self refreshAllObjects];
		[[self objects] makeObjectsPerformSelector:@selector(setContainer:)
										withObject:nil];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerWillAddObject
															object:self];

		[[self storage] setObjects:objs];

		[[self objects] makeObjectsPerformSelector:@selector(setContainer:)
										withObject:self];
		[[self objects] makeObjectsPerformSelector:@selector(objectWasAddedToLayer:)
										withObject:self];
		[self refreshAllObjects];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerDidAddObject
															object:self];
		[self setRulerMarkerUpdatesEnabled:YES];
	}
}

- (NSArray*)objects
{
	return [[[self storage] objects] copy];
}

- (NSArray*)availableObjects
{
	return [self availableObjectsInRect:[[self drawing] interior]];
}

- (NSArray*)availableObjectsInRect:(NSRect)aRect
{
	// an available object is one that is both visible and not locked. Stacking order is maintained.

	NSMutableArray* ao = [[NSMutableArray alloc] init];

	if (![self lockedOrHidden]) {
		NSEnumerator* iter = [self objectEnumeratorForUpdateRect:aRect
														  inView:nil];
		for (DKDrawableObject* od in iter) {
			if ([od visible] && ![od locked]) {
				[ao addObject:od];
			}
		}
	}
	return ao;
}

- (NSArray*)availableObjectsOfClass:(Class)aClass
{
	NSMutableArray* ao = [[NSMutableArray alloc] init];

	if (![self lockedOrHidden]) {
		NSEnumerator* iter = [[self objects] objectEnumerator];

		for (DKDrawableObject* od in iter) {
			if ([od visible] && ![od locked] && [od isKindOfClass:aClass]) {
				[ao addObject:od];
			}
		}
	}
	return ao;
}

- (NSArray*)visibleObjects
{
	return [self visibleObjectsInRect:[[self drawing] interior]];
}

- (NSArray*)visibleObjectsInRect:(NSRect)aRect
{
	NSMutableArray* vo = nil;

	if ([self visible]) {
		vo = [[NSMutableArray alloc] init];

		NSEnumerator* iter = [self objectEnumeratorForUpdateRect:aRect
														  inView:nil];
		for (DKDrawableObject* od in iter) {
			if ([od visible]) {
				[vo addObject:od];
			}
		}
	}

	return vo;
}

- (NSArray*)objectsWithStyle:(DKStyle*)style
{
	NSMutableArray* ao = [[NSMutableArray alloc] init];
	NSString* key = [style uniqueKey];

	for (DKDrawableObject* od in self.objects) {
		if ([[[od style] uniqueKey] isEqualToString:key])
			[ao addObject:od];
	}

	return ao;
}

- (NSArray*)objectsReturning:(NSInteger)answer toSelector:(SEL)selector
{
	NSMutableArray* result = [NSMutableArray array];

	for (id o in [self objects]) {
		if ([o respondsToSelector:selector]) {
			NSInteger rval = 0;

			NSInvocation* inv = [NSInvocation invocationWithMethodSignature:[o methodSignatureForSelector:selector]];

			[inv setSelector:selector];
			[inv invokeWithTarget:o];

			if ([[inv methodSignature] methodReturnLength] <= sizeof(NSInteger))
				[inv getReturnValue:&rval];

			if (rval == answer)
				[result addObject:o];
		}
	}

	return result;
}

#pragma mark -
#pragma mark - getting objects

- (NSUInteger)countOfObjects
{
	return [[self storage] countOfObjects];
}

- (DKDrawableObject*)objectInObjectsAtIndex:(NSUInteger)indx
{
	NSAssert(indx < [self countOfObjects], @"error - index is beyond bounds");

	return (DKDrawableObject*)[[self storage] objectInObjectsAtIndex:indx];
}

- (DKDrawableObject*)topObject
{
	return [[self objects] lastObject];
}

- (DKDrawableObject*)bottomObject
{
	return [[self objects] firstObject];
}

- (NSUInteger)indexOfObject:(DKDrawableObject*)obj
{
	return [[self storage] indexOfObject:obj];
}

#pragma mark -

- (NSArray*)objectsAtIndexes:(NSIndexSet*)set
{
	return [[self storage] objectsAtIndexes:set];
}

- (NSIndexSet*)indexesOfObjectsInArray:(NSArray*)objs
{
	NSAssert(objs != nil, @"can't get indexes for a nil array");

	NSMutableIndexSet* mset = [[NSMutableIndexSet alloc] init];

	for (DKDrawableObject* o in objs) {
		NSUInteger indx = [[self storage] indexOfObject:o];

		if (indx != NSNotFound)
			[mset addIndex:indx];
	}

	return mset;
}

#pragma mark -
#pragma mark - adding and removing objects(KVC / KVO compliant)

- (void)insertObject:(DKDrawableObject*)obj inObjectsAtIndex:(NSUInteger)indx
{
	NSAssert(obj != nil, @"attempt to add a nil object to the layer");

	LogEvent_(kReactiveEvent, @"inserting %@ at: %lu, count = %lu", obj, (unsigned long)indx, (unsigned long)[self countOfObjects]);

	if (![[self storage] containsObject:obj] && ![self lockedOrHidden]) {
		[[[self undoManager] prepareWithInvocationTarget:self] removeObject:obj];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerWillAddObject
															object:self];
		[[self storage] insertObject:obj
					inObjectsAtIndex:indx];
		[obj setContainer:self];
		[obj notifyVisualChange];
		[obj objectWasAddedToLayer:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerDidAddObject
															object:self];
	}
}

- (void)removeObjectFromObjectsAtIndex:(NSUInteger)indx
{
	NSAssert(indx < [self countOfObjects], @"error - index is beyond bounds");

	if (![self lockedOrHidden]) {
		DKDrawableObject* obj = [self objectInObjectsAtIndex:indx];
		LogEvent_(kReactiveEvent, @"removing object %@, index = %lu", obj, (unsigned long)indx);

		[[[self undoManager] prepareWithInvocationTarget:self] insertObject:obj
														   inObjectsAtIndex:indx];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerWillRemoveObject
															object:self];

		[obj notifyVisualChange];
		[[self storage] removeObjectFromObjectsAtIndex:indx];
		[obj objectWasRemovedFromLayer:self];
		[obj setContainer:nil];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerDidRemoveObject
															object:self];
	}
}

- (void)replaceObjectInObjectsAtIndex:(NSUInteger)indx withObject:(DKDrawableObject*)obj
{
	NSAssert(obj != nil, @"attempt to add a nil object to the layer (replace)");
	NSAssert(indx < [self countOfObjects], @"error - index is beyond bounds");

	if (![self lockedOrHidden]) {
		DKDrawableObject* old = [self objectInObjectsAtIndex:indx];

		[[[self undoManager] prepareWithInvocationTarget:self] replaceObjectInObjectsAtIndex:indx
																				  withObject:old];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerWillRemoveObject
															object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerWillAddObject
															object:self];
		[old notifyVisualChange];
		[old objectWasRemovedFromLayer:self];
		[old setContainer:nil];

		[[self storage] replaceObjectInObjectsAtIndex:indx
										   withObject:obj];
		[obj setContainer:self];
		[obj notifyVisualChange];
		[obj objectWasAddedToLayer:self];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerDidRemoveObject
															object:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerDidAddObject
															object:self];
	}
}

- (void)insertObjects:(NSArray*)objs atIndexes:(NSIndexSet*)set
{
	NSAssert(objs != nil, @"can't insert a nil array");
	NSAssert(set != nil, @"can't insert - index set was nil");
	NSAssert([objs count] == [set count], @"number of objects does not match number of indexes");

	if (![self lockedOrHidden] && [set count] > 0) {
		[[[self undoManager] prepareWithInvocationTarget:self] removeObjectsAtIndexes:set];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerWillAddObject
															object:self];

		[[self storage] insertObjects:objs
							atIndexes:set];

		[objs makeObjectsPerformSelector:@selector(setContainer:)
							  withObject:self];
		[objs makeObjectsPerformSelector:@selector(notifyVisualChange)];
		[objs makeObjectsPerformSelector:@selector(objectWasAddedToLayer:)
							  withObject:self];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerDidAddObject
															object:self];
	}
}

- (void)removeObjectsAtIndexes:(NSIndexSet*)set
{
	NSAssert(set != nil, @"can't remove objects - index set is nil");

	if (![self lockedOrHidden]) {
		// sanity check that the count of indexes is less than the list length but not zero

		if ([set count] <= [self countOfObjects] && [set count] > 0) {
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerWillRemoveObject
																object:self];

			NSArray* objs = [self objectsAtIndexes:set];
			[objs makeObjectsPerformSelector:@selector(notifyVisualChange)];
			[[[self undoManager] prepareWithInvocationTarget:self] insertObjects:objs
																	   atIndexes:set];
			[[self storage] removeObjectsAtIndexes:set];
			[objs makeObjectsPerformSelector:@selector(objectWasRemovedFromLayer:)
								  withObject:self];
			[objs makeObjectsPerformSelector:@selector(setContainer:)
								  withObject:nil];

			[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerDidRemoveObject
																object:self];
		}
	}
}

#pragma mark -
#pragma mark - adding and removing objects(general)

- (void)addObject:(DKDrawableObject*)obj
{
	NSAssert(obj != nil, @"attempt to add a nil object to the layer");

	if (![[self storage] containsObject:obj] && ![self lockedOrHidden])
		[self insertObject:obj
			inObjectsAtIndex:[self countOfObjects]];
}

- (void)addObject:(DKDrawableObject*)obj atIndex:(NSUInteger)indx
{
	NSAssert(obj != nil, @"attempt to add a nil object to the layer");

	if (![[self storage] containsObject:obj] && ![self lockedOrHidden])
		[self insertObject:obj
			inObjectsAtIndex:indx];
}

- (void)addObjectsFromArray:(NSArray*)objs
{
	NSAssert(objs != nil, @"attempt to add a nil array of objects to the layer");

	if (![self lockedOrHidden]) {
		NSIndexSet* set = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([self countOfObjects], [objs count])];
		[self insertObjects:objs
				  atIndexes:set];
	}
}

- (BOOL)addObjectsFromArray:(NSArray*)objs relativeToPoint:(NSPoint)origin pinToInterior:(BOOL)pin
{
	return [self addObjectsFromArray:objs
							  bounds:NSZeroRect
					 relativeToPoint:origin
					   pinToInterior:pin];
}

- (BOOL)addObjectsFromArray:(NSArray*)objs bounds:(NSRect)bounds relativeToPoint:(NSPoint)origin pinToInterior:(BOOL)pin
{
	if (![self lockedOrHidden]) {
		NSRect di = [[self drawing] interior];
		CGFloat rx, ry;
		NSRect br = bounds;
		BOOL result = YES;

		if (NSEqualRects(NSZeroRect, br)) {
			br = [DKDrawableObject unionOfBoundsOfDrawablesInArray:objs];
		}

		rx = origin.x - br.origin.x;
		ry = origin.y - br.origin.y;

		for (DKDrawableObject* o in objs) {
			NSPoint proposedLocation = [o location];
			proposedLocation.x += rx;
			proposedLocation.y += ry;

			if (!NSPointInRect(proposedLocation, di)) {
				if (pin)
					proposedLocation = [[self drawing] pinPointToInterior:proposedLocation];
				else
					result = NO;
			}
			[o setLocation:proposedLocation];
		}

		[self addObjectsFromArray:objs];
		return result;
	}

	return NO;
}

#pragma mark -

- (void)removeObject:(DKDrawableObject*)obj
{
	NSAssert(obj != nil, @"cannot remove a nil object");

	if ([[self storage] containsObject:obj] && ![self lockedOrHidden]) {
		NSInteger indx = [[self storage] indexOfObject:obj];
		[self removeObjectFromObjectsAtIndex:indx];
	}
}

- (void)removeObjectAtIndex:(NSUInteger)indx
{
	NSAssert(indx < [self countOfObjects], @"error - index is beyond bounds");

	if (![self lockedOrHidden])
		[self removeObjectFromObjectsAtIndex:indx];
}

- (void)removeObjectsInArray:(NSArray*)objs
{
	[self removeObjectsAtIndexes:[self indexesOfObjectsInArray:objs]];
}

- (void)removeAllObjects
{
	if (![self lockedOrHidden] && [self countOfObjects] > 0) {
		NSIndexSet* allIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self countOfObjects] - 1)];
		[self removeObjectsAtIndexes:allIndexes];
	}
}

#pragma mark -
#ifdef DRAWKIT_DEPRECATED

- (NSEnumerator*)objectTopToBottomEnumerator
{
	return [[self objects] reverseObjectEnumerator];
}

- (NSEnumerator*)objectBottomToTopEnumerator
{
	return [[self objects] objectEnumerator];
}

#endif

- (NSEnumerator*)objectEnumeratorForUpdateRect:(NSRect)rect inView:(NSView*)aView
{
	return [self objectEnumeratorForUpdateRect:rect
										inView:aView
									   options:0];
}

- (NSEnumerator*)objectEnumeratorForUpdateRect:(NSRect)rect inView:(NSView*)aView options:(DKObjectStorageOptions)options
{
	return [[self objectsForUpdateRect:rect
								inView:aView
							   options:options] objectEnumerator];
}

- (NSArray*)objectsForUpdateRect:(NSRect)rect inView:(NSView*)aView
{
	return [self objectsForUpdateRect:rect
							   inView:aView
							  options:0];
}

- (NSArray<DKDrawableObject*>*)objectsForUpdateRect:(NSRect)rect inView:(NSView*)aView options:(DKObjectStorageOptions)options
{
	return [[self storage] objectsIntersectingRect:rect
											inView:aView
										   options:options];
}

#pragma mark -
#pragma mark - updating and drawing

- (void)drawable:(DKDrawableObject*)obj needsDisplayInRect:(NSRect)rect
{
#pragma unused(obj)

	// if the layer is cached, invalidate it. This forces the cache to get rebuilt when a change occurs while inactive,
	// for example an undo was performed on a contained object that changed its appearance

	[self invalidateCache];
	[self setNeedsDisplayInRect:rect];
}

- (void)drawVisibleObjects
{
	BOOL outlines;
	DKStyle* tempStyle = nil;

	//NSLog(@"drawing %d objects in view: %@", [[self visibleObjects] count], [self currentView]);

	outlines = (([self layerCacheOption] & kDKLayerCacheObjectOutlines) != 0);

	if (outlines)
		tempStyle = [DKStyle styleWithFillColour:nil
									strokeColour:[NSColor blackColor]
									 strokeWidth:1.0];

	for (DKDrawableObject* od in self.visibleObjects) {
		if (outlines)
			[od drawContentWithStyle:tempStyle];
		else
			[od drawContentWithSelectedState:NO];
	}
}

- (NSImage*)imageOfObjects
{
	NSImage* img = nil;
	NSRect sb;

	if ([[self visibleObjects] count] > 0) {
		sb = [self unionOfAllObjectBounds];

		img = [[NSImage alloc] initWithSize:sb.size];

		NSAffineTransform* tfm = [NSAffineTransform transform];
		[tfm translateXBy:-sb.origin.x
					  yBy:-sb.origin.y];

		[img lockFocus];

		[[NSColor clearColor] set];
		NSRectFill(NSMakeRect(0, 0, sb.size.width, sb.size.height));

		[tfm concat];
		[self drawVisibleObjects];
		[img unlockFocus];
	}
	return img;
}

- (NSData*)pdfDataOfObjects
{
	NSData* pdfData = nil;

	if ([[self visibleObjects] count] > 0) {
		NSRect fr = NSZeroRect;

		fr.size = [[self drawing] drawingSize];

		DKLayerPDFView* pdfView = [[DKLayerPDFView alloc] initWithFrame:fr
															  withLayer:self];
		DKViewController* vc = [pdfView makeViewController];

		[[self drawing] addController:vc];

		NSRect sr = [self unionOfAllObjectBounds];

		//NSLog(@"pdf view = %@", pdfView );

		pdfData = [pdfView dataWithPDFInsideRect:sr];

		//NSLog(@"created PDF data in rect: %@, data size = %d", NSStringFromRect( sr ), [pdfData length]);
	}
	return pdfData;
}

#pragma mark -
#pragma mark - handling a pending object

- (void)addObjectPendingCreation:(DKDrawableObject*)pend
{
	NSAssert(pend != nil, @"pending object cannot be nil");

	[self removePendingObject];
	mNewObjectPending = pend;
	[mNewObjectPending setContainer:self];
}

- (void)removePendingObject
{
	if (mNewObjectPending != nil) {
		[mNewObjectPending notifyVisualChange];
		mNewObjectPending = nil;
	}
}

- (void)commitPendingObjectWithUndoActionName:(NSString*)actionName
{
	NSAssert(mNewObjectPending != nil, @"can't commit pending object because it is nil");

	[self addObject:mNewObjectPending];
	[self removePendingObject];
	[[self undoManager] setActionName:actionName];
}

- (void)drawPendingObjectInView:(NSView*)aView
{
	if (mNewObjectPending != nil) {
		if ([aView needsToDrawRect:[mNewObjectPending bounds]])
			[mNewObjectPending drawContentWithSelectedState:YES];
	}
}

@synthesize pendingObject = mNewObjectPending;

#pragma mark -
#pragma mark - geometry

- (NSRect)unionOfAllObjectBounds
{
	NSRect u = NSZeroRect;

	for (DKDrawableObject* obj in self.visibleObjects) {
		u = UnionOfTwoRects(u, [obj bounds]);
	}

	return u;
}

- (void)refreshObjectsInContainer:(id)container
{
	[container makeObjectsPerformSelector:@selector(notifyVisualChange)];
}

- (void)refreshAllObjects
{
	[self refreshObjectsInContainer:[self visibleObjects]];
}

- (NSAffineTransform*)renderingTransform
{
	return [NSAffineTransform transform];
}

- (void)applyTransformToObjects:(NSAffineTransform*)transform
{
	[[self objects] makeObjectsPerformSelector:@selector(applyTransform:)
									withObject:transform];
}

#pragma mark -
#pragma mark - stacking order

- (void)moveUpObject:(DKDrawableObject*)obj
{
	NSUInteger new = [self indexOfObject : obj];
	if (new != NSNotFound)
		[self moveObject:obj
				 toIndex:new + 1];
}

- (void)moveDownObject:(DKDrawableObject*)obj
{
	NSUInteger new = [self indexOfObject : obj];
	if (new != NSNotFound)
		[self moveObject:obj
				 toIndex:new - 1];
}

- (void)moveObjectToTop:(DKDrawableObject*)obj
{
	NSUInteger top = [self countOfObjects];
	if (top != 0)
		[self moveObject:obj
				 toIndex:top - 1];
}

- (void)moveObjectToBottom:(DKDrawableObject*)obj
{
	[self moveObject:obj
			 toIndex:0];
}

- (void)moveObject:(DKDrawableObject*)obj toIndex:(NSUInteger)indx
{
	if (![self lockedOrHidden]) {
		NSAssert(obj != nil, @"cannot move nil object");
		NSAssert([obj layer] == self, @"error - layer doesn't own the object being moved");

		indx = MIN(indx, [self countOfObjects] - 1);

		NSUInteger old = [self indexOfObject:obj];

		if (old != indx) {
			[[[self undoManager] prepareWithInvocationTarget:self] moveObject:obj
																	  toIndex:old];

			[[self storage] moveObject:obj
							   toIndex:indx];
			[obj notifyVisualChange];

			[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerDidReorderObjects
																object:self];
		}
	}
}

- (void)moveObjectsAtIndexes:(NSIndexSet*)set toIndex:(NSUInteger)indx
{
	NSAssert(set != nil, @"cannot move objects as index set is nil");

	if ([set count] > 0) {
		NSArray* objs = [self objectsAtIndexes:set];
		[self moveObjectsInArray:objs
						 toIndex:indx];
	}
}

- (void)moveObjectsInArray:(NSArray*)objs toIndex:(NSUInteger)indx
{
	NSAssert(objs != nil, @"can't move objects - array is nil");

	if ([objs count] > 0) {
		// iterate in reverse - insertion at index reverses the order

		NSEnumerator* iter = [objs reverseObjectEnumerator];

		for (DKDrawableObject* od in iter) {
			[self moveObject:od
					 toIndex:indx];
		}
	}
}

#pragma mark -
#pragma mark - clipboard ops& predictive pasting support

/** @brief Unarchive a list of objects from the pasteboard, if possible

 This factors the dearchiving of objects from the pasteboard. If the pasteboard does not contain
 any valid types, nil is returned
 @param pb the pasteboard to take objects from
 @return a list of objects
 */
- (NSArray*)nativeObjectsFromPasteboard:(NSPasteboard*)pb
{
	return [DKDrawableObject nativeObjectsFromPasteboard:pb];
}

- (void)addObjects:(NSArray<DKDrawableObject*>*)objects fromPasteboard:(NSPasteboard*)pb atDropLocation:(NSPoint)p
{
#pragma unused(pb)

	if ([self lockedOrHidden])
		return;

	NSAssert(objects != nil, @"cannot drop - array of objects is nil");

	DKDrawableObject* o;
	CGFloat dx, dy;
	BOOL hadFirst = NO;
	NSPoint q = NSZeroPoint;
	NSRect dropBounds;

	dropBounds = [DKDrawableObject unionOfBoundsOfDrawablesInArray:objects];
	o = [objects objectAtIndex:0]; // drop location is relative to the location of the first object

	dx = [o location].x - NSMinX(dropBounds);
	dy = [o location].y - NSMaxY(dropBounds);

	p.x += dx;
	p.y += dy;

	p = [[self drawing] snapToGrid:p
				   withControlFlag:NO];

	for (o in objects) {
		if (![o isKindOfClass:[DKDrawableObject class]])
			[NSException raise:NSInternalInconsistencyException
						format:@"error - trying to drop non-drawable objects"];

		if (!hadFirst) {
			q = [o location];
			[o setLocation:p];
			hadFirst = YES;
		} else {
			dx = [o location].x - q.x;
			dy = [o location].y - q.y;

			[o setLocation:NSMakePoint(p.x + dx, p.y + dy)];
		}
		// the object is given an opportunity to read private data from the pasteboard if it wishes:

		[o readSupplementaryDataFromPasteboard:pb];
	}

	[self addObjectsFromArray:objects];
}

- (void)setPasteOffsetX:(CGFloat)x y:(CGFloat)y
{
	// sets the paste/duplicate offset to x, y - if there is a grid and snap to grid is on, the offset is made a grid
	// integral size.

	[self setPasteOffset:NSMakeSize(x, y)];

	if ([[self drawing] snapsToGrid]) {
		DKGridLayer* grid = [[self drawing] gridLayer];
		[self setPasteOffset:[grid nearestGridIntegralToSize:[self pasteOffset]]];
	}
}

- (BOOL)updatePasteCountWithPasteboard:(NSPasteboard*)pb
{
	NSInteger cc = [pb changeCount];
	if (cc == mPasteboardLastChange) {
		++mPasteCount;
		return NO;
	} else {
		mPasteCount = 1;
		mPasteboardLastChange = cc;
		[self setPasteOffsetX:DEFAULT_PASTE_OFFSET
							y:DEFAULT_PASTE_OFFSET];

		DKPasteboardInfo* info = [DKPasteboardInfo pasteboardInfoWithPasteboard:pb];

		if (info) {
			// determine whether this new paste came from this layer, or some other layer. If another layer, set the
			// paste offset to 0 so that the objects are initially placed in their original locations.

			NSString* originatingLayerID = [info keyOfOriginatingLayer];

			if (![originatingLayerID isEqualToString:[self uniqueKey]])
				[self setPasteOffsetX:0
									y:0];

			[self setPasteOrigin:[info bounds].origin];
		}

		return YES;
	}
}

@synthesize pasteCount = mPasteCount;
@synthesize pasteOrigin = m_pasteAnchor;
@synthesize recordingPasteOffset = m_recordPasteOffset;
@synthesize pasteOffset = m_pasteOffset;

- (void)objects:(NSArray*)objects wereDraggedFromPoint:(NSPoint)startPt toPoint:(NSPoint)endPt
{
// called by the standard selection tool at the end of a drag of objects, this informs the layer how far the objects
// were moved in total. This is then used to set the paste offset if it is being recorded.

#pragma unused(startPt, endPt)

	if ([self isRecordingPasteOffset]) {
		// the total offset is the difference in origin between the objects bounding rect and m_PasteAnchor.

		NSPoint oldOrigin = [self pasteOrigin];
		NSPoint newOrigin = [DKDrawableObject unionOfBoundsOfDrawablesInArray:objects].origin;

		[self setPasteOffset:NSMakeSize((newOrigin.x - oldOrigin.x), (newOrigin.y - oldOrigin.y))];
		[self setRecordingPasteOffset:NO];
	}
}

#pragma mark -
#pragma mark - hit testing

- (DKDrawableObject*)hitTest:(NSPoint)point
{
	return [self hitTest:point
				partCode:NULL];
}

- (DKDrawableObject*)hitTest:(NSPoint)point partCode:(NSInteger*)part
{
	NSInteger partcode;
	NSArray* objects = [[self storage] objectsContainingPoint:point];

	LogEvent_(kUserEvent, @"hit-testing %lu objects; layer = %@; objects = %@", (unsigned long)[objects count], self, objects);

	for (DKDrawableObject* o in [objects reverseObjectEnumerator]) {
		partcode = [o hitPart:point];

		if (partcode != kDKDrawingNoPart) {
			if (part) {
				*part = partcode;
			}

			LogEvent_(kUserEvent, @"found hit = %@", o);

			return o;
		}
	}

	if (part)
		*part = kDKDrawingNoPart;

	LogEvent_(kUserEvent, @"nothing hit");

	return nil;
}

- (NSArray*)objectsInRect:(NSRect)rect
{
	NSEnumerator* iter = [self objectEnumeratorForUpdateRect:rect
													  inView:nil];
	NSMutableArray* hits;

	hits = [[NSMutableArray alloc] init];

	for (DKDrawableObject* o in iter) {
		if ([o intersectsRect:rect])
			[hits addObject:o];
	}

	return hits;
}

- (void)drawable:(DKDrawableObject*)obj wasDoubleClickedAtPoint:(NSPoint)mp
{
#pragma unused(obj, mp)
}

#pragma mark -
#pragma mark - snapping

- (NSPoint)snapPoint:(NSPoint)p toAnyObjectExcept:(DKDrawableObject*)except snapTolerance:(CGFloat)tol
{
#pragma unused(tol)

	if ([self allowsSnapToObjects]) {
		NSInteger pc;
		NSEnumerator* iter;

		iter = [[self objects] reverseObjectEnumerator];

		for (DKDrawableObject* ho in iter) {
			if (ho != except) {
				pc = [ho hitSelectedPart:p
						forSnapDetection:YES];

				if (pc != kDKDrawingNoPart && pc != kDKDrawingEntireObjectPart) {
					p = [ho pointForPartcode:pc];
					//	LogEvent_(kInfoEvent, @"detectedsnap on %@, pc = %d", ho, pc );
					break;
				}
			}
		}
	}

	return p;
}

- (NSPoint)snappedMousePoint:(NSPoint)mp forObject:(DKDrawableObject*)obj withControlFlag:(BOOL)snapControl
{
	NSPoint omp = mp;
	NSPoint gp;

	// snap to other objects unless the snapControl is pressed - object snapping has priority
	// over grid and guide snapping, but also has the least "pull" on the point

	if (!snapControl && [self allowsSnapToObjects])
		mp = [self snapPoint:mp
			toAnyObjectExcept:obj
				snapTolerance:2.0];

	// if point remains unmodified, check for grid and guides

	if (NSEqualPoints(mp, omp)) {
		mp = [[self drawing] snapToGuides:mp];
		gp = [[self drawing] snapToGrid:omp
						withControlFlag:snapControl];

		// use whichever is closest to the original point but which is not the original point. Consider x and y independently so that
		// a snap to one doesn't disable snap to the other.

		CGFloat dx1, dx2, dy1, dy2;
		NSPoint rp;

		// use squared distances to increase precision and eliminate negative terms

		dx1 = (mp.x - omp.x) * (mp.x - omp.x);
		dx2 = (gp.x - omp.x) * (gp.x - omp.x);
		dy1 = (mp.y - omp.y) * (mp.y - omp.y);
		dy2 = (gp.y - omp.y) * (gp.y - omp.y);

		if (dx1 > dx2 || dx1 == 0.0)
			rp.x = (dx2 == 0.0) ? mp.x : gp.x;
		else
			rp.x = mp.x;

		if (dy1 > dy2 || dy1 == 0.0)
			rp.y = (dy2 == 0.0) ? mp.y : gp.y;
		else
			rp.y = mp.y;

		return rp;
	}

	return mp;
}

#pragma mark -
#pragma mark - options

- (BOOL)allowsEditing
{
	return m_allowEditing && ![self lockedOrHidden];
}

@synthesize allowsEditing = m_allowEditing;
@synthesize allowsSnapToObjects = m_allowSnapToObjects;
@synthesize layerCacheOption = mLayerCachingOption;

- (void)setHighlightedForDrag:(BOOL)highlight
{
	if (highlight != m_inDragOp) {
		m_inDragOp = highlight;
		[self setNeedsDisplay:YES];
	}
}

@synthesize highlightedForDrag = m_inDragOp;

- (void)drawHighlightingForDrag
{
	NSRect ir = [[self drawing] interior];

	[[self selectionColour] set];
	NSFrameRectWithWidth(NSInsetRect(ir, -5, -5), 5.0);
}

#pragma mark -
#pragma mark - user actions

- (IBAction)toggleSnapToObjects:(id)sender
{
#pragma unused(sender)

	[self setAllowsSnapToObjects:![self allowsSnapToObjects]];
}

- (IBAction)toggleShowStorageDebuggingPath:(id)sender
{
#pragma unused(sender)
	mShowStorageDebugging = !mShowStorageDebugging;
	[self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark - private

/** @brief Builds the offscreen cache(s) for drawing the layer more quickly when it's inactive

 Application code shouldn't call this directly
 */
- (void)updateCache
{
	// not implemented
}

/** @brief Discard the offscreen cache(s) used for drawing the layer more quickly when it's inactive

 Application code shouldn't call this directly
 */
- (void)invalidateCache
{
	// not implemented
}

#pragma mark -
#pragma mark As a DKLayer

/** @brief Called when the drawing's undo manager is changed - this gives objects that cache the UM a chance
 to update their references

 Pushes out the new um to all object's styles (which cache the um)
 @param um the new undo manager
 */
- (void)drawingHasNewUndoManager:(NSUndoManager*)um
{
	[[self allStyles] makeObjectsPerformSelector:@selector(setUndoManager:)
									  withObject:um];
}

/** @brief Called when the drawing's size changed - this gives layers that need to know about this a
 direct notification

 The storage is informed so that if it is spatially based it can update itself
 @param sizeVal the new size of the drawing.
 */
- (void)drawingDidChangeToSize:(NSValue*)sizeVal
{
	[[self storage] setCanvasSize:[sizeVal sizeValue]];
}

/** @brief Called when the drawing's margins changed - this gives layers that need to know about this a
 direct notification

 You can ask the drawing directly for its new interior rect
 @param oldInterior the old interior rect of the drawing - extract -rectValue.
 */
- (void)drawingDidChangeMargins:(NSValue*)oldInterior
{
	LogEvent_(kReactiveEvent, @"changed margins, old = %@", NSStringFromRect([oldInterior rectValue]));

	NSRect old = [oldInterior rectValue];
	NSRect new = [[self drawing] interior];

	NSAffineTransform* tfm = [NSAffineTransform transform];
	[tfm translateXBy:new.origin.x - old.origin.x
				  yBy:new.origin.y - old.origin.y];

	[self applyTransformToObjects:tfm];
}

/** @brief Draws the layer and its contents on demand

 Called by the drawing when necessary to update the views. This will draw from the cache if set
 to do so and the layer isn't active
 @param rect the area being updated
 */
- (void)drawRect:(NSRect)rect inView:(DKDrawingView*)aView
{
#pragma unused(rect)

	if ([self countOfObjects] > 0) {
		NSEnumerator* iter = [self objectEnumeratorForUpdateRect:rect
														  inView:aView];

		// draw the objects - this enumerator has already excluded any not needing to be drawn

		for (DKDrawableObject* obj in iter)
			[obj drawContentWithSelectedState:NO];
	}

	// draw any pending object on top of the others

	[self drawPendingObjectInView:aView];

	if ([self isHighlightedForDrag])
		[self drawHighlightingForDrag];

	if (mShowStorageDebugging && [[self storage] respondsToSelector:@selector(debugStorageDivisions)]) {
		NSBezierPath* debug = [(id)[self storage] debugStorageDivisions];

		[debug setLineWidth:0];
		[[NSColor redColor] set];
		[debug stroke];
	}
}

/** @brief Does the point hit anything in the layer?
 @param p the point to test
 @return YES if any object is hit, NO otherwise
 */
- (BOOL)hitLayer:(NSPoint)p
{
	return ([self hitTest:p] != nil);
}

/** @brief Returns a list of styles used by the current set of objects

 Being a set, the result is unordered
 @return the set of unique style objects
 */
- (NSSet*)allStyles
{
	NSEnumerator<DKDrawableObject*>* iter = [[self objects] reverseObjectEnumerator];
	NSMutableSet<DKStyle*>* unionOfAllStyles = nil;

	for (DKDrawableObject* dko in iter) {
		NSSet<DKStyle*>* styles = [dko allStyles];

		if (styles != nil) {
			// we got one - make a set to union them with if necessary

			if (unionOfAllStyles == nil)
				unionOfAllStyles = [styles mutableCopy];
			else
				[unionOfAllStyles unionSet:styles];
		}
	}

	return [unionOfAllStyles copy];
}

/** @brief Returns a list of styles used by the current set of objects that are also registered

 Being a set, the result is unordered
 @return the set of unique registered style objects used by objects in this layer
 */
- (NSSet*)allRegisteredStyles
{
	NSEnumerator<DKDrawableObject*>* iter = [[self objects] reverseObjectEnumerator];
	NSMutableSet<DKStyle*>* unionOfAllStyles = nil;

	for (DKDrawableObject* dko in iter) {
		NSSet<DKStyle*>* styles = [dko allRegisteredStyles];

		if (styles != nil) {
			// we got one - make a set to union them with if necessary

			if (unionOfAllStyles == nil)
				unionOfAllStyles = [styles mutableCopy];
			else
				[unionOfAllStyles unionSet:styles];
		}
	}

	return [unionOfAllStyles copy];
}

/** @brief Given a set of styles, replace those that have a matching key with the objects in the set

 Used when consolidating a document's saved styles with the application registry after a load
 @param aSet a set of style objects
 */
- (void)replaceMatchingStylesFromSet:(NSSet*)aSet
{
	// propagate this to all drawables in the layer

	[[self objects] makeObjectsPerformSelector:@selector(replaceMatchingStylesFromSet:)
									withObject:aSet];
}

/** @brief Get a list of the data types that the layer is able to deal with in a paste or drop operation
 @param op a set of flags indicating what operation the types should be relevant to. This is arranged
 @return an array of acceptable pasteboard data types for the given operation in preferred order
 */
- (NSArray*)pasteboardTypesForOperation:(DKPasteboardOperationType)op
{
	// we can always cut/paste and drag/drop our native type:

	NSMutableArray* types = [NSMutableArray arrayWithObject:kDKDrawableObjectPasteboardType];

	// info type is internal to DK, allows us to find out how many objects are being pasted without dearchiving

	[types addObject:kDKDrawableObjectInfoPasteboardType];

	// we can read any image format or a file containing one, or a string

	if ((op & kDKAllReadableTypes) != 0) {
		[types addObjectsFromArray:[NSImage imageTypes]];
		[types addObject:(NSString*)kUTTypeFileURL];
		[types addObject:NSPasteboardTypeString];
	}

	// we can write PDF and TIFF image formats:

	if ((op & kDKAllWritableTypes) != 0) {
		[types addObjectsFromArray:@[NSPasteboardTypePDF, NSPasteboardTypeTIFF]];
	}

	return types;
}

/** @brief Invoked when the layer becomes the active layer

 Invalidates the layer cache - only inactive layers draw from their cache
 */
- (void)layerDidBecomeActiveLayer
{
	[self invalidateCache];

	if (([self layerCacheOption] & kDKLayerCacheObjectOutlines) != 0)
		[self setNeedsDisplay:YES];
}

/** @brief Invoked when the layer resigned the active layer
 */
- (void)layerDidResignActiveLayer
{
	if (([self layerCacheOption] & kDKLayerCacheObjectOutlines) != 0)
		[self setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark As an NSObject
- (void)dealloc
{
	// though we are about to release all the objects, set their container to nil - this ensures that
	// if anything else is retaining them, when they are later released they won't have stale refs to the drawing, owner, et. al.

	[[self objects] makeObjectsPerformSelector:@selector(setContainer:)
									withObject:nil];
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		mStorage = [[[[self class] storageClass] alloc] init];

		LogEvent_(kInfoEvent, @"%@ allocated storage: %@", self, mStorage);

		[self setPasteOffsetX:DEFAULT_PASTE_OFFSET
							y:DEFAULT_PASTE_OFFSET];
		[self setAllowsSnapToObjects:YES];
		[self setAllowsEditing:YES];
		[self setLayerCacheOption:[[self class] defaultLayerCacheOption]];
		[self setLayerName:NSLocalizedString(@"Drawing Layer", @"default name for new drawing layers")];
	}
	return self;
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"%@,\nstorage = %@", [super description], [self storage]];
}

#pragma mark -
#pragma mark As part of DKDrawableContainer Protocol

/** @brief Returns the layer of a drawable's container - since this is that layer, returns self

 See DKDrawableObject which also implements this protocol
 @return self
 */
- (DKObjectOwnerLayer*)layer
{
	return self;
}

- (DKImageDataManager*)imageManager
{
	return [[self drawing] imageManager];
}

- (id)metadataObjectForKey:(NSString*)key
{
	return [super metadataObjectForKey:key];
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];

	// only the objects are archived as a simple array, not the storage itself. This allows the
	// storage to be selected for any file at runtime.

	[coder encodeObject:[self objects]
				 forKey:@"objects"];
	[coder encodeBool:[self allowsEditing]
			   forKey:@"editable"];
	[coder encodeBool:[self allowsSnapToObjects]
			   forKey:@"snappable"];
	[coder encodeInteger:[self layerCacheOption]
				  forKey:@"DKObjectOwnerLayer_cacheOption"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	LogEvent_(kFileEvent, @"decoding object owner layer %@", self);

	self = [super initWithCoder:coder];
	if (self != nil) {
		// we don't archive the storage itself, only its objects. This allows us to swap in whatever storage approach we want for
		// any file. However for a brief time storage was archived, so to allow those files to load, we attempt to unarchive
		// the storage, and if present get the objects from it.

		// allocate the storage we want to use:

		mStorage = [[[[self class] storageClass] alloc] init];

		LogEvent_(kInfoEvent, @"%@ '%@' allocated storage: %@", self, [self layerName], mStorage);

		// attempt to dearchive storage from the file - most files encountered won't have this

		id<DKObjectStorage> tempStorage = [coder decodeObjectForKey:@"DKObjectOwnerLayer_storage"];

		if (tempStorage) {
			// storage was archived, so get its objects and assign them to the real storage

			[self setObjects:[tempStorage objects]];
		} else {
			// common case: storage wasn't archived but objects were

			[self setObjects:[coder decodeObjectForKey:@"objects"]];
		}

		[self setPasteOffsetX:20
							y:20];
		[self setAllowsEditing:[coder decodeBoolForKey:@"editable"]];
		[self setAllowsSnapToObjects:[coder decodeBoolForKey:@"snappable"]];
		[self setLayerCacheOption:[[self class] defaultLayerCacheOption]];
	}
	return self;
}

#pragma mark -
#pragma mark As part of the NSDraggingDestination protocol

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
	BOOL result = NO;
	NSView* view = [self currentView];
	NSPasteboard* pb = [sender draggingPasteboard];
	NSPoint cp, ip = [sender draggedImageLocation];
	NSArray* dropObjects = nil;

	cp = [view convertPoint:ip
				   fromView:nil];

	NSString* dt = [pb availableTypeFromArray:[self pasteboardTypesForOperation:kDKReadableTypesForDrag]];

	if ([dt isEqualToString:kDKDrawableObjectPasteboardType]) {
		// drag contains native objects, which we can use directly.
		// if dragging source is this layer, remove existing

		dropObjects = [self nativeObjectsFromPasteboard:pb];
		[self addObjects:dropObjects
			fromPasteboard:pb
			atDropLocation:cp];
		[[self undoManager] setActionName:NSLocalizedString(@"Drag and Drop Objects", @"undo string for drag/drop objects")];

		result = YES;
	} else if ([dt isEqualToString:NSPasteboardTypeString]) {
		// create a text object to contain the dropped string

		NSString* theString = [pb stringForType:NSPasteboardTypeString];

		if (theString != nil) {
			DKTextShape* tShape = [DKTextShape textShapeWithString:theString
															inRect:NSMakeRect(0, 0, 200, 100)];
			[tShape fitToText:self];

			cp = [view convertPoint:[sender draggingLocation]
						   fromView:nil];
			cp.x -= [tShape size].width * 0.5;
			cp.y += [tShape size].height * 0.5;

			dropObjects = @[tShape];
			[self addObjects:dropObjects
				fromPasteboard:pb
				atDropLocation:cp];
			[[self undoManager] setActionName:NSLocalizedString(@"Drag and Drop Text", @"undo string for drag/drop text")];

			result = YES;
		}
	} else if ([NSImage canInitWithPasteboard:pb]) {
		// so that image can be efficiently cached and subsequently archived, we make the image via the image manager and
		// initialise the object that way.

		NSString* newKey = nil;
		NSImage* image = [[[self drawing] imageManager] makeImageWithPasteboard:pb
																			key:&newKey];

		if (image) {
			DKImageShape* imshape = [[DKImageShape alloc] initWithImage:image];
			[imshape setImageKey:newKey];

			// centre the image on the drop location as the drag image is from Finder and is of little use to us here

			cp = [view convertPoint:[sender draggingLocation]
						   fromView:nil];

			cp.x -= [imshape size].width * 0.5;
			cp.y += [imshape size].height * 0.5;

			dropObjects = @[imshape];
			[self addObjects:dropObjects
				fromPasteboard:pb
				atDropLocation:cp];
			[[self undoManager] setActionName:NSLocalizedString(@"Drag and Drop Image", @"undo string for drag/drop image")];

			result = YES;
		}
	}

	m_inDragOp = NO;
	[self setNeedsDisplay:YES];

	return result;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
#pragma unused(sender)

	m_inDragOp = YES;
	[self setNeedsDisplay:YES];

	return NSDragOperationGeneric;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
#pragma unused(sender)

	m_inDragOp = NO;
	[self setNeedsDisplay:YES];
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
#pragma unused(sender)

	return NSDragOperationGeneric;
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
#pragma unused(sender)

	return YES;
}

#pragma mark -
#pragma mark As part of NSMenuValidation Protocol

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	SEL action = [item action];

	if (action == @selector(toggleSnapToObjects:)) {
		[item setState:[self allowsSnapToObjects] ? NSOnState : NSOffState];
		return YES;
	}

	if (action == @selector(toggleShowStorageDebuggingPath:)) {
		[item setState:mShowStorageDebugging ? NSOnState : NSOffState];
		return YES;
	}

	return [super validateMenuItem:item];
}

@end
