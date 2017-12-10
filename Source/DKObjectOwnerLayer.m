/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKObjectOwnerLayer.h"
#import "DKLayer+Metadata.h"
#import "DKDrawing.h"
#import "DKStyle.h"
#import "DKDrawingView.h"
#import "DKDrawKitMacros.h"
#import "DKGeometryUtilities.h"
#import "DKGridLayer.h"
#import "DKImageShape.h"
#import "DKTextShape.h"
#import "DKSelectionPDFView.h"
#import "DKUndoManager.h"
#import "LogEvent.h"
#import "DKImageDataManager.h"
#import "DKBSPObjectStorage.h"
#import "DKPasteboardInfo.h"

// constants

NSString* kDKLayerWillAddObject = @"kDKLayerWillAddObject";
NSString* kDKLayerDidAddObject = @"kDKLayerDidAddObject";
NSString* kDKLayerWillRemoveObject = @"kDKLayerWillRemoveObject";
NSString* kDKLayerDidRemoveObject = @"kDKLayerDidRemoveObject";

@interface DKObjectOwnerLayer (Private)
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
	if ([aClass conformsToProtocol:@protocol(DKObjectStorage)])
		sStorageClass = aClass;
}

+ (Class)storageClass
{
	if (sStorageClass == nil)
		return [DKLinearObjectStorage class]; //[DKBSPObjectStorage class];
	else
		return sStorageClass;
}

/** @brief Sets the storag eobject for the layer

 This is an advanced feature that allows the object storage to be replaced independently. Alternative
 storage algorithms can enhance performance for very large data sets, for example. Note that the
 storage should not be swapped while a layer contains objects, since they will be discarded. The
 intention is that the desired storage is part of a layer's initialisation.
 @param storage a storage object
 */
- (void)setStorage:(id<DKObjectStorage>)storage
{
	if ([storage conformsToProtocol:@protocol(DKObjectStorage)]) {
		LogEvent_(kReactiveEvent, @"owner layer (%@) setting storage = %@", self, storage);

		[storage retain];
		[mStorage release];
		mStorage = storage;
	}
}

/** @brief Returns the storage object for the layer
 @return a storage object
 */
- (id<DKObjectStorage>)storage
{
	return mStorage;
}

#pragma mark - the list of objects

/** @brief Sets the objects that this layer owns
 @param objs an array of DKDrawableObjects, or subclasses thereof
 */
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

/** @brief Returns all owned objects
 @return an array of the objects
 */
- (NSArray*)objects
{
	return [[[[self storage] objects] copy] autorelease];
}

/** @brief Returns objects that are available to the user, that is, not locked or invisible

 If the layer itself is locked, returns the empty list
 @return an array of available objects
 */
- (NSArray*)availableObjects
{
	return [self availableObjectsInRect:[[self drawing] interior]];
}

/** @brief Returns objects that are available to the user, that is, not locked or invisible and that
 intersect the rect

 If the layer itself is locked, returns the empty list
 @param aRect - objects must also intersect this rect
 @return an array of available objects
 */
- (NSArray*)availableObjectsInRect:(NSRect)aRect
{
	// an available object is one that is both visible and not locked. Stacking order is maintained.

	NSMutableArray* ao = [[NSMutableArray alloc] init];

	if (![self lockedOrHidden]) {
		NSEnumerator* iter = [self objectEnumeratorForUpdateRect:aRect
														  inView:nil];
		DKDrawableObject* od;

		while ((od = [iter nextObject])) {
			if ([od visible] && ![od locked])
				[ao addObject:od];
		}
	}
	return [ao autorelease];
}

/** @brief Returns objects that are available to the user of the given class

 If the layer itself is locked, returns the empty list
 @param aClass - class of the desired objects
 @return an array of available objects
 */
- (NSArray*)availableObjectsOfClass:(Class)aClass
{
	NSMutableArray* ao = [[NSMutableArray alloc] init];

	if (![self lockedOrHidden]) {
		NSEnumerator* iter = [[self objects] objectEnumerator];
		DKDrawableObject* od;

		while ((od = [iter nextObject])) {
			if ([od visible] && ![od locked] && [od isKindOfClass:aClass])
				[ao addObject:od];
		}
	}
	return [ao autorelease];
}

/** @brief Returns objects that are visible to the user, but may be locked

 If the layer itself is not visible, returns nil
 @return an array of visible objects
 */
- (NSArray*)visibleObjects
{
	return [self visibleObjectsInRect:[[self drawing] interior]];
}

/** @brief Returns objects that are visible to the user, intersect the rect, but may be locked

 If the layer itself is not visible, returns nil
 @param aRect the objects returned intersect this rect
 @return an array of visible objects
 */
- (NSArray*)visibleObjectsInRect:(NSRect)aRect
{
	NSMutableArray* vo = nil;

	if ([self visible]) {
		vo = [[NSMutableArray alloc] init];

		NSEnumerator* iter = [self objectEnumeratorForUpdateRect:aRect
														  inView:nil];
		DKDrawableObject* od;

		while ((od = [iter nextObject])) {
			if ([od visible])
				[vo addObject:od];
		}
	}

	return [vo autorelease];
}

/** @brief Returns objects that share the given style

 The style is compared by unique key, so style clones are not considered a match. Unavailable objects are
 also included.
 @param style the style to compare
 @return an array of those objects that have the style
 */
- (NSArray*)objectsWithStyle:(DKStyle*)style
{
	NSMutableArray* ao = [[NSMutableArray alloc] init];
	NSEnumerator* iter = [[self objects] objectEnumerator];
	DKDrawableObject* od;
	NSString* key = [style uniqueKey];

	while ((od = [iter nextObject])) {
		if ([[[od style] uniqueKey] isEqualToString:key])
			[ao addObject:od];
	}

	return [ao autorelease];
}

/** @brief Returns objects that respond to the selector with the value <answer>
 <selector> a selector taking no parameters

 This is a very simple type of predicate test. Note - the method <selector> must not return
 anything larger than an int or it will be ignored and the result may be wrong.
 @return an array, objects that match the value of <answer>
 */
- (NSArray*)objectsReturning:(NSInteger)answer toSelector:(SEL)selector
{
	NSEnumerator* iter = [[self objects] objectEnumerator];
	NSMutableArray* result = [NSMutableArray array];
	id o;
	NSInteger rval;

	while ((o = [iter nextObject])) {
		if ([o respondsToSelector:selector]) {
			rval = 0;

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

/** @brief Returns the number of objects in the layer
 @return the count of all objects
 */
- (NSUInteger)countOfObjects
{
	return [[self storage] countOfObjects];
}

/** @brief Returns the object at a given stacking position index
 @param index the stacking position
 */
- (DKDrawableObject*)objectInObjectsAtIndex:(NSUInteger)indx
{
	NSAssert(indx < [self countOfObjects], @"error - index is beyond bounds");

	return (DKDrawableObject*)[[self storage] objectInObjectsAtIndex:indx];
}

/** @brief Returns the topmost object
 @return the topmost object
 */
- (DKDrawableObject*)topObject
{
	return [[self objects] lastObject];
}

/** @brief Returns the bottom object
 @return the bottom object
 */
- (DKDrawableObject*)bottomObject
{
	return [[self objects] objectAtIndex:0];
}

/** @brief Returns the stacking position of the given object

 Will return NSNotFound if the object is not presently owned by the layer
 @param obj the object
 @return the object's stacking order index
 */
- (NSUInteger)indexOfObject:(DKDrawableObject*)obj
{
	return [[self storage] indexOfObject:obj];
}

#pragma mark -

/** @brief Returns a list of objects given by the index set
 @param set an index set
 @return a list of objects
 */
- (NSArray*)objectsAtIndexes:(NSIndexSet*)set
{
	return [[self storage] objectsAtIndexes:set];
}

/** @brief Given a list of objects that are part of this layer, return an index set for them
 @param objs a list of objects
 @return an index set listing the array index positions for the objects passed
 */
- (NSIndexSet*)indexesOfObjectsInArray:(NSArray*)objs
{
	NSAssert(objs != nil, @"can't get indexes for a nil array");

	NSMutableIndexSet* mset = [[NSMutableIndexSet alloc] init];
	DKDrawableObject* o;
	NSEnumerator* iter = [objs objectEnumerator];
	NSUInteger indx;

	while ((o = [iter nextObject])) {
		indx = [[self storage] indexOfObject:o];

		if (indx != NSNotFound)
			[mset addIndex:indx];
	}

	return [mset autorelease];
}

#pragma mark -
#pragma mark - adding and removing objects(KVC / KVO compliant)

/** @brief Adds an object to the layer
 @param obj the object to add
 @param index the index at which the object should be inserted
 @return none
 these. Adding multiple objects calls this multiple times.
 */
- (void)insertObject:(DKDrawableObject*)obj inObjectsAtIndex:(NSUInteger)indx
{
	NSAssert(obj != nil, @"attempt to add a nil object to the layer");

	LogEvent_(kReactiveEvent, @"inserting %@ at: %d, count = %d", obj, indx, [self countOfObjects]);

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

/** @brief Removes an object from the layer
 @param index the index at which the object should be removed
 @return none
 these. Removing multiple objects calls this multiple times.
 */
- (void)removeObjectFromObjectsAtIndex:(NSUInteger)indx
{
	NSAssert(indx < [self countOfObjects], @"error - index is beyond bounds");

	if (![self lockedOrHidden]) {
		DKDrawableObject* obj = [[self objectInObjectsAtIndex:indx] retain];
		LogEvent_(kReactiveEvent, @"removing object %@, index = %d", obj, indx);

		[[[self undoManager] prepareWithInvocationTarget:self] insertObject:obj
														   inObjectsAtIndex:indx];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerWillRemoveObject
															object:self];

		[obj notifyVisualChange];
		[[self storage] removeObjectFromObjectsAtIndex:indx];
		[obj objectWasRemovedFromLayer:self];
		[obj setContainer:nil];
		[obj release];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerDidRemoveObject
															object:self];
	}
}

/** @brief Replaces an object in the layer with another
 @param index the index at which the object should be exchanged
 @param obj the object that will replace the item at index
 @return none
 can be observed if desired to get notified of these events.
 */
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

/** @brief Inserts a set of objects at the indexes given. The array and set order should match, and
 have equal counts.
 @param objs the objects to insert
 @param set the indexes where they should be inserted
 */
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

/** @brief Removes objects from the indexes listed by the set
 @param set an index set
 */
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

/** @brief Adds an object to the layer

 If layer locked, does nothing
 @param obj the object to add
 */
- (void)addObject:(DKDrawableObject*)obj
{
	NSAssert(obj != nil, @"attempt to add a nil object to the layer");

	if (![[self storage] containsObject:obj] && ![self lockedOrHidden])
		[self insertObject:obj
			inObjectsAtIndex:[self countOfObjects]];
}

/** @brief Adds an object to the layer at a specific stacking index position
 @param obj the object to add
 @param indx the stacking order position index (0 = bottom, grows upwards)
 */
- (void)addObject:(DKDrawableObject*)obj atIndex:(NSUInteger)indx
{
	NSAssert(obj != nil, @"attempt to add a nil object to the layer");

	if (![[self storage] containsObject:obj] && ![self lockedOrHidden])
		[self insertObject:obj
			inObjectsAtIndex:indx];
}

/** @brief Adds a set of objects to the layer

 Take care that no objects are already owned by any layer - this doesn't check.
 @param objs an array of DKDrawableObjects, or subclasses.
 */
- (void)addObjectsFromArray:(NSArray*)objs
{
	NSAssert(objs != nil, @"attempt to add a nil array of objects to the layer");

	if (![self lockedOrHidden]) {
		NSIndexSet* set = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange([self countOfObjects], [objs count])];
		[self insertObjects:objs
				  atIndexes:set];
	}
}

/** @brief Adds a set of objects to the layer offsetting their location by the given delta values relative to
 a given point.

 Used for paste and other similar ops. The objects are placed such that their bounding rect's origin
 ends up at <origin>, regardless of the object's current location. Note that if pin is YES, the
 method will not return NO, as no object was placed outside the interior.
 @param objs a list of DKDrawableObjects to add
 @param origin the required relative origin of the group of objects
 @param pin if YES, object locations are pinned to the drawing interior
 @return YES if all objects were placed within the interior bounds of the drawing, NO if any object was
 placed outside the interior.
 */
- (BOOL)addObjectsFromArray:(NSArray*)objs relativeToPoint:(NSPoint)origin pinToInterior:(BOOL)pin
{
	return [self addObjectsFromArray:objs
							  bounds:NSZeroRect
					 relativeToPoint:origin
					   pinToInterior:pin];
}

/** @brief Adds a set of objects to the layer offsetting their location by the given delta values relative to
 a given point.

 Used for paste and other similar ops. The objects are placed such that their bounding rect's origin
 ends up at <origin>, regardless of the object's current location. Note that if pin is YES, the
 method will not return NO, as no object was placed outside the interior. Note that the <bounds> parameter
 can differ when calculated compared with the original recorded bounds during the copy. This is because
 bounds often takes into account other relationships such as the layer's knobs and so on, which might
 no be available when pasting. For accurate positioning, the original bounds should be passed.
 @param objs a list of DKDrawableObjects to add
 @param bounds the original bounding rect of the objects. If NSZeroRect, it is calculated.
 @param origin the required relative origin of the group of objects
 @param pin if YES, object locations are pinned to the drawing interior
 @return YES if all objects were placed within the interior bounds of the drawing, NO if any object was
 placed outside the interior.
 */
- (BOOL)addObjectsFromArray:(NSArray*)objs bounds:(NSRect)bounds relativeToPoint:(NSPoint)origin pinToInterior:(BOOL)pin
{
	if (![self lockedOrHidden]) {
		NSEnumerator* iter = [objs objectEnumerator];
		DKDrawableObject* o;
		NSRect di = [[self drawing] interior];
		CGFloat rx, ry;
		NSRect br = bounds;
		BOOL result = YES;

		if (NSEqualRects(NSZeroRect, br))
			br = [DKDrawableObject unionOfBoundsOfDrawablesInArray:objs];

		rx = origin.x - br.origin.x;
		ry = origin.y - br.origin.y;

		while ((o = [iter nextObject])) {
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

/** @brief Removes the object from the layer
 @param obj the object to remove
 */
- (void)removeObject:(DKDrawableObject*)obj
{
	NSAssert(obj != nil, @"cannot remove a nil object");

	if ([[self storage] containsObject:obj] && ![self lockedOrHidden]) {
		NSInteger indx = [[self storage] indexOfObject:obj];
		[self removeObjectFromObjectsAtIndex:indx];
	}
}

/** @brief Removes the object at the given stacking position index
 @param index the stacking index value
 */
- (void)removeObjectAtIndex:(NSUInteger)indx
{
	NSAssert(indx < [self countOfObjects], @"error - index is beyond bounds");

	if (![self lockedOrHidden])
		[self removeObjectFromObjectsAtIndex:indx];
}

/** @brief Removes a set of objects from the layer
 */
- (void)removeObjectsInArray:(NSArray*)objs
{
	[self removeObjectsAtIndexes:[self indexesOfObjectsInArray:objs]];
}

/** @brief Removes all objects from the layer
 */
- (void)removeAllObjects
{
	if (![self lockedOrHidden] && [self countOfObjects] > 0) {
		NSIndexSet* allIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self countOfObjects] - 1)];
		[self removeObjectsAtIndexes:allIndexes];
	}
}

#pragma mark -
#ifdef DRAWKIT_DEPRECATED

/** @brief Return an iterator that will enumerate the object in top to bottom order

 The idea is to insulate you from the implementation detail of how stacking order relates to the
 list order of objects internally. Because this enumerates a copy of the objects list, it is safe
 to modify the objects in the layer itself while iterating.
 @return an iterator
 */
- (NSEnumerator*)objectTopToBottomEnumerator
{
	return [[self objects] reverseObjectEnumerator];
}

/** @brief Return an iterator that will enumerate the object in bottom to top order

 The idea is to insulate you from the implementation detail of how stacking order relates to the
 list order of objects internally. Because this enumerates a copy of the objects list, it is safe
 to modify the objects in the layer itself while iterating.
 @return an iterator
 */
- (NSEnumerator*)objectBottomToTopEnumerator
{
	return [[self objects] objectEnumerator];
}

#endif

/** @brief Return an iterator that will enumerate the objects needing update

 The iterator returned iterates in bottom-to-top order and includes only those objects that are
 visible and whose bounds intersect the update region of the view. If the view is nil <rect> is
 still used to determine inclusion.
 @param rect the update rect as passed to a drawRect: method of a view
 @param aView the view being updated, if any (may be nil)
 @return an iterator
 */
- (NSEnumerator*)objectEnumeratorForUpdateRect:(NSRect)rect inView:(NSView*)aView
{
	return [self objectEnumeratorForUpdateRect:rect
										inView:aView
									   options:0];
}

/** @brief Return an iterator that will enumerate the objects needing update

 The iterator returned iterates in bottom-to-top order and includes only those objects that are
 visible and whose bounds intersect the update region of the view. If the view is nil <rect> is
 still used to determine inclusion.
 @param rect the update rect as passed to a drawRect: method of a view
 @param aView the view being updated, if any (may be nil)
 @param options various flags that you can pass to modify behaviour:
 @return an iterator
 */
- (NSEnumerator*)objectEnumeratorForUpdateRect:(NSRect)rect inView:(NSView*)aView options:(DKObjectStorageOptions)options
{
	return [[self objectsForUpdateRect:rect
								inView:aView
							   options:options] objectEnumerator];
}

/** @brief Return the objects needing update

 If the view is nil <rect> is used to determine inclusion.
 @param rect the update rect as passed to a drawRect: method of a view
 @param aView the view being updated, if any (may be nil)
 @return an array, the objects needing update, in drawing order
 */
- (NSArray*)objectsForUpdateRect:(NSRect)rect inView:(NSView*)aView
{
	return [self objectsForUpdateRect:rect
							   inView:aView
							  options:0];
}

/** @brief Return the objects needing update

 If the view is nil <rect> is used to determine inclusion.
 @param rect the update rect as passed to a drawRect: method of a view
 @param aView the view being updated, if any (may be nil)
 @param options various flags that you can pass to modify behaviour:
 @return an array, the objects needig update, in drawing order
 */
- (NSArray*)objectsForUpdateRect:(NSRect)rect inView:(NSView*)aView options:(DKObjectStorageOptions)options
{
	return [[self storage] objectsIntersectingRect:rect
											inView:aView
										   options:options];
}

#pragma mark -
#pragma mark - updating and drawing

/** @brief Flags part of a layer as needing redrawing

 Allows the object requesting the update to be identified - by default this just invalidates <rect>
 @param obj the drawable object requesting the update
 @param rect the area that needs to be redrawn
 */
- (void)drawable:(DKDrawableObject*)obj needsDisplayInRect:(NSRect)rect
{
#pragma unused(obj)

	// if the layer is cached, invalidate it. This forces the cache to get rebuilt when a change occurs while inactive,
	// for example an undo was performed on a contained object that changed its appearance

	[self invalidateCache];
	[self setNeedsDisplayInRect:rect];
}

/** @brief Draws all of the visible objects

 This is used when drawing the layer into special contexts, not for view rendering
 */
- (void)drawVisibleObjects
{
	NSEnumerator* iter = [[self visibleObjects] objectEnumerator];
	DKDrawableObject* od;
	BOOL outlines;
	DKStyle* tempStyle = nil;

	//NSLog(@"drawing %d objects in view: %@", [[self visibleObjects] count], [self currentView]);

	outlines = (([self layerCacheOption] & kDKLayerCacheObjectOutlines) != 0);

	if (outlines)
		tempStyle = [DKStyle styleWithFillColour:nil
									strokeColour:[NSColor blackColor]
									 strokeWidth:1.0];

	while ((od = [iter nextObject])) {
		if (outlines)
			[od drawContentWithStyle:tempStyle];
		else
			[od drawContentWithSelectedState:NO];
	}
}

/** @brief Get an image of the current objects in the layer

 If there are no visible objects, returns nil.
 @return an NSImage
 */
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
	return [img autorelease];
}

/** @brief Get a PDF of the current visible objects in the layer

 If there are no visible objects, returns nil.
 @return PDF data in an NSData object
 */
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
		[pdfView release];

		//NSLog(@"created PDF data in rect: %@, data size = %d", NSStringFromRect( sr ), [pdfData length]);
	}
	return pdfData;
}

#pragma mark -
#pragma mark - handling a pending object

/** @brief Adds a new object to the layer pending successful interactive creation

 When interactively creating objects, it is preferable to create the object successfully before
 committing it to the layer - this gives the caller a chance to abort the creation without needing
 to be concerned about any undos, etc. The pending object is drawn on top of all others as normal
 but until it is committed, it creates no undo task for the layer.
 @param pend a new potential object to be added to the layer
 */
- (void)addObjectPendingCreation:(DKDrawableObject*)pend
{
	NSAssert(pend != nil, @"pending object cannot be nil");

	[self removePendingObject];
	mNewObjectPending = [pend retain];
	[mNewObjectPending setContainer:self];
}

/** @brief Removes a pending object in the situation that the creation was unsuccessful

 When interactively creating objects, if for any reason the creation failed, this should be called
 to remove the object from the layer without triggering any undo tasks, and to remove any the object
 itself made
 */
- (void)removePendingObject
{
	if (mNewObjectPending != nil) {
		[mNewObjectPending notifyVisualChange];
		[mNewObjectPending release];
		mNewObjectPending = nil;
	}
}

/** @brief Commits the pending object to the layer and sets up the undo task action name

 When interactively creating objects, if the creation succeeded, the pending object should be
 committed to the layer permanently. This does that by adding it using addObject. The undo task
 thus created is given the action name (note that other operations can also change this later).
 @param actionName the action name to give the undo manager after committing the object
 */
- (void)commitPendingObjectWithUndoActionName:(NSString*)actionName
{
	NSAssert(mNewObjectPending != nil, @"can't commit pending object because it is nil");

	[self addObject:mNewObjectPending];
	[self removePendingObject];
	[[self undoManager] setActionName:actionName];
}

/** @brief Draws the pending object, if any, in the layer - called by drawRect:inView:

 Pending objects are drawn normally is if part of the current list, and on top of all others. Subclasses
 may need to override this if the selected state needs passing differently. Typically pending objects
 will be drawn selected, so the default is YES.
 @param aView the view being drawn into
 */
- (void)drawPendingObjectInView:(NSView*)aView
{
	if (mNewObjectPending != nil) {
		if ([aView needsToDrawRect:[mNewObjectPending bounds]])
			[mNewObjectPending drawContentWithSelectedState:YES];
	}
}

/** @brief Returns the pending object, if any, in the layer
 @return the pending object, or nil
 */
- (DKDrawableObject*)pendingObject
{
	return mNewObjectPending;
}

#pragma mark -
#pragma mark - geometry

/** @brief Return the union of all the visible objects in the layer. If there are no visible objects, returns
 NSZeroRect.

 Avoid using for refreshing objects. It is more efficient to use refreshAllObjects
 @return a rect, the union of all visible object's bounds in the layer
 */
- (NSRect)unionOfAllObjectBounds
{
	NSEnumerator* iter = [[self visibleObjects] objectEnumerator];
	DKDrawableObject* obj;
	NSRect u = NSZeroRect;

	while ((obj = [iter nextObject]))
		u = UnionOfTwoRects(u, [obj bounds]);

	return u;
}

/** @brief Causes all objects in the passed array, set or other container to redraw themselves
 @param container a container of drawable objects. Any NSArray or NSSet is acceptable
 */
- (void)refreshObjectsInContainer:(id)container
{
	[container makeObjectsPerformSelector:@selector(notifyVisualChange)];
}

/** @brief Causes all visible objects to redraw themselves
 */
- (void)refreshAllObjects
{
	[self refreshObjectsInContainer:[self visibleObjects]];
}

/** @brief Returns the layer's transform used when rendering objects within

 Returns the identity transform
 @return a transform
 */
- (NSAffineTransform*)renderingTransform
{
	return [NSAffineTransform transform];
}

/** @brief Modifies the objects by applying the given transform to each of them.

 This modifies the geometry of each object by applying the transform to each one. The purpose of
 this is to permit gross changes to a drawing's layout if the
 client application requires it - for example scaling all objects to some new size.
 @param transform a transform
 */
- (void)applyTransformToObjects:(NSAffineTransform*)transform
{
	[[self objects] makeObjectsPerformSelector:@selector(applyTransform:)
									withObject:transform];
}

#pragma mark -
#pragma mark - stacking order

/** @brief Moves the object up in the stacking order
 @param obj object to move
 */
- (void)moveUpObject:(DKDrawableObject*)obj
{
	NSUInteger new = [self indexOfObject : obj];
	if (new != NSNotFound)
		[self moveObject:obj
				 toIndex:new + 1];
}

/** @brief Moves the object down in the stacking order
 @param obj the object to move
 */
- (void)moveDownObject:(DKDrawableObject*)obj
{
	NSUInteger new = [self indexOfObject : obj];
	if (new != NSNotFound)
		[self moveObject:obj
				 toIndex:new - 1];
}

/** @brief Moves the object to the top of the stacking order
 @param obj the object to move
 */
- (void)moveObjectToTop:(DKDrawableObject*)obj
{
	NSUInteger top = [self countOfObjects];
	if (top != 0)
		[self moveObject:obj
				 toIndex:top - 1];
}

/** @brief Moves the object to the bottom of the stacking order
 @param obj object to move
 */
- (void)moveObjectToBottom:(DKDrawableObject*)obj
{
	[self moveObject:obj
			 toIndex:0];
}

/** @brief Movesthe object to the given stacking position index

 Used to implement all the other moveTo.. ops
 @param obj the object to move
 @param i the index it should be moved to
 */
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

/** @brief Moves the objects indexed by the set to the given stacking position index

 Useful for restacking several objects
 @param set a set of indexes
 @param indx the index it should be moved to
 */
- (void)moveObjectsAtIndexes:(NSIndexSet*)set toIndex:(NSUInteger)indx
{
	NSAssert(set != nil, @"cannot move objects as index set is nil");

	if ([set count] > 0) {
		NSArray* objs = [self objectsAtIndexes:set];
		[self moveObjectsInArray:objs
						 toIndex:indx];
	}
}

/** @brief Moves the objects in the array to the given stacking position index

 Useful for restacking several objects. Array passed can be the selection. The order of objects in
 the array is preserved relative to one another, after the operation the lowest indexed object
 will be at <indx> and the rest at consecutive indexes above it.
 @param objs an array of objects already owned by the layer
 @param indx the index it should be moved to
 */
- (void)moveObjectsInArray:(NSArray*)objs toIndex:(NSUInteger)indx
{
	NSAssert(objs != nil, @"can't move objects - array is nil");

	if ([objs count] > 0) {
		// iterate in reverse - insertion at index reverses the order

		NSEnumerator* iter = [objs reverseObjectEnumerator];
		DKDrawableObject* od;

		while ((od = [iter nextObject]))
			[self moveObject:od
					 toIndex:indx];
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

/** @brief Add objects to the layer from the pasteboard
 @param objects a list of objects already dearchived from the pasteboard
 @param pb the pasteboard (for information only)
 @param p the drop location of the objects, defined as the lower left corner of the drag image - thus
 @return none
 a multiple selection is positioned at the point p, with others maintaining their positions
 relative to this object as in the original set. 
 This is the preferred method to use when pasting or dropping anything, because the subclass that
 implements selection overrides this to handle the selection also. Thus when pasting non-native
 objects, convert them to native objects and pass to this method in an array.
 */
- (void)addObjects:(NSArray*)objects fromPasteboard:(NSPasteboard*)pb atDropLocation:(NSPoint)p
{
#pragma unused(pb)

	if ([self lockedOrHidden])
		return;

	NSAssert(objects != nil, @"cannot drop - array of objects is nil");

	NSEnumerator* iter = [objects objectEnumerator];
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

	while ((o = [iter nextObject])) {
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

/** @brief Establish the paste offset - a value used to position items when pasting and duplicating

 The values passed will be adjusted to the nearest grid interval if snap to grid is on.
 @param x>, <y the x and y values of the offset
 */
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

/** @brief Detect whether the paste from the pasteboard is a new paste, or a repeat paste

 Since this is a one-shot method that changes the internal state of the layer, it should not be
 called except internally to manage the auto paste repeat. It may either increment or reset the
 paste count. It also sets the paste origin to the origin of the pasted objects' bounds.
 @param pb the pasteboard in question
 @return YES if this is a new paste, NO if a repeat
 */
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

/** @brief Return the current number of repeated pastes since the last new paste

 The paste count is reset to 1 by a new paste, and incremented for each subsequent paste of the
 same objects. This is used when calculating appropriate positioning for repeated pasting.
 @return the current number of pastes since the last new paste
 */
- (NSInteger)pasteCount
{
	return mPasteCount;
}

/** @brief Return the current point where pasted object will be positioned relative to

 See paste: for how this is used
 @return the paste origin
 */
- (NSPoint)pasteOrigin
{
	return m_pasteAnchor;
}

/** @brief Sets the current point where pasted object will be positioned relative to

 See paste: for how this is used
 @param po the desired paste origin.
 */
- (void)setPasteOrigin:(NSPoint)po
{
	m_pasteAnchor = po;
}

/** @brief Return whether the paste offset will be recorded for the current drag operation
 @return YES if paste offset will be recorded, NO otherwise
 */
- (BOOL)isRecordingPasteOffset
{
	return m_recordPasteOffset;
}

/** @brief Set whether the paste offset will be recorded for the current drag operation
 @param record YES to record the offset
 */
- (void)setRecordingPasteOffset:(BOOL)record
{
	m_recordPasteOffset = record;
}

/** @brief Returns the paste offset (distance between successively pasted objects)
 @return the paste offset as a NSSize
 */
- (NSSize)pasteOffset
{
	return m_pasteOffset;
}

/** @brief Sets the paste offset (distance between successively pasted objects)
 @param offset the paste offset as a NSSize
 */
- (void)setPasteOffset:(NSSize)offset
{
	m_pasteOffset = offset;
}

/** @brief Sets the paste offset (distance between successively pasted objects)
 @param objects the list of objects that were moved
 @param startPt the starting point for the drag
 @param endPt the ending point for the drag
 @return none
 if offset recording is currently set to YES, then resets the record flag.
 */
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

/** @brief Find which object was hit by the given point, if any
 @param point a point to test against
 @return the object hit, or nil if none
 */
- (DKDrawableObject*)hitTest:(NSPoint)point
{
	return [self hitTest:point
				partCode:NULL];
}

/** @brief Performs a hit test but also returns the hit part code
 @param point the point to test
 @param part pointer to int, receives the partcode hit as a result of the test. Can be NULL to ignore
 @return the object hit, or nil if none
 */
- (DKDrawableObject*)hitTest:(NSPoint)point partCode:(NSInteger*)part
{
	NSEnumerator* iter;
	DKDrawableObject* o;
	NSInteger partcode;
	NSArray* objects = [[self storage] objectsContainingPoint:point];

	LogEvent_(kUserEvent, @"hit-testing %d objects; layer = %@; objects = %@", [objects count], self, objects);

	iter = [objects reverseObjectEnumerator];

	while ((o = [iter nextObject])) {
		partcode = [o hitPart:point];

		if (partcode != kDKDrawingNoPart) {
			if (part)
				*part = partcode;

			LogEvent_(kUserEvent, @"found hit = %@", o);

			return o;
		}
	}

	if (part)
		*part = kDKDrawingNoPart;

	LogEvent_(kUserEvent, @"nothing hit");

	return nil;
}

/** @brief Finds all objects touched by the given rect

 Test for inclusion by calling the object's intersectsRect method. Can be used to select objects in
 a given rect or for any other purpose. For selections, the results can be passed directly to
 exchangeSelection:
 @param rect a rectangle
 @return a list of objects touched by the rect
 */
- (NSArray*)objectsInRect:(NSRect)rect
{
	NSEnumerator* iter = [self objectEnumeratorForUpdateRect:rect
													  inView:nil];
	DKDrawableObject* o;
	NSMutableArray* hits;

	hits = [[NSMutableArray alloc] init];

	while ((o = [iter nextObject])) {
		if ([o intersectsRect:rect])
			[hits addObject:o];
	}

	return [hits autorelease];
}

/** @brief An object owned by the layer was double-clicked

 Override to use
 @param obj the object hit
 @param mp the mouse point of the click
 */
- (void)drawable:(DKDrawableObject*)obj wasDoubleClickedAtPoint:(NSPoint)mp
{
#pragma unused(obj, mp)
}

#pragma mark -
#pragma mark - snapping

/** @brief Snap a point to any existing object control point within tolerance

 If snap to object is not set for this layer, this simply returns the original point unmodified.
 currently uses hitPart to test for a hit, so tolerance is ignored and objects apply their internal
 hit testing tolerance.
 @param p a point
 @param except don't snap to this object (intended to be the one being snapped)
 @param tol has to be within this distance to snap
 @return the modified point, or the original point
 */
- (NSPoint)snapPoint:(NSPoint)p toAnyObjectExcept:(DKDrawableObject*)except snapTolerance:(CGFloat)tol
{
#pragma unused(tol)

	if ([self allowsSnapToObjects]) {
		NSInteger pc;
		DKDrawableObject* ho;
		NSEnumerator* iter;

		iter = [[self objects] reverseObjectEnumerator];

		while ((ho = [iter nextObject])) {
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

/** @brief Snap a (mouse) point to grid, guide or other object according to settings

 Usually called from snappedMousePoint: method in DKDrawableObject
 @param p a point
 @return the modified point, or the original point
 */
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

/** @brief Sets whether the layer permits editing of its objects
 @param editable YES to enable editing, NO to prevent it
 */
- (void)setAllowsEditing:(BOOL)editable
{
	m_allowEditing = editable;
}

/** @brief Does the layer permit editing of its objects?

 Locking and hiding the layer also disables editing
 @return YES if editing will take place, NO if it is prevented
 */
- (BOOL)allowsEditing
{
	return m_allowEditing && ![self lockedOrHidden];
}

/** @brief Sets whether the layer permits snapping to its objects
 @param snap YES to allow snapping
 */
- (void)setAllowsSnapToObjects:(BOOL)snap
{
	m_allowSnapToObjects = snap;
}

/** @brief Does the layer permit snapping to its objects?
 @return YES if snapping allowed
 */
- (BOOL)allowsSnapToObjects
{
	return m_allowSnapToObjects;
}

/** @brief Set whether the layer caches its content in an offscreen layer when not active, and how

 Layers can cache their entire contents offscreen when they are inactive. This can boost
 drawing performance when there are many layers, or the layers have complex contents. When the
 layer is deactivated the cache is updated, on activation the "real" content is drawn.
 @param option the desired cache option
 */
- (void)setLayerCacheOption:(DKLayerCacheOption)option
{
	mLayerCachingOption = option;
}

/** @brief Query whether the layer caches its content in an offscreen layer when not active

 Layers can cache their entire contents offscreen when they are inactive. This can boost
 drawing performance when there are many layers, or the layers have complex contents. When the
 layer is deactivated the cache is updated, on activation the "real" content is drawn.
 @return the current cache option
 */
- (DKLayerCacheOption)layerCacheOption
{
	return mLayerCachingOption;
}

/** @brief Query whether the layer is currently highlighted for a drag (receive) operation
 @return YES if highlighted, NO otherwise
 */
- (BOOL)isHighlightedForDrag
{
	return m_inDragOp;
}

/** @brief Set whether the layer is currently highlighted for a drag (receive) operation
 @param highlight YES to highlight, NO otherwise
 */
- (void)setHighlightedForDrag:(BOOL)highlight
{
	if (highlight != m_inDragOp) {
		m_inDragOp = highlight;
		[self setNeedsDisplay:YES];
	}
}

/** @brief Draws the highlighting to indicate the layer is a drag target

 Is only called when the drag highlight is YES. Override for different highlight effect.
 */
- (void)drawHighlightingForDrag
{
	NSRect ir = [[self drawing] interior];

	[[self selectionColour] set];
	NSFrameRectWithWidth(NSInsetRect(ir, -5, -5), 5.0);
}

#pragma mark -
#pragma mark - user actions

/** @brief Sets the snapping state for the layer
 */
- (IBAction)toggleSnapToObjects:(id)sender
{
#pragma unused(sender)

	[self setAllowsSnapToObjects:![self allowsSnapToObjects]];
}

/** @brief Toggles whether the debugging path is overlaid afterdrawing the content.

 This is purely to assist with storage debugging and should not be invoked in production code.
 */
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
		DKDrawableObject* obj;

		// draw the objects - this enumerator has already excluded any not needing to be drawn

		while ((obj = [iter nextObject]))
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
	NSEnumerator* iter = [[self objects] reverseObjectEnumerator];
	DKDrawableObject* dko;
	NSSet* styles;
	NSMutableSet* unionOfAllStyles = nil;

	while ((dko = [iter nextObject])) {
		styles = [dko allStyles];

		if (styles != nil) {
			// we got one - make a set to union them with if necessary

			if (unionOfAllStyles == nil)
				unionOfAllStyles = [styles mutableCopy];
			else
				[unionOfAllStyles unionSet:styles];
		}
	}

	return [unionOfAllStyles autorelease];
}

/** @brief Returns a list of styles used by the current set of objects that are also registered

 Being a set, the result is unordered
 @return the set of unique registered style objects used by objects in this layer
 */
- (NSSet*)allRegisteredStyles
{
	NSEnumerator* iter = [[self objects] reverseObjectEnumerator];
	DKDrawableObject* dko;
	NSSet* styles;
	NSMutableSet* unionOfAllStyles = nil;

	while ((dko = [iter nextObject])) {
		styles = [dko allRegisteredStyles];

		if (styles != nil) {
			// we got one - make a set to union them with if necessary

			if (unionOfAllStyles == nil)
				unionOfAllStyles = [styles mutableCopy];
			else
				[unionOfAllStyles unionSet:styles];
		}
	}

	return [unionOfAllStyles autorelease];
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
		[types addObjectsFromArray:[NSImage imagePasteboardTypes]];
		[types addObject:NSFilenamesPboardType];
		[types addObject:NSStringPboardType];
	}

	// we can write PDF and TIFF image formats:

	if ((op & kDKAllWritableTypes) != 0) {
		[types addObjectsFromArray:[NSArray arrayWithObjects:NSPDFPboardType, NSTIFFPboardType, nil]];
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

	[mStorage release];
	[super dealloc];
}

- (id)init
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

- (id)initWithCoder:(NSCoder*)coder
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
	} else if ([dt isEqualToString:NSStringPboardType]) {
		// create a text object to contain the dropped string

		NSString* theString = [pb stringForType:NSStringPboardType];

		if (theString != nil) {
			DKTextShape* tShape = [DKTextShape textShapeWithString:theString
															inRect:NSMakeRect(0, 0, 200, 100)];
			[tShape fitToText:self];

			cp = [view convertPoint:[sender draggingLocation]
						   fromView:nil];
			cp.x -= [tShape size].width * 0.5;
			cp.y += [tShape size].height * 0.5;

			dropObjects = [NSArray arrayWithObject:tShape];
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

			dropObjects = [NSArray arrayWithObject:imshape];
			[imshape release];
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
