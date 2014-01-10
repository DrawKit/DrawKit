/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKLayer.h"
#import "DKObjectStorageProtocol.h"
#import "DKDrawableContainerProtocol.h"

@class DKDrawableObject, DKStyle;

// caching options

typedef enum {
    kDKLayerCacheNone = 0, // no caching
    kDKLayerCacheUsingPDF = (1 << 0), // layer is cached in a PDF Image Rep
    kDKLayerCacheUsingCGLayer = (1 << 1), // layer is cached in a CGLayer bitmap
    kDKLayerCacheObjectOutlines = (1 << 2) // objects are drawn using a simple outline stroke only
} DKLayerCacheOption;

// the class

/** @brief This layer class can be the owner of any number of DKDrawableObjects.

This layer class can be the owner of any number of DKDrawableObjects. It implements the ability to contain and render
these objects.

It does NOT support the concept of a selection, or of a list of selected objects (DKObjectDrawingLayer subclasses this to
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
@interface DKObjectOwnerLayer : DKLayer <NSCoding, DKDrawableContainer> {
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

+ (void)setDefaultLayerCacheOption:(DKLayerCacheOption)option;
+ (DKLayerCacheOption)defaultLayerCacheOption;

// setting the storage (n.b. storage is set by default, this is an advanced feature that you can ignore 99% of the time):

+ (void)setStorageClass:(Class)aClass;
+ (Class)storageClass;

- (void)setStorage:(id<DKObjectStorage>)storage;

/** @brief Returns the storage object for the layer
 @return a storage object
 */
- (id<DKObjectStorage>)storage;

// as a container for a DKDrawableObject:

/** @brief Returns the layer of a drawable's container - since this is that layer, returns self

 See DKDrawableObject which also implements this protocol
 @return self
 */
- (DKObjectOwnerLayer*)layer;

// the list of objects:

/** @brief Sets the objects that this layer owns
 @param objs an array of DKDrawableObjects, or subclasses thereof
 */
- (void)setObjects:(NSArray*)objs; // KVC/KVO compliant

/** @brief Returns all owned objects
 @return an array of the objects
 */
- (NSArray*)objects; // KVC/KVO compliant

/** @brief Returns objects that are available to the user, that is, not locked or invisible

 If the layer itself is locked, returns the empty list
 @return an array of available objects
 */
- (NSArray*)availableObjects;

/** @brief Returns objects that are available to the user, that is, not locked or invisible and that
 intersect the rect

 If the layer itself is locked, returns the empty list
 @param aRect - objects must also intersect this rect
 @return an array of available objects
 */
- (NSArray*)availableObjectsInRect:(NSRect)aRect;

/** @brief Returns objects that are available to the user of the given class

 If the layer itself is locked, returns the empty list
 @param aClass - class of the desired objects
 @return an array of available objects
 */
- (NSArray*)availableObjectsOfClass:(Class)aClass;

/** @brief Returns objects that are visible to the user, but may be locked

 If the layer itself is not visible, returns nil
 @return an array of visible objects
 */
- (NSArray*)visibleObjects;

/** @brief Returns objects that are visible to the user, intersect the rect, but may be locked

 If the layer itself is not visible, returns nil
 @param aRect the objects returned intersect this rect
 @return an array of visible objects
 */
- (NSArray*)visibleObjectsInRect:(NSRect)aRect;

/** @brief Returns objects that share the given style

 The style is compared by unique key, so style clones are not considered a match. Unavailable objects are
 also included.
 @param style the style to compare
 @return an array of those objects that have the style
 */
- (NSArray*)objectsWithStyle:(DKStyle*)style;

/** @brief Returns objects that respond to the selector with the value <answer>
 <selector> a selector taking no parameters

 This is a very simple type of predicate test. Note - the method <selector> must not return
 anything larger than an int or it will be ignored and the result may be wrong.
 @return an array, objects that match the value of <answer>
 */
- (NSArray*)objectsReturning:(NSInteger)answer toSelector:(SEL)selector;

// getting objects:

- (NSUInteger)countOfObjects; // KVC/KVO compliant

/** @brief Returns the object at a given stacking position index
 @param index the stacking position
 */
- (DKDrawableObject*)objectInObjectsAtIndex:(NSUInteger)indx; // KVC/KVO compliant

/** @brief Returns the topmost object
 @return the topmost object
 */
- (DKDrawableObject*)topObject;

/** @brief Returns the bottom object
 @return the bottom object
 */
- (DKDrawableObject*)bottomObject;

/** @brief Returns the stacking position of the given object

 Will return NSNotFound if the object is not presently owned by the layer
 @param obj the object
 @return the object's stacking order index
 */
- (NSUInteger)indexOfObject:(DKDrawableObject*)obj;

/** @brief Returns a list of objects given by the index set
 @param set an index set
 @return a list of objects
 */
- (NSArray*)objectsAtIndexes:(NSIndexSet*)set; // KVC/KVO compliant

/** @brief Given a list of objects that are part of this layer, return an index set for them
 @param objs a list of objects
 @return an index set listing the array index positions for the objects passed
 */
- (NSIndexSet*)indexesOfObjectsInArray:(NSArray*)objs;

// adding and removing objects:
// note that the 'objects' property is fully KVC/KVO compliant because where necessary all methods call some directly KVC/KVO compliant method internally.
// those marked KVC/KVO compliant are *directly* compliant because they follow the standard KVC naming conventions. For observing a change via KVO, an
// observer must use one of the marked methods, but they can be sure they will observe the change even when other code makes use of a non-compliant method.

/** @brief Adds an object to the layer
 @param obj the object to add
 @param index the index at which the object should be inserted
 @return none
 these. Adding multiple objects calls this multiple times.
 */
- (void)insertObject:(DKDrawableObject*)obj inObjectsAtIndex:(NSUInteger)indx; // KVC/KVO compliant

/** @brief Removes an object from the layer
 @param index the index at which the object should be removed
 @return none
 these. Removing multiple objects calls this multiple times.
 */
- (void)removeObjectFromObjectsAtIndex:(NSUInteger)indx; // KVC/KVO compliant

/** @brief Replaces an object in the layer with another
 @param index the index at which the object should be exchanged
 @param obj the object that will replace the item at index
 @return none
 can be observed if desired to get notified of these events.
 */
- (void)replaceObjectInObjectsAtIndex:(NSUInteger)indx withObject:(DKDrawableObject*)obj; // KVC/KVO compliant

/** @brief Inserts a set of objects at the indexes given. The array and set order should match, and
 have equal counts.
 @param objs the objects to insert
 @param set the indexes where they should be inserted
 */
- (void)insertObjects:(NSArray*)objs atIndexes:(NSIndexSet*)set; // KVC/KVO compliant

/** @brief Removes objects from the indexes listed by the set
 @param set an index set
 */
- (void)removeObjectsAtIndexes:(NSIndexSet*)set; // KVC/KVO compliant

// general purpose adding/removal (call through to KVC/KVO methods as necessary, but can't be observed directly)

/** @brief Adds an object to the layer

 If layer locked, does nothing
 @param obj the object to add
 */
- (void)addObject:(DKDrawableObject*)obj;
- (void)addObject:(DKDrawableObject*)obj atIndex:(NSUInteger)index;

/** @brief Adds a set of objects to the layer

 Take care that no objects are already owned by any layer - this doesn't check.
 @param objs an array of DKDrawableObjects, or subclasses.
 */
- (void)addObjectsFromArray:(NSArray*)objs;

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
- (BOOL)addObjectsFromArray:(NSArray*)objs relativeToPoint:(NSPoint)origin pinToInterior:(BOOL)pin;

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
- (BOOL)addObjectsFromArray:(NSArray*)objs bounds:(NSRect)bounds relativeToPoint:(NSPoint)origin pinToInterior:(BOOL)pin;

/** @brief Removes the object from the layer
 @param obj the object to remove
 */
- (void)removeObject:(DKDrawableObject*)obj;

/** @brief Removes the object at the given stacking position index
 @param index the stacking index value
 */
- (void)removeObjectAtIndex:(NSUInteger)indx;

/** @brief Removes a set of objects from the layer
 */
- (void)removeObjectsInArray:(NSArray*)objs;

/** @brief Removes all objects from the layer
 */
- (void)removeAllObjects;

// enumerating objects (typically for drawing)

/** @brief Return an iterator that will enumerate the objects needing update

 The iterator returned iterates in bottom-to-top order and includes only those objects that are
 visible and whose bounds intersect the update region of the view. If the view is nil <rect> is
 still used to determine inclusion.
 @param rect the update rect as passed to a drawRect: method of a view
 @param aView the view being updated, if any (may be nil)
 @return an iterator
 */
- (NSEnumerator*)objectEnumeratorForUpdateRect:(NSRect)rect inView:(NSView*)aView;

/** @brief Return an iterator that will enumerate the objects needing update

 The iterator returned iterates in bottom-to-top order and includes only those objects that are
 visible and whose bounds intersect the update region of the view. If the view is nil <rect> is
 still used to determine inclusion.
 @param rect the update rect as passed to a drawRect: method of a view
 @param aView the view being updated, if any (may be nil)
 @param options various flags that you can pass to modify behaviour:
 @return an iterator
 */
- (NSEnumerator*)objectEnumeratorForUpdateRect:(NSRect)rect inView:(NSView*)aView options:(DKObjectStorageOptions)options;

/** @brief Return the objects needing update

 If the view is nil <rect> is used to determine inclusion.
 @param rect the update rect as passed to a drawRect: method of a view
 @param aView the view being updated, if any (may be nil)
 @return an array, the objects needing update, in drawing order
 */
- (NSArray*)objectsForUpdateRect:(NSRect)rect inView:(NSView*)aView;

/** @brief Return the objects needing update

 If the view is nil <rect> is used to determine inclusion.
 @param rect the update rect as passed to a drawRect: method of a view
 @param aView the view being updated, if any (may be nil)
 @param options various flags that you can pass to modify behaviour:
 @return an array, the objects needig update, in drawing order
 */
- (NSArray*)objectsForUpdateRect:(NSRect)rect inView:(NSView*)aView options:(DKObjectStorageOptions)options;

// updating & drawing objects:

- (void)drawable:(DKDrawableObject*)obj needsDisplayInRect:(NSRect)rect;
- (void)drawVisibleObjects;
- (NSImage*)imageOfObjects;
- (NSData*)pdfDataOfObjects;

// pending object - used during interactive creation of new objects

/** @brief Adds a new object to the layer pending successful interactive creation

 When interactively creating objects, it is preferable to create the object successfully before
 committing it to the layer - this gives the caller a chance to abort the creation without needing
 to be concerned about any undos, etc. The pending object is drawn on top of all others as normal
 but until it is committed, it creates no undo task for the layer.
 @param pend a new potential object to be added to the layer
 */
- (void)addObjectPendingCreation:(DKDrawableObject*)pend;

/** @brief Removes a pending object in the situation that the creation was unsuccessful

 When interactively creating objects, if for any reason the creation failed, this should be called
 to remove the object from the layer without triggering any undo tasks, and to remove any the object
 itself made
 */
- (void)removePendingObject;

/** @brief Commits the pending object to the layer and sets up the undo task action name

 When interactively creating objects, if the creation succeeded, the pending object should be
 committed to the layer permanently. This does that by adding it using addObject. The undo task
 thus created is given the action name (note that other operations can also change this later).
 @param actionName the action name to give the undo manager after committing the object
 */
- (void)commitPendingObjectWithUndoActionName:(NSString*)actionName;

/** @brief Draws the pending object, if any, in the layer - called by drawRect:inView:

 Pending objects are drawn normally is if part of the current list, and on top of all others. Subclasses
 may need to override this if the selected state needs passing differently. Typically pending objects
 will be drawn selected, so the default is YES.
 @param aView the view being drawn into
 */
- (void)drawPendingObjectInView:(NSView*)aView;

/** @brief Returns the pending object, if any, in the layer
 @return the pending object, or nil
 */
- (DKDrawableObject*)pendingObject;

// geometry:

/** @brief Return the union of all the visible objects in the layer. If there are no visible objects, returns
 NSZeroRect.

 Avoid using for refreshing objects. It is more efficient to use refreshAllObjects
 @return a rect, the union of all visible object's bounds in the layer
 */
- (NSRect)unionOfAllObjectBounds;

/** @brief Causes all objects in the passed array, set or other container to redraw themselves
 @param container a container of drawable objects. Any NSArray or NSSet is acceptable
 */
- (void)refreshObjectsInContainer:(id)container;

/** @brief Causes all visible objects to redraw themselves
 */
- (void)refreshAllObjects;

/** @brief Returns the layer's transform used when rendering objects within

 Returns the identity transform
 @return a transform
 */
- (NSAffineTransform*)renderingTransform;

/** @brief Modifies the objects by applying the given transform to each of them.

 This modifies the geometry of each object by applying the transform to each one. The purpose of
 this is to permit gross changes to a drawing's layout if the
 client application requires it - for example scaling all objects to some new size.
 @param transform a transform
 */
- (void)applyTransformToObjects:(NSAffineTransform*)transform;

// stacking order:

/** @brief Moves the object up in the stacking order
 @param obj object to move
 */
- (void)moveUpObject:(DKDrawableObject*)obj;

/** @brief Moves the object down in the stacking order
 @param obj the object to move
 */
- (void)moveDownObject:(DKDrawableObject*)obj;

/** @brief Moves the object to the top of the stacking order
 @param obj the object to move
 */
- (void)moveObjectToTop:(DKDrawableObject*)obj;

/** @brief Moves the object to the bottom of the stacking order
 @param obj object to move
 */
- (void)moveObjectToBottom:(DKDrawableObject*)obj;

/** @brief Movesthe object to the given stacking position index

 Used to implement all the other moveTo.. ops
 @param obj the object to move
 @param i the index it should be moved to
 */
- (void)moveObject:(DKDrawableObject*)obj toIndex:(NSUInteger)indx;

// restacking multiple objects:

/** @brief Moves the objects indexed by the set to the given stacking position index

 Useful for restacking several objects
 @param set a set of indexes
 @param indx the index it should be moved to
 */
- (void)moveObjectsAtIndexes:(NSIndexSet*)set toIndex:(NSUInteger)indx;

/** @brief Moves the objects in the array to the given stacking position index

 Useful for restacking several objects. Array passed can be the selection. The order of objects in
 the array is preserved relative to one another, after the operation the lowest indexed object
 will be at <indx> and the rest at consecutive indexes above it.
 @param objs an array of objects already owned by the layer
 @param indx the index it should be moved to
 */
- (void)moveObjectsInArray:(NSArray*)objs toIndex:(NSUInteger)indx;

// clipboard ops:

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
- (void)addObjects:(NSArray*)objects fromPasteboard:(NSPasteboard*)pb atDropLocation:(NSPoint)p;

/** @brief Detect whether the paste from the pasteboard is a new paste, or a repeat paste

 Since this is a one-shot method that changes the internal state of the layer, it should not be
 called except internally to manage the auto paste repeat. It may either increment or reset the
 paste count. It also sets the paste origin to the origin of the pasted objects' bounds.
 @param pb the pasteboard in question
 @return YES if this is a new paste, NO if a repeat
 */
- (BOOL)updatePasteCountWithPasteboard:(NSPasteboard*)pb;

/** @brief Return whether the paste offset will be recorded for the current drag operation
 @return YES if paste offset will be recorded, NO otherwise
 */
- (BOOL)isRecordingPasteOffset;

/** @brief Set whether the paste offset will be recorded for the current drag operation
 @param record YES to record the offset
 */
- (void)setRecordingPasteOffset:(BOOL)record;
- (NSInteger)pasteCount;

/** @brief Return the current point where pasted object will be positioned relative to

 See paste: for how this is used
 @return the paste origin
 */
- (NSPoint)pasteOrigin;

/** @brief Sets the current point where pasted object will be positioned relative to

 See paste: for how this is used
 @param po the desired paste origin.
 */
- (void)setPasteOrigin:(NSPoint)po;

/** @brief Returns the paste offset (distance between successively pasted objects)
 @return the paste offset as a NSSize
 */
- (NSSize)pasteOffset;

/** @brief Sets the paste offset (distance between successively pasted objects)
 @param offset the paste offset as a NSSize
 */
- (void)setPasteOffset:(NSSize)offset;

/** @brief Establish the paste offset - a value used to position items when pasting and duplicating

 The values passed will be adjusted to the nearest grid interval if snap to grid is on.
 @param x>, <y the x and y values of the offset
 */
- (void)setPasteOffsetX:(CGFloat)x y:(CGFloat)y;

/** @brief Sets the paste offset (distance between successively pasted objects)
 @param objects the list of objects that were moved
 @param startPt the starting point for the drag
 @param endPt the ending point for the drag
 @return none
 if offset recording is currently set to YES, then resets the record flag.
 */
- (void)objects:(NSArray*)objects wereDraggedFromPoint:(NSPoint)startPt toPoint:(NSPoint)endPt;

// hit testing:

/** @brief Find which object was hit by the given point, if any
 @param point a point to test against
 @return the object hit, or nil if none
 */
- (DKDrawableObject*)hitTest:(NSPoint)point;

/** @brief Performs a hit test but also returns the hit part code
 @param point the point to test
 @param part pointer to int, receives the partcode hit as a result of the test. Can be NULL to ignore
 @return the object hit, or nil if none
 */
- (DKDrawableObject*)hitTest:(NSPoint)point partCode:(NSInteger*)part;

/** @brief Finds all objects touched by the given rect

 Test for inclusion by calling the object's intersectsRect method. Can be used to select objects in
 a given rect or for any other purpose. For selections, the results can be passed directly to
 exchangeSelection:
 @param rect a rectangle
 @return a list of objects touched by the rect
 */
- (NSArray*)objectsInRect:(NSRect)rect;

/** @brief An object owned by the layer was double-clicked

 Override to use
 @param obj the object hit
 @param mp the mouse point of the click
 */
- (void)drawable:(DKDrawableObject*)obj wasDoubleClickedAtPoint:(NSPoint)mp;

// snapping:

/** @brief Snap a point to any existing object control point within tolerance

 If snap to object is not set for this layer, this simply returns the original point unmodified.
 currently uses hitPart to test for a hit, so tolerance is ignored and objects apply their internal
 hit testing tolerance.
 @param p a point
 @param except don't snap to this object (intended to be the one being snapped)
 @param tol has to be within this distance to snap
 @return the modified point, or the original point
 */
- (NSPoint)snapPoint:(NSPoint)p toAnyObjectExcept:(DKDrawableObject*)except snapTolerance:(CGFloat)tol;

/** @brief Snap a (mouse) point to grid, guide or other object according to settings

 Usually called from snappedMousePoint: method in DKDrawableObject
 @param p a point
 @return the modified point, or the original point
 */
- (NSPoint)snappedMousePoint:(NSPoint)mp forObject:(DKDrawableObject*)obj withControlFlag:(BOOL)snapControl;

// options:

/** @brief Sets whether the layer permits editing of its objects
 @param editable YES to enable editing, NO to prevent it
 */
- (void)setAllowsEditing:(BOOL)editable;

/** @brief Does the layer permit editing of its objects?

 Locking and hiding the layer also disables editing
 @return YES if editing will take place, NO if it is prevented
 */
- (BOOL)allowsEditing;

/** @brief Sets whether the layer permits snapping to its objects
 @param snap YES to allow snapping
 */
- (void)setAllowsSnapToObjects:(BOOL)snap;

/** @brief Does the layer permit snapping to its objects?
 @return YES if snapping allowed
 */
- (BOOL)allowsSnapToObjects;

/** @brief Set whether the layer caches its content in an offscreen layer when not active, and how

 Layers can cache their entire contents offscreen when they are inactive. This can boost
 drawing performance when there are many layers, or the layers have complex contents. When the
 layer is deactivated the cache is updated, on activation the "real" content is drawn.
 @param option the desired cache option
 */
- (void)setLayerCacheOption:(DKLayerCacheOption)option;

/** @brief Query whether the layer caches its content in an offscreen layer when not active

 Layers can cache their entire contents offscreen when they are inactive. This can boost
 drawing performance when there are many layers, or the layers have complex contents. When the
 layer is deactivated the cache is updated, on activation the "real" content is drawn.
 @return the current cache option
 */
- (DKLayerCacheOption)layerCacheOption;

/** @brief Query whether the layer is currently highlighted for a drag (receive) operation
 @return YES if highlighted, NO otherwise
 */
- (BOOL)isHighlightedForDrag;

/** @brief Set whether the layer is currently highlighted for a drag (receive) operation
 @param highlight YES to highlight, NO otherwise
 */
- (void)setHighlightedForDrag:(BOOL)highlight;

/** @brief Draws the highlighting to indicate the layer is a drag target

 Is only called when the drag highlight is YES. Override for different highlight effect.
 */
- (void)drawHighlightingForDrag;

// user actions:

/** @brief Sets the snapping state for the layer
 */
- (IBAction)toggleSnapToObjects:(id)sender;

/** @brief Toggles whether the debugging path is overlaid afterdrawing the content.

 This is purely to assist with storage debugging and should not be invoked in production code.
 */
- (IBAction)toggleShowStorageDebuggingPath:(id)sender;

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
- (NSEnumerator*)objectTopToBottomEnumerator;

/** @brief Return an iterator that will enumerate the object in bottom to top order

 The idea is to insulate you from the implementation detail of how stacking order relates to the
 list order of objects internally. Because this enumerates a copy of the objects list, it is safe
 to modify the objects in the layer itself while iterating.
 @return an iterator
 */
- (NSEnumerator*)objectBottomToTopEnumerator;

/** @brief Unarchive a list of objects from the pasteboard, if possible

 This factors the dearchiving of objects from the pasteboard. If the pasteboard does not contain
 any valid types, nil is returned
 @param pb the pasteboard to take objects from
 @return a list of objects
 */
- (NSArray*)nativeObjectsFromPasteboard:(NSPasteboard*)pb;

@end

#endif

extern NSString* kDKDrawableObjectPasteboardType;
extern NSString* kDKDrawableObjectInfoPasteboardType;
extern NSString* kDKLayerDidReorderObjects;

extern NSString* kDKLayerWillAddObject;
extern NSString* kDKLayerDidAddObject;
extern NSString* kDKLayerWillRemoveObject;
extern NSString* kDKLayerDidRemoveObject;

#define DEFAULT_PASTE_OFFSET 20
