/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKObjectOwnerLayer.h"

@class DKShapeGroup;

/** @brief This layer adds the concept of selection to drawable objects as defined by DKObjectOwnerLayer.

This layer adds the concept of selection to drawable objects as defined by DKObjectOwnerLayer. Selected objects are held in the -selection
list, which is a set (there is no order to selected objects per se - though sometimes the relative Z-stacking order of objects in the selection
is needed, and the method -selectedObjectsPreservingStackingOrder et. al. will provide that.

Note that for selection, the locked state of owned objects is ignored (because it is OK to select a locked object, just not to
do anything with it except unlock it).

Commands directed at this layer are usually meant to to go to "the selection", either multiple or single objects.

This class provides no direct mouse handlers for actually changing the selection - typically the selection and other manipulation
of objects in this layer is done through the agency of tools and a DKToolController.

The actual appearance of the selection is mainly down to the objects themselves, with some information supplied by the layer (for example
the layer's selectionColour). Also, the layer's (or more typically the drawing's) DKKnob class is generally used by objects to display their
selected state.
*/
@interface DKObjectDrawingLayer : DKObjectOwnerLayer <NSCoding> {
@private
	NSMutableSet* m_selection; // list of selected objects
	NSSet* m_selectionUndo; // old selection when setting up undo
	NSRect m_dragExcludeRect; // drags will become "real" once this rect is left
	BOOL m_selectionIsUndoable; // YES if selection changes tracked by undo
	BOOL m_drawSelectionOnTop; // YES if selection highlights are drawn in a pseudo-layer on top of all objects
	BOOL m_selectionVisible; // YES if selection is actually drawn
	BOOL m_allowDragTargeting; // YES if the layer can target individual objects when receiving a drag/drop
	BOOL mMultipleAutoForwarding; // YES to automatically forward actions to all objects in the selection that can respond
	BOOL mBufferSelectionChanges; // YES to buffer a series of selection changes during a multiple forwarding invocation
	NSUInteger mUndoCount; // records undo count when the selection state is recorded
	NSArray* m_objectsPendingDrag; // temporary list of objects being dragged from the layer
	DKDrawableObject* mKeyAlignmentObject; // the master object to which others can be aligned
	NSRect mSelBoundsCached; // cached value of the selection bounds
}

// default settings:

+ (void)setSelectionIsShownWhenInactive:(BOOL)visInactive;
+ (BOOL)selectionIsShownWhenInactive;
+ (void)setDefaultSelectionChangesAreUndoable:(BOOL)undoSel;
+ (BOOL)defaultSelectionChangesAreUndoable;

// convenience constructor:

/** @brief Convenience method creates an entire new layer containing the given objects

 The objects are not initially selected
 @param objects an array containing drawable objects which must not be already owned by another layer
 @return a new layer object containing the objects
 */
+ (DKObjectDrawingLayer*)layerWithObjectsInArray:(NSArray*)objects;

// useful lists of objects:

/** @brief Returns the objects that are not locked, visible and selected

 This also preserves the stacking order of the objects (unlike -selection), so is the most useful
 means of obtaining the set of objects that can be acted upon by a command or user interface control.
 Note that if the layer is locked as a whole, this always returns an empty list
 @return an array, objects that can be acted upon by a command as a set
 */
- (NSArray*)selectedAvailableObjects; // KVC/KVO compliant (read only)

/** @brief Returns the objects that are not locked, visible and selected and which have the given class

 See comments for selectedAvailableObjects
 @return an array, objects of the given class that can be acted upon by a command as a set
 */
- (NSArray*)selectedAvailableObjectsOfClass:(Class)aClass;

/** @brief Returns the objects that are visible and selected

 See comments for selectedAvailableObjects
 @return an array
 */
- (NSArray*)selectedVisibleObjects;
- (NSSet*)selectedObjectsReturning:(NSInteger)answer toSelector:(SEL)selector;

/** @brief Returns objects that respond to the selector <selector>

 This is a more general kind of test for ensuring that selectors are only sent to those
 objects that can respond. Hidden or locked objects are also excluded.
 @param selector any selector
 @return an array, objects in the selection that do respond to the given selector
 */
- (NSSet*)selectedObjectsRespondingToSelector:(SEL)selector;

/** @brief Returns an array consisting of a copy of the selected objects

 The result maintains the stacking order of the original objects, but the objects do not belong to
 where objects are ultimately going to be pasted back in to this or another layer.
 @return an array of objects. 
 */
- (NSArray*)duplicatedSelection;

/** @brief Returns the selected objects in their original stacking order.

 Slower than -selection, as it needs to iterate over the objects. This ignores visible and locked
 states of the objects. See also -selectedAvailableObjects. If the layer itself is locked, returns
 an empty array.
 @return an array, the selected objects in their original order
 */
- (NSArray*)selectedObjectsPreservingStackingOrder;

/** @brief Returns the number of objects that are visible and not locked

 If the layer itself is locked, returns 0
 @return the count
 */
- (NSUInteger)countOfSelectedAvailableObjects; // KVC/KVO compliant

/** @brief Returns the indexed object
 @param indx the index of the required object
 @return the object at that index
 */
- (DKDrawableObject*)objectInSelectedAvailableObjectsAtIndex:(NSUInteger)indx; // KVC/KVO compliant (read only)

// doing stuff to each one:

/** @brief Makes the selected available object perform a given selector.

 An easy way to apply a command to the set of selected available objects, provided that the
 selector requires no parameters
 @param selector the selector the objects should perform
 */
- (void)makeSelectedAvailableObjectsPerform:(SEL)selector;

/** @brief Makes the selected available object perform a given selector with a single object parameter
 @param selector the selector the objects should perform
 @param anObject the object parameter to pass to each method
 */
- (void)makeSelectedAvailableObjectsPerform:(SEL)selector withObject:(id)anObject;

/** @brief Locks or unlocks all the selected objects
 @param lock YES to lock the objects, NO to unlock them
 */
- (void)setSelectedObjectsLocked:(BOOL)lock;

/** @brief Hides or shows all of the objects in the selection

 Since hidden selected objects are not drawn, use with care, since usability may be severely
 compromised (for example, how are you going to be able to select hidden objects in order to show them?)
 @param visible YES to show the objects, NO to hide them
 */
- (void)setSelectedObjectsVisible:(BOOL)visible;

/** @brief Reveals any hidden objects, setting the selection to those revealed
 @return YES if at least one object was shown, NO otherwise
 */
- (BOOL)setHiddenObjectsVisible;

/** @brief Causes all selected objects to redraw themselves
 */
- (void)refreshSelectedObjects;

/** @brief Changes the location of all objects in the selection by dx and dy
 @param dx add this much to each object's x coordinate
 @param dy add this much to each object's y coordinate
 @return YES if there were selected objects, NO if there weren't, and so nothing happened
 */
- (BOOL)moveSelectedObjectsByX:(CGFloat)dx byY:(CGFloat)dy;

// the selection:

/** @brief Sets the selection to a given set of objects

 For interactive selections, exchangeSelectionWithObjectsInArray: is more appropriate and efficient
 @param sel a set of objects to select
 */
- (void)setSelection:(NSSet*)sel;
- (NSSet*)selection;

/** @brief If the selection consists of a single available object, return it. Otherwise nil.

 This is useful for easily handling the case where an operation can only operate on one object to be
 meaningful. It is also used by the automatic invocation forwarding mechanism.
 @return the selected object if it's the only one and it's available
 */
- (DKDrawableObject*)singleSelection;

/** @brief Return the number of items in the selection.

 KVC compliant; returns 0 if the layer is locked or hidden.
 @return an integer, the countof selected objects
 */
- (NSUInteger)countOfSelection;

// selection operations:

/** @brief Deselect any selected objects
 */
- (void)deselectAll;

/** @brief Select all available objects

 This also adds hidden objects to the selection, even though they are not visible
 */
- (void)selectAll;

/** @brief Add a single object to the selection

 Any existing objects in the selection remain selected
 @param obj an object to select
 */
- (void)addObjectToSelection:(DKDrawableObject*)obj;

/** @brief Add a set of objects to the selection

 Existing objects in the selection remain selected
 @param objs an array of objects to select
 */
- (void)addObjectsToSelectionFromArray:(NSArray*)objs;

/** @brief Select the given object, deselecting all previously selected objects
 @param obj the object to select
 @return YES if the selection changed, NO if it did not (i.e. if <obj> was already the only selected object)
 */
- (BOOL)replaceSelectionWithObject:(DKDrawableObject*)obj;

/** @brief Remove a single object from the selection

 Other objects in the selection are unaffected
 @param obj the object to deselect
 */
- (void)removeObjectFromSelection:(DKDrawableObject*)obj;

/** @brief Remove a series of object from the selection

 Other objects in the selection are unaffected
 @param objs the list of objects to deselect
 */
- (void)removeObjectsFromSelectionInArray:(NSArray*)objs;

/** @brief Sets the selection to a given set of objects

 This is intended as a more efficient version of setSelection:, since it only changes the state of
 objects that differ between the current selection and the list passed. It is intended to be called
 when interactively making a selection such as during a marquee drag, when it's likely that the same
 set of objects is repeatedly offered for selection. Also, since it accepts an array parameter, it may
 be used directly with sets of objects without first making into a set.
 @param sel the set of objects to select
 @return YES if the selection changed, NO if it did not
 */
- (BOOL)exchangeSelectionWithObjectsFromArray:(NSArray*)sel;

/** @brief Scrolls one or all views attached to the drawing so that the selection within this layer is visible
 @param aView if not nil, the view to scroll. If nil, scrolls all views
 */
- (void)scrollToSelectionInView:(NSView*)aView;

// style operations on multiple items:

/** @brief Sets the selection to the set of objects that have the given style

 The style is compared by key, so clones of the style are not considered a match
 @param style the style to match
 @return YES if the selection changed, NO if it did not
 */
- (BOOL)selectObjectsWithStyle:(DKStyle*)style;
- (BOOL)replaceStyle:(DKStyle*)style withStyle:(DKStyle*)newStyle selectingObjects:(BOOL)select;

// useful selection tests:

/** @brief Query whether a given object is selected or not
 @param obj the object to test
 @return YES if it is selected, NO if not
 */
- (BOOL)isSelectedObject:(DKDrawableObject*)obj;

/** @brief Query whether any objects are selected
 @return YES if there is at least one object selected, NO if none are
 */
- (BOOL)isSelectionNotEmpty;

/** @brief Query whether there is exactly one object selected
 @return YES if one object selected, NO if none or more than one are
 */
- (BOOL)isSingleObjectSelected;

/** @brief Query whether the selection contains any objects matching the given class
 @param c the class of object sought
 @return YES if there is at least one object of type <c>, NO otherwise
 */
- (BOOL)selectionContainsObjectOfClass:(Class)c;

/** @brief Return the overall area bounded by the objects in the selection
 @return the union of the bounds of all selected objects
 */
- (NSRect)selectionBounds;
- (NSRect)selectionLogicalBounds;

// selection undo stuff:

/** @brief Set whether selection changes should be recorded for undo.

 Different apps may want to treat selection changes as undoable state changes or not.
 @param undoable YES to record selection changes, NO to not bother.
 */
- (void)setSelectionChangesAreUndoable:(BOOL)undoable;

/** @brief Are selection changes undoable?
 @return YES if they are undoable, NO if not
 */
- (BOOL)selectionChangesAreUndoable;

/** @brief Make a copy of the selection for a possible undo recording

 The selection is copied and stored in the ivar <_selectionUndo>. Usually called at the start of
 an operation that can potentially change the selection state, such as a mouse down.
 */
- (void)recordSelectionForUndo;

/** @brief Sends the recorded selection state to the undo manager and tags it with the given action name

 Usually called at the end of any operation than might have changed the selection. This also sets
 the action name even if the selection is unaffected, so callers can just call this with the
 desired action name and get the correct outcome, whether or not selection is undoable or changed.
 This will help keep code tidy.
 @param actionName undo menu string, or nil to use a preset name
 */
- (void)commitSelectionUndoWithActionName:(NSString*)actionName;

/** @brief Test whether the selection is now different from the recorded selection
 @return YES if the selection differs, NO if they are the same
 */
- (BOOL)selectionHasChangedFromRecorded;

// making images of the selected objects:

/** @brief Draws only the selected objects, but with the selection highlight itself not shown. This is used when
 imaging the selection to a PDF or other context.
 */
- (void)drawSelectedObjects;

/** @brief Draws only the selected objects, with the selection highlight given. This is used when
 imaging the selection to a PDF or other context.

 Usually there is no good reason to copy objects with the selection state set to YES, but this is
 provided for special needs when you do want that.
 @param selected YES to show the selection, NO to not show it
 */
- (void)drawSelectedObjectsWithSelectionState:(BOOL)selected;

/** @brief Creates an image of the selected objects

 Used to create an image representation of the selection when performing a cut or copy operation, to
 allow the selection to be exported to graphical apps that don't understand our internal object format.
 @return an image
 */
- (NSImage*)imageOfSelectedObjects;

/** @brief Creates a PDF representation of the selected objects

 Used to create a PDF representation of the selection when performing a cut or copy operation, to
 allow the selection to be exported to PDF apps that don't understand our internal object format.
 This requires the use of a temporary special view for recording the output as PDF.
 @return PDF data of the selected objects only
 */
- (NSData*)pdfDataOfSelectedObjects;

// clipboard ops:

/** @brief Copies the selection to the given pasteboard in a variety of formats

 Data is recorded as native data, PDF and TIFF. Note that locked objects can't be copied as
 native types, but images are still copied.
 @param pb the pasteboard to copy to
 */
- (void)copySelectionToPasteboard:(NSPasteboard*)pb;

// options:

/** @brief Sets whether selection highlights should be drawn on top of all other objects, or if they should be
 drawn with the object at its current stacking position.

 Default is YES
 @param onTop YES to draw on top, NO to draw in situ
 */
- (void)setDrawsSelectionHighlightsOnTop:(BOOL)onTop;

/** @brief Draw selection highlights on top or in situ?

 Default is YES
 @return YES if drawn on top, NO in situ.
 */
- (BOOL)drawsSelectionHighlightsOnTop;

/** @brief Sets whether a drag into this layer will target individual objects or not.

 If YES, the object under the mouse will highlight as a drag into the layer proceeds, and upon drop,
 the object itself will be passed the drop information. Default is YES.
 @param allow allow individual objects to receive drags
 */
- (void)setAllowsObjectsToBeTargetedByDrags:(BOOL)allow;

/** @brief Returns whether a drag into this layer will target individual objects or not.

 If YES, the object under the mouse will highlight as a drag into the layer proceeds, and upon drop,
 the object itself will be passed the drop information. Default is YES.
 @return YES if objects can be targeted by drags
 */
- (BOOL)allowsObjectsToBeTargetedByDrags;

/** @brief Sets whether the selection is actually shown or not.

 Normally the selection should be visible, but some tools might want to hide it temporarily
 at certain well-defined times, such as when dragging objects.
 @param vis YES to show the selection, NO to hide it
 */
- (void)setSelectionVisible:(BOOL)vis;

/** @brief Whether the selection is actually shown or not.

 Normally the selection should be visible, but some tools might want to hide it temporarily
 at certain well-defined times, such as when dragging objects.
 @return YES if the selection is visible, NO if hidden
 */
- (BOOL)selectionVisible;

/**
 Default is NO for backward compatibility. This feature is useful to allow an action to be
 defined by an object but to have it invoked on all objects that are able to respond in the
 current selection without having to implement the action in the layer. Formerly such actions were
 only forwarded if exactly one object was selected that could respond. See -forwardInvocation.
 @param autoForward YES to automatically forward, NO to only operate on a single selected object
 */
- (void)setMultipleSelectionAutoForwarding:(BOOL)autoForward;
- (BOOL)multipleSelectionAutoForwarding;

/** @brief Handle validation of menu items in a multiple selection when autoforwarding is enabled

 This also tries to intelligently set the state of the item. If some objects set the state one way
 and others to another state, this will automatically set the mixed state. While the menu item
 itself is enabled if any object enabled it, the mixed state indicates that the outcome of the
 operation is likely to vary for different objects. 
 @param item the menu item to validate
 @return YES if at least one of the objects enabled the item, NO otherwise
 */
- (BOOL)multipleSelectionValidatedMenuItem:(NSMenuItem*)item;

// drag + drop:

/** @brief Sets the rect outside of which a mouse drag will drag the selection with the drag manager.

 By default the drag exclusion rect is set to the interior of the drawing. Dragging objects to the
 margins thus drags them "off" the drawing.
 @param aRect a rectangle - drags inside this rect do not cause a DM operation. Can be empty to
 */
- (void)setDragExclusionRect:(NSRect)aRect;

/** @brief Gets the rect outside of which a mouse drag will drag the selection with the drag manager.
 @return a rect defining the area within which drags do not traigger DM operations
 */
- (NSRect)dragExclusionRect;

/** @brief Initiates a drag of the selection to another document or app, or back to self.

 Keeps control until the drag completes. Swallows the mouseUp event. called from the mouseDragged
 method when the mouse leaves the drag exclusion rect.
 @param event the event that triggered the action - must be a mouseDown or mouseDragged
 @param view the view in which the user dragging operation is taking place
 */
- (void)beginDragOfSelectedObjectsWithEvent:(NSEvent*)event inView:(NSView*)view;
- (void)drawingSizeChanged:(NSNotification*)note;

// grouping & ungrouping operations:

/** @brief Layer is about to group a number of objects

 The default does nothing and returns YES - subclasses could override this to enhance or refuse
 grouping. This is invoked by the high level groupObjects: action method.
 @param objectsToBeGrouped the objects about to be grouped
 @param aGroup a group into which they will be placed
 @return YES to proceed with the group, NO to abandon the grouping
 */
- (BOOL)shouldGroupObjects:(NSArray*)objectsToBeGrouped intoGroup:(DKShapeGroup*)aGroup;

/** @brief Layer did create the group and added it to the layer

 The default does nothing - subclasses could override this. This is invoked by the high level
 @param aGroup the group just added
 */
- (void)didAddGroup:(DKShapeGroup*)aGroup;

/** @brief A group object is about to be ungrouped

 The default does nothing - subclasses could override this. This is invoked by a group when it
 is about to ungroup - see [DKShapeGroup ungroupObjects:]
 @param aGroup the group about to be ungrouped
 @return YES to allow the ungroup, NO to prevent it
 */
- (BOOL)shouldUngroup:(DKShapeGroup*)aGroup;

/** @brief A group object was ungrouped and its contents added back into the layer

 The default does nothing - subclasses could override this. This is invoked by the group just after
 it has ungrouped - see [DKShapeGroup ungroupObjects:]
 @param ungroupedObjects the objects just ungrouped
 */
- (void)didUngroupObjects:(NSArray*)ungroupedObjects;

// user actions:

/** @brief Perform a cut

 Cuts the selection
 @param sender the action's sender
 */
- (IBAction)cut:(id)sender;

/** @brief Perform a copy

 Copies the selection to the general pasteboard
 @param sender the action's sender
 */
- (IBAction)copy:(id)sender;

/** @brief Perform a paste

 Pastes from the general pasteboard
 @param sender the action's sender
 */
- (IBAction)paste:(id)sender;

/** @brief Performs a delete operation
 @param sender the action's sender
 */
- (IBAction) delete:(id)sender;

/**
 Calls delete: when backspace key is typed
 @param sender the action's sender
 */
- (IBAction)deleteBackward:(id)sender;

/** @brief Duplicates the selection
 @param sender the action's sender
 */
- (IBAction)duplicate:(id)sender;

/** @brief Selects all objects
 @param sender the action's sender (in fact the view)
 */
- (IBAction)selectAll:(id)sender;

/** @brief Deselects all objects in the selection
 @param sender the action's sender
 */
- (IBAction)selectNone:(id)sender;

/** @brief Selects the objects not selected, deselects those that are ("inverts" selection)
 @param sender the action's sender
 */
- (IBAction)selectOthers:(id)sender;

/** @brief Brings the selected object forward
 @param sender the action's sender
 */
- (IBAction)objectBringForward:(id)sender;

/** @brief Sends the selected object backward
 @param sender the action's sender
 */
- (IBAction)objectSendBackward:(id)sender;

/** @brief Brings the selected object to the front
 @param sender the action's sender
 */
- (IBAction)objectBringToFront:(id)sender;

/** @brief Sends the selected object to the back
 @param sender the action's sender
 */
- (IBAction)objectSendToBack:(id)sender;

/** @brief Locks all selected objects
 @param sender the action's sender
 */
- (IBAction)lockObject:(id)sender;

/** @brief Unlocks all selected objects
 @param sender the action's sender
 */
- (IBAction)unlockObject:(id)sender;

/** @brief Shows all selected objects
 @param sender the action's sender
 */
- (IBAction)showObject:(id)sender;

/** @brief Hides all selected objects, then deselects all

 Caution: hiding the selection has usability implications!!
 @param sender the action's sender
 */
- (IBAction)hideObject:(id)sender;

/** @brief Reveals any hidden objects, setting the selection to them

 Beeps if no objects were hidden
 @param sender the action's sender
 */
- (IBAction)revealHiddenObjects:(id)sender;

/** @brief Turns the selected objects into a group.

 The new group is placed on top of all objects even if the objects grouped were not on top. The group
 as a whole can be moved to any index - ungrouping replaces objects at that index.
 @param sender the action's sender
 */
- (IBAction)groupObjects:(id)sender;
- (IBAction)clusterObjects:(id)sender;

/** @brief Set the selected objects ghosted.

 Ghosted objects draw using an unobtrusive placeholder style
 @param sender the action's sender
 */
- (IBAction)ghostObjects:(id)sender;

/** @brief Set the selected objects unghosted.

 Ghosted objects draw using an unobtrusive placeholder style
 @param sender the action's sender
 */
- (IBAction)unghostObjects:(id)sender;

/** @brief Nudges the selected objects left by one unit

 The nudge amount is determined by the drawing's grid settings
 @param sender the action's sender (in fact the view)
 */
- (IBAction)moveLeft:(id)sender;

/** @brief Nudges the selected objects right by one unit

 The nudge amount is determined by the drawing's grid settings
 @param sender the action's sender (in fact the view)
 */
- (IBAction)moveRight:(id)sender;

/** @brief Nudges the selected objects up by one unit

 The nudge amount is determined by the drawing's grid settings
 @param sender the action's sender (in fact the view)
 */
- (IBAction)moveUp:(id)sender;

/** @brief Nudges the selected objects down by one unit

 The nudge amount is determined by the drawing's grid settings
 @param sender the action's sender (in fact the view)
 */
- (IBAction)moveDown:(id)sender;

/** @brief Selects all objects having the same style as the single selected object
 @param sender the action's sender
 */
- (IBAction)selectMatchingStyle:(id)sender;

/** @brief Connects any paths sharing an end point into a single path
 @param sender the action's sender
 */
- (IBAction)joinPaths:(id)sender;

/** @brief Applies a style to the objects in the selection

 The sender -representedObject must be a DKStyle. This is designed to match the menu items managed
 by DKStyleRegistry, but can be arranged to be any object that can have a represented object.
 @param sender the action's sender
 */
- (IBAction)applyStyle:(id)sender;

@end

// magic numbers:

enum {
	kDKMakeColinearJoinTag = 200, // set this tag value in "Join Paths" menu item to make the join colinear
	kDKPasteCommandContextualMenuTag = 201 // used for contextual 'paste' menu to use mouse position when positioning pasted items
};

extern NSString* kDKLayerSelectionDidChange;
extern NSString* kDKLayerKeyObjectDidChange;
