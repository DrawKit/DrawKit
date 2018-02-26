/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKDrawableContainerProtocol.h"
#import "DKLayer.h"
#import "DKObjectStorageProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class DKDrawableObject, DKStyle;

/** @brief caching options
 */
typedef NS_OPTIONS(NSUInteger, DKLayerCacheOption) {
	kDKLayerCacheNone = 0, //!< no caching
	kDKLayerCacheUsingPDF = (1 << 0), //!< layer is cached in a PDF Image Rep
	kDKLayerCacheUsingCGLayer = (1 << 1), //!< layer is cached in a CGLayer bitmap
	kDKLayerCacheObjectOutlines = (1 << 2) //!< objects are drawn using a simple outline stroke only
};

// the class

/** @brief This layer class can be the owner of any number of DKDrawableObjects.

 This layer class can be the owner of any number of DKDrawableObjects. It implements the ability to contain and render
 these objects.

 It does NOT support the concept of a selection, or of a list of selected objects (\c DKObjectDrawingLayer subclasses this to
 provide that functionality).

 This split between the owner/renderer layer and selection allows a more fine-grained opportunity to subclass for different
application needs.

 Layer caching:

 When a layer is NOT active, it may boost drawing performance to cache the layer's contents offscreen. This is especially beneficial
 if you are using many layers. By setting the cache option, you can control how caching is done. If set to "none", objects
 are never drawn using a cache, but simply drawn in the usual way. If "pdf", the cache is an NSPDFImageRep, which stores the image
 as a PDF and so draws it at full vector quality at all zoom scales. If "CGLayer", an offscreen CGLayer is used which gives the
 fastest rendering but will show pixellation at higher zooms. If both pdf and CGLayer are set, both caches will be created and
 the CGLayer one used when DKDrawing has its "low quality" hint set, and the PDF rep otherwise.

 The cache is only used for screen drawing.
 
 NOTE: PDF caching has been shown to be actually slower when there are many objects, espcially with advanced storage in use. This is
 because it's an all-or-nothing rendering proposition which direct drawing of a layer's objects is not.
*/
@interface DKObjectOwnerLayer : DKLayer <NSCoding, NSDraggingDestination, DKDrawableContainer> {
@private
	id<DKObjectStorage> mStorage; // the object storage
	NSPoint m_pasteAnchor; // used when recording the paste/duplication offset
	BOOL m_allowEditing; // YES to allow editing of objects, NO to prevent
	BOOL m_allowSnapToObjects; // YES to let snapping look for other objects
	DKDrawableObject* mNewObjectPending; // temporary object being created - is drawn and handled as a normal object but can be deleted without undo
	DKLayerCacheOption mLayerCachingOption; // see constants defined above
	NSRect mCacheBounds; // the bounds rect of the cached layer or PDF rep - used to accurately position the cache when drawn
	BOOL m_inDragOp; // YES if a drag is happening over the layer
	NSSize m_pasteOffset; // distance to offset a pasted object
	BOOL m_recordPasteOffset; // set to YES following a paste, and NO following a drag. When YES, paste offset is recorded.
	NSInteger mPasteboardLastChange; // last change count recorded during a paste
	NSInteger mPasteCount; // number of repeated paste operations since last new paste
@protected
	BOOL mShowStorageDebugging; // if YES, draws the debugging path for the storage on top (debugging feature only)
}

@property (class) DKLayerCacheOption defaultLayerCacheOption;

/** @name Setting The Storage
 @brief n.b. Storage is set by default, this is an advanced feature that you can ignore 99% of the time.
 @{ */

/** @brief The storage class.
 */
@property (class, null_resettable) Class storageClass;

/** @brief The storage object for the layer.
 
 This is an advanced feature that allows the object storage to be replaced independently. Alternative
 storage algorithms can enhance performance for very large data sets, for example. Note that the
 storage should not be swapped while a layer contains objects, since they will be discarded. The
 intention is that the desired storage is part of a layer's initialisation.
 @return a storage object
 */
@property (nonatomic, strong) id<DKObjectStorage> storage;

/** @}
 @name As A Container For A \c DKDrawableObject
 @{ */

/** @brief Returns the layer of a drawable's container - since this is that layer, returns \c self

 See \c DKDrawableObject which also implements this protocol.
 @return \c self
 */
@property (readonly, strong) DKObjectOwnerLayer* layer;

/** @}
 @name Objects
 @brief The list of objects.
 @{ */

/** @brief The objects that this layer owns.
 Is an array of <code>DKDrawableObject</code>s, or subclasses thereof.
 */
@property (nonatomic, copy) NSArray<DKDrawableObject*>* objects; // KVC/KVO compliant

/** @brief Returns objects that are available to the user, that is, not locked or invisible

 If the layer itself is locked, returns an empty list.
 @return An array of available objects.
 */
@property (readonly, copy) NSArray<DKDrawableObject*>* availableObjects;

/** @brief Returns objects that are available to the user, that is, not locked or invisible and that
 intersect the rect.

 If the layer itself is locked, returns an empty list.
 @param aRect Objects must also intersect this rect.
 @return An array of available objects.
 */
- (NSArray<DKDrawableObject*>*)availableObjectsInRect:(NSRect)aRect;

/** @brief Returns objects that are available to the user of the given class

 If the layer itself is locked, returns an empty list.
 @param aClass Class of the desired objects.
 @return An array of available objects.
 */
- (NSArray<DKDrawableObject*>*)availableObjectsOfClass:(Class)aClass NS_REFINED_FOR_SWIFT;

/** @brief Returns objects that are visible to the user, but may be locked.

 If the layer itself is not visible, returns <code>nil</code>.
 */
@property (readonly, copy, nullable) NSArray<DKDrawableObject*>* visibleObjects;

/** @brief Returns objects that are visible to the user, intersect the rect, but may be locked

 If the layer itself is not visible, returns nil.
 @param aRect The objects returned intersect this rect.
 @return An array of visible objects.
 */
- (nullable NSArray<DKDrawableObject*>*)visibleObjectsInRect:(NSRect)aRect;

/** @brief Returns objects that share the given style.

 The style is compared by unique key, so style clones are not considered a match. Unavailable objects are
 also included.
 @param style The style to compare.
 @return An array of those objects that have the style.
 */
- (NSArray<DKDrawableObject*>*)objectsWithStyle:(DKStyle*)style NS_SWIFT_NAME(objectsWith(_:));

/** @brief Returns objects that respond to the selector with the value <code>answer</code>.

 This is a very simple type of predicate test. Note - the method \c selector must not return
 anything larger than an \c NSInteger or it will be ignored and the result may be wrong.
 @param selector A selector taking no parameters.
 @return An array, objects that match the value of <code>answer</code>.
 */
- (NSArray<DKDrawableObject*>*)objectsReturning:(NSInteger)answer toSelector:(SEL)selector;

/** @}
 @name Getting Objects
 @{ */

/** @brief Returns the number of objects in the layer.
 */
@property (readonly) NSUInteger countOfObjects; // KVC/KVO compliant

/** @brief Returns the object at a given stacking position index
 @param indx The stacking position.
 */
- (DKDrawableObject*)objectInObjectsAtIndex:(NSUInteger)indx; // KVC/KVO compliant

/** @brief Returns the topmost object.
 */
@property (readonly, strong, nullable) DKDrawableObject* topObject;

/** @brief Returns the bottom object.
 */
@property (readonly, strong, nullable) DKDrawableObject* bottomObject;

/** @brief Returns the stacking position of the given object.

 Will return \c NSNotFound if the object is not presently owned by the layer.
 @param obj The object.
 @return The object's stacking order index.
 */
- (NSUInteger)indexOfObject:(DKDrawableObject*)obj;

/** @brief Returns a list of objects given by the index set.
 @param set An index set.
 @return A list of objects.
 */
- (NSArray<DKDrawableObject*>*)objectsAtIndexes:(NSIndexSet*)set; // KVC/KVO compliant

/** @brief Given a list of objects that are part of this layer, return an index set for them.
 @param objs A list of objects.
 @return An index set listing the array index positions for the objects passed.
 */
- (NSIndexSet*)indexesOfObjectsInArray:(NSArray<DKDrawableObject*>*)objs;

/** @}
 @name Adding and Removing Objects
 @brief Adding and removing objects.
 @discussion note that the 'objects' property is fully KVC/KVO compliant because where necessary all methods call some directly KVC/KVO compliant method internally.
 Those marked KVC/KVO compliant are *directly* compliant because they follow the standard KVC naming conventions. For observing a change via KVO, an
 observer must use one of the marked methods, but they can be sure they will observe the change even when other code makes use of a non-compliant method.
 @{ */

/** @brief Adds an object to the layer.
 @discussion KVC/KVO compliant.
 
 If layer is locked, does nothing. This is the KVC/KVO compliant method for adding objects that
 can be observed if desired to get notified of these events. All other add/remove methods call
 this. Adding multiple objects calls this multiple times.
 @param obj The object to add.
 @param indx The index at which the object should be inserted.
 */
- (void)insertObject:(DKDrawableObject*)obj inObjectsAtIndex:(NSUInteger)indx; // KVC/KVO compliant

/** @brief Removes an object from the layer.
 @discussion KVC/KVO compliant.
 
 if layer is locked, does nothing. This is the KVC/KVO compliant method for removing objects that
 can be observed if desired to get notified of these events. All other add/remove methods call
 this. Removing multiple objects calls this multiple times.
 @param indx The index at which the object should be removed.
 */
- (void)removeObjectFromObjectsAtIndex:(NSUInteger)indx; // KVC/KVO compliant

/** @brief Replaces an object in the layer with another.
 @discussion KVC/KVO compliant.
 
 If layer is locked, does nothing. This is the KVC/KVO compliant method for exchanging objects that
 can be observed if desired to get notified of these events.
 @param indx The index at which the object should be replaced.
 @param obj The object that will replace the item at <code>index</code>.
 */
- (void)replaceObjectInObjectsAtIndex:(NSUInteger)indx withObject:(DKDrawableObject*)obj; // KVC/KVO compliant

/** @brief Inserts a set of objects at the indexes given. The array and set order should match, and
 have equal counts.
 @discussion KVC/KVO compliant.
 @param objs The objects to insert.
 @param set The indexes where they should be inserted.
 */
- (void)insertObjects:(NSArray<DKDrawableObject*>*)objs atIndexes:(NSIndexSet*)set; // KVC/KVO compliant

/** @brief Removes objects from the indexes listed by the set.
 @discussion KVC/KVO compliant.
 @param set An index set.
 */
- (void)removeObjectsAtIndexes:(NSIndexSet*)set; // KVC/KVO compliant

/** @}
 @name General Purpose Adding/Removal
 @brief General purpose adding/removal.
 @discussion Call through to KVC/KVO methods as necessary, but can't be observed directly.
 @{ */

/** @brief Adds an object to the layer

 If layer locked, does nothing
 @param obj The object to add.
 */
- (void)addObject:(DKDrawableObject*)obj;

/** @brief Adds an object to the layer at a specific stacking index position.
 @param obj The object to add.
 @param index The stacking order position index (0 = bottom, grows upwards).
 */
- (void)addObject:(DKDrawableObject*)obj atIndex:(NSUInteger)index;

/** @brief Adds a set of objects to the layer.

 Take care that no objects are already owned by any layer - this doesn't check.
 @param objs An array of <code>DKDrawableObject</code>s, or subclasses.
 */
- (void)addObjectsFromArray:(NSArray<DKDrawableObject*>*)objs;

/** @brief Adds a set of objects to the layer offsetting their location by the given delta values relative to
 a given point.

 Used for paste and other similar ops. The objects are placed such that their bounding rect's origin
 ends up at <code>origin</code>, regardless of the object's current location. Note that if pin is <code>YES</code>, the
 method will not return <code>NO</code>, as no object was placed outside the interior.
 @param objs A list of <code>DKDrawableObject</code>s to add.
 @param origin The required relative origin of the group of objects.
 @param pin If <code>YES</code>, object locations are pinned to the drawing interior.
 @return \c YES if all objects were placed within the interior bounds of the drawing, \c NO if any object was
 placed outside the interior.
 */
- (BOOL)addObjectsFromArray:(NSArray<DKDrawableObject*>*)objs relativeToPoint:(NSPoint)origin pinToInterior:(BOOL)pin;

/** @brief Adds a set of objects to the layer offsetting their location by the given delta values relative to
 a given point.

 Used for paste and other similar ops. The objects are placed such that their bounding rect's origin
 ends up at <code>origin</code>, regardless of the object's current location. Note that if pin is YES, the
 method will not return NO, as no object was placed outside the interior. Note that the \c bounds parameter
 can differ when calculated compared with the original recorded bounds during the copy. This is because
 bounds often takes into account other relationships such as the layer's knobs and so on, which might
 no be available when pasting. For accurate positioning, the original bounds should be passed.
 @param objs A list of <code>DKDrawableObject</code>s to add.
 @param bounds The original bounding rect of the objects. If <code>NSZeroRect</code>, it is calculated.
 @param origin The required relative origin of the group of objects.
 @param pin If <code>YES</code>, object locations are pinned to the drawing interior.
 @return \c YES if all objects were placed within the interior bounds of the drawing, \c NO if any object was
 placed outside the interior.
 */
- (BOOL)addObjectsFromArray:(NSArray<DKDrawableObject*>*)objs bounds:(NSRect)bounds relativeToPoint:(NSPoint)origin pinToInterior:(BOOL)pin;

/** @brief Removes the object from the layer.
 @param obj The object to remove.
 */
- (void)removeObject:(DKDrawableObject*)obj;

/** @brief Removes the object at the given stacking position index.
 @param indx The stacking index value.
 */
- (void)removeObjectAtIndex:(NSUInteger)indx;

/** @brief Removes a set of objects from the layer
 */
- (void)removeObjectsInArray:(NSArray<DKDrawableObject*>*)objs;

/** @brief Removes all objects from the layer
 */
- (void)removeAllObjects;

/** @}
 @name Enumerating Objects
 @brief Enumerating objects (typically for drawing).
 @{ */

/** @brief Return an iterator that will enumerate the objects needing update.

 The iterator returned iterates in bottom-to-top order and includes only those objects that are
 visible and whose bounds intersect the update region of the view. If \c aView is <code>nil</code>, \c rect is
 still used to determine inclusion.
 @param rect The update rect as passed to a \c drawRect: method of a view.
 @param aView The view being updated, if any (may be <code>nil</code>).
 @return An iterator.
 */
- (NSEnumerator<DKDrawableObject*>*)objectEnumeratorForUpdateRect:(NSRect)rect inView:(nullable NSView*)aView;

/** @brief Return an iterator that will enumerate the objects needing update.

 The iterator returned iterates in bottom-to-top order and includes only those objects that are
 visible and whose bounds intersect the update region of the view. If \c aView is <code>nil</code>, \c rect is
 still used to determine inclusion.
 @param rect The update rect as passed to a \c drawRect: method of a view.
 @param aView The view being updated, if any (may be <code>nil</code>).
 @param options Various flags that you can pass to modify behaviour.
 @return An iterator.
 */
- (NSEnumerator<DKDrawableObject*>*)objectEnumeratorForUpdateRect:(NSRect)rect inView:(nullable NSView*)aView options:(DKObjectStorageOptions)options;

/** @brief Return the objects needing update.

 If \c aView is <code>nil</code>, \c rect is used to determine inclusion.
 @param rect the update rect as passed to a drawRect: method of a view
 @param aView The view being updated, if any (may be <code>nil</code>).
 @return An array, the objects needing update, in drawing order.
 */
- (NSArray<DKDrawableObject*>*)objectsForUpdateRect:(NSRect)rect inView:(nullable NSView*)aView;

/** @brief Return the objects needing update.

 If \c aView is <code>nil</code>, \c rect is used to determine inclusion.
 @param rect The update rect as passed to a \c drawRect: method of a view.
 @param aView The view being updated, if any (may be <code>nil</code>).
 @param options Various flags that you can pass to modify behaviour.
 @return An array, the objects needig update, in drawing order.
 */
- (NSArray<DKDrawableObject*>*)objectsForUpdateRect:(NSRect)rect inView:(nullable NSView*)aView options:(DKObjectStorageOptions)options;

/** @}
 @name Updating & Drawing Objects
 @{ */

/** @brief Flags part of a layer as needing redrawing.
 
 Allows the object requesting the update to be identified - by default this just invalidates <code>rect</code>.
 @param obj The drawable object requesting the update.
 @param rect The area that needs to be redrawn.
 */
- (void)drawable:(DKDrawableObject*)obj needsDisplayInRect:(NSRect)rect;

/** @brief Draws all of the visible objects.
 
 This is used when drawing the layer into special contexts, not for view rendering.
 */
- (void)drawVisibleObjects;

/** @brief Get an image of the current objects in the layer.
 
 If there are no visible objects, returns <code>nil</code>.
 @return An NSImage.
 */
- (nullable NSImage*)imageOfObjects;

/** @brief Get a PDF of the current visible objects in the layer.
 
 If there are no visible objects, returns <code>nil</code>.
 @return PDF Data in an \c NSData object.
 */
- (nullable NSData*)pdfDataOfObjects;

/** @}
 @name Pending Object
 @brief Used during interactive creation of new objects.
 @{ */

/** @brief Adds a new object to the layer pending successful interactive creation.

 When interactively creating objects, it is preferable to create the object successfully before
 committing it to the layer - this gives the caller a chance to abort the creation without needing
 to be concerned about any undos, etc. The pending object is drawn on top of all others as normal
 but until it is committed, it creates no undo task for the layer.
 @param pend A new potential object to be added to the layer.
 */
- (void)addObjectPendingCreation:(DKDrawableObject*)pend;

/** @brief Removes a pending object in the situation that the creation was unsuccessful.

 When interactively creating objects, if for any reason the creation failed, this should be called
 to remove the object from the layer without triggering any undo tasks, and to remove any objects
 itself made.
 */
- (void)removePendingObject;

/** @brief Commits the pending object to the layer and sets up the undo task action name.

 When interactively creating objects, if the creation succeeded, the pending object should be
 committed to the layer permanently. This does that by adding it using <code>-addObject:</code>. The undo task
 thus created is given the action name (note that other operations can also change this later).
 @param actionName The action name to give the undo manager after committing the object.
 */
- (void)commitPendingObjectWithUndoActionName:(NSString*)actionName;

/** @brief Draws the pending object, if any, in the layer - called by <code>-drawRect:inView:</code>

 Pending objects are drawn normally is if part of the current list, and on top of all others. Subclasses
 may need to override this if the selected state needs passing differently. Typically pending objects
 will be drawn selected, so the default is YES.
 @param aView The view being drawn into.
 */
- (void)drawPendingObjectInView:(NSView*)aView;

/** @brief Returns the pending object, if any, in the layer.
 @return the pending object, or nil
 */
@property (readonly, strong, nullable) DKDrawableObject* pendingObject;

/** @}
 @name Geometry
 @} */

/** @brief Return the union of all the visible objects in the layer. If there are no visible objects, returns
 <code>NSZeroRect</code>.

 Avoid using for refreshing objects. It is more efficient to use <code>-refreshAllObjects</code>.
 @return A rect, the union of all visible object's bounds in the layer.
 */
- (NSRect)unionOfAllObjectBounds;

/** @brief Causes all objects in the passed array, set or other container to redraw themselves.
 @param container A container of drawable objects. Any \c NSArray or \c NSSet is acceptable.
 */
- (void)refreshObjectsInContainer:(id)container;

/** @brief Causes all visible objects to redraw themselves.
 */
- (void)refreshAllObjects;

/** @brief Returns the layer's transform used when rendering objects within.

 Returns the identity transform.
 */
@property (readonly, copy) NSAffineTransform* renderingTransform;

/** @brief Modifies the objects by applying the given transform to each of them.

 This modifies the geometry of each object by applying the transform to each one. The purpose of
 this is to permit gross changes to a drawing's layout if the
 client application requires it - for example scaling all objects to some new size.
 @param transform A transform.
 */
- (void)applyTransformToObjects:(NSAffineTransform*)transform;

/** @}
 @name Stacking Order
 @{ */

/** @brief Moves the object up in the stacking order.
 @param obj The object to move.
 */
- (void)moveUpObject:(DKDrawableObject*)obj;

/** @brief Moves the object down in the stacking order.
 @param obj The object to move.
 */
- (void)moveDownObject:(DKDrawableObject*)obj;

/** @brief Moves the object to the top of the stacking order.
 @param obj The object to move.
 */
- (void)moveObjectToTop:(DKDrawableObject*)obj;

/** @brief Moves the object to the bottom of the stacking order.
 @param obj The object to move.
 */
- (void)moveObjectToBottom:(DKDrawableObject*)obj;

/** @brief Moves the object to the given stacking position index.

 Used to implement all the other \c moveTo... ops.
 @param obj The object to move.
 @param indx The index it should be moved to.
 */
- (void)moveObject:(DKDrawableObject*)obj toIndex:(NSUInteger)indx;

/** @}
 @name Restacking Multiple Objects
 @{ */

/** @brief Moves the objects indexed by the set to the given stacking position index.

 Useful for restacking several objects.
 @param set A set of indexes.
 @param indx The index it should be moved to.
 */
- (void)moveObjectsAtIndexes:(NSIndexSet*)set toIndex:(NSUInteger)indx;

/** @brief Moves the objects in the array to the given stacking position index.

 Useful for restacking several objects. Array passed can be the selection. The order of objects in
 the array is preserved relative to one another. After the operation the lowest indexed object
 will be at \c indx and the rest at consecutive indexes above it.
 @param objs An array of objects already owned by the layer.
 @param indx The index they should be moved to.
 */
- (void)moveObjectsInArray:(NSArray<DKDrawableObject*>*)objs toIndex:(NSUInteger)indx;

/** @}
 @name Clipboard Ops
 @brief Clipboard ops and predictive pasting support.
 @{ */

/** @brief Add objects to the layer from the pasteboard.
 
 This is the preferred method to use when pasting or dropping anything, because the subclass that
 implements selection overrides this to handle the selection also. Thus when pasting non-native
 objects, convert them to native objects and pass to this method in an array.
 @param objects A list of objects already dearchived from the pasteboard.
 @param pb The pasteboard (for information only).
 @param p The drop location of the objects, defined as the lower left corner of the drag image - thus
 a multiple selection is positioned at the point <code>p</code>, with others maintaining their positions
 relative to this object as in the original set. 
 */
- (void)addObjects:(NSArray<DKDrawableObject*>*)objects fromPasteboard:(NSPasteboard*)pb atDropLocation:(NSPoint)p;

/** @brief Detect whether the paste from the pasteboard is a new paste, or a repeat paste

 Since this is a one-shot method that changes the internal state of the layer, it should not be
 called except internally to manage the auto paste repeat. It may either increment or reset the
 paste count. It also sets the paste origin to the origin of the pasted objects' bounds.
 @param pb The pasteboard in question.
 @return \c YES if this is a new paste, \c NO if a repeat.
 */
- (BOOL)updatePasteCountWithPasteboard:(NSPasteboard*)pb;

/** @brief Whether the paste offset will be recorded for the current drag operation.
 @return \c YES if paste offset will be recorded, \c NO otherwise.
 */
@property (getter=isRecordingPasteOffset) BOOL recordingPasteOffset;

/** @brief Return the current number of repeated pastes since the last new paste.
 
 The paste count is reset to \c 1 by a new paste, and incremented for each subsequent paste of the
 same objects. This is used when calculating appropriate positioning for repeated pasting.
 */
@property (readonly) NSInteger pasteCount;

/** @brief The current point where pasted objects will be positioned relative to.

 See \c paste: for how this is used.
 */
@property (nonatomic) NSPoint pasteOrigin;

/** @brief The paste offset (distance between successively pasted objects).
 */
@property (nonatomic) NSSize pasteOffset;

/** @brief Establish the paste offset - a value used to position items when pasting and duplicating.

 The values passed will be adjusted to the nearest grid interval if snap to grid is on.
 @param x The x value of the offset.
 @param y The y value of the offset.
 */
- (void)setPasteOffsetX:(CGFloat)x y:(CGFloat)y NS_SWIFT_NAME(setPasteOffset(x:y:));

/** @brief Sets the paste offset (distance between successively pasted objects).
 
 Called by the standard select/edit tool as part of an informal protocol. This sets the paste offset
 if offset recording is currently set to YES, then resets the record flag.
 @param objects The list of objects that were moved.
 @param startPt The starting point for the drag.
 @param endPt The ending point for the drag.
 */
- (void)objects:(NSArray*)objects wereDraggedFromPoint:(NSPoint)startPt toPoint:(NSPoint)endPt;

/** @}
 @name Hit Testing
 @{ */

/** @brief Find which object was hit by the given point, if any.
 @param point A point to test against.
 @return The object hit, or \c nil if none.
 */
- (nullable DKDrawableObject*)hitTest:(NSPoint)point;

/** @brief Performs a hit test but also returns the hit part code.
 @param point the point to test
 @param part Pointer to an <code>NSInteger</code>, receives the partcode hit as a result
 of the test. Can be \c NULL to ignore.
 @return The object hit, or \c nil if none.
 */
- (nullable DKDrawableObject*)hitTest:(NSPoint)point partCode:(nullable NSInteger*)part;

/** @brief Finds all objects touched by the given rect.

 Test for inclusion by calling the object's intersectsRect method. Can be used to select objects in
 a given rect or for any other purpose. For selections, the results can be passed directly to
 \c exchangeSelection:
 @param rect A rectangle.
 @return A list of objects touched by <code>rect</code>.
 */
- (NSArray<DKDrawableObject*>*)objectsInRect:(NSRect)rect;

/** @brief An object owned by the layer was double-clicked.

 Override to use.
 @param obj The object hit.
 @param mp The mouse point of the click.
 */
- (void)drawable:(DKDrawableObject*)obj wasDoubleClickedAtPoint:(NSPoint)mp;

/** @}
 @name Snapping
 @{ */

/** @brief Snap a point to any existing object control point within tolerance.

 If snap to object is not set for this layer, this simply returns the original point unmodified.
 currently uses hitPart to test for a hit, so tolerance is ignored and objects apply their internal
 hit testing tolerance.
 @param p a point
 @param except Don't snap to this object (intended to be the one being snapped).
 @param tol Has to be within this distance to snap.
 @return The modified point, or the original point.
 */
- (NSPoint)snapPoint:(NSPoint)p toAnyObjectExcept:(DKDrawableObject*)except snapTolerance:(CGFloat)tol;

/** @brief Snap a (mouse) point to grid, guide or other object according to settings.

 Usually called from \c snappedMousePoint: method in <code>DKDrawableObject</code>.
 @param mp A point.
 @return The modified point, or the original point.
 */
- (NSPoint)snappedMousePoint:(NSPoint)mp forObject:(DKDrawableObject*)obj withControlFlag:(BOOL)snapControl;

/** @}
 @name Options
 @{ */

/** @brief Does the layer permit editing of its objects?

 Locking and hiding the layer also disables editing.
 Is \c YES if editing will take place, \c NO if it is prevented.
 */
@property (nonatomic) BOOL allowsEditing;

/** @brief Does the layer permit snapping to its objects?
 Is YES if snapping allowed.
 */
@property BOOL allowsSnapToObjects;

/** @brief Query whether the layer caches its content in an offscreen layer when not active.

 Layers can cache their entire contents offscreen when they are inactive. This can boost
 drawing performance when there are many layers, or the layers have complex contents. When the
 layer is deactivated the cache is updated, on activation the "real" content is drawn.
 */
@property (nonatomic) DKLayerCacheOption layerCacheOption;

/** @brief Set whether the layer is currently highlighted for a drag (receive) operation.
 Is \c YES if highlighted, \c NO otherwise.
 */
@property (nonatomic, getter=isHighlightedForDrag) BOOL highlightedForDrag;

/** @brief Draws the highlighting to indicate the layer is a drag target.

 Is only called when the drag highlight is YES. Override for different highlight effect.
 */
- (void)drawHighlightingForDrag;

/** @}
 @name User Actions
 @{ */

/** @brief Sets the snapping state for the layer
 */
- (IBAction)toggleSnapToObjects:(nullable id)sender;

/** @brief Toggles whether the debugging path is overlaid afterdrawing the content.

 This is purely to assist with storage debugging and should not be invoked in production code.
 */
- (IBAction)toggleShowStorageDebuggingPath:(nullable id)sender;

/** @} */

@end

// deprecated methods

#ifdef DRAWKIT_DEPRECATED

@interface DKObjectOwnerLayer (Deprecated)

/** @brief Return an iterator that will enumerate the object in top to bottom order

 The idea is to insulate you from the implementation detail of how stacking order relates to the
 list order of objects internally. Because this enumerates a copy of the objects list, it is safe
 to modify the objects in the layer itself while iterating.
 @return an iterator
 */
- (null_unspecified NSEnumerator*)objectTopToBottomEnumerator DEPRECATED_ATTRIBUTE;

/** @brief Return an iterator that will enumerate the object in bottom to top order

 The idea is to insulate you from the implementation detail of how stacking order relates to the
 list order of objects internally. Because this enumerates a copy of the objects list, it is safe
 to modify the objects in the layer itself while iterating.
 @return an iterator
 */
- (null_unspecified NSEnumerator*)objectBottomToTopEnumerator DEPRECATED_ATTRIBUTE;

/** @brief Unarchive a list of objects from the pasteboard, if possible

 This factors the dearchiving of objects from the pasteboard. If the pasteboard does not contain
 any valid types, nil is returned
 @param pb the pasteboard to take objects from
 @return a list of objects
 */
- (null_unspecified NSArray*)nativeObjectsFromPasteboard:(null_unspecified NSPasteboard*)pb DEPRECATED_ATTRIBUTE;

@end

#endif

extern NSPasteboardType const kDKDrawableObjectInfoPasteboardType NS_SWIFT_NAME(dkDrawableObjectInfo);
extern NSNotificationName const kDKLayerDidReorderObjects;

extern NSNotificationName const kDKLayerWillAddObject;
extern NSNotificationName const kDKLayerDidAddObject;
extern NSNotificationName const kDKLayerWillRemoveObject;
extern NSNotificationName const kDKLayerDidRemoveObject;

#define DEFAULT_PASTE_OFFSET 20

NS_ASSUME_NONNULL_END
