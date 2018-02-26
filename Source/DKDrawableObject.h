/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKCommonTypes.h"
#import "DKDrawableContainerProtocol.h"
#import "DKObjectStorageProtocol.h"
#import "DKRasterizerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class DKObjectOwnerLayer, DKStyle, DKDrawing, DKDrawingTool, DKShapeGroup;

/** @brief This object is responsible for the visual representation of the selection as well as any content.

 A drawable object is owned by a <code>DKObjectDrawingLayer</code>, which is responsible for drawing it when required and handling
 selections. This object is responsible for the visual representation of the selection as well as any content.

 It can draw whatever it likes within <code>bounds</code>, which it is responsible for calculating correctly.

 \c hitTest can return an integer to indicate which part was hit - a value of \c 0 means nothing hit. The returned value's meaning
 is otherwise private to the class, but is returned in the mouse event methods.

 This is intended to be a semi-abstract class - it draws nothing itself. Subclasses include \c DKDrawableShape and \c DKDrawablePath -
 often subclassing one of those will be more straightforward than subclassing this. A subclass must implement \c NSCoding and
 \c NSCopying to be archivable, etc. There are also numerous informal protocols for geometry, snapping, hit testing, drawing and ungrouping
 that need to be implemented correctly for a subclass to work fully correctly within DK.

 The user info is a dictionary attached to an object. It plays no part in the graphics system, but can be used by applications
 to attach arbitrary data to any drawable object.
*/
@interface DKDrawableObject : NSObject <DKStorableObject, DKRenderable, NSCoding, NSCopying> {
@private
	id<DKDrawableContainer> __weak mContainerRef; // the immediate container of this object (layer, group or another drawable)
	DKStyle* m_style; // the drawing style attached
	__weak id<DKObjectStorage> mStorageRef; // ref to the object's storage (DKStorableObject protocol)
	NSMutableDictionary* mUserInfo; // user info including metadata is stored in this dictionary
	NSSize m_mouseOffset; // used to track where mouse was relative to bounds
	NSUInteger mZIndex; // used by the DKStorableObject protocol
	BOOL m_visible; // YES if visible
	BOOL m_locked; // YES if locked
	BOOL mLocationLocked; // YES if location is locked (independently of general lock)
	BOOL m_snapEnable; // YES if mouse actions snap to grid/guides
	BOOL m_inMouseOp; // YES while a mouse operation (drag) is in progress
	BOOL m_mouseEverMoved; // used to set up undo for mouse operations
	BOOL mMarked; // used by DKStorableObject protocol implementation
	BOOL mGhosted; // YES if object is drawn ghosted
	BOOL mIsHitTesting; // YES when drawContent is called for the purposes of hit-testing
	NSMutableDictionary* mRenderingCache; // a dictionary to support general caching by renderers
@protected
	BOOL m_showBBox : 1; // debugging - display the object's bounding box
	BOOL m_clipToBBox : 1; // debugging - force clip region to the bbox
	BOOL m_showPartcodes : 1; // debugging - display the partcodes for each control/knob/handle
	BOOL m_showTargets : 1; // debugging - show the bbox for each control/knob/handle
	BOOL m_unused_padding : 4; // not used - reserved
}

/** @brief Whether an info floater is displayed when resizing an object.

 Size info is width and height.
 */
@property (class) BOOL displaysSizeInfoWhenDragging;

/** @brief Returns the union of the bounds of the objects in the array.

 Utility method as this is a very common task - throws exception if any object in the list is
 not a \c DKDrawableObject or subclass thereof.
 @param array a list of \c DKDrawable objects.
 @return A rect, the union of the bounds of all objects. */
+ (NSRect)unionOfBoundsOfDrawablesInArray:(NSArray<DKDrawableObject*>*)array;

/** @brief Return the partcode that should be used by tools when initially creating a new object.

 Default method does nothing - subclasses must override this and supply the right partcode value
 appropriate to the class. The client of this method is <code>DKObjectCreationTool</code>.
 @return A partcode value.
 */
@property (class, readonly) NSInteger initialPartcodeForObjectCreation;

/** @brief Return whether obejcts of this class can be grouped

 Default is <code>YES</code>. See also <code>-[DKShapeGroup objectsAvailableForGroupingFromArray]</code>.
 @return \c YES if objects can be included in groups.
 */
@property (class, readonly, getter=isGroupable) BOOL groupable;

/** @name Ghosting Settings.
 @{ */

/** @brief The outline colour used when drawing objects in their ghosted state.

 The ghost colour is persistent, stored using the \c kDKGhostColourPreferencesKey key.
 The default is light gray.
 */
@property (class, retain, null_resettable) NSColor* ghostColour;

/** @}
 @name Pasteboard Types
 @brief Pasteboard types for drag/drop.
 @{ */

/** @brief Return pasteboard types that this object class can receive.

 Default method does nothing - subclasses will override if they can receive a drag
 @param op Set of flags indicating what this operation the types relate to. Currently objects can only
 receive drags so this is the only flag that should be passed.
 @return An array of pasteboard types.
 */
+ (nullable NSArray<NSPasteboardType>*)pasteboardTypesForOperation:(DKPasteboardOperationType)op;
/** @brief Unarchive a list of objects from the pasteboard, if possible.

 This factors the dearchiving of objects from the pasteboard. If the pasteboard does not contain
 any valid types, \c nil is returned.
 @param pb The pasteboard to take objects from.
 @return A list of objects.
 */
+ (nullable NSArray<DKDrawableObject*>*)nativeObjectsFromPasteboard:(NSPasteboard*)pb;

/** @brief Return the number of native objects held by the pasteboard.

 This efficiently queries the info object rather than dearchiving the objects themselves. A value
 of \c 0 means no native objects on the pasteboard (naturally).
 @param pb The pasteboard to read from.
 @return A count.
 */
+ (NSUInteger)countOfNativeObjectsOnPasteboard:(NSPasteboard*)pb;

/** @}
 @name Interconversion Table
 @brief Interconversion table used when changing one drawable into another - can be customised.
 @{ */

/** @brief The interconversion table.

 The interconversion table is used when drawables are converted to another type. The table can be
 customised to permit conversions to subclasses of the requested class. The default is <code>nil</code>,
 which simply passes through the requested type unchanged. The dictionary consists of the base class
 as a string, and returns the class to use in place of that type.
 */
@property (class, copy, nullable) NSDictionary<NSString*, Class>* interconversionTable;

/** @brief Return the class to use in place of the given class when performing a conversion.

 The default passes through the input class unchanged. By customising the conversion table, other
 classes can be substituted when performing a conversion.
 @param aClass The base class which we are converting TO.
 @return The actual object class to use for that conversion.
 */
+ (Class)classForConversionRequestFor:(Class)aClass;

/** @brief Sets the class to use in place of the a base class when performing a conversion.

 This is only used when performing conversions, not when creating new objects in other circumstances.
 \c newClass must be a subclass of <code>baseClass</code>.
 @param newClass The class which we are converting TO.
 @param baseClass The base class.
 */
+ (void)substituteClass:(Class)newClass forClass:(Class)baseClass;

/** @}
 @name Initializers
 @{ */

/** @brief Initializes the drawable to have the style given

 You can use \c -init to initialize using the default style. Note that if creating many objects at
 once, supplying the style when initializing is more efficient.
 @param aStyle the initial style for the object
 @return the object
 */
- (instancetype)initWithStyle:(nullable DKStyle*)aStyle NS_DESIGNATED_INITIALIZER;

- (instancetype)init;

/** @}
 @name Relationships
 @{ */

/** @brief Returns the layer that this object ultimately belongs to

 This returns the layer even if container isn't the layer, by recursing up the tree as needed
 @return the containing layer
 */
@property (readonly, strong) DKObjectOwnerLayer* layer;
/** @brief Returns the drawing that owns this object's layer
 @return the drawing
 */
@property (readonly, strong) DKDrawing* drawing;
/** @brief Returns the undo manager used to handle undoable actions for this object
 @return the undo manager in use
 */
@property (readonly, strong, nullable) NSUndoManager* undoManager;

/** @brief The immediate parent of this object.

 A parent is usually a layer, same as owner - but can be a group if the object is grouped.
 
 The container itself is responsible for setting this - applications should not set this. An
 object's container is usually the layer, but can be a group. \c container is not retained. Note that
 a valid container is required for the object to locate an undo manager, so nothing is undoable
 until this is set to a valid object that can supply one.
 */
@property (nonatomic, weak, nullable) id<DKDrawableContainer> container;

/** @brief Returns the index position of this object in its container layer

 This is intended for debugging and should generally be avoided by user code.
 @return the index position
 */
@property (readonly) NSUInteger indexInContainer;

/** @}
 @name State
 @{ */

/** @brief Is the object visible?

 The visible property is independent of the locked property, i.e. locked objects may be hidden & shown.
*/
@property (nonatomic) BOOL visible;

/** @brief Is the object locked?

 Locked objects are visible but can't be edited.
*/
@property (nonatomic) BOOL locked;

/** @brief Whether the object's location is locked or not.

 Location may be locked independently of the general lock.
 */
@property (nonatomic) BOOL locationLocked;

/** @brief Is mouse snapping enabled?
 */
@property BOOL mouseSnappingEnabled;

/** @brief Whether the object is ghosted rather than with its full style.

 Ghosting is an alternative to hiding - ghosted objects are still visible but are only drawn using
 a thin outline. See also: \c +setGhostingColour:
*/
@property (nonatomic, getter=isGhosted) BOOL ghosted;

/** @}
 @name Internal State Accessors
 @{ */

@property (getter=isTrackingMouse) BOOL trackingMouse;
@property NSSize mouseDragOffset;
@property BOOL mouseHasMovedSinceStartOfTracking;

/** @}
 @name Selection State
 @{ */

/** @brief Returns whether the object is selected.

 Assumes that the owning layer is an object drawing layer (which is a reasonable assumption!).
*/
@property (readonly, getter=isSelected) BOOL selected;

/** @brief Get notified when the object is selected

 Subclasses can override to take action when they become selected (drawing the selection isn't
 part of this - the layer will do that). Overrides should generally invoke super.
 */
- (void)objectDidBecomeSelected NS_REQUIRES_SUPER;

/** @brief Get notified when an object is deselected
 
 Subclasses can override to take action when they are deselected
 */
- (void)objectIsNoLongerSelected;

/** @brief Is the object able to be selected?

 Subclasses can override to disallow selection. By default all objects are selectable, but for some
 specialised use this might be useful.
 @return \c YES if selectable, \c NO if not.
 */
@property (readonly) BOOL objectMayBecomeSelected;

/** @brief Is the object currently a pending object?

 Esoteric. An object is pending while it is being created and not otherwise. There are few reasons
 to need to know, but one might be to implement a special selection highlight for this case.
 @return \c YES if pending, \c NO if not.
 */
@property (readonly, getter=isPendingObject) BOOL pendingObject;

/** @brief Is the object currently the layer's key object?

 \c DKObjectDrawingLayer maintains a 'key object' for the purposes of alignment operations. The drawable
 could use this information to draw itself in a particular way for example. Note that DK doesn't
 use this information except for object alignment operations.
 @return \c YES if key, \c NO if not.
 */
@property (readonly, getter=isKeyObject) BOOL keyObject;

/** @brief Return the subselection of the object

 DK objects do not have subselections without subclassing, but this method provides a common method
 for subselections to be passed back to a UI, etc. If there is no subselection, this should return
 either the empty set, \c nil or a set containing self.
 Subclasses will override and return whatever is appropriate. They are also responsible for the complete
 implementation of the selection including hit-testing and highlighting. In addition, the notification
 \c kDKDrawableSubselectionChangedNotification should be sent when this changes.
 @return a set containing the selection within the object. May be empty, nil or contain self.
 */
@property (readonly, copy) NSSet<DKDrawableObject*>* subSelection;

/** @}
 @name Add/Remove Layer Notification
 @brief Notification about being added and removed from a layer.
 @{ */

/** @brief The object was added to a layer

 Purely for information, should an object need to know. Override to make use of this. Subclasses
 should call super.
 @param aLayer the layer this was added to
 */
- (void)objectWasAddedToLayer:(DKObjectOwnerLayer*)aLayer;

/** @brief The object was removed from the layer

 Purely for information, should an object need to know. Override to make use of this. Subclasses
 should call super to maintain notifications.
 @param aLayer the layer this was removed from
 */
- (void)objectWasRemovedFromLayer:(DKObjectOwnerLayer*)aLayer;

/** @}
 @name Primary Drawing Method
 @{ */

/** @brief Draw the object and its selection on demand

 The caller will have determined that the object needs drawing, so this will only be called when
 necessary. The default method does nothing - subclasses must override this.
 @param selected \c YES if the object is to draw itself in the selected state, \c NO otherwise
 */
- (void)drawContentWithSelectedState:(BOOL)selected;

/** @}
 @name Drawing Factors
 @{ */

/** @brief Draw the content of the object

 This just hands off to the style rendering by default, but subclasses may override it to do more.
 */
- (void)drawContent;

/** @brief Draw the content of the object but using a specific style, which might not be the one attached
 @param aStyle a valid style object, or nil to use the object's current style
 */
- (void)drawContentWithStyle:(DKStyle*)aStyle;

/** @brief Draw the ghosted content of the object
 
 The default simply strokes the rendering path at minimum width using the ghosting colour. Can be
 overridden for more complex appearances. Note that ghosting should deliberately keep the object
 unobtrusive and simple.
 */
- (void)drawGhostedContent;

/** @brief Draw the selection highlight for the object
 
 The owning layer may call this independently of drawContent~ in some circumstances, so
 subclasses need to be ready to factor this code as required.
 */
- (void)drawSelectedState;

/** @brief Stroke the given path using the selection highlight colour for the owning layer
 
 This is a convenient utility method your subclasses can use as needed to make selections consistent
 among different objects and layers. A side effect is that the line width of the path may be changed.
 @param path the selection highlight path
 */
- (void)drawSelectionPath:(NSBezierPath*)path;

/** @}
 @name Refresh Notifiers
 @{ */

/** @brief Request a redraw of this object

 Marks the object's bounds as needing updating. Most operations on an object that affect its
 appearance to the user should call this before and after the operation is performed.
 Subclasses that override this for optimisation purposes should make sure that the layer is
 updated through the drawable:needsDisplayInRect: method and that the notification is sent, otherwise
 there may be problems when layer contents are cached.
 */
- (void)notifyVisualChange;
/** @brief Notify the drawing and its controllers that a non-visual status change occurred

 The drawing passes this back to any controllers it has
 */
- (void)notifyStatusChange;
/** @brief Notify that the geomnetry of the object has changed

 Subclasses can override this to make use of the change notification. This is intended to signal
 purely geometric changes which for some objects could be used to invalidate cached information
 that more general changes might not need to invalidate. This also informs the storage about the
 bounds change so that if the storage uses bounds information to optimise storage, it can do
 whatever it needs to to keep the storage correctly organised.
 @param oldBounds the bounds of the object *before* it got changed by whatever is calling this
 */
- (void)notifyGeometryChange:(NSRect)oldBounds;
/** @brief Sets the ruler markers for all of the drawing's views to the logical bounds of this

 This is largely automatic, but if there is an operation that shoul dupdate the markers, you can
 call this to perform it. Also, if a subclass has some special way to set the markers, it may
 override this.
 */
- (void)updateRulerMarkers;

/** @brief Mark some part of the drawing as needing update

 Usually an object should mark only areas within its bounds using this, to be polite.
 @param rect this area requires an update
 */
- (void)setNeedsDisplayInRect:(NSRect)rect;
/** @brief Mark multiple parts of the drawing as needing update

 The layer call with NSZeroRect is to ensure the layer's caches work
 @param setOfRects a set of NSRect/NSValues to be updated.
 */
- (void)setNeedsDisplayInRects:(NSSet<NSValue*>*)setOfRects;
/** @brief Mark multiple parts of the drawing as needing update

 The layer call with \c NSZeroRect is to ensure the layer's caches work
 @param setOfRects a set of NSRect/NSValues to be updated.
 @param padding some additional margin added to each rect before marking as needing update
 */
- (void)setNeedsDisplayInRects:(NSSet<NSValue*>*)setOfRects withExtraPadding:(NSSize)padding;

- (nullable NSBezierPath*)renderingPath;
@property (readonly) BOOL useLowQualityDrawing;

/** @brief Return a number that changes when any aspect of the geometry changes. This can be used to detect
 that a change has taken place since an earlier time.

 Do not rely on what the number is, only whether it has changed. Also, do not persist it in any way.
 @return a number
 */
@property (readonly) NSUInteger geometryChecksum;

/** @}
 @name Specialised Drawing
 @{ */

/** @brief Renders the object or part of it into the current context, applying scaling and/or a temporary style.

 Useful for rendering the object into any context at any size. The object is scaled by the ratio
 of srcRect to destRect. \c destRect can't be zero-sized.
 @param destRect the destination rect in the current context
 @param srcRect the srcRect in the same coordinate space as the current bounds, or NSZeroRect to mean the
 @param aStyle currently unused - draws in the object's attached style
 */
- (void)drawContentInRect:(NSRect)destRect fromRect:(NSRect)srcRect withStyle:(nullable DKStyle*)aStyle;

/** @brief Returns the single object rendered as a PDF image

 This allows the object to be extracted as a single PDF in isolation. It works by creating a
 temporary view that draws just this object.
 @return PDF data of the object
 */
- (NSData*)pdf;

/** @}
 @name Style
 @{ */

/** @brief The attached style.
 
 It's important to call the inherited method if you override this, as objects generally need to
 subscribe to a style's notifications, and a style needs to know when it is attached to objects.
 */
@property (nonatomic, copy, nullable) DKStyle* style;

/** @brief Called when the attached style is about to change.
 */
- (void)styleWillChange:(NSNotification*)note;

/** @brief Called just after the attached style has changed.
 */
- (void)styleDidChange:(NSNotification*)note;

/** @brief Return all styles used by this object.
 
 This is part of an informal protocol used for, among other possible uses, remerging styles after
 a document load. Objects higher up the chain form the union of all such sets, which is why this
 is returned as a set, even though it contains just one style. Subclasses might also use more than
 one style.
 @return A set, containing the object's style.
 */
@property (readonly, copy, nullable) NSSet<DKStyle*>* allStyles;

/** @brief Return all registered styles used by this object
 
 This is part of an informal protocol used for remerging styles after
 a document load. Objects higher up the chain form the union of all such sets, which is why this
 is returned as a set, even though it contains just one style. Subclasses might also use more than
 one style. After a fresh load from an archive, this returns the style if the remerge flag is set,
 but at all other times it returns the style if registered. The remerge flag is cleared by this
 method, thus you need to make sure to call it just once after a reload if it's the remerge flagged
 styles you want (in general this usage is automatic and is handled at a much higher level - see
 <code>DKDrawingDocument</code>).
 @return A set, containing the object's style if it is registerd or flagged for remerge.
 */
@property (readonly, copy, nullable) NSSet<DKStyle*>* allRegisteredStyles;

/** @brief Replace the object's style from any in th egiven set that have the same ID.
 
 This is part of an informal protocol used for remerging registered styles after
 a document load. If \c aSet contains a style having the same ID as this object's current style,
 the style is updated with the one from the set.
 @param aSet A set of style objects.
 */
- (void)replaceMatchingStylesFromSet:(NSSet<DKStyle*>*)aSet;

/** @brief If the object's style is currently sharable, copy it and make it non-sharable.

 If the style is already non-sharable, this does nothing. The purpose of this is to detach this
 from it style such that it has its own private copy. It does not change appearance.
 */
- (void)detachStyle;

/** @}
 @name Geometry
 @{ */

/** @name Size
 @brief Size (invariant with angle).
 @{ */

/** @brief The object's size.
 
 Subclasses should override to get/set the object's size.
 */
@property (nonatomic) NSSize size;

/** @brief Resizes the object by scaling its width and height by the given factors.
 
 Factors of \c 1.0 have no effect; factors must be postive and > 0.
 @param xFactor The width scale.
 @param yFactor The height scale.
 */
- (void)resizeWidthBy:(CGFloat)xFactor heightBy:(CGFloat)yFactor NS_SWIFT_NAME(resizeBy(width:height:));

/** @}
 @name Location
 @brief Location within the drawing.
 @{ */

/** @brief Location within the drawing.
 
 The object can decide how it aligns itself about its own location in any way that is self-consistent.
 the default is to align the origin of the bounds at the point, but most subclasses do something
 more sophisticated.
 */
@property (nonatomic) NSPoint location;

/** @brief Offsets the object's position by the values passed.
 @param dx Add this much to the x coordinate.
 @param dy Add this much to the y coordinate.
 */
- (void)offsetLocationByX:(CGFloat)dx byY:(CGFloat)dy NS_SWIFT_NAME(offsetLocationBy(x:y:));

/** @}
 @name Angle
 @brief Angle of object with respect to its container.
 @{ */

/** @brief The object's angle (radians).

 Override if your subclass implements variable angles.
 */
@property (nonatomic) CGFloat angle;

/** @brief Return the shape's current rotation angle.

 This method is primarily to supply the angle for display to the user, rather than for doing angular
 calculations with. It converts negative values -180 to 0 to +180 to 360 degrees.
 @return The shape's angle in degrees.
 */
@property (readonly) CGFloat angleInDegrees;

/** @brief Rotate the shape by adding a delta angle to the current angle.

 \c da is a value in radians.
 @param da Add this much to the current angle.
 */
- (void)rotateByAngle:(CGFloat)da;

/** @}
 @name Locus Offset
 @brief Relative offset of locus within the object.
 @{ */

/** @brief The relative offset of the object's anchor point.

 Subclasses must override if they support this concept.
 Is a width and height value relative to the object's bounds.
 */
@property (nonatomic) NSSize offset;

/** @brief Reset the relative offset of the object's anchor point to its original value.

 Subclasses must override if they support this concept.
 */
- (void)resetOffset;

/** @}
 @name Path Transforms
 @{ */

/** @brief Return a transform that maps the object's stored path to its true location in the drawing.

 Override for real transforms - the default merely returns the identity matrix
 @return A transform. */
@property (readonly, copy) NSAffineTransform* transform;

/** @brief Return the container's transform.

 The container transform must be taken into account for rendering this object, as it accounts for
 groups and other possible containers.
 @return A transform. */
@property (readonly, copy) NSAffineTransform* containerTransform;

/** @brief Apply the transform to the object

 The object's position, size and path are modified by the transform. This is called by the owning
 layer's applyTransformToObjects method. This ignores locked objects.
 @param transform a transform
 */
- (void)applyTransform:(NSAffineTransform*)transform;

/** @}
 @name Bounding Rects
 @{ */

/** @brief Return the full extent of the object within the drawing, including any decoration, etc.

 The object must draw only within its declared bounds. If it draws outside of this, it will leave
 trails and debris when moved, rotated or scaled. All style-based decoration must be contained within
 bounds. The style has the method \c -extraSpaceNeeded to help you determine the correct bounds.
 subclasses must override this and return a valid, sensible bounds rect
 @return the full bounds of the object
 */
@property (readonly) NSRect bounds;

/** @brief Returns the visually apparent bounds

 This bounds is intended for use when aligning objects to each other or to guides, etc. By default
 it is the same as the bounds, but subclasses may redefine it to be something else.
 @return the apparent bounds rect
 */
@property (readonly) NSRect apparentBounds;

/** @brief Returns the logical bounds

 The logical bounds is the object's bounds ignoring any stylistic effects. Unlike the other bounds,
 it remains constant for a given paht even if styles change. By default it is the same as the bounds,
 but subclasses will probably wish to redefine it.
 @return the logical bounds
 */
@property (readonly) NSRect logicalBounds;

/** @brief Returns the extra space needed to display the object graphically. This will usually be the difference
 between the logical and reported bounds.
 @return the extra space required
 */
@property (readonly) NSSize extraSpaceNeeded;

/** @}
 @}
 @name Creation Tool Protocol
 @{ */

/** @brief Called by the creation tool when this object has just beeen created by the tool.

 FYI - override to make use of this
 @param tool The tool that created this.
 @param p The initial point that the tool will start dragging the object from. */
- (void)creationTool:(DKDrawingTool*)tool willBeginCreationAtPoint:(NSPoint)p;

/** @brief Called by the creation tool when this object has finished being created by the tool.

 FYI - override to make use of this
 @param tool The tool that created this.
 @param p The point that the tool finished dragging the object to. */
- (void)creationTool:(DKDrawingTool*)tool willEndCreationAtPoint:(NSPoint)p;

/** @brief Return whether the object is valid in terms of having a visible, usable state.

 Subclasses must override and implement this appropriately. It is called by the object creation tool
 at the end of a creation operation to determine if what was created is in any way useful. Objects that
 cannot be used will not be added to the drawing. The object type needs to decide what constitutes
 validity - for example shapes with zero size or paths with zero length are likely not valid.
 @return \c YES if valid, \c NO otherwise.
 */
@property (readonly) BOOL objectIsValid;

/** @}
 @name Grouping/Ungrouping Protocol
 @{ */

/** @brief This object is being added to a group.

 Can be overridden if this event is of interest. Note that for grouping, the object doesn't need
 to do anything special - the group takes care of it.
 @param aGroup The group adding the object.
 */
- (void)groupWillAddObject:(DKShapeGroup*)aGroup;

/** @brief This object is being ungrouped from a group.

 When ungrouping, an object must help the group to the right thing by resizing, rotating and repositioning
 itself appropriately. At the time this is called, the object has already has its container set to
 the layer it will be added to but has not actually been added. Must be overridden.
 @param aGroup The group containing the object.
 @param aTransform The transform that the group is applying to the object to scale rotate and translate it.
 */
- (void)group:(DKShapeGroup*)aGroup willUngroupObjectWithTransform:(NSAffineTransform*)aTransform;

/** @brief This object was ungrouped from a group.

 This is called when the ungrouping operation has finished entirely. The object will belong to its
 original container and have its location, etc set as required. Override to make use of this notification.
 */
- (void)objectWasUngrouped;

/** @}
 @name Substitution
 @brief Post-processing when being substituted for another object (boolean ops, etc).
 @{ */

/** @brief Some high-level operations substitute a new object in place of an existing one (or several). In
 those cases this should be called to allow the object to do any special substitution work.

 Subclasses should override this to do additional work during a substitution. Note that user info
 and style is handled for you, this does not need to deal with those properties.
 @param obj The original object his is being substituted for.
 @param aLayer The layer this will be added to (but is not yet).
 */
- (void)willBeAddedAsSubstituteFor:(DKDrawableObject*)obj toLayer:(DKObjectOwnerLayer*)aLayer;

/** @}
 @name Snapping
 @brief Snapping to guides, grid and other objects (utility methods).
 @{ */

/** @brief Offset the point to cause snap to grid + guides accoding to the drawing's settings.

 DKObjectOwnerLayer + DKDrawing implements the details of this method. The \c snapControl flag is
 intended to come from a modifier flag - usually <b>ctrl</b>.
 @param mp A point which is the proposed location of the shape.
 @return A new point which may be offset from the input enough to snap it to the guides and grid. */
- (NSPoint)snappedMousePoint:(NSPoint)mp withControlFlag:(BOOL)snapControl;

/** @brief Offset the point to cause snap to grid + guides according to the drawing's settings.

 Given a proposed location, this modifies it by checking if any of the points returned by the
 object's snappingPoints method will snap. The result can be passed to \c moveToPoint:
 @param mp A point which is the proposed location of the shape
 @return A new point which may be offset from the input enough to snap it to the guides and grid.
 */
- (NSPoint)snappedMousePoint:(NSPoint)mp forSnappingPointsWithControlFlag:(BOOL)snapControl;

// NSPoints
/** @brief Return an array of \c NSPoint values representing points that can be snapped to guides.
 */
@property (readonly, copy) NSArray<NSValue*>* snappingPoints;

/** @brief Return an array of \c NSPoint values representing points that can be snapped to guides.

 Snapping points are locations within an object that will snap to a guide. List can be empty.
 @param offset An offset value that is added to each point.
 @return A list of points (NSValues).
 */
- (NSArray<NSValue*>*)snappingPointsWithOffset:(NSSize)offset;

/** @brief Returns the offset between the mouse point and the shape's location during a drag.

 Result is undefined except during a dragging operation.
 */
@property (readonly) NSSize mouseOffset;

/** @}
 @name Drawing Coordinates
 @brief Getting dimensions in drawing coordinates.
 @{ */

/** @brief Convert a distance in quartz coordinates to the units established by the drawing grid.

 This is a conveniece API to query the drawing's grid layer.
 @param len A distance in pixels.
 @return The distance in drawing units.
 */
- (CGFloat)convertLength:(CGFloat)len;

/** @brief Convert a point in quartz coordinates to the units established by the drawing grid.

 This is a conveniece API to query the drawing's grid layer.
 @param pt A point value.
 @return The equivalent point in drawing units.
 */
- (NSPoint)convertPointToDrawing:(NSPoint)pt;

/** @}
 @name Hit Testing
 @{ */

/** @brief Test whether the object intersects a given rectangle.

 Used for selecting using a marquee, and other things. The default hit tests by rendering the object
 into a special 1-byte bitmap and testing its alpha channel - this is fast and efficient and in most
 simple cases doesn't need to be overridden.
 @param rect The rect to test against.
 @return \c YES if the object intersects the rect, \c NO otherwise.
 */
- (BOOL)intersectsRect:(NSRect)rect;

/** @brief Hit test the object.

 Part codes are private to the object class, except for \c 0 = nothing hit and \c -1 = entire object hit.
 for other parts, the object is free to return any code it likes and attach any meaning it wishes.
 the part code is passed back by the mouse event methods but apart from \c 0 and \c -1 is never interpreted
 by any other object.
 @param pt The mouse location.
 @return A part code representing which part of the object got hit, if any.
 */
- (NSInteger)hitPart:(NSPoint)pt;

/** @brief Hit test the object in the selected state.

 This is a factoring of the general \c hitPart: method to allow parts that only come into play when
 selected to be hit tested. It is also used when snapping to objects. Subclasses should override
 for the partcodes they define such as control knobs that operate when selected.
 @param pt The mouse location.
 @param snap Is \c YES if called to detect snap, \c NO otherwise.
 @return A part code representing which part of the selected object got hit, if any. */
- (NSInteger)hitSelectedPart:(NSPoint)pt forSnapDetection:(BOOL)snap;

/** @brief Return the point associated with the part code.

 If partcode is no object, returns {-1,-1}, if entire object, return location. Object classes
 should override this to correctly implement it for partcodes they define
 @param pc A valid partcode for this object.
 @return The current point associated with the partcode.
 */
- (NSPoint)pointForPartcode:(NSInteger)pc;

/** @brief Provide a mapping between the object's partcode and a knob type draw for that part.

 Knob types are defined by DKKnob, they describe the functional type of the knob, plus the locked
 state. Concrete subclasses should override this unless the default suffices.
 @param pc A valid partcode for this object.
 @return A valid knob type.
 */
- (DKKnobType)knobTypeForPartCode:(NSInteger)pc;

/** @brief Test if a rect encloses any of the shape's actual pixels.

 Note this can be an expensive way to test this - eliminate all obvious trivial cases first.
 @param r The rect to test.
 @return \c YES if at least one pixel enclosed by the rect, \c NO otherwise.
 */
- (BOOL)rectHitsPath:(NSRect)r;

/** @brief Test a point against the offscreen bitmap representation of the shape

 Special case of the \crectHitsPath call, which is now the fastest way to perform this test.
 @param p The point to test.
 @return \c YES if the point hit the shape's pixels, \c NO otherwise.
 */
- (BOOL)pointHitsPath:(NSPoint)p;

/** @brief Is a hit-test in progress?

 Drawing methods can check this to see if they can take shortcuts to save time when hit-testing.
 This will only return \c YES during calls to \c -drawContent etc. when invoked by the \c rectHitsPath method.

 Applicaitons should not generally set this. It allows certain container classes (e.g. groups) to
 flag that \a they are being hit tested to provide easier hitting of thin objects in groups.
 */
@property (nonatomic, getter=isBeingHitTested) BOOL beingHitTested;

/** @}
 @name Mouse Events
 @{ */

/** @brief The mouse went down in this object.

 Default method records the mouse offset, but otherwise you will override to make use of this.
 @param mp The mouse point (already converted to the relevant view - gives drawing relative coordinates).
 @param partcode The partcode that was returned by hitPart if non-zero.
 @param evt The original event.
 */
- (void)mouseDownAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt;

/** @brief The mouse is dragging within this object.

 Default method moves the entire object, and snaps to grid and guides if enabled. Control key disables
 snapping temporarily.
 @param mp The mouse point (already converted to the relevant view - gives drawing relative coordinates).
 @param partcode The partcode that was returned by hitPart if non-zero.
 @param evt The original event.
 */
- (void)mouseDraggedAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt;

/** @brief The mouse went up in this object.
 @param mp The mouse point (already converted to the relevant view - gives drawing relative coordinates).
 @param partcode The partcode that was returned by hitPart if non-zero.
 @param evt The original event.
 */
- (void)mouseUpAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt;

/** @brief Get the view currently drawing or passing events to this.

 The view is only meaningful when called from within a drawing or event handling method.
 */
- (NSView*)currentView;

/** @brief Return the cursor displayed when a given partcode is hit or entered.

 The cursor may be displayed when the mouse hovers over or is clicked in the area indicated by the
 partcode. The default is simply to return the standard arrow - override for others.
 @param partcode The partcode.
 @param button \c YES if the mouse left button is pressed, \c NO otherwise.
 @return A cursor object.
 */
- (NSCursor*)cursorForPartcode:(NSInteger)partcode mouseButtonDown:(BOOL)button;

/** @brief Inform the object that it was double-clicked.

 This is invoked by the select tool and any others that decide to implement it. The object can
 respond however it likes - by default it simply broadcasts a notification. Override for
 different behaviours.
 @param mp The point where it was clicked.
 @param partcode The partcode.
 @param evt The original mouse event.
 */
- (void)mouseDoubleClickedAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt;

/** @}
 @name Contextual Menu
 @{ */

/** @brief Reurn the menu to use as the object's contextual menu.

 The menu is obtained via <code>DKAuxiliaryMenu</code>'s helper object which in turn loads the menu from a nib,
 overridable by the app. This is the preferred method of supplying the menu. It doesn't need to
 be overridden by subclasses generally speaking, since all menu customisation per class is done in
 the nib.
 @return The menu.
 */
- (NSMenu*)menu;

/** @brief Allows the object to populate the menu with commands that are relevant to its current state and type.

 The default method adds commands to copy and paste the style.
 @param theMenu A menu - add items and commands to it as required.
 @return \c YES if any items were added, \c NO otherwise.
 */
- (BOOL)populateContextualMenu:(NSMenu*)theMenu;

/** @brief Allows the object to populate the menu with commands that are relevant to its current state and type.

 The default method adds commands to copy and paste the style. This method allows the point to
 be used by subclasses to refine the menu for special areas within the object.
 @param theMenu A menu - add items and commands to it as required.
 @param localPoint The point in local (view) coordinates where the menu click went down.
 @return \c YES if any items were added, \c NO otherwise.
 */
- (BOOL)populateContextualMenu:(NSMenu*)theMenu atPoint:(NSPoint)localPoint;

/** @}
 @name Swatches
 @brief Swatch image of this object.
 @{ */

/** @brief Returns an image of this object rendered using its current style and path.

 If \c size is <code>NSZeroRect</code>, uses the current bounds size.
 @param size Desired size of the image - shape is scaled to fit in this size.
 @return The image.
 */
- (nullable NSImage*)swatchImageWithSize:(NSSize)size;

/** @}
 @name User Info
 @{ */

/** @brief Attach a dictionary of metadata to the object

 The dictionary replaces the current user info. To merge with any existing user info, use \c addUserInfo:
 @param info A dictionary containing anything you wish.
 */
- (void)setUserInfo:(NSDictionary<NSString*, id>*)info NS_REFINED_FOR_SWIFT;

/** @brief Add a dictionary of metadata to the object.
 
 \c info is merged with the existing content of the user info.
 @param info A dictionary containing anything you wish.
 */
- (void)addUserInfo:(NSDictionary<NSString*, id>*)info;

/** @brief Return the attached user info.

 The user info is returned as a mutable dictionary (which it is), and can thus have its contents
 mutated directly for certain uses. Doing this cannot cause any notification of the status of
 the object however.
 @return The user info.
 */
- (NSMutableDictionary<NSString*, id>*)userInfo NS_REFINED_FOR_SWIFT;

/** @brief Return an item of user info.
 @param key The key to use to refer to the item.
 @return The user info item.
 */
- (nullable id)userInfoObjectForKey:(NSString*)key;

/** @brief Set an item of user info.
 @param obj The object to store.
 @param key The key to use to refer to the item.
 */
- (void)setUserInfoObject:(id)obj forKey:(NSString*)key;

/** @}
 @name Cache Management
 @{ */

/** @brief Discard all cached rendering information

 The rendering cache is simply emptied. The contents of the cache are generally set by individual
 renderers to speed up drawing, and are not known to this object. The cache is invalidated by any
 change that alters the object's appearance - size, position, angle, style, etc.
 */
- (void)invalidateRenderingCache;

/** @brief Returns an image of the object representing its current appearance at 100% scale.

 This image is stored in the rendering cache. If the cache is empty the image is recreated. This
 image can be used to speed up hit testing.
 @return an image of the object
 */
@property (readonly, strong) NSImage* cachedImage;

/** @}
 @name Pasteboard
 @{ */

/** @brief Write additional data to the pasteboard specific to the object.

 The owning layer generally handles the case of writing the selected objects to the pasteboard but
 sometimes an object might wish to supplement that data. For example a text-bearing object might
 add the text to the pasteboard. This is only invoked when the object is the only object selected.
 The default method does nothing - override to make use of this. Also, your override must declare
 the types it's writing using addTypes:owner:
 @param pb the pasteboard to write to
 */
- (void)writeSupplementaryDataToPasteboard:(NSPasteboard*)pb;

/** @brief Read additional data from the pasteboard specific to the object.

 This is invoked by the owning layer after an object has been pasted. Override to make use of. Note
 that this is not necessarily symmetrical with \c -writeSupplementaryDataToPasteboard: depending on
 what data types the other method actually wrote. For example standard text would not normally
 need to be handled as a special case.
 @param pb The pasteboard to read from.
 */
- (void)readSupplementaryDataFromPasteboard:(NSPasteboard*)pb;

/** @}
 @name User Commands.
 @brief User level commands that can be responded to by this object (and its subclasses).
 @{ */

/** @brief Copies the object's style to the general pasteboard.
 @param sender The action's sender.
 */
- (IBAction)copyDrawingStyle:(nullable id)sender;

/** @brief Pastes a style from the general pasteboard onto the object.

 Attempts to maintain shared styles by using the style's name initially.
 @param sender The action's sender.
 */
- (IBAction)pasteDrawingStyle:(nullable id)sender;
- (IBAction)lock:(nullable id)sender;
- (IBAction)unlock:(nullable id)sender;
- (IBAction)lockLocation:(nullable id)sender;
- (IBAction)unlockLocation:(nullable id)sender;

/** @} */

#ifdef qIncludeGraphicDebugging

/** @name Debugging
 @{ */
- (IBAction)toggleShowBBox:(nullable id)sender;
- (IBAction)toggleClipToBBox:(nullable id)sender;
- (IBAction)toggleShowPartcodes:(nullable id)sender;
- (IBAction)toggleShowTargets:(nullable id)sender;
- (IBAction)logDescription:(nullable id)sender;
/** @} */
#endif

@end

/** @name Public Partcodes
 @brief Partcodes that are known to the layer - most are private to the drawable object class, but these are public.
 @{ */
enum {
	kDKDrawingNoPart = 0,
	kDKDrawingEntireObjectPart = -1
};
/** @} */

enum {
	/** Used to identify a possible "Convert To" submenu in an object's contextual menu. */
	kDKConvertToSubmenuTag = -55
};

/** @name Constant Strings
 @{ */

/** @brief \c DKDrawableObject pasteboard type.
 */
extern NSPasteboardType const kDKDrawableObjectPasteboardType NS_SWIFT_NAME(dkDrawableObject);
extern NSNotificationName const kDKDrawableDidChangeNotification;
extern NSNotificationName const kDKDrawableStyleWillBeDetachedNotification;
extern NSNotificationName const kDKDrawableStyleWasAttachedNotification;
extern NSNotificationName const kDKDrawableDoubleClickNotification;
extern NSNotificationName const kDKDrawableSubselectionChangedNotification;

/** @name Notification User Keys
 @brief Keys for items in user info sent with notifications.
 @{ */

/** @brief Old style key.
 */
extern NSString* const kDKDrawableOldStyleKey;

/** @brief New style key.
 */
extern NSString* const kDKDrawableNewStyleKey;

/** @brief Clicked point key.
 */
extern NSString* const kDKDrawableClickedPointKey;

/** @}
 @name Pref Keys
 @{ */

/** @brief Ghost color preferences key.
 */
extern NSString* const kDKGhostColourPreferencesKey;

/** @brief Drag feedback enabled preferences key.
 */
extern NSString* const kDKDragFeedbackEnabledPreferencesKey;

/** @}
 @} */

NS_ASSUME_NONNULL_END
