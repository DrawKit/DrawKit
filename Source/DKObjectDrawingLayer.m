/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKObjectDrawingLayer.h"
#import "DKDrawablePath.h"
#import "DKDrawing.h"
#import "DKGeometryUtilities.h"
#import "DKImageShape.h"
#import "DKObjectDrawingLayer+Alignment.h"
#import "DKPasteboardInfo.h"
#import "DKRuntimeHelper.h"
#import "DKSelectionPDFView.h"
#import "DKShapeCluster.h"
#import "DKStyle.h"
#import "DKTextShape.h"
#import "DKUndoManager.h"
#import "LogEvent.h"
#import "NSMutableArray+DKAdditions.h"

#pragma mark Contants(Non - localized)

NSString* const kDKLayerDidReorderObjects = @"kDKLayerDidReorderObjects";
NSString* const kDKDrawableObjectPasteboardType = @"net.apptree.drawkit.drawable";
NSString* const kDKDrawableObjectInfoPasteboardType = @"kDKDrawableObjectInfoPasteboardType";
NSString* const kDKLayerSelectionDidChange = @"kDKLayerSelectionDidChange";
NSString* const kDKLayerKeyObjectDidChange = @"kDKLayerKeyObjectDidChange";

#pragma mark Static Vars
static BOOL sSelVisWhenInactive = NO;
static NSMutableDictionary* sSelectionBuffer = nil;

@interface DKSecretSelectorsDrawingLayer : NSObject
- (IBAction)unionSelectedObjects:(id)sender;
- (IBAction)combineSelectedObjects:(id)sender;
- (IBAction)diffSelectedObjects:(id)sender;
- (IBAction)intersectionSelectedObjects:(id)sender;
- (IBAction)xorSelectedObjects:(id)sender;
- (IBAction)divideSelectedObjects:(id)sender;
@end

@interface DKObjectDrawingLayer ()

enum {
	kObjectRemove,
	kObjectArrayRemove,
	kObjectAdd,
	kObjectArrayAdd,
	kObjectAction
};

- (void)beginBufferingSelectionChanges;
- (void)endBufferingSelectionChanges;
- (BOOL)isBufferingSelectionChanges;
- (void)bufferObject:(id)obj forSelectionOp:(NSInteger)op;

@end

#pragma mark -
@implementation DKObjectDrawingLayer
#pragma mark As a DKObjectDrawingLayer

+ (void)setSelectionIsShownWhenInactive:(BOOL)visInactive
{
	sSelVisWhenInactive = visInactive;
}

+ (BOOL)selectionIsShownWhenInactive
{
	return sSelVisWhenInactive;
}

+ (void)setDefaultSelectionChangesAreUndoable:(BOOL)undoSel
{
	[[NSUserDefaults standardUserDefaults] setBool:undoSel
											forKey:@"DKDrawingLayer_undoableSelectionDefault"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)defaultSelectionChangesAreUndoable
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"DKDrawingLayer_undoableSelectionDefault"];
}

/** @brief Convenience method creates an entire new layer containing the given objects

 The objects are not initially selected
 @param objects an array containing drawable objects which must not be already owned by another layer
 @return a new layer object containing the objects
 */
+ (DKObjectDrawingLayer*)layerWithObjectsInArray:(NSArray*)objects
{
	NSAssert(objects != nil, @"can't create a new layer from a nil array");
	NSAssert([objects count] > 0, @"can't create a new layer from an empty array");

	DKObjectDrawingLayer* newLayer = [[self alloc] init];
	[newLayer addObjectsFromArray:objects];

	return newLayer;
}

#pragma mark -
#pragma mark - useful lists of objects

/** @brief Returns the objects that are not locked, visible and selected

 This also preserves the stacking order of the objects (unlike -selection), so is the most useful
 means of obtaining the set of objects that can be acted upon by a command or user interface control.
 Note that if the layer is locked as a whole, this always returns an empty list
 @return an array, objects that can be acted upon by a command as a set
 */
- (NSArray*)selectedAvailableObjects
{
	NSMutableArray* ao = [[NSMutableArray alloc] init];

	if (![self lockedOrHidden] && [self countOfSelection] > 0) {
		NSEnumerator* iter = [[self availableObjectsInRect:[self selectionBounds]] objectEnumerator];

		for (DKDrawableObject* od in iter) {
			if ([self isSelectedObject:od]) {
				[ao addObject:od];
			}
		}
	}
	return ao;
}

- (NSArray<__kindof DKDrawableObject*>*)selectedAvailableObjectsOfClass:(Class)aClass
{
	NSMutableArray* ao = [[NSMutableArray alloc] init];

	if (![self lockedOrHidden] && [self countOfSelection] > 0) {
		NSEnumerator* iter = [[self availableObjectsInRect:[self selectionBounds]] objectEnumerator];

		for (DKDrawableObject* od in iter) {
			if ([self isSelectedObject:od] && [od isKindOfClass:aClass])
				[ao addObject:od];
		}
	}
	return ao;
}

/** @brief Returns the objects that are visible and selected

 See comments for selectedAvailableObjects
 @return an array
 */
- (NSArray<DKDrawableObject*>*)selectedVisibleObjects
{
	NSMutableArray* ao = [[NSMutableArray alloc] init];

	if ([self visible] && [self countOfSelection] > 0) {
		NSEnumerator* iter = [[self visibleObjectsInRect:[self selectionBounds]] objectEnumerator];

		for (DKDrawableObject* od in iter) {
			if ([self isSelectedObject:od]) {
				[ao addObject:od];
			}
		}
	}
	return ao;
}

/** @brief Returns objects that respond to the selector with the value <answer>

 This is a very simple type of predicate test. Note - the method <selector> must not return
 anything larger than an int or it will be ignored and the result may be wrong.
 @param answer a value that should match the response ofthe selector
 @param selector a selector taking no parameters
 @return an array, objects in the selection that match the value of <answer>
 */
- (NSSet*)selectedObjectsReturning:(NSInteger)answer toSelector:(SEL)selector
{
	NSMutableSet* result = [NSMutableSet set];
	NSInteger rval;

	for (id o in [self selection]) {
		if ([o respondsToSelector:selector]) {
			rval = 0;

			NSInvocation* inv = [NSInvocation invocationWithMethodSignature:[o methodSignatureForSelector:selector]];

			[inv setSelector:selector];
			[inv invokeWithTarget:o];

			if ([[inv methodSignature] methodReturnLength] <= (NSUInteger)(sizeof(NSInteger)))
				[inv getReturnValue:&rval];

			if (rval == answer)
				[result addObject:o];
		}
	}

	//LogEvent_( kInfoEvent, @"%d objects (of %d) returned '%d' to selector '%@'", [result count], [[self selection] count], answer, NSStringFromSelector( selector ));

	return result;
}

/** @brief Returns objects that respond to the selector <selector>

 This is a more general kind of test for ensuring that selectors are only sent to those
 objects that can respond. Hidden or locked objects are also excluded.
 @param selector any selector
 @return an array, objects in the selection that do respond to the given selector
 */
- (NSSet<DKDrawableObject*>*)selectedObjectsRespondingToSelector:(SEL)selector
{
	NSMutableSet* result = [NSMutableSet set];

	for (id o in self.selection) {
		if ([o respondsToSelector:selector] && [o visible] && ![o locked]) {
			[result addObject:o];
		}
	}

	//LogEvent_( kInfoEvent, @"%d objects (of %d) respond to selector '%@'", [result count], [[self selection] count], NSStringFromSelector( selector ));

	return result;
}

/** @brief Returns an array consisting of a copy of the selected objects

 The result maintains the stacking order of the original objects, but the objects do not belong to
 where objects are ultimately going to be pasted back in to this or another layer.
 @return an array of objects.
 */
- (NSArray<DKDrawableObject*>*)duplicatedSelection
{
	NSMutableArray* arr;
	DKDrawableObject* odc;

	arr = [[NSMutableArray alloc] init];

	for (DKDrawableObject* od in self.selectedObjectsPreservingStackingOrder) {
		odc = [od copy];
		[arr addObject:odc];
	}

	return arr;
}

/** @brief Returns the selected objects in their original stacking order.

 Slower than -selection, as it needs to iterate over the objects. This ignores visible and locked
 states of the objects. See also -selectedAvailableObjects. If the layer itself is locked, returns
 an empty array.
 @return an array, the selected objects in their original order
 */
- (NSArray<DKDrawableObject*>*)selectedObjectsPreservingStackingOrder
{
	NSMutableArray* arr = [NSMutableArray array];

	if ([self countOfSelection] > 0 && ![self lockedOrHidden]) {
		NSArray* updObjs = [self objectsForUpdateRect:[self selectionBounds]
											   inView:nil];

		for (DKDrawableObject* obj in updObjs) {
			if ([self isSelectedObject:obj]) {
				[arr addObject:obj];
			}
		}
	}
	return arr;
}

/** @brief Returns the number of objects that are visible and not locked

 If the layer itself is locked, returns 0
 @return the count
 */
- (NSUInteger)countOfSelectedAvailableObjects
{
	// returns the number of selected objects that are also unlocked and visible.

	NSUInteger cc = 0;

	if (![self lockedOrHidden]) {
		for (DKDrawableObject* od in self.selection) {
			if ([od visible] && ![od locked]) {
				++cc;
			}
		}
	}
	return cc;
}

/** @brief Returns the indexed object
 @param indx the index of the required object
 @return the object at that index
 */
- (DKDrawableObject*)objectInSelectedAvailableObjectsAtIndex:(NSUInteger)indx
{
	return [[self selectedAvailableObjects] objectAtIndex:indx];
}

#pragma mark -
#pragma mark - doing stuff to each item in the selection

/** @brief Makes the selected available object perform a given selector.

 An easy way to apply a command to the set of selected available objects, provided that the
 selector requires no parameters
 @param selector the selector the objects should perform
 */
- (void)makeSelectedAvailableObjectsPerform:(SEL)selector
{
	[[self selectedAvailableObjects] makeObjectsPerformSelector:selector];
}

/** @brief Makes the selected available object perform a given selector with a single object parameter
 @param selector the selector the objects should perform
 @param anObject the object parameter to pass to each method
 */
- (void)makeSelectedAvailableObjectsPerform:(SEL)selector withObject:(id)anObject
{
	[[self selectedAvailableObjects] makeObjectsPerformSelector:selector
													 withObject:anObject];
}

/** @brief Locks or unlocks all the selected objects
 @param lock YES to lock the objects, NO to unlock them
 */
- (void)setSelectedObjectsLocked:(BOOL)lock
{
	for (DKDrawableObject* od in self.selection) {
		[od setLocked:lock];
	}
}

/** @brief Hides or shows all of the objects in the selection

 Since hidden selected objects are not drawn, use with care, since usability may be severely
 compromised (for example, how are you going to be able to select hidden objects in order to show them?)
 @param visible YES to show the objects, NO to hide them
 */
- (void)setSelectedObjectsVisible:(BOOL)visible
{
	// sets the visible state of all objects in the selection to <visible>

	for (DKDrawableObject* od in self.selection)
		[od setVisible:visible];
}

/** @brief Reveals any hidden objects, setting the selection to those revealed
 @return YES if at least one object was shown, NO otherwise
 */
- (BOOL)setHiddenObjectsVisible
{
	NSMutableSet* hidden = [NSMutableSet set];

	for (DKDrawableObject* od in self.objects) {
		if (![od visible]) {
			[od setVisible:YES];
			[hidden addObject:od];
		}
	}

	if ([hidden count] > 0) {
		[self setSelection:hidden];
		return YES;
	} else
		return NO;
}

#pragma mark -

/** @brief Causes all selected objects to redraw themselves
 */
- (void)refreshSelectedObjects
{
	[self refreshObjectsInContainer:[self selection]];
}

/** @brief Changes the location of all objects in the selection by dx and dy
 @param dx add this much to each object's x coordinate
 @param dy add this much to each object's y coordinate
 @return YES if there were selected objects, NO if there weren't, and so nothing happened
 */
- (BOOL)moveSelectedObjectsByX:(CGFloat)dx byY:(CGFloat)dy
{
	NSArray* arr = [self selectedAvailableObjects];

	if (([arr count] > 0) && ((dx != 0.0) || (dy != 0.0))) {
		for (DKDrawableObject* od in arr) {
			[od offsetLocationByX:dx
							  byY:dy];
		}

		return YES;
	} else
		return NO;
}

#pragma mark -
#pragma mark - the selection

/** @brief Sets the selection to a given set of objects

 For interactive selections, exchangeSelectionWithObjectsInArray: is more appropriate and efficient
 @param sel a set of objects to select
 */
- (void)setSelection:(NSSet*)sel
{
	NSAssert(sel != nil, @"attempt to set selection with a nil set");

	if (![self lockedOrHidden]) {
		// if this doesn't change the selection, do nothing

		if (![sel isEqualToSet:m_selection]) {
			// if this change is coming from the undo manager, ignore the undoable flag

			if ([self selectionChangesAreUndoable] || [[self undoManager] isUndoing] || [[self undoManager] isRedoing])
				[[[self undoManager] prepareWithInvocationTarget:self] setSelection:[self selection]];

			[self refreshSelectedObjects];
			[m_selection makeObjectsPerformSelector:@selector(objectIsNoLongerSelected)];

			NSMutableSet* temp = [sel mutableCopy];
			m_selection = temp;
			mSelBoundsCached = NSZeroRect;

			[m_selection makeObjectsPerformSelector:@selector(objectDidBecomeSelected)];
			[self refreshSelectedObjects];
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerSelectionDidChange
																object:self];
		}
	}
}

/** @brief Returns the list of objects that are selected

 If stacking order of the items in the selection is important,
 a method such as selectedAvailableObjects or selectedObjectsPreservingStackingOrder should be used.
 if the layer itself is locked or hidden, always returns nil.
 @return all selected objects
 */
- (NSSet*)selection
{
	return [self lockedOrHidden] ? nil : [m_selection copy];
}

/** @brief If the selection consists of a single available object, return it. Otherwise nil.

 This is useful for easily handling the case where an operation can only operate on one object to be
 meaningful. It is also used by the automatic invocation forwarding mechanism.
 @return the selected object if it's the only one and it's available
 */
- (DKDrawableObject*)singleSelection
{
	// if the selection consists of a single object, return it. nil otherwise.

	if ([self isSingleObjectSelected])
		return [m_selection anyObject];
	else
		return nil;
}

/** @brief Return the number of items in the selection.

 KVC compliant; returns 0 if the layer is locked or hidden.
 @return an integer, the countof selected objects
 */
- (NSUInteger)countOfSelection
{
	return [self lockedOrHidden] ? 0 : [m_selection count];
}

#pragma mark -
#pragma mark - selection operations

/** @brief Deselect any selected objects
 */
- (void)deselectAll
{
	if ([self isSelectionNotEmpty]) {
		[self refreshSelectedObjects];
		[m_selection makeObjectsPerformSelector:@selector(objectIsNoLongerSelected)];
		[m_selection removeAllObjects];
		[self hideRulerMarkers];
		mSelBoundsCached = NSZeroRect;
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerSelectionDidChange
															object:self];
	}
}

/** @brief Select all available objects

 This also adds hidden objects to the selection, even though they are not visible
 */
- (void)selectAll
{
	[self exchangeSelectionWithObjectsFromArray:[self objects]];
}

/** @brief Add a single object to the selection

 Any existing objects in the selection remain selected
 @param obj an object to select
 */
- (void)addObjectToSelection:(DKDrawableObject*)obj
{
	NSAssert(obj != nil, @"cannot add a nil object to the selection");

	if (![m_selection containsObject:obj] && ![self lockedOrHidden] && [obj objectMayBecomeSelected]) {
		[m_selection addObject:obj];
		[obj objectDidBecomeSelected];
		[obj notifyVisualChange];
		mSelBoundsCached = NSZeroRect;
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerSelectionDidChange
															object:self];
	}
}

/** @brief Add a set of objects to the selection

 Existing objects in the selection remain selected
 @param objs an array of objects to select
 */
- (void)addObjectsToSelectionFromArray:(NSArray*)objs
{
	NSAssert(objs != nil, @"attempt to add a nil array to the selection");

	if ([objs count] > 0) {
		[self setRulerMarkerUpdatesEnabled:NO];

		for (DKDrawableObject* o in objs) {
			[self addObjectToSelection:o];
		}

		[[self layerGroup] updateRulerMarkersForRect:[self selectionLogicalBounds]];
		[self setRulerMarkerUpdatesEnabled:YES];
	}
}

/** @brief Select the given object, deselecting all previously selected objects
 @param obj the object to select
 @return YES if the selection changed, NO if it did not (i.e. if <obj> was already the only selected object)
 */
- (BOOL)replaceSelectionWithObject:(DKDrawableObject*)obj
{
	NSAssert(obj != nil, @"attempt to replace selection with nil");

	return [self exchangeSelectionWithObjectsFromArray:@[obj]];
}

/** @brief Remove a single object from the selection

 Other objects in the selection are unaffected
 @param obj the object to deselect
 */
- (void)removeObjectFromSelection:(DKDrawableObject*)obj
{
	NSAssert(obj != nil, @"attempt to remove nil object from selection");

	if ([m_selection containsObject:obj] && ![self lockedOrHidden]) {
		if ([self isBufferingSelectionChanges])
			[self bufferObject:obj
				forSelectionOp:kObjectRemove];
		else {
			[obj notifyVisualChange];
			[obj objectIsNoLongerSelected];
			[m_selection removeObject:obj];

			[self updateRulerMarkersForRect:[self selectionLogicalBounds]];

			mSelBoundsCached = NSZeroRect;
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerSelectionDidChange
																object:self];
		}
	}
}

/** @brief Remove a series of object from the selection

 Other objects in the selection are unaffected
 @param objs the list of objects to deselect
 */
- (void)removeObjectsFromSelectionInArray:(NSArray*)objs
{
	NSAssert(objs != nil, @"array passed to -removeObjectsFromSelectionInArray: was nil");

	if (![self lockedOrHidden]) {
		NSSet* removeSet = [NSSet setWithArray:objs];
		[self refreshObjectsInContainer:objs];
		[objs makeObjectsPerformSelector:@selector(objectIsNoLongerSelected)];
		[m_selection minusSet:removeSet];

		[self updateRulerMarkersForRect:[self selectionLogicalBounds]];

		mSelBoundsCached = NSZeroRect;
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerSelectionDidChange
															object:self];
	}
}

/** @brief Sets the selection to a given set of objects

 This is intended as a more efficient version of setSelection:, since it only changes the state of
 objects that differ between the current selection and the list passed. It is intended to be called
 when interactively making a selection such as during a marquee drag, when it's likely that the same
 set of objects is repeatedly offered for selection. Also, since it accepts an array parameter, it may
 be used directly with sets of objects without first making into a set.
 @param sel the set of objects to select
 @return YES if the selection changed, NO if it did not
 */
- (BOOL)exchangeSelectionWithObjectsFromArray:(NSArray*)sel
{
	NSAssert(sel != nil, @"attempt to exchange selection with nil array");

	BOOL didChange = NO;

	if (![self lockedOrHidden]) {
		if ([self isBufferingSelectionChanges])
			[self bufferObject:sel
				forSelectionOp:kObjectArrayAdd];
		else {
			if ([sel count] == 0) {
				if ([m_selection count] > 0) {
					[self deselectAll];
					didChange = YES;
				} else
					return NO;
			} else {
				NSMutableSet* newSel = [NSMutableSet set];

				// check that if any objects in the new set refuse the selection, that they are not included

				for (DKDrawableObject* od in sel) {
					if ([od objectMayBecomeSelected]) {
						[newSel addObject:od];
					}
				}

				if (![m_selection isEqualToSet:newSel]) {
					NSMutableSet* oldSel = [m_selection mutableCopy];

					[self setRulerMarkerUpdatesEnabled:NO];

					[oldSel minusSet:newSel]; // these are not present in the new selection, so will be deselected
					[newSel minusSet:m_selection]; // these are not present in the old selection, so will be selected

					[oldSel makeObjectsPerformSelector:@selector(objectIsNoLongerSelected)];
					[oldSel makeObjectsPerformSelector:@selector(notifyVisualChange)];

					[m_selection setSet:[NSSet setWithArray:sel]];

					[newSel makeObjectsPerformSelector:@selector(objectDidBecomeSelected)];
					[newSel makeObjectsPerformSelector:@selector(notifyVisualChange)];

					mSelBoundsCached = NSZeroRect;
					[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerSelectionDidChange
																		object:self];
					didChange = YES;

					[self setRulerMarkerUpdatesEnabled:YES];
					[self updateRulerMarkersForRect:[self selectionLogicalBounds]];
				}
			}
		}
	}
	return didChange;
}

/** @brief Scrolls one or all views attached to the drawing so that the selection within this layer is visible
 @param aView if not nil, the view to scroll. If nil, scrolls all views
 */
- (void)scrollToSelectionInView:(NSView*)aView
{
	if ([self isSelectionNotEmpty]) {
		NSRect sb = [self selectionBounds];

		if (aView == nil)
			[[self drawing] scrollToRect:sb];
		else
			[aView scrollRectToVisible:sb];
	}
}

#pragma mark -

// these private methods implement a selection buffering behaviour used when performing automatic multiple selection forwarding. Because objects methods called that way typically
// operate in isolation, without buffering the selection the user would typically only see the last object operated on remain selected. This accumulates the various selection
// changes and submits them all in one go after all operations have been completed, thus unifying the separate selection operations into one. See -forwardInvocation.

- (void)beginBufferingSelectionChanges
{
	mBufferSelectionChanges = YES;
}

- (void)endBufferingSelectionChanges
{
	mBufferSelectionChanges = NO;

	if (sSelectionBuffer) {
		// flush the accumulated selection changes to the real selection, thus making them appear all at once.

		NSMutableArray* buf = [sSelectionBuffer objectForKey:@"tobeselected"];

		NSAssert(buf != nil, @"selection buffer was nil");

		// if no objects were added to this list, it means we probably shouldn't change the selection

		if ([buf count] > 0)
			[self exchangeSelectionWithObjectsFromArray:buf];

		[buf removeAllObjects];

		buf = [sSelectionBuffer objectForKey:@"tobedeselected"];

		NSAssert(buf != nil, @"deselection buffer was nil");

		[buf removeAllObjects];

		NSString* action = [sSelectionBuffer objectForKey:@"lastactionname"];
		[self commitSelectionUndoWithActionName:action];

		[sSelectionBuffer removeObjectForKey:@"lastactionname"];
	}
}

- (BOOL)isBufferingSelectionChanges
{
	return mBufferSelectionChanges;
}

- (void)bufferObject:(id)obj forSelectionOp:(NSInteger)op
{
	if (![self isBufferingSelectionChanges] || obj == nil)
		return; // no-op if not buffering

	// make sure buffering structure is inited

	if (sSelectionBuffer == nil)
		sSelectionBuffer = [[NSMutableDictionary alloc] init];

	NSMutableArray* buf;

	if (sSelectionBuffer) {
		buf = [sSelectionBuffer objectForKey:@"tobeselected"];
		if (buf == nil)
			[sSelectionBuffer setObject:[NSMutableArray array]
								 forKey:@"tobeselected"];

		buf = [sSelectionBuffer objectForKey:@"tobedeselected"];
		if (buf == nil)
			[sSelectionBuffer setObject:[NSMutableArray array]
								 forKey:@"tobedeselected"];
	}

	switch (op) {
	case kObjectRemove:
		buf = [sSelectionBuffer objectForKey:@"tobedeselected"];
		[buf addObject:obj];
		break;

	case kObjectArrayRemove:
		buf = [sSelectionBuffer objectForKey:@"tobedeselected"];
		[buf addObjectsFromArray:obj];
		break;

	case kObjectAdd:
		buf = [sSelectionBuffer objectForKey:@"tobeselected"];
		[buf addObject:obj];
		break;

	case kObjectArrayAdd:
		buf = [sSelectionBuffer objectForKey:@"tobeselected"];
		[buf addObjectsFromArray:obj];
		break;

	case kObjectAction:
		[sSelectionBuffer setObject:obj
							 forKey:@"lastactionname"];
		break;

	default:
		break;
	}
}

#pragma mark -
#pragma mark - style operations on multiple items

/** @brief Sets the selection to the set of objects that have the given style

 The style is compared by key, so clones of the style are not considered a match
 @param style the style to match
 @return YES if the selection changed, NO if it did not
 */
- (BOOL)selectObjectsWithStyle:(DKStyle*)style
{
	return [self exchangeSelectionWithObjectsFromArray:[self objectsWithStyle:style]];
}

- (BOOL)replaceStyle:(DKStyle*)style withStyle:(DKStyle*)newStyle selectingObjects:(BOOL)selectObjects
{
	NSArray* matches = [self objectsWithStyle:style];

	for (DKDrawableObject* o in matches) {
		[o setStyle:newStyle];
	}

	if (selectObjects)
		return [self exchangeSelectionWithObjectsFromArray:matches];
	else
		return NO;
}

#pragma mark -
#pragma mark - useful selection tests

/** @brief Query whether a given object is selected or not
 @param obj the object to test
 @return YES if it is selected, NO if not
 */
- (BOOL)isSelectedObject:(DKDrawableObject*)obj
{
	return [m_selection containsObject:obj];
}

/** @brief Query whether any objects are selected
 @return YES if there is at least one object selected, NO if none are
 */
- (BOOL)isSelectionNotEmpty
{
	return [[self selection] count] > 0;
}

/** @brief Query whether there is exactly one object selected
 @return YES if one object selected, NO if none or more than one are
 */
- (BOOL)isSingleObjectSelected
{
	return [[self selection] count] == 1;
}

/** @brief Query whether the selection contains any objects matching the given class
 @param c the class of object sought
 @return YES if there is at least one object of type <c>, NO otherwise
 */
- (BOOL)selectionContainsObjectOfClass:(Class)c
{
	for (id o in self.selection) {
		if ([o isKindOfClass:c]) {
			return YES;
		}
	}

	return NO;
}

/** @brief Return the overall area bounded by the objects in the selection
 @return the union of the bounds of all selected objects
 */
- (NSRect)selectionBounds
{
	//if( !NSIsEmptyRect( mSelBoundsCached ))
	//	return mSelBoundsCached;

	mSelBoundsCached = NSZeroRect;

	if ([self isSelectionNotEmpty]) {
		for (DKDrawableObject* od in self.selection) {
			mSelBoundsCached = UnionOfTwoRects(mSelBoundsCached, [od bounds]);
		}
	}
	return mSelBoundsCached;
}

- (NSRect)selectionLogicalBounds
{
	NSRect lbr = NSZeroRect;

	if ([self isSelectionNotEmpty]) {
		for (DKDrawableObject* od in self.selection) {
			lbr = UnionOfTwoRects(lbr, [od logicalBounds]);
		}
	}
	return lbr;
}

#pragma mark -
#pragma mark - selection undo stuff

/** @brief Set whether selection changes should be recorded for undo.

 Different apps may want to treat selection changes as undoable state changes or not.
 @param undoable YES to record selection changes, NO to not bother.
 */
- (void)setSelectionChangesAreUndoable:(BOOL)undoable
{
	m_selectionIsUndoable = undoable;
}

/** @brief Are selection changes undoable?
 @return YES if they are undoable, NO if not
 */
- (BOOL)selectionChangesAreUndoable
{
	return m_selectionIsUndoable;
}

/** @brief Make a copy of the selection for a possible undo recording

 The selection is copied and stored in the ivar <_selectionUndo>. Usually called at the start of
 an operation that can potentially change the selection state, such as a mouse down.
 */
- (void)recordSelectionForUndo
{
	if (m_selectionUndo) {
		m_selectionUndo = nil;
	}

	// keep a note of the undo count at this point - if it hasn't changed when the
	// selection is committed, then don't record the selection change unless the flag forces it.

	if ([[self undoManager] respondsToSelector:@selector(changeCount)])
		mUndoCount = [(DKUndoManager*)[self undoManager] changeCount];

	m_selectionUndo = [self selection];

	LogEvent_(kReactiveEvent, @"recorded selection for possible undo, count = %lu", (unsigned long)mUndoCount);
}

/** @brief Sends the recorded selection state to the undo manager and tags it with the given action name

 Usually called at the end of any operation than might have changed the selection. This also sets
 the action name even if the selection is unaffected, so callers can just call this with the
 desired action name and get the correct outcome, whether or not selection is undoable or changed.
 This will help keep code tidy.
 @param actionName undo menu string, or nil to use a preset name
 */
- (void)commitSelectionUndoWithActionName:(NSString*)actionName
{
	// sends the recorded selection to the undo manager. If sel changes are not undoable on their own, the sel change is only
	// added to the undo stack if some other operation has also occurred, and then only if the selection actually
	// changed. If the flag is to record all changes, unaccompanied sel changes are recorded regardless.

	if ([self isBufferingSelectionChanges])
		[self bufferObject:actionName
			forSelectionOp:kObjectAction];
	else {
		NSUInteger cc = mUndoCount + 1;

		if ([[self undoManager] respondsToSelector:@selector(changeCount)])
			cc = [(DKUndoManager*)[self undoManager] changeCount];

		if (([self selectionChangesAreUndoable] || cc > mUndoCount) && m_selectionUndo != nil) {
			// if selection hasn't changed, do nothing

			if ([self selectionHasChangedFromRecorded]) {
				LogEvent_(kStateEvent, @"selection changed - recording for undo");

				[[[self undoManager] prepareWithInvocationTarget:self] setSelection:m_selectionUndo];

				// use the passed action name if there is one, otherwise any stored action name

				if (actionName != nil)
					[[self undoManager] setActionName:actionName];
			}
		} else {
			// here, the selection is the only change, and it's not meant to be undone, so
			// do not set the action name

			actionName = nil;
		}

		if (actionName != nil)
			[[self undoManager] setActionName:actionName];

		// done with the recorded selection, so get rid of it

		m_selectionUndo = nil;
	}
}

/** @brief Test whether the selection is now different from the recorded selection
 @return YES if the selection differs, NO if they are the same
 */
- (BOOL)selectionHasChangedFromRecorded
{
	// returns whether the recorded selection differs from the current selection

	return ![[self selection] isEqualToSet:m_selectionUndo];
}

#pragma mark -
#pragma mark - making images of the selected objects

/** @brief Draws only the selected objects, but with the selection highlight itself not shown. This is used when
 imaging the selection to a PDF or other context.
 */
- (void)drawSelectedObjects
{
	[self drawSelectedObjectsWithSelectionState:NO];
}

/** @brief Draws only the selected objects, with the selection highlight given. This is used when
 imaging the selection to a PDF or other context.

 Usually there is no good reason to copy objects with the selection state set to YES, but this is
 provided for special needs when you do want that.
 @param selected YES to show the selection, NO to not show it
 */
- (void)drawSelectedObjectsWithSelectionState:(BOOL)selected
{
	NSArray* sel = [self selectedObjectsPreservingStackingOrder];

	for (DKDrawableObject* od in sel) {
		[od drawContentWithSelectedState:selected];
	}
}

/** @brief Creates an image of the selected objects

 Used to create an image representation of the selection when performing a cut or copy operation, to
 allow the selection to be exported to graphical apps that don't understand our internal object format.
 @return an image
 */
- (NSImage*)imageOfSelectedObjects
{
	NSImage* img;
	NSRect sb;

	sb = [self selectionBounds];

	img = [[NSImage alloc] initWithSize:sb.size];

	NSAffineTransform* tfm = [NSAffineTransform transform];
	[tfm translateXBy:-sb.origin.x
				  yBy:-sb.origin.y];

	[img lockFocusFlipped:[[self drawing] isFlipped]];
	[tfm concat];
	[self drawSelectedObjects];
	[img unlockFocus];

	return img;
}

/** @brief Creates a PDF representation of the selected objects

 Used to create a PDF representation of the selection when performing a cut or copy operation, to
 allow the selection to be exported to PDF apps that don't understand our internal object format.
 This requires the use of a temporary special view for recording the output as PDF.
 @return PDF data of the selected objects only
 */
- (NSData*)pdfDataOfSelectedObjects
{
	// returns pdf data of the objects in the selection. This images just the selected objects and leaves out any others,
	// even if they overlap or interleave with the selected objects. If the selection is empty, returns nil.

	NSRect fr = NSZeroRect;

	fr.size = [[self drawing] drawingSize];
	DKSelectionPDFView* pdfView = [[DKSelectionPDFView alloc] initWithFrame:fr];
	DKViewController* vc = [pdfView makeViewController];

	[[self drawing] addController:vc];

	NSRect sr = [self selectionBounds];
	NSData* pdfData = [pdfView dataWithPDFInsideRect:sr];

	return pdfData;
}

#pragma mark -
#pragma mark - clipboard ops

/** @brief Copies the selection to the given pasteboard in a variety of formats

 Data is recorded as native data, PDF and TIFF. Note that locked objects can't be copied as
 native types, but images are still copied.
 @param pb the pasteboard to copy to
 */
- (void)copySelectionToPasteboard:(NSPasteboard*)pb
{
	NSAssert(pb != nil, @"cannot write to nil pasteboard");

	NSMutableArray* dataTypes = [[self pasteboardTypesForOperation:kDKAllWritableTypes] mutableCopy];
	NSArray* sel = [self selectedAvailableObjects];

	// if the selection is empty, remove the native type from the list

	if ([sel count] == 0)
		[dataTypes removeObject:kDKDrawableObjectPasteboardType];

	[pb declareTypes:dataTypes
			   owner:self];

	// add an info object to the pasteboard - allows info about the objects to be read without dearchiving
	// the objects themselves.

	DKPasteboardInfo* pbInfo = [DKPasteboardInfo pasteboardInfoForObjects:sel];
	[pbInfo writeToPasteboard:pb];

	if ([sel count] > 0) {
		// convert selection to data by archiving it.
		// DK's native pasteboard type is simply an archived array of the selection.

		NSData* pbdata = [NSKeyedArchiver archivedDataWithRootObject:sel];
		[pb setData:pbdata
			forType:kDKDrawableObjectPasteboardType];

		// if a single object is selected, it is offered the chance to add further data to the clipboard

		if ([sel count] == 1) {
			DKDrawableObject* ss = [sel lastObject];
			[ss writeSupplementaryDataToPasteboard:pb];
		}
	}

	// add image of selection in PDF format:
	NSData* pdf = [self pdfDataOfSelectedObjects];
	[pb setData:pdf
		forType:NSPasteboardTypePDF];

	// and TIFF format:

	NSImage* si = [self imageOfSelectedObjects];
	[pb setData:[si TIFFRepresentation]
		forType:NSPasteboardTypeTIFF];
}

#pragma mark -
#pragma mark - options

/** @brief Sets whether selection highlights should be drawn on top of all other objects, or if they should be
 drawn with the object at its current stacking position.

 Default is YES
 @param onTop YES to draw on top, NO to draw in situ
 */
- (void)setDrawsSelectionHighlightsOnTop:(BOOL)onTop
{
	m_drawSelectionOnTop = onTop;
}

/** @brief Draw selection highlights on top or in situ?

 Default is YES
 @return YES if drawn on top, NO in situ.
 */
- (BOOL)drawsSelectionHighlightsOnTop
{
	return m_drawSelectionOnTop;
}

/** @brief Sets whether a drag into this layer will target individual objects or not.

 If YES, the object under the mouse will highlight as a drag into the layer proceeds, and upon drop,
 the object itself will be passed the drop information. Default is YES.
 @param allow allow individual objects to receive drags
 */
- (void)setAllowsObjectsToBeTargetedByDrags:(BOOL)allow
{
	m_allowDragTargeting = allow;
}

/** @brief Returns whether a drag into this layer will target individual objects or not.

 If YES, the object under the mouse will highlight as a drag into the layer proceeds, and upon drop,
 the object itself will be passed the drop information. Default is YES.
 @return YES if objects can be targeted by drags
 */
- (BOOL)allowsObjectsToBeTargetedByDrags
{
	return m_allowDragTargeting;
}

/** @brief Sets whether the selection is actually shown or not.

 Normally the selection should be visible, but some tools might want to hide it temporarily
 at certain well-defined times, such as when dragging objects.
 @param vis YES to show the selection, NO to hide it
 */
- (void)setSelectionVisible:(BOOL)vis
{
	if (vis != m_selectionVisible) {
		m_selectionVisible = vis;
		[self refreshSelectedObjects];
	}
}

/** @brief Whether the selection is actually shown or not.

 Normally the selection should be visible, but some tools might want to hide it temporarily
 at certain well-defined times, such as when dragging objects.
 @return YES if the selection is visible, NO if hidden
 */
- (BOOL)selectionVisible
{
	return m_selectionVisible;
}

/**
 Default is NO for backward compatibility. This feature is useful to allow an action to be
 defined by an object but to have it invoked on all objects that are able to respond in the
 current selection without having to implement the action in the layer. Formerly such actions were
 only forwarded if exactly one object was selected that could respond. See -forwardInvocation.
 @param autoForward YES to automatically forward, NO to only operate on a single selected object
 */
- (void)setMultipleSelectionAutoForwarding:(BOOL)autoForward
{
	mMultipleAutoForwarding = autoForward;
}

- (BOOL)multipleSelectionAutoForwarding
{
	return mMultipleAutoForwarding;
}

/** @brief Handle validation of menu items in a multiple selection when autoforwarding is enabled

 This also tries to intelligently set the state of the item. If some objects set the state one way
 and others to another state, this will automatically set the mixed state. While the menu item
 itself is enabled if any object enabled it, the mixed state indicates that the outcome of the
 operation is likely to vary for different objects.
 @param item the menu item to validate
 @return YES if at least one of the objects enabled the item, NO otherwise
 */
- (BOOL)multipleSelectionValidatedMenuItem:(NSMenuItem*)item
{
	NSControlStateValue menuItemState = NSOffState;
	BOOL hadFirst = NO;
	BOOL valid = NO;

	for (DKDrawableObject* obj in self.selection) {
		if ([obj validateMenuItem:item]) {
			valid = YES;

			if (!hadFirst) {
				menuItemState = [item state];
				hadFirst = YES;
			} else {
				if ([item state] != menuItemState && menuItemState != NSMixedState)
					menuItemState = NSMixedState;
			}
		}
	}

	[item setState:menuItemState];
	return valid;
}

#pragma mark -
#pragma mark - drag + drop

@synthesize dragExclusionRect = m_dragExcludeRect;

/** @brief Initiates a drag of the selection to another document or app, or back to self.

 Keeps control until the drag completes. Swallows the mouseUp event. called from the mouseDragged
 method when the mouse leaves the drag exclusion rect.
 @param event the event that triggered the action - must be a mouseDown or mouseDragged
 @param view the view in which the user dragging operation is taking place
 */
- (void)beginDragOfSelectedObjectsWithEvent:(NSEvent*)event inView:(NSView*)view
{
	// starts a "real" drag of the selection. Usually called from mouseDragged when the mouse leaves the drag exclusion rect.

	NSImage* image = [self imageOfSelectedObjects];
	NSPasteboard* pb = [NSPasteboard pasteboardWithName:NSDragPboard];
	NSPoint dragLoc;

	dragLoc.x = NSMinX([self selectionBounds]);
	dragLoc.y = NSMaxY([self selectionBounds]);

	// set the image the other way up and make it a bit transparent

	[image lockFocus];
	[image drawAtPoint:NSZeroPoint
			  fromRect:NSZeroRect
			 operation:NSCompositeCopy
			  fraction:0.5];
	[image unlockFocus];

	// put the selection on the pasteboard

	[self copySelectionToPasteboard:pb];
	[self hideInfoWindow];

	// save a temporary list of the objects being dragged so that if they are dragged back into the same layer,
	// the originals can be removed.

	m_objectsPendingDrag = [self selectedObjectsPreservingStackingOrder];
	[self setSelectedObjectsVisible:NO];

	[view dragImage:image
				 at:dragLoc
			 offset:NSZeroSize
			  event:event
		 pasteboard:pb
			 source:self
		  slideBack:YES];
}

- (void)drawingSizeChanged:(NSNotification*)note
{
#pragma unused(note)

	[self setDragExclusionRect:[[self drawing] interior]];
}

#pragma mark -
#pragma mark - group operations

/** @brief Layer is about to group a number of objects

 The default does nothing and returns YES - subclasses could override this to enhance or refuse
 grouping. This is invoked by the high level groupObjects: action method.
 @param objectsToBeGrouped the objects about to be grouped
 @param aGroup a group into which they will be placed
 @return YES to proceed with the group, NO to abandon the grouping
 */
- (BOOL)shouldGroupObjects:(NSArray*)objectsToBeGrouped intoGroup:(DKShapeGroup*)aGroup
{
#pragma unused(objectsToBeGrouped, aGroup)

	return YES;
}

/** @brief Layer did create the group and added it to the layer

 The default does nothing - subclasses could override this. This is invoked by the high level
 @param aGroup the group just added
 */
- (void)didAddGroup:(DKShapeGroup*)aGroup
{
#pragma unused(aGroup)
}

/** @brief A group object is about to be ungrouped

 The default does nothing - subclasses could override this. This is invoked by a group when it
 is about to ungroup - see [DKShapeGroup ungroupObjects:]
 @param aGroup the group about to be ungrouped
 @return YES to allow the ungroup, NO to prevent it
 */
- (BOOL)shouldUngroup:(DKShapeGroup*)aGroup
{
#pragma unused(aGroup)
	return YES;
}

/** @brief A group object was ungrouped and its contents added back into the layer

 The default does nothing - subclasses could override this. This is invoked by the group just after
 it has ungrouped - see [DKShapeGroup ungroupObjects:]
 @param ungroupedObjects the objects just ungrouped
 */
- (void)didUngroupObjects:(NSArray*)ungroupedObjects
{
#pragma unused(ungroupedObjects)
}

#pragma mark -
#pragma mark - user actions

/** @brief Perform a cut

 Cuts the selection
 @param sender the action's sender
 */
- (IBAction)cut:(id)sender
{
	[self copy:sender];
	[self delete:sender];
	[[self undoManager] setActionName:NSLocalizedString(@"Cut", @"undo string for cut object from layer")];
}

/** @brief Perform a copy

 Copies the selection to the general pasteboard
 @param sender the action's sender
 */
- (IBAction)copy:(id)sender
{
#pragma unused(sender)

	if ([self isSelectionNotEmpty])
		[self copySelectionToPasteboard:[NSPasteboard generalPasteboard]];
}

/** @brief Perform a paste

 Pastes from the general pasteboard
 @param sender the action's sender
 */
- (IBAction)paste:(id)sender
{
#pragma unused(sender)

	if ([self lockedOrHidden])
		return;

	[self recordSelectionForUndo];

	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	NSArray* objects = [DKDrawableObject nativeObjectsFromPasteboard:pb];
	BOOL isContextMenu = ([sender tag] == kDKPasteCommandContextualMenuTag);
	NSPoint cp = NSZeroPoint;
	NSView* view = (NSView*)[[NSApp keyWindow] firstResponder];

	// if the command came from the context menu, use the mouse location to position the item

	if (isContextMenu)
		cp = [DKDrawingView pointForLastContextualMenuEvent];
	else
		cp = [(GCZoomView*)view centredPointInDocView];

	if (objects != nil && [objects count] > 0) {
		/*
		if ( isContextMenu )
		{
			// figure out the bottom left corner of the pasted objects
		 
			NSRect ur = [DKDrawableObject unionOfBoundsOfDrawablesInArray:objects];
			cp.x -= ur.size.width * 0.5;
			cp.y += ur.size.height * 0.5;
		 
			[super addObjects:objects fromPasteboard:pb atDropLocation:cp];
			[self exchangeSelectionWithObjectsFromArray:objects];
		}
		else
		 */
		{
			// for repeated pastes, calculate the desired paste origin. Use the original bounds if possible for
			// most accurate positioning when pasting. Calculated bounds may differ as layer, etc not present.

			DKPasteboardInfo* pbInfo = [DKPasteboardInfo pasteboardInfoWithPasteboard:pb];
			NSRect originalBounds = [pbInfo bounds];

			[self updatePasteCountWithPasteboard:pb];

			NSPoint pasteOrigin = [self pasteOrigin];
			NSSize pasteOffset = [self pasteOffset];

			pasteOrigin.x += pasteOffset.width;
			pasteOrigin.y += pasteOffset.height;

			if ([self pasteCount] > 1) {
				[self setPasteOrigin:pasteOrigin];
				pasteOrigin.x += pasteOffset.width;
				pasteOrigin.y += pasteOffset.height;
			}

			[self addObjectsFromArray:objects
							   bounds:originalBounds
					  relativeToPoint:pasteOrigin
						pinToInterior:YES];
			[self exchangeSelectionWithObjectsFromArray:objects];

			// compensate after a zero-offset paste so that next one will be in the right place.

			if (pasteOffset.width == 0 && pasteOffset.height == 0) {
				[self setPasteOffsetX:DEFAULT_PASTE_OFFSET
									y:DEFAULT_PASTE_OFFSET];
				pasteOrigin.x -= DEFAULT_PASTE_OFFSET;
				pasteOrigin.y -= DEFAULT_PASTE_OFFSET;
				[self setPasteOrigin:pasteOrigin];
			}

			[self setRecordingPasteOffset:YES];
		}

		// select the objects that were pasted
		[self scrollToSelectionInView:view];

		NSString* action = ([objects count] == 1) ? NSLocalizedString(@"Paste Object", @"undo action for paste object") : NSLocalizedString(@"Paste Objects", @"undo action for paste objects");
		[self commitSelectionUndoWithActionName:action];
	} else if ([pb availableTypeFromArray:@[NSPasteboardTypeString]] != nil) {
		// pasting a string - add a text object

		NSString* theString = [pb stringForType:NSPasteboardTypeString];

		if (theString != nil) {
			DKTextShape* tShape = [DKTextShape textShapeWithString:theString
															inRect:NSMakeRect(0, 0, 200, 100)];
			[tShape fitToText:self];

			cp.x -= [tShape size].width * 0.5;
			cp.y += [tShape size].height * 0.5;

			objects = @[tShape];
			[self addObjects:objects
				fromPasteboard:pb
				atDropLocation:cp];
			[self scrollToSelectionInView:view];
			[self commitSelectionUndoWithActionName:NSLocalizedString(@"Paste Text", @"undo string for paste text")];
		}
	} else if ([NSImage canInitWithPasteboard:pb]) {
		// convert to an image shape and add it. Since this doesn't have a position, paste it in the centre of
		// the view.

		NSImage* image = [[NSImage alloc] initWithPasteboard:pb];
		DKImageShape* imshape = [[DKImageShape alloc] initWithImage:image];

		objects = @[imshape];

		cp.x -= [imshape size].width * 0.5;
		cp.y += [imshape size].height * 0.5;

		[self addObjects:objects
			fromPasteboard:pb
			atDropLocation:cp];
		[self scrollToSelectionInView:view];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Paste Image", @"undo string for paste image")];
	}
}

/** @brief Performs a delete operation
 @param sender the action's sender
 */
- (IBAction) delete:(id)sender
{
#pragma unused(sender)

	if ([[self selectedAvailableObjects] count] > 0 && ![self lockedOrHidden]) {
		[self recordSelectionForUndo];
		NSArray* objectsToDelete = [self selectedAvailableObjects];
		[self removeObjectsInArray:objectsToDelete];
		[objectsToDelete makeObjectsPerformSelector:@selector(setContainer:)
										 withObject:nil];
		[self deselectAll];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Delete", @"undo string for Delete")];
	}
}

/**
 Calls delete: when backspace key is typed
 @param sender the action's sender
 */
- (IBAction)deleteBackward:(id)sender
{
	[self delete:sender];
}

/** @brief Duplicates the selection
 @param sender the action's sender
 */
- (IBAction)duplicate:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden]) {
		NSArray* s = [self duplicatedSelection];

		if ([s count] > 0) {
			[self setPasteOrigin:[DKDrawableObject unionOfBoundsOfDrawablesInArray:s].origin];
			[self recordSelectionForUndo];

			NSPoint rel = [self pasteOrigin];
			rel.x += [self pasteOffset].width;
			rel.y += [self pasteOffset].height;

			[self addObjectsFromArray:s
					  relativeToPoint:rel
						pinToInterior:YES];
			[self exchangeSelectionWithObjectsFromArray:s];
			[self scrollToSelectionInView:nil];
			[self commitSelectionUndoWithActionName:NSLocalizedString(@"Duplicate", @"undo string for Duplicate")];
			[self setRecordingPasteOffset:YES];
		}
	}
}

/** @brief Selects all objects
 @param sender the action's sender (in fact the view)
 */
- (IBAction)selectAll:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden]) {
		[self recordSelectionForUndo];
		[self selectAll];
		[self scrollToSelectionInView:nil];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Select All", @"undo string for select all")];
	}
}

/** @brief Deselects all objects in the selection
 @param sender the action's sender
 */
- (IBAction)selectNone:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden]) {
		[self recordSelectionForUndo];
		[self deselectAll];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Deselect All", @"undo string for deselect all")];
	}
}

/** @brief Selects the objects not selected, deselects those that are ("inverts" selection)
 @param sender the action's sender
 */
- (IBAction)selectOthers:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden]) {
		[self recordSelectionForUndo];

		NSMutableSet* allObjects = [NSMutableSet setWithArray:[self availableObjects]];
		NSSet* selection = [self selection];

		[allObjects minusSet:selection];
		[self setSelection:allObjects];

		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Select Others", @"undo string for select others")];
	}
}

/** @brief Brings the selected object forward
 @param sender the action's sender
 */
- (IBAction)objectBringForward:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden] && [self isSingleObjectSelected]) {
		[self moveUpObject:[self singleSelection]];
		[[self undoManager] setActionName:NSLocalizedString(@"Bring Forwards", @"undo name for bring object forward")];
	}
}

/** @brief Sends the selected object backward
 @param sender the action's sender
 */
- (IBAction)objectSendBackward:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden] && [self isSingleObjectSelected]) {
		[self moveDownObject:[self singleSelection]];
		[[self undoManager] setActionName:NSLocalizedString(@"Send Backwards", @"undo name for send object backward")];
	}
}

/** @brief Brings the selected object to the front
 @param sender the action's sender
 */
- (IBAction)objectBringToFront:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden] && [self isSingleObjectSelected]) {
		[self moveObjectToTop:[self singleSelection]];
		[[self undoManager] setActionName:NSLocalizedString(@"Bring To Front", @"undo name for bring object to front")];
	}
}

/** @brief Sends the selected object to the back
 @param sender the action's sender
 */
- (IBAction)objectSendToBack:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden] && [self isSingleObjectSelected]) {
		[self moveObjectToBottom:[self singleSelection]];
		[[self undoManager] setActionName:NSLocalizedString(@"Send To Back", @"undo name for send object to back")];
	}
}

/** @brief Locks all selected objects
 @param sender the action's sender
 */
- (IBAction)lockObject:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden]) {
		// lock the selected objects (not the layer)

		[self setSelectedObjectsLocked:YES];
		[[self undoManager] setActionName:NSLocalizedString(@"Lock", @"undo name for lock object")];

		// because the selecton usually means the "available" object, and locking makes fewer objects available,
		// a change of selection should be notified. This sends a notification but will not trigger a KVO-based
		// notification.

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerSelectionDidChange
															object:self];
	}
}

/** @brief Unlocks all selected objects
 @param sender the action's sender
 */
- (IBAction)unlockObject:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden]) {
		// unlock the selected objects (not the layer)

		[self setSelectedObjectsLocked:NO];
		[[self undoManager] setActionName:NSLocalizedString(@"Unlock", @"undo name for lock object")];

		// because the selecton usually means the "available" object, and unlocking makes more objects available,
		// a change of selection should be notified. This sends a notificaiton but will not trigger a KVO-based
		// notification.

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerSelectionDidChange
															object:self];
	}
}

/** @brief Shows all selected objects
 @param sender the action's sender
 */
- (IBAction)showObject:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden]) {
		[self setSelectedObjectsVisible:YES];
		[self scrollToSelectionInView:nil];
		[[self undoManager] setActionName:NSLocalizedString(@"Show Objects", @"undo name for show object")];
	}
}

/** @brief Hides all selected objects, then deselects all

 Caution: hiding the selection has usability implications!!
 @param sender the action's sender
 */
- (IBAction)hideObject:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden]) {
		[self recordSelectionForUndo];
		[self setSelectedObjectsVisible:NO];
		[self deselectAll];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Hide Objects", @"undo string for hide objects")];
	}
}

/** @brief Reveals any hidden objects, setting the selection to them

 Beeps if no objects were hidden
 @param sender the action's sender
 */
- (IBAction)revealHiddenObjects:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden]) {
		[self recordSelectionForUndo];
		if ([self setHiddenObjectsVisible]) {
			[self scrollToSelectionInView:nil];
			[self commitSelectionUndoWithActionName:NSLocalizedString(@"Reveal Hidden Objects", @"undo string for reveal hidden objects")];
		} else
			NSBeep();
	}
}

/** @brief Turns the selected objects into a group.

 The new group is placed on top of all objects even if the objects grouped were not on top. The group
 as a whole can be moved to any index - ungrouping replaces objects at that index.
 @param sender the action's sender
 */
- (IBAction)groupObjects:(id)sender
{
#pragma unused(sender)

	// turn the selected objects into a group object

	if (![self lockedOrHidden] && [self isSelectionNotEmpty] && ![self isSingleObjectSelected]) {
		// filter the selection so that objects that refuse grouping are removed:

		NSArray* objects = [DKShapeGroup objectsAvailableForGroupingFromArray:[self selectedAvailableObjects]];

		// if there are < 2 remaining, beep and do nothing

		if ([objects count] < 2) {
			NSBeep();
			return;
		}

		DKShapeGroup* group = [[DKShapeGroup alloc] init];

		if ([self shouldGroupObjects:objects
						   intoGroup:group]) {
			[self recordSelectionForUndo];

			// because the objects need a valid container in order for their location change to be recorded for undo,
			// the group must be added to the layer before objects are added to the group. hence we do not use the
			// convenience method +groupWithObjects: here, as it does not allow this order of the transfer of objects.

			[self removeObjectsInArray:objects];
			[self addObject:group];
			[group setGroupObjects:objects];

			[self didAddGroup:group];
			[self replaceSelectionWithObject:group];
			[self commitSelectionUndoWithActionName:NSLocalizedString(@"Group", @"undo string for grouping")];
		}
	}
}

- (IBAction)clusterObjects:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden] && [self isSelectionNotEmpty] && ![self isSingleObjectSelected]) {
		NSArray* objects = [DKShapeGroup objectsAvailableForGroupingFromArray:[self selectedAvailableObjects]];

		// if there are < 2 remaining, beep and do nothing

		if ([objects count] < 2) {
			NSBeep();
			return;
		}

		[self recordSelectionForUndo];

		DKShapeCluster* group = [DKShapeCluster clusterWithObjects:objects
													  masterObject:[objects lastObject]];

		[self removeObjectsInArray:objects];
		[self addObject:group];
		[self replaceSelectionWithObject:group];
		[self commitSelectionUndoWithActionName:NSLocalizedString(@"Cluster", @"undo string for clustering")];
	}
}

/** @brief Set the selected objects ghosted.

 Ghosted objects draw using an unobtrusive placeholder style
 @param sender the action's sender
 */
- (IBAction)ghostObjects:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden]) {
		for (DKDrawableObject* od in self.selection) {
			[od setGhosted:YES];
		}

		[[self undoManager] setActionName:NSLocalizedString(@"Ghost Objects", @"undo name for ghost object")];
	}
}

/** @brief Set the selected objects unghosted.

 Ghosted objects draw using an unobtrusive placeholder style
 @param sender the action's sender
 */
- (IBAction)unghostObjects:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden]) {
		for (DKDrawableObject* od in self.selection) {
			[od setGhosted:NO];
		}

		[[self undoManager] setActionName:NSLocalizedString(@"Unghost Objects", @"undo name for unghost object")];
	}
}

#pragma mark -

/** @brief Nudges the selected objects left by one unit

 The nudge amount is determined by the drawing's grid settings
 @param sender the action's sender (in fact the view)
 */
- (IBAction)moveLeft:(id)sender
{
	if (![self lockedOrHidden]) {
		NSPoint nd = [[self drawing] nudgeOffset];
		if ([self moveSelectedObjectsByX:-nd.x
									 byY:0]) {
			[self scrollToSelectionInView:sender];
			[[self undoManager] setActionName:NSLocalizedString(@"Nudge Left", @"undo string for nudge left")];
		}
	}
}

/** @brief Nudges the selected objects right by one unit

 The nudge amount is determined by the drawing's grid settings
 @param sender the action's sender (in fact the view)
 */
- (IBAction)moveRight:(id)sender
{
	if (![self lockedOrHidden]) {
		NSPoint nd = [[self drawing] nudgeOffset];

		if ([self moveSelectedObjectsByX:nd.x
									 byY:0]) {
			[self scrollToSelectionInView:sender];
			[[self undoManager] setActionName:NSLocalizedString(@"Nudge Right", @"undo string for nudge left")];
		}
	}
}

/** @brief Nudges the selected objects up by one unit

 The nudge amount is determined by the drawing's grid settings
 @param sender the action's sender (in fact the view)
 */
- (IBAction)moveUp:(id)sender
{
	if (![self lockedOrHidden]) {
		NSPoint nd = [[self drawing] nudgeOffset];
		if ([self moveSelectedObjectsByX:0
									 byY:-nd.y]) {
			[self scrollToSelectionInView:sender];
			[[self undoManager] setActionName:NSLocalizedString(@"Nudge Up", @"undo string for nudge left")];
		}
	}
}

/** @brief Nudges the selected objects down by one unit

 The nudge amount is determined by the drawing's grid settings
 @param sender the action's sender (in fact the view)
 */
- (IBAction)moveDown:(id)sender
{
	if (![self lockedOrHidden]) {
		NSPoint nd = [[self drawing] nudgeOffset];
		if ([self moveSelectedObjectsByX:0
									 byY:nd.y]) {
			[self scrollToSelectionInView:sender];
			[[self undoManager] setActionName:NSLocalizedString(@"Nudge Down", @"undo string for nudge left")];
		}
	}
}

#pragma mark -

/** @brief Selects all objects having the same style as the single selected object
 @param sender the action's sender
 */
- (IBAction)selectMatchingStyle:(id)sender
{
#pragma unused(sender)

	if (![self lockedOrHidden]) {
		DKStyle* style = [[self singleSelection] style];

		if (style) {
			[self selectObjectsWithStyle:style];
			[self scrollToSelectionInView:nil];
		}
	}
}

/** @brief Connects any paths sharing an end point into a single path
 @param sender the action's sender
 */
- (IBAction)joinPaths:(id)sender
{
	if (![self lockedOrHidden]) {
		NSArray* sp = [self selectedAvailableObjectsOfClass:[DKDrawablePath class]];
		DKDrawablePath* a = nil;
		NSInteger joinsMade = 0;

		if ([sp count] < 2)
			return;

		BOOL colin = ([sender tag] == kDKMakeColinearJoinTag);

		// use a tolerance value equal to a grid square, or 2, whichever is greater:

		CGFloat tolerance = [[self drawing] nudgeOffset].x;

		if (tolerance < 2)
			tolerance = 2;

		[self recordSelectionForUndo];

		for (DKDrawablePath* path in sp) {
			// first path is "master" and dictates style etc of result

			if (a == nil)
				a = path;
			else {
				if ([a join:path
						   tolerance:tolerance
						makeColinear:colin]) {
					[self removeObject:path];
					++joinsMade;
				}
			}
		}

		if (joinsMade > 0)
			[self commitSelectionUndoWithActionName:NSLocalizedString(@"Join Paths", @"undo string for join paths")];
		else
			NSBeep();
	}
}

/** @brief Applies a style to the objects in the selection

 The sender -representedObject must be a DKStyle. This is designed to match the menu items managed
 by DKStyleRegistry, but can be arranged to be any object that can have a represented object.
 @param sender the action's sender
 */
- (IBAction)applyStyle:(id)sender
{
	id repObject = [sender representedObject];

	if (sender && repObject && [self isSelectionNotEmpty]) {
		if ([repObject isKindOfClass:[DKStyle class]]) {
			[[self selectedAvailableObjects] makeObjectsPerformSelector:@selector(setStyle:)
															 withObject:repObject];
			[[self undoManager] setActionName:NSLocalizedString(@"Apply Style", @"undo action for Apply Style")];
		}
	}
}

#pragma mark -
#pragma mark As a DKObjectOwnerLayer

/** @brief Performs a hit test but also returns the hit part code

 See notes for hitTest:
 @param point the point to test
 @param part pointer to int, receives the partcode hit as a result of the test
 @return the object hit, or nil if none
 */
- (DKDrawableObject*)hitTest:(NSPoint)point partCode:(NSInteger*)part
{
	// test for hits in the layer's objects. When selections are drawn on top, this first does a top-down search of the selected
	// objects so that the user is better able to manipulate a control knob that lies on top of another object.

	NSEnumerator* iter;
	NSInteger pc;

	if ([self drawsSelectionHighlightsOnTop]) {
		iter = [[self selectedObjectsPreservingStackingOrder] reverseObjectEnumerator];

		for (DKDrawableObject* o in iter) {
			pc = [o hitPart:point];

			if (pc != kDKDrawingEntireObjectPart && pc != kDKDrawingNoPart) {
				if (part)
					*part = pc;

				return o;
			}
		}
	}

	return [super hitTest:point
				 partCode:part];
}

/** @brief Removes an object from the layer

 If the object is selected, it is removed from the selection
 @param indx the index at which the object should be removed
 */
- (void)removeObjectFromObjectsAtIndex:(NSUInteger)indx
{
	NSAssert(indx < [self countOfObjects], @"error - index is beyond bounds");

	if (![self lockedOrHidden]) {
		DKDrawableObject* obj = [self objectInObjectsAtIndex:indx];
		[super removeObjectFromObjectsAtIndex:indx];
		[self removeObjectFromSelection:obj];

		if (obj == mKeyAlignmentObject)
			mKeyAlignmentObject = nil;
	}
}

/** @brief Replaces an object in the layer with another

 If index is selected, new object replaces the object in the selection
 @param indx the index at which the object should be exchanged
 @param obj the object that will replace the item at index
 */
- (void)replaceObjectInObjectsAtIndex:(NSUInteger)indx withObject:(DKDrawableObject*)obj
{
	NSAssert(obj != nil, @"attempt to add a nil object to the layer (replace)");
	NSAssert(indx < [self countOfObjects], @"error - index is beyond bounds");

	if (![self lockedOrHidden]) {
		DKDrawableObject* oldObj = [self objectInObjectsAtIndex:indx];
		BOOL selected = [oldObj isSelected];

		[super replaceObjectInObjectsAtIndex:indx
								  withObject:obj];

		if (selected) {
			[self removeObjectFromSelection:oldObj];
			[self addObjectToSelection:obj];
		}

		if (oldObj == mKeyAlignmentObject)
			mKeyAlignmentObject = obj;
	}
}

/** @brief Removes objects from the indexes listed by the set

 If the indexes are present in the selection, they are removed
 @param set an index set
 */
- (void)removeObjectsAtIndexes:(NSIndexSet*)set
{
	NSAssert(set != nil, @"can't remove objects - index set is nil");

	if (![self lockedOrHidden]) {
		NSArray* objs = [self objectsAtIndexes:set];
		[super removeObjectsAtIndexes:set];
		[self removeObjectsFromSelectionInArray:objs];

		if ([objs containsObject:mKeyAlignmentObject])
			mKeyAlignmentObject = nil;
	}
}

/** @brief Add objects to the layer from the pasteboard

 Overrides the superclass so that the added objects are initially selected
 @param objects a list of objects already dearchived from the pasteboard
 @param pb the pasteboard (for information only)
 @param p the drop location of the objects
 */
- (void)addObjects:(NSArray*)objects fromPasteboard:(NSPasteboard*)pb atDropLocation:(NSPoint)p
{
	[self recordSelectionForUndo];
	[super addObjects:objects
		fromPasteboard:pb
		atDropLocation:p];
	[self exchangeSelectionWithObjectsFromArray:objects];

	// need to commit the selection change here but caller may want to set a more specific action name

	[self commitSelectionUndoWithActionName:NSLocalizedString(@"Drop", @"undo string for generic drop")];
}

#pragma mark -
#pragma mark As a DKLayer

/** @brief Draws the layer and its contents on demand

 Called by the drawing when necessary to update the views.
 @param rect the area being updated
 */
- (void)drawRect:(NSRect)rect inView:(DKDrawingView*)aView
{
	SAVE_GRAPHICS_CONTEXT

	if ([[self drawing] activeLayer] == self || [[self class] selectionIsShownWhenInactive]) {
		// anything to draw?

		if ([self countOfObjects] > 0) {
			@autoreleasepool {

				BOOL screen = [NSGraphicsContext currentContextDrawingToScreen];
				BOOL drawSelected = [self selectionVisible] && screen && ([self isActive] || [[self class] selectionIsShownWhenInactive]) && ![self locked];
				NSArray* objectsToDraw = [self objectsForUpdateRect:rect
															 inView:aView];

				// draw the objects

				if (!drawSelected || [self drawsSelectionHighlightsOnTop]) {

					for (DKDrawableObject* obj in objectsToDraw) {
						[obj drawContentWithSelectedState:NO];
					}

				} else {

					for (DKDrawableObject* obj in objectsToDraw) {
						[obj drawContentWithSelectedState:[self isSelectedObject:obj]];
					}
				}

				// draw the selection on top if set to do so

				if ([self drawsSelectionHighlightsOnTop] && drawSelected) {

					for (DKDrawableObject* obj in objectsToDraw) {
						if ([self isSelectedObject:obj])
							[obj drawSelectedState];
					}
				}
			}
		}

		// draw any pending object

		[self drawPendingObjectInView:aView];

		if ([self isHighlightedForDrag])
			[self drawHighlightingForDrag];

		if (mShowStorageDebugging && [[self storage] respondsToSelector:@selector(debugStorageDivisions)]) {
			NSBezierPath* debug = [(id)[self storage] debugStorageDivisions];

			[debug setLineWidth:0];
			[[NSColor orangeColor] set];
			[debug stroke];
		}
	} else
		[super drawRect:rect
				 inView:aView];

	RESTORE_GRAPHICS_CONTEXT
}

/**
 Refreshes the selection when the layer becomes active
 */
- (void)layerDidBecomeActiveLayer
{
	[super layerDidBecomeActiveLayer];
	[self refreshSelectedObjects];
}

/**
 Refreshes the selection when the layer resigns active state
 */
- (void)layerDidResignActiveLayer
{
	[self refreshSelectedObjects];
	[super layerDidResignActiveLayer];
}

/** @brief Builds a contextual menu for the layer

 This first gives any hit object a chance to populate the menu, then adds the layer level commands
 @param theEvent the event that triggered this call (right mouse click)
 @param view the view that received it
 @return a menu
 */
- (NSMenu*)menuForEvent:(NSEvent*)theEvent inView:(NSView*)view
{
	if ([self locked])
		return nil;

	NSMenu* contextmenu = [[NSMenu alloc] initWithTitle:@"DL_ContextM"]; // title is never displayed
	NSMenuItem* item;

	// if the mouse hit an object, give the object a chance to populate the menu.

	NSPoint mp = [view convertPoint:[theEvent locationInWindow]
						   fromView:nil];
	DKDrawableObject* od = [self hitTest:mp];

	if (od) {
		//[self replaceSelection:od];

		if ([od populateContextualMenu:contextmenu
							   atPoint:mp])
			[contextmenu addItem:[NSMenuItem separatorItem]];

		// add the layer level commands
		// if >1 groupable object selected, add group command

		NSArray* groupables = [DKShapeGroup objectsAvailableForGroupingFromArray:[self selectedAvailableObjects]];

		if ([groupables count] > 1) {
			[[contextmenu addItemWithTitle:NSLocalizedString(@"Group", @"menu item for group")
									action:@selector(groupObjects:)
							 keyEquivalent:@"g"] setTarget:self];
		}

		[[contextmenu addItemWithTitle:NSLocalizedString(@"Copy", @"menu item for Copy")
								action:@selector(copy:)
						 keyEquivalent:@"c"] setTarget:self];
		[[contextmenu addItemWithTitle:NSLocalizedString(@"Duplicate", @"menu item for Duplicate")
								action:@selector(duplicate:)
						 keyEquivalent:@"d"] setTarget:self];
		[[contextmenu addItemWithTitle:NSLocalizedString(@"Delete", @"menu item for Delete")
								action:@selector(delete:)
						 keyEquivalent:@""] setTarget:self];

		if ([self countOfSelectedAvailableObjects] == 1) {
			item = [contextmenu addItemWithTitle:NSLocalizedString(@"Arrange", @"menu item for Arrange")
										  action:nil
								   keyEquivalent:@""];

			NSMenu* am = [[NSMenu alloc] initWithTitle:@""];
			[[am addItemWithTitle:NSLocalizedString(@"Bring To Front", @"menu item for bring to front")
						   action:@selector(objectBringToFront:)
					keyEquivalent:@""] setTarget:self];
			[[am addItemWithTitle:NSLocalizedString(@"Bring Forwards", @"menu item for bring forwards")
						   action:@selector(objectBringForward:)
					keyEquivalent:@""] setTarget:self];
			[[am addItemWithTitle:NSLocalizedString(@"Send Backwards", @"menu item for send backwards")
						   action:@selector(objectSendBackward:)
					keyEquivalent:@""] setTarget:self];
			[[am addItemWithTitle:NSLocalizedString(@"Send To Back", @"menu item for send to back")
						   action:@selector(objectSendToBack:)
					keyEquivalent:@""] setTarget:self];

			[item setSubmenu:am];
		}
	} else {
		item = [contextmenu addItemWithTitle:NSLocalizedString(@"Paste", @"menu item for Paste")
									  action:@selector(paste:)
							   keyEquivalent:@"v"];
		[item setTarget:self];
		[item setTag:kDKPasteCommandContextualMenuTag];
	}

	return contextmenu;
}

- (void)setLayerGroup:(DKLayerGroup*)aGroup
{
	[super setLayerGroup:aGroup];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(drawingSizeChanged:)
												 name:kDKDrawingDidChangeSize
											   object:[self drawing]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(drawingSizeChanged:)
												 name:kDKDrawingDidChangeMargins
											   object:[self drawing]];
	[self setDragExclusionRect:[[self drawing] interior]];
}

/** @brief Locks or unlocks the layer

 Redraws the objects when the layer's lock state changes (selections are not shown for locked layers)
 @param locked YES to lock, NO to unlock
 */
- (void)setLocked:(BOOL)locked
{
	if (locked != [self locked]) {
		[super setLocked:locked];
		[self refreshSelectedObjects];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerSelectionDidChange
															object:self];
	}
}

- (NSArray*)pasteboardTypesForOperation:(DKPasteboardOperationType)op
{
	// if drag-targeting of objects is allowed, this adds the types declared by the objects to the types declared by the
	// layer itself. Currently only drag receives are allowed.

	NSMutableArray* types = [[super pasteboardTypesForOperation:op] mutableCopy];

	if ([self allowsObjectsToBeTargetedByDrags] && ((op & kDKReadableTypesForDrag) != 0)) {
		// append all the types from the object classes we can accept:

		NSArray* eligibleClasses = [DKRuntimeHelper allClassesOfKind:[DKDrawableObject class]];

		for (Class class in eligibleClasses) {
			NSArray* dragTypes;
			if ([class respondsToSelector:@selector(pasteboardTypesForOperation:)])
				dragTypes = [class pasteboardTypesForOperation:op];
			else
				dragTypes = nil;

			if (dragTypes != nil)
				[types addUniqueObjectsFromArray:dragTypes];
		}
	}

	return types;
}

- (void)logDescription:(id)sender
{
	NSSet* responders = [self selectedObjectsRespondingToSelector:_cmd];

	if ([responders count] > 0)
		[responders makeObjectsPerformSelector:_cmd
									withObject:sender];
	else
		[super logDescription:sender];
}

#pragma mark -
#pragma mark As part of the NSDraggingDestination protocol

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
	NSDragOperation result = [super draggingUpdated:sender];

	if ([self allowsObjectsToBeTargetedByDrags] && [sender draggingSource] != self) {
		// one problem here is that if the drag originated in another document, our native objects are also written as images.
		// It isn't sensible to add such images to an existing object, so we just need to do an additional check here to
		// see if what's being dragged is our native type - if so, don't try and target an individual object.

		NSPasteboard* pb = [sender draggingPasteboard];
		NSString* availableType = [pb availableTypeFromArray:@[kDKDrawableObjectPasteboardType]];

		if (availableType != nil) {
			[self deselectAll];
			return NSDragOperationCopy;
		}

		NSPoint cp = [sender draggingLocation];
		cp = [[self currentView] convertPoint:cp
									 fromView:nil];

		//	LogEvent_(kUserEvent, @"drag pt = %@", NSStringFromPoint( cp ));

		DKDrawableObject* target = [self hitTest:cp];

		if (target != nil && ![target locked] && [target visible]) {
			// there is an object under the mouse. If it is able to respond to the drag, select it:

			NSArray* types = [[target class] pasteboardTypesForOperation:kDKReadableTypesForDrag];
			availableType = [pb availableTypeFromArray:types];

			if (availableType != nil) {
				// yes, the object is able to respond to this drag, so select it:

				[self replaceSelectionWithObject:target];
				result = NSDragOperationCopy;
			} else {
				[self deselectAll];
				result = NSDragOperationNone;
			}
		} else
			[self deselectAll];
	}

	return result;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
	DKDrawableObject* target = [self singleSelection];
	BOOL wasHandled = NO;

	if (target != nil && [self allowsObjectsToBeTargetedByDrags] && [target conformsToProtocol:@protocol(NSDraggingDestination)] && ![target locked] && [target visible]) {
		// can the target handle the drag?

		NSArray* types = [[target class] pasteboardTypesForOperation:kDKReadableTypesForDrag];
		NSPasteboard* pb = [sender draggingPasteboard];
		NSString* availableType = [pb availableTypeFromArray:types];

		if (availableType != nil) {
			// yes, so pass the drag info to the target and let it get on with it
			//	LogEvent_(kReactiveEvent, @"passing drop to target = %@, availableType = %@", target, availableType );

			wasHandled = [(id<NSDraggingDestination>)target performDragOperation:sender];
		}
	}

	if (!wasHandled) {
		BOOL result = [super performDragOperation:sender];

		if (result) {
			if ([sender draggingSource] == self) {
				// delete the objects held in the temporary drag list, as we have dragged them to self

				[self removeObjectsInArray:m_objectsPendingDrag];
				m_objectsPendingDrag = nil;
			}
		}

		return result;
	} else {
		// remove the layer highlight
		[self setHighlightedForDrag:NO];
		return YES;
	}
}

#pragma mark -
#pragma mark As part of the NSDraggingSource protocol

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
#pragma unused(session)
#pragma unused(screenPoint)
#pragma unused(operation)

	//	LogEvent_(kReactiveEvent, @"drag ended - cleaning up pending list");

	// if the pending drag list still exists, re-show all the objects in it

	if (m_objectsPendingDrag != nil) {
		for (DKDrawableObject* dko in m_objectsPendingDrag) {
			[dko setVisible:YES];
		}

		m_objectsPendingDrag = nil;
	}
}

- (NSDragOperation)draggingSession:(nonnull NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
#pragma unused(session)
#pragma unused(context)
	
	return NSDragOperationMove;
}


#pragma mark -
#pragma mark As an NSObject
- (void)dealloc
{
	//	LogEvent_(kReactiveEvent, @"dealloc - DKObjectDrawingLayer");

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

/** @brief Allows actions to be retargeted on single selected objects directly

 Commands can be implemented by a selected objects that wants to make use of them - this makes
 it happen by forwarding unrecognised method calls to those objects if possible. If multiple
 auto-forwarding is NO, commands are only forwarded to a single selected object if there is one.
 @param invocation the invocation
 */
- (void)forwardInvocation:(NSInvocation*)invocation
{
	SEL aSelector = [invocation selector];

	if ([self multipleSelectionAutoForwarding]) {
		NSSet* responders = [self selectedObjectsRespondingToSelector:aSelector];

		if ([responders count] > 0) {
			// when forwarding multiple invocations, the layer needs to buffer selection changes so that they are all made together.
			// This is to disguise the fact that often operations performed by the layer replace the selection per object as they occur in
			// isolation.

			[self beginBufferingSelectionChanges];

			for (DKDrawableObject* od in responders) {
				[invocation invokeWithTarget:od];
			}

			[self endBufferingSelectionChanges];
		} else
			[self doesNotRecognizeSelector:aSelector];
	} else {
		DKDrawableObject* od = [self singleSelection];

		if ([od visible] && [od respondsToSelector:aSelector])
			[invocation invokeWithTarget:od];
		else
			[self doesNotRecognizeSelector:aSelector];
	}
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		m_selection = [[NSMutableSet alloc] init];
		m_selectionIsUndoable = [[self class] defaultSelectionChangesAreUndoable];
		m_drawSelectionOnTop = YES;
		m_selectionVisible = YES;
		m_allowDragTargeting = YES;

		if (m_selection == nil) {
			return nil;
		}
	}
	return self;
}

/** @return the method signature
 */
- (NSMethodSignature*)methodSignatureForSelector:(SEL)aSelector
{
	NSMethodSignature* sig;

	sig = [super methodSignatureForSelector:aSelector];

	if (sig == nil) {
		if ([self multipleSelectionAutoForwarding])
			sig = [[[self selectedObjectsRespondingToSelector:aSelector] anyObject] methodSignatureForSelector:aSelector];
		else
			sig = [[self singleSelection] methodSignatureForSelector:aSelector];
	}
	return sig;
}

/**
 Locked objects are excluded here since the unlockObject: method is handled by the layer
 @return YES if the selector is recognised, NO if not
 */
- (BOOL)respondsToSelector:(SEL)aSelector
{
	DKDrawableObject* od = [self singleSelection];

	if (od == nil && [self multipleSelectionAutoForwarding])
		od = [[self selectedObjectsRespondingToSelector:aSelector] anyObject];

	return (([od visible] && ![od locked] && [od respondsToSelector:aSelector]) || [super respondsToSelector:aSelector]);
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];

	[coder encodeBool:m_selectionIsUndoable
			   forKey:@"selundo"];
	[coder encodeBool:m_drawSelectionOnTop
			   forKey:@"selOnTop"];
	[coder encodeBool:[self allowsObjectsToBeTargetedByDrags]
			   forKey:@"DKObjectDrawingLayer_allowDragTargets"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	//	LogEvent_(kFileEvent, @"decoding object drawing layer %@", self);

	self = [super initWithCoder:coder];
	if (self != nil) {
		m_selection = [[NSMutableSet alloc] init];
		NSAssert(m_selectionUndo == nil, @"Expected init to zero");
		[self setDragExclusionRect:[[self drawing] interior]];

		m_selectionIsUndoable = [[self class] defaultSelectionChangesAreUndoable];

		m_drawSelectionOnTop = [coder decodeBoolForKey:@"selOnTop"];
		m_selectionVisible = YES;

		if ([coder containsValueForKey:@"DKObjectDrawingLayer_allowDragTargets"])
			[self setAllowsObjectsToBeTargetedByDrags:[coder decodeBoolForKey:@"DKObjectDrawingLayer_allowDragTargets"]];
		else
			[self setAllowsObjectsToBeTargetedByDrags:YES];

		if (m_selection == nil) {
			return nil;
		}
	}

	return self;
}

#pragma mark -
#pragma mark As part of NSMenuValidation Protocol

/** @brief Validates the menu items pertaining to actions that this layer can handle
 @param item the menu item to validate
 @return YES if it's enabled, NO if not
 */
- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	SEL action = [item action];
	DKDrawableObject* od = [self singleSelection];

	NSUInteger alignCrit = [self alignmentMenuItemRequiredObjects:item];

	if (alignCrit != 0) {
		if ([item action] == @selector(assignKeyObject:)) {
			id ko = [self keyObject];

			if ([self singleSelection] == ko && ko != nil)
				[item setState:NSOnState];
			else if ([[self selection] containsObject:ko])
				[item setState:NSMixedState];
			else
				[item setState:NSOffState];
		}

		return ([self countOfSelectedAvailableObjects] >= alignCrit);
	}

	if (action == @selector(cut:) || action == @selector(delete:) || action == @selector(lockObject:) || action == @selector(hideObject:) || action == @selector(applyStyle:)) {
		return ([self countOfSelectedAvailableObjects] > 0);
	}

	if (action == @selector(selectAll:)) {
		return ![self lockedOrHidden];
	}

	if (action == @selector(copy:) || action == @selector(duplicate:) || action == @selector(selectNone:) || action == @selector(selectOthers:)) {
		return [self isSelectionNotEmpty];
	}

	if (action == @selector(selectMatchingStyle:))
		return ([self singleSelection] != nil);

	if (action == @selector(unlockObject:)) {
		NSInteger locks = [[self selectedObjectsReturning:YES
											   toSelector:@selector(locked)] count];
		return locks > 0;
	}

	if (action == @selector(revealHiddenObjects:)) {
		NSInteger hidden = [[self objectsReturning:NO
										toSelector:@selector(visible)] count];
		return hidden > 0;
	}

	if (action == @selector(paste:)) {
		return ([[NSPasteboard generalPasteboard] availableTypeFromArray:[self pasteboardTypesForOperation:kDKReadableTypesForPaste]] != nil);
	}

	if (action == @selector(groupObjects:) || action == @selector(clusterObjects:)) {
		// for grouping, check that the selected items accept grouping

		NSArray* groupables = [DKShapeGroup objectsAvailableForGroupingFromArray:[self selectedAvailableObjects]];
		return [groupables count] > 1;
	}

	if (action == @selector(unionSelectedObjects:) || action == @selector(combineSelectedObjects:)) {
		return ([self countOfSelectedAvailableObjects] > 1);
	}

	if (action == @selector(objectBringForward:) || action == @selector(objectBringToFront:)) {
		return (od != nil) && ![od locked] && [od visible] && (od != [self topObject]);
	}

	if (action == @selector(objectSendBackward:) || action == @selector(objectSendToBack:)) {
		return (od != nil) && ![od locked] && [od visible] && (od != [self bottomObject]);
	}

	if (action == @selector(diffSelectedObjects:) || action == @selector(intersectionSelectedObjects:) || action == @selector(xorSelectedObjects:) || action == @selector(divideSelectedObjects:)) {
		return ([self countOfSelectedAvailableObjects] == 2);
	}

	if (action == @selector(joinPaths:)) {
		// enable if there are at least 2 paths selected and at least 1 pair would in fact join.

		NSArray* sel = [self selectedAvailableObjectsOfClass:[DKDrawablePath class]];

		return [sel count] > 1;
	}

	if (action == @selector(ghostObjects:)) {
		return (([[self selectedObjectsReturning:NO
									  toSelector:@selector(isGhosted)] count]
					> 0)
			&& ![self lockedOrHidden]);
	}

	if (action == @selector(unghostObjects:)) {
		return (([[self selectedObjectsReturning:YES
									  toSelector:@selector(isGhosted)] count]
					> 0)
			&& ![self lockedOrHidden]);
	}

	BOOL enable = NO;

	if ([self multipleSelectionAutoForwarding])
		enable |= [self multipleSelectionValidatedMenuItem:item];

	if ([self isSingleObjectSelected])
		enable |= [[self singleSelection] validateMenuItem:item];

	enable |= [super validateMenuItem:item];

	return enable;
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem
{
	NSUInteger alignCrit = [self alignmentMenuItemRequiredObjects:anItem];

	if (alignCrit != 0)
		return ([self countOfSelectedAvailableObjects] >= alignCrit);

	return [super validateUserInterfaceItem:anItem];
}

@end
