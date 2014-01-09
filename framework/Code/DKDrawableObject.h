/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>
#import "DKCommonTypes.h"
#import "DKObjectStorageProtocol.h"
#import "DKRasterizerProtocol.h"
#import "DKDrawableContainerProtocol.h"

@class DKObjectOwnerLayer, DKStyle, DKDrawing, DKDrawingTool, DKShapeGroup;

/**
A drawable object is owned by a DKObjectDrawingLayer, which is responsible for drawing it when required and handling
 selections. This object is responsible for the visual representation of the selection as well as any content.
 
 It can draw whatever it likes within <bounds>, which it is responsible for calculating correctly.
 
 hitTest can return an integer to indicate which part was hit - a value of 0 means nothing hit. The returned value's meaning
 is otherwise private to the class, but is returned in the mouse event methods.
 
 This is intended to be a semi-abstract class - it draws nothing itself. Subclasses include DKDrawableShape and DKDrawablePath -
 often subclassing one of those will be more straightforward than subclassing this. A subclass must implement NSCoding and
 NSCopying to be archivable, etc. There are also numerous informal protocols for geometry, snapping, hit testing, drawing and ungrouping
 that need to be implemented correctly for a subclass to work fully correctly within DK.
 
 The user info is a dictionary attached to an object. It plays no part in the graphics system, but can be used by applications
 to attach arbitrary data to any drawable object.
*/
@interface DKDrawableObject : NSObject <DKStorableObject, DKRenderable, NSCoding, NSCopying>
{
@private
	id<DKDrawableContainer> mContainerRef;		// the immediate container of this object (layer, group or another drawable)
	DKStyle*			m_style;				// the drawing style attached
	id<DKObjectStorage>	mStorageRef;			// ref to the object's storage (DKStorableObject protocol)
	NSMutableDictionary* mUserInfo;				// user info including metadata is stored in this dictionary
	NSSize				m_mouseOffset;			// used to track where mouse was relative to bounds
	NSUInteger			mZIndex;				// used by the DKStorableObject protocol
	BOOL				m_visible;				// YES if visible
	BOOL				m_locked;				// YES if locked
	BOOL				mLocationLocked;		// YES if location is locked (independently of general lock)
	BOOL				m_snapEnable;			// YES if mouse actions snap to grid/guides
	BOOL				m_inMouseOp;			// YES while a mouse operation (drag) is in progress
	BOOL				m_mouseEverMoved;		// used to set up undo for mouse operations
	BOOL				mMarked;				// used by DKStorableObject protocol implementation
	BOOL				mGhosted;				// YES if object is drawn ghosted
	BOOL				mIsHitTesting;			// YES when drawContent is called for the purposes of hit-testing
	NSMutableDictionary*	mRenderingCache;	// a dictionary to support general caching by renderers
@protected
	BOOL				m_showBBox:1;			// debugging - display the object's bounding box
	BOOL				m_clipToBBox:1;			// debugging - force clip region to the bbox
	BOOL				m_showPartcodes:1;		// debugging - display the partcodes for each control/knob/handle
	BOOL				m_showTargets:1;		// debugging - show the bbox for each control/knob/handle
	BOOL				m_unused_padding:4;		// not used - reserved
}

/** @brief Return whether an info floater is displayed when resizing an object
 * @note
 * Size info is width and height
 * @return YES to show the info, NO to not show it
 */
+ (BOOL)				displaysSizeInfoWhenDragging;

/** @brief Set whether an info floater is displayed when resizing an object
 * @note
 * Size info is width and height
 * @param doesDisplay YES to show the info, NO to not show it
 */
+ (void)				setDisplaysSizeInfoWhenDragging:(BOOL) doesDisplay;

/** @brief Returns the union of the bounds of the objects in the array
 * @note
 * Utility method as this is a very common task - throws exception if any object in the list is
 * not a DKDrawableObject or subclass thereof
 * @param array a list of DKDrawable objects
 * @return a rect, the union of the bounds of all objects
 */
+ (NSRect)				unionOfBoundsOfDrawablesInArray:(NSArray*) array;
+ (NSInteger)			initialPartcodeForObjectCreation;

/** @brief Return whether obejcts of this class can be grouped
 * @note
 * Default is YES. see also [DKShapeGroup objectsAvailableForGroupingFromArray];
 * @return YES if objects can be included in groups
 * @public
 */
+ (BOOL)				isGroupable;

// ghosting settings:

/** @brief Set the outline colour to use when drawing objects in their ghosted state
 * @note
 * The ghost colour is persistent, stored using the kDKGhostColourPreferencesKey key
 * @param ghostColour the colour to use
 * @public
 */
+ (void)				setGhostColour:(NSColor*) ghostColour;

/** @brief Return the outline colour to use when drawing objects in their ghosted state
 * @note
 * The default is light gray
 * @return the colour to use
 * @public
 */
+ (NSColor*)			ghostColour;

// pasteboard types for drag/drop:

+ (NSArray*)			pasteboardTypesForOperation:(DKPasteboardOperationType) op;
+ (NSArray*)			nativeObjectsFromPasteboard:(NSPasteboard*) pb;

/** @brief Return the number of native objects held by the pasteboard
 * @note
 * This efficiently queries the info object rather than dearchiving the objects themselves. A value
 * of 0 means no native objects on the pasteboard (naturally)
 * @param pb the pasteboard to read from
 * @return a count
 * @public
 */
+ (NSUInteger)			countOfNativeObjectsOnPasteboard:(NSPasteboard*) pb;

// interconversion table used when changing one drawable into another - can be customised

/** @brief Return the interconversion table
 * @note
 * The interconversion table is used when drawables are converted to another type. The table can be
 * customised to permit conversions to subclasses or other types of object. The default is nil,
 * which simply passes through the requested type unchanged.
 * @return the table (a dictionary)
 * @public
 */
+ (NSDictionary*)		interconversionTable;

/** @brief Return the interconversion table
 * @note
 * The interconversion table is used when drawables are converted to another type. The table can be
 * customised to permit conversions to subclasses of the requested class. The default is nil,
 * which simply passes through the requested type unchanged. The dictionary consists of the base class
 * as a string, and returns the class to use in place of that type.
 * @param icTable a dictionary containing mappings from standard base classes to custom classes
 * @public
 */
+ (void)				setInterconversionTable:(NSDictionary*) icTable;

/** @brief Return the class to use in place of the given class when performing a conversion
 * @note
 * The default passes through the input class unchanged. By customising the conversion table, other
 * classes can be substituted when performing a conversion.
 * @param aClass the base class which we are converting TO.
 * @return the actual object class to use for that conversion.
 * @public
 */
+ (Class)				classForConversionRequestFor:(Class) aClass;

/** @brief Sets the class to use in place of the a base class when performing a conversion
 * @note
 * This is only used when performing conversions, not when creating new objects in other circumstances.
 * <newClass> must be a subclass of <baseClass>
 * @param newClass the class which we are converting TO
 * @param baseClass the base class
 * @public
 */
+ (void)				substituteClass:(Class) newClass forClass:(Class) baseClass;

// initializers:

/** @brief Initializes the drawable to have the style given
 * @note
 * You can use -init to initialize using the default style. Note that if creating many objects at
 * once, supplying the style when initializing is more efficient.
 * @param aStyle the initial style for the object
 * @return the object
 * @public
 */
- (id)					initWithStyle:(DKStyle*) aStyle;

// relationships:

/** @brief Returns the layer that this object ultimately belongs to
 * @note
 * This returns the layer even if container isn't the layer, by recursing up the tree as needed
 * @return the containing layer
 * @public
 */
- (DKObjectOwnerLayer*)	layer;
- (DKDrawing*)			drawing;
- (NSUndoManager*)		undoManager;

/** @brief Returns the immediate parent of this object
 * @note
 * A parent is usually a layer, same as owner - but can be a group if the object is grouped
 * @return the object's parent
 * @public
 */
- (id<DKDrawableContainer>)	container;
- (void)				setContainer:(id<DKDrawableContainer>) aContainer;

/** @brief Returns the index position of this object in its container layer
 * @note
 * This is intended for debugging and should generally be avoided by user code.
 * @return the index position
 * @public
 */

/** @brief Where object storage stores the Z-index in the object itself, this returns it.
 * @note
 * See DKObjectStorageProtocol.h
 * @return the Z value for the object
 * @public
 */
- (NSUInteger)			indexInContainer;

// state:

- (void)				setVisible:(BOOL) vis;
- (BOOL)				visible;
- (void)				setLocked:(BOOL) locked;
- (BOOL)				locked;

/** @brief Sets whether the object's location is locked or not
 * @note
 * Location may be locked independently of the general lock
 * @param lockLocation YES to lock location, NO to unlock
 * @public
 */
- (void)				setLocationLocked:(BOOL) lockLocation;

/** @brief Whether the object's location is locked or not
 * @note
 * Location may be locked independently of the general lock
 * @return YES if locked location, NO to unlock
 * @public
 */
- (BOOL)				locationLocked;
- (void)				setMouseSnappingEnabled:(BOOL) ems;
- (BOOL)				mouseSnappingEnabled;

/** @brief Set whether the object is ghosted rather than with its full style
 * @note
 * Ghosting is an alternative to hiding - ghosted objects are still visible but are only drawn using
 * a thin outline. See also: +setGhostingColour:
 * @param ghosted YES to ghost the object, NO to unghost it
 * @public
 */
- (void)				setGhosted:(BOOL) ghosted;

/** @brief Retuirn whether the object is ghosted rather than with its full style
 * @note
 * Ghosting is an alternative to hiding - ghosted objects are still visible but are only drawn using
 * a thin outline. See also: +setGhostingColour:
 * @return YES if the object is ghosted, NO otherwise
 * @public
 */
- (BOOL)				isGhosted;

// internal state accessors:

- (BOOL)				isTrackingMouse;
- (void)				setTrackingMouse:(BOOL) tracking;

- (NSSize)				mouseDragOffset;
- (void)				setMouseDragOffset:(NSSize) offset;

- (BOOL)				mouseHasMovedSinceStartOfTracking;
- (void)				setMouseHasMovedSinceStartOfTracking:(BOOL) moved;

// selection state:

- (BOOL)				isSelected;
- (void)				objectDidBecomeSelected;
- (void)				objectIsNoLongerSelected;

/** @brief Is the object able to be selected?
 * @note
 * Subclasses can override to disallow selection. By default all objects are selectable, but for some
 * specialised use this might be useful.
 * @return YES if selectable, NO if not
 * @public
 */
- (BOOL)				objectMayBecomeSelected;

/** @brief Is the object currently a pending object?
 * @note
 * Esoteric. An object is pending while it is being created and not otherwise. There are few reasons
 * to need to know, but one might be to implement a special selection highlight for this case.
 * @return YES if pending, NO if not
 * @public
 */
- (BOOL)				isPendingObject;

/** @brief Is the object currently the layer's key object?
 * @note
 * DKObjectDrawingLayer maintains a 'key object' for the purposes of alignment operations. The drawable
 * could use this information to draw itself in a particular way for example. Note that DK doesn't
 * use this information except for object alignment operations.
 * @return YES if key, NO if not
 * @public
 */
- (BOOL)				isKeyObject;

/** @brief Return the subselection of the object
 * @note
 * DK objects do not have subselections without subclassing, but this method provides a common method
 * for subselections to be passed back to a UI, etc. If there is no subselection, this should return
 * either the empty set, nil or a set containing self.
 * Subclasses will override and return whatever is appropriate. They are also responsible for the complete
 * implementation of the selection including hit-testing and highlighting. In addition, the notification
 * 'kDKDrawableSubselectionChangedNotification' should be sent when this changes.
 * @return a set containing the selection within the object. May be empty, nil or contain self.
 * @public
 */
- (NSSet*)				subSelection;

// notification about being added and removed from a layer

/** @brief The object was added to a layer
 * @note
 * Purely for information, should an object need to know. Override to make use of this. Subclasses
 * should call super.
 * @param aLayer the layer this was added to
 * @public
 */
- (void)				objectWasAddedToLayer:(DKObjectOwnerLayer*) aLayer;

/** @brief The object was removed from the layer
 * @note
 * Purely for information, should an object need to know. Override to make use of this. Subclasses
 * should call super to maintain notifications.
 * @param aLayer the layer this was removed from
 * @public
 */
- (void)				objectWasRemovedFromLayer:(DKObjectOwnerLayer*) aLayer;

// primary drawing method:

- (void)				drawContentWithSelectedState:(BOOL) selected;

// drawing factors:

- (void)				drawContent;
- (void)				drawContentWithStyle:(DKStyle*) aStyle;
- (void)				drawGhostedContent;
- (void)				drawSelectedState;
- (void)				drawSelectionPath:(NSBezierPath*) path;

// refresh notifiers:

- (void)				notifyVisualChange;
- (void)				notifyStatusChange;
- (void)				notifyGeometryChange:(NSRect) oldBounds;
- (void)				updateRulerMarkers;

- (void)				setNeedsDisplayInRect:(NSRect) rect;
- (void)				setNeedsDisplayInRects:(NSSet*) setOfRects;
- (void)				setNeedsDisplayInRects:(NSSet*) setOfRects withExtraPadding:(NSSize) padding;

- (NSBezierPath*)		renderingPath;
- (BOOL)				useLowQualityDrawing;

- (NSUInteger)			geometryChecksum;

// specialised drawing:

- (void)				drawContentInRect:(NSRect) destRect fromRect:(NSRect) srcRect withStyle:(DKStyle*) aStyle;

/** @brief Returns the single object rendered as a PDF image
 * @note
 * This allows the object to be extracted as a single PDF in isolation. It works by creating a
 * temporary view that draws just this object.
 * @return PDF data of the object
 * @public
 */
- (NSData*)				pdf;

// style:

- (void)				setStyle:(DKStyle*) aStyle;
- (DKStyle*)			style;
- (void)				styleWillChange:(NSNotification*) note;
- (void)				styleDidChange:(NSNotification*) note;
- (NSSet*)				allStyles;
- (NSSet*)				allRegisteredStyles;
- (void)				replaceMatchingStylesFromSet:(NSSet*) aSet;

/** @brief If the object's style is currently sharable, copy it and make it non-sharable.
 * @note
 * If the style is already non-sharable, this does nothing. The purpose of this is to detach this
 * from it style such that it has its own private copy. It does not change appearance.
 * @public
 */
- (void)				detachStyle;

// geometry:
// size (invariant with angle)

- (void)				setSize:(NSSize) size;
- (NSSize)				size;
- (void)				resizeWidthBy:(CGFloat) xFactor heightBy:(CGFloat) yFactor;

// location within the drawing

- (void)				setLocation:(NSPoint) p;
- (NSPoint)				location;
- (void)				offsetLocationByX:(CGFloat) dx byY:(CGFloat) dy;

// angle of object with respect to its container

/** @brief Set the object's current angle in radians
 * @param angle the object's angle (radians)
 * @public
 */
- (void)				setAngle:(CGFloat) angle;
- (CGFloat)				angle;

/** @brief Return the shape's current rotation angle
 * @note
 * This method is primarily to supply the angle for display to the user, rather than for doing angular
 * calculations with. It converts negative values -180 to 0 to +180 to 360 degrees.
 * @return the shape's angle in degrees
 * @public
 */
- (CGFloat)				angleInDegrees;

/** @brief Rotate the shape by adding a delta angle to the current angle
 * @note
 * Da is a value in radians
 * @param da add this much to the current angle
 * @public
 */
- (void)				rotateByAngle:(CGFloat) da;

// relative offset of locus within the object

- (void)				setOffset:(NSSize) offs;
- (NSSize)				offset;
- (void)				resetOffset;

// path transforms

/** @brief Return a transform that maps the object's stored path to its true location in the drawing
 * @note
 * Override for real transforms - the default merely returns the identity matrix
 * @return a transform
 */
- (NSAffineTransform*)	transform;

/** @brief Return the container's transform
 * @note
 * The container transform must be taken into account for rendering this object, as it accounts for
 * groups and other possible containers.
 * @return a transform
 */
- (NSAffineTransform*)	containerTransform;

/** @brief Apply the transform to the object
 * @note
 * The object's position, size and path are modified by the transform. This is called by the owning
 * layer's applyTransformToObjects method. This ignores locked objects.
 * @param transform a transform
 * @public
 */
- (void)				applyTransform:(NSAffineTransform*) transform;

// bounding rects:

- (NSRect)				bounds;
- (NSRect)				apparentBounds;
- (NSRect)				logicalBounds;
- (NSSize)				extraSpaceNeeded;

// creation tool protocol:

- (void)				creationTool:(DKDrawingTool*) tool willBeginCreationAtPoint:(NSPoint) p;
- (void)				creationTool:(DKDrawingTool*) tool willEndCreationAtPoint:(NSPoint) p;
- (BOOL)				objectIsValid;

// grouping/ungrouping protocol:

/** @brief This object is being added to a group
 * @note
 * Can be overridden if this event is of interest. Note that for grouping, the object doesn't need
 * to do anything special - the group takes care of it.
 * @param aGroup the group adding the object
 * @public
 */
- (void)				groupWillAddObject:(DKShapeGroup*) aGroup;

/** @brief This object is being ungrouped from a group
 * @note
 * When ungrouping, an object must help the group to the right thing by resizing, rotating and repositioning
 * itself appropriately. At the time this is called, the object has already has its container set to
 * the layer it will be added to but has not actually been added. Must be overridden.
 * @param aGroup the group containing the object
 * @param aTransform the transform that the group is applying to the object to scale rotate and translate it.
 * @public
 */
- (void)				group:(DKShapeGroup*) aGroup willUngroupObjectWithTransform:(NSAffineTransform*) aTransform;

/** @brief This object was ungrouped from a group
 * @note
 * This is called when the ungrouping operation has finished entirely. The object will belong to its
 * original container and have its location, etc set as required. Override to make use of this notification.
 * @public
 */
- (void)				objectWasUngrouped;

// post-processing when being substituted for another object (boolean ops, etc)

/** @brief Some high-level operations substitute a new object in place of an existing one (or several). In
 * those cases this should be called to allow the object to do any special substitution work.
 * @note
 * Subclasses should override this to do additional work during a substitution. Note that user info
 * and style is handled for you, this does not need to deal with those properties.
 * @param obj the original object his is being substituted for
 * @param aLayer the layer this will be added to (but is not yet)
 * @public
 */
- (void)				willBeAddedAsSubstituteFor:(DKDrawableObject*) obj toLayer:(DKObjectOwnerLayer*) aLayer;

// snapping to guides, grid and other objects (utility methods)

/** @brief Offset the point to cause snap to grid + guides accoding to the drawing's settings
 * @note
 * DKObjectOwnerLayer + DKDrawing implements the details of this method. The snapControl flag is
 * intended to come from a modifier flag - usually <ctrl>.
 * @param mp a point which is the proposed location of the shape
 * @return a new point which may be offset from the input enough to snap it to the guides and grid
 */
- (NSPoint)				snappedMousePoint:(NSPoint) mp withControlFlag:(BOOL) snapControl;
- (NSPoint)				snappedMousePoint:(NSPoint) mp forSnappingPointsWithControlFlag:(BOOL) snapControl;

- (NSArray*)			snappingPoints;
- (NSArray*)			snappingPointsWithOffset:(NSSize) offset;
- (NSSize)				mouseOffset;

// getting dimensions in drawing coordinates

- (CGFloat)				convertLength:(CGFloat) len;
- (NSPoint)				convertPointToDrawing:(NSPoint) pt;

// hit testing:

- (BOOL)				intersectsRect:(NSRect) rect;
- (NSInteger)			hitPart:(NSPoint) pt;
- (NSInteger)			hitSelectedPart:(NSPoint) pt forSnapDetection:(BOOL) snap;
- (NSPoint)				pointForPartcode:(NSInteger) pc;
- (DKKnobType)			knobTypeForPartCode:(NSInteger) pc;

/** @brief Test if a rect encloses any of the shape's actual pixels
 * @note
 * Note this can be an expensive way to test this - eliminate all obvious trivial cases first.
 * @param r the rect to test
 * @return YES if at least one pixel enclosed by the rect, NO otherwise
 * @private
 */
- (BOOL)				rectHitsPath:(NSRect) r;

/** @brief Test a point against the offscreen bitmap representation of the shape
 * @note
 * Special case of the rectHitsPath call, which is now the fastest way to perform this test
 * @param p the point to test
 * @return YES if the point hit the shape's pixels, NO otherwise
 * @private
 */
- (BOOL)				pointHitsPath:(NSPoint) p;

/** @brief Is a hit-test in progress
 * @note
 * Drawing methods can check this to see if they can take shortcuts to save time when hit-testing.
 * This will only return YES during calls to -drawContent etc when invoked by the rectHitsPath method.
 * @return YES if hit-testing is taking place, otherwise NO
 * @private
 */
- (BOOL)				isBeingHitTested;

/** @brief Set whether a hit-test in progress
 * @note
 * Applicaitons should not generally use this. It allows certain container classes (e.g. groups) to
 * flag the *they* are being hit tested to provide easier hitting of thin objects in groups.
 * @param hitTesting YES if hit-testing, NO otherwise
 * @private
 */
- (void)				setBeingHitTested:(BOOL) hitTesting;

// mouse events:

- (void)				mouseDownAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt;
- (void)				mouseDraggedAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt;
- (void)				mouseUpAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt;
- (NSView*)				currentView;

- (NSCursor*)			cursorForPartcode:(NSInteger) partcode mouseButtonDown:(BOOL) button;
- (void)				mouseDoubleClickedAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt;

// contextual menu:

/** @brief Reurn the menu to use as the object's contextual menu
 * @note
 * The menu is obtained via DKAuxiliaryMenus helper object which in turn loads the menu from a nib,
 * overridable by the app. This is the preferred method of supplying the menu. It doesn't need to
 * be overridden by subclasses generally speaking, since all menu customisation per class is done in
 * the nib.
 * @return the menu
 * @public
 */
- (NSMenu*)				menu;
- (BOOL)				populateContextualMenu:(NSMenu*) theMenu;
- (BOOL)				populateContextualMenu:(NSMenu*) theMenu atPoint:(NSPoint) localPoint;

// swatch image of this object:

- (NSImage*)			swatchImageWithSize:(NSSize) size;

// user info:

- (void)				setUserInfo:(NSDictionary*) info;
- (void)				addUserInfo:(NSDictionary*) info;

/** @brief Return the attached user info
 * @note
 * The user info is returned as a mutable dictionary (which it is), and can thus have its contents
 * mutated directly for certain uses. Doing this cannot cause any notification of the status of
 * the object however.
 * @return the user info
 * @public
 */
- (NSMutableDictionary*)userInfo;

/** @brief Return an item of user info
 * @param key the key to use to refer to the item
 * @return the user info item
 * @public
 */
- (id)					userInfoObjectForKey:(NSString*) key;

/** @brief Set an item of user info
 * @param obj the object to store
 * @param key the key to use to refer to the item
 * @public
 */
- (void)				setUserInfoObject:(id) obj forKey:(NSString*) key;

// cache management:

/** @brief Discard all cached rendering information
 * @note
 * The rendering cache is simply emptied. The contents of the cache are generally set by individual
 * renderers to speed up drawing, and are not known to this object. The cache is invalidated by any
 * change that alters the object's appearance - size, position, angle, style, etc.
 * @public
 */
- (void)				invalidateRenderingCache;

/** @brief Returns an image of the object representing its current appearance at 100% scale.
 * @note
 * This image is stored in the rendering cache. If the cache is empty the image is recreated. This
 * image can be used to speed up hit testing.
 * @return an image of the object
 * @public
 */
- (NSImage*)			cachedImage;

// pasteboard:

/** @brief Write additional data to the pasteboard specific to the object
 * @note
 * The owning layer generally handles the case of writing the selected objects to the pasteboard but
 * sometimes an object might wish to supplement that data. For example a text-bearing object might
 * add the text to the pasteboard. This is only invoked when the object is the only object selected.
 * The default method does nothing - override to make use of this. Also, your override must declare
 * the types it's writing using addTypes:owner:
 * @param pb the pasteboard to write to
 * @public
 */
- (void)				writeSupplementaryDataToPasteboard:(NSPasteboard*) pb;

/** @brief Read additional data from the pasteboard specific to the object
 * @note
 * This is invoked by the owning layer after an object has been pasted. Override to make use of. Note
 * that this is not necessarily symmetrical with -writeSupplementaryDataToPasteboard: depending on
 * what data types the other method actually wrote. For example standard text would not normally
 * need to be handled as a special case.
 * @param pb the pasteboard to read from
 * @public
 */
- (void)				readSupplementaryDataFromPasteboard:(NSPasteboard*) pb;

// user level commands that can be responded to by this object (and its subclasses)

- (IBAction)			copyDrawingStyle:(id) sender;
- (IBAction)			pasteDrawingStyle:(id) sender;
- (IBAction)			lock:(id) sender;
- (IBAction)			unlock:(id) sender;
- (IBAction)			lockLocation:(id) sender;
- (IBAction)			unlockLocation:(id) sender;

#ifdef qIncludeGraphicDebugging
// debugging:

- (IBAction)			toggleShowBBox:(id) sender;
- (IBAction)			toggleClipToBBox:(id) sender;
- (IBAction)			toggleShowPartcodes:(id) sender;
- (IBAction)			toggleShowTargets:(id) sender;
- (IBAction)			logDescription:(id) sender;

#endif

@end

// partcodes that are known to the layer - most are private to the drawable object class, but these are public:

enum
{
	kDKDrawingNoPart			= 0,
	kDKDrawingEntireObjectPart	= -1
};

// used to identify a possible "Convert To" submenu in an object's contextual menu

enum
{
	kDKConvertToSubmenuTag		= -55
};

// constant strings:

extern NSString*		kDKDrawableObjectPasteboardType;
extern NSString*		kDKDrawableDidChangeNotification;
extern NSString*		kDKDrawableStyleWillBeDetachedNotification;
extern NSString*		kDKDrawableStyleWasAttachedNotification;
extern NSString*		kDKDrawableDoubleClickNotification;
extern NSString*		kDKDrawableSubselectionChangedNotification;

// keys for items in user info sent with notifications

extern NSString*		kDKDrawableOldStyleKey;
extern NSString*		kDKDrawableNewStyleKey;
extern NSString*		kDKDrawableClickedPointKey;

// prefs keys

extern NSString*		kDKGhostColourPreferencesKey;
extern NSString*		kDKDragFeedbackEnabledPreferencesKey;

