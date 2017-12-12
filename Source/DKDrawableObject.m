/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawableObject.h"
#import "DKDrawing.h"
#import "DKStyle.h"
#import "DKKnob.h"
#import "DKObjectDrawingLayer.h"
#import "NSDictionary+DeepCopy.h"
#import "DKGeometryUtilities.h"
#import "LogEvent.h"
#import "NSAffineTransform+DKAdditions.h"
#import "DKDrawKitMacros.h"
#import "NSColor+DKAdditions.h"
#import "NSBezierPath+Combinatorial.h"
#import "DKDrawableObject+Metadata.h"
#import "DKDrawableContainerProtocol.h"
#import "DKObjectDrawingLayer+Alignment.h"
#import "DKAuxiliaryMenus.h"
#import "DKSelectionPDFView.h"
#import "DKPasteboardInfo.h"

#ifdef qIncludeGraphicDebugging
#import "DKDrawingView.h"
#include <tgmath.h>
#endif

#pragma mark Contants(Non - localized)
NSString* kDKDrawableDidChangeNotification = @"kDKDrawableDidChangeNotification";
NSString* kDKDrawableStyleWillBeDetachedNotification = @"kDKDrawableStyleWillBeDetachedNotification";
NSString* kDKDrawableStyleWasAttachedNotification = @"kDKDrawableStyleWasAttachedNotification";
NSString* kDKDrawableDoubleClickNotification = @"kDKDrawableDoubleClickNotification";
NSString* kDKDrawableSubselectionChangedNotification = @"kDKDrawableSubselectionChangedNotification";

NSString* kDKDrawableOldStyleKey = @"old_style";
NSString* kDKDrawableNewStyleKey = @"new_style";
NSString* kDKDrawableClickedPointKey = @"click_point";

NSString* kDKGhostColourPreferencesKey = @"kDKGhostColourPreferencesKey";
NSString* kDKDragFeedbackEnabledPreferencesKey = @"kDKDragFeedbackEnabledPreferencesKey";

NSString* kDKDrawableCachedImageKey = @"DKD_Cached_Img";

#pragma mark Static vars

static NSColor* s_ghostColour = nil;
static NSDictionary* s_interconversionTable = nil;

#pragma mark -
@implementation DKDrawableObject
#pragma mark As a DKDrawableObject

/** @brief Return whether an info floater is displayed when resizing an object

 Size info is width and height
 @return YES to show the info, NO to not show it */
+ (BOOL)displaysSizeInfoWhenDragging
{
	return ![[NSUserDefaults standardUserDefaults] boolForKey:kDKDragFeedbackEnabledPreferencesKey];
}

/** @brief Set whether an info floater is displayed when resizing an object

 Size info is width and height
 @param doesDisplay YES to show the info, NO to not show it */
+ (void)setDisplaysSizeInfoWhenDragging:(BOOL)doesDisplay
{
	[[NSUserDefaults standardUserDefaults] setBool:!doesDisplay
											forKey:kDKDragFeedbackEnabledPreferencesKey];
}

/** @brief Returns the union of the bounds of the objects in the array

 Utility method as this is a very common task - throws exception if any object in the list is
 not a DKDrawableObject or subclass thereof
 @param array a list of DKDrawable objects
 @return a rect, the union of the bounds of all objects */
+ (NSRect)unionOfBoundsOfDrawablesInArray:(NSArray*)array
{
	NSAssert(array != nil, @"array cannot be nil");

	NSRect u = NSZeroRect;
	NSEnumerator* iter = [array objectEnumerator];
	id dko;

	while ((dko = [iter nextObject])) {
		if (![dko isKindOfClass:[DKDrawableObject class]])
			[NSException raise:NSInternalInconsistencyException
						format:@"objects must all derive from DKDrawableObject"];

		u = UnionOfTwoRects(u, [dko bounds]);
	}

	return u;
}

/** @brief Return pasteboard types that this object class can receive

 Default method does nothing - subclasses will override if they can receive a drag
 @param op set of flags indicating what this operation the types relate to. Currently objects can only
 @return an array of pasteboard types
 */
+ (NSArray*)pasteboardTypesForOperation:(DKPasteboardOperationType)op
{
#pragma unused(op)
	return nil;
}

/** @brief Return the partcode that should be used by tools when initially creating a new object

 Default method does nothing - subclasses must override this and supply the right partcode value
 appropriate to the class. The client of this method is DKObjectCreationTool.
 @return a partcode value
 */
+ (NSInteger)initialPartcodeForObjectCreation
{
	return kDKDrawingNoPart;
}

/** @brief Return whether obejcts of this class can be grouped

 Default is YES. see also [DKShapeGroup objectsAvailableForGroupingFromArray];
 @return YES if objects can be included in groups
 */
+ (BOOL)isGroupable
{
	return YES;
}

/** @brief Unarchive a list of objects from the pasteboard, if possible

 This factors the dearchiving of objects from the pasteboard. If the pasteboard does not contain
 any valid types, nil is returned
 @param pb the pasteboard to take objects from
 @return a list of objects
 */
+ (NSArray*)nativeObjectsFromPasteboard:(NSPasteboard*)pb
{
	NSData* pbdata = [pb dataForType:kDKDrawableObjectPasteboardType];
	NSArray* objects = nil;

	if (pbdata != nil)
		objects = [NSKeyedUnarchiver unarchiveObjectWithData:pbdata];

	return objects;
}

/** @brief Return the number of native objects held by the pasteboard

 This efficiently queries the info object rather than dearchiving the objects themselves. A value
 of 0 means no native objects on the pasteboard (naturally)
 @param pb the pasteboard to read from
 @return a count
 */
+ (NSUInteger)countOfNativeObjectsOnPasteboard:(NSPasteboard*)pb
{
	DKPasteboardInfo* info = [DKPasteboardInfo pasteboardInfoWithPasteboard:pb];
	return [info count];
}

/** @brief Set the outline colour to use when drawing objects in their ghosted state

 The ghost colour is persistent, stored using the kDKGhostColourPreferencesKey key
 @param ghostColour the colour to use
 */
+ (void)setGhostColour:(NSColor*)ghostColour
{
	[ghostColour retain];
	[s_ghostColour release];
	s_ghostColour = ghostColour;

	[[NSUserDefaults standardUserDefaults] setObject:[ghostColour hexString]
											  forKey:kDKGhostColourPreferencesKey];
}

/** @brief Return the outline colour to use when drawing objects in their ghosted state

 The default is light gray
 @return the colour to use
 */
+ (NSColor*)ghostColour
{
	if (s_ghostColour == nil) {
		NSColor* ghost = [NSColor colorWithHexString:[[NSUserDefaults standardUserDefaults] stringForKey:kDKGhostColourPreferencesKey]];

		if (ghost == nil)
			ghost = [NSColor lightGrayColor];

		[self setGhostColour:ghost];
	}

	return s_ghostColour;
}

#pragma mark -

/** @brief Return the interconversion table

 The interconversion table is used when drawables are converted to another type. The table can be
 customised to permit conversions to subclasses or other types of object. The default is nil,
 which simply passes through the requested type unchanged.
 @return the table (a dictionary)
 */
+ (NSDictionary*)interconversionTable
{
	return s_interconversionTable;
}

/** @brief Return the interconversion table

 The interconversion table is used when drawables are converted to another type. The table can be
 customised to permit conversions to subclasses of the requested class. The default is nil,
 which simply passes through the requested type unchanged. The dictionary consists of the base class
 as a string, and returns the class to use in place of that type.
 @param icTable a dictionary containing mappings from standard base classes to custom classes
 */
+ (void)setInterconversionTable:(NSDictionary*)icTable
{
	[icTable retain];
	[s_interconversionTable release];
	s_interconversionTable = icTable;
}

/** @brief Return the class to use in place of the given class when performing a conversion

 The default passes through the input class unchanged. By customising the conversion table, other
 classes can be substituted when performing a conversion.
 @param aClass the base class which we are converting TO.
 @return the actual object class to use for that conversion.
 */
+ (Class)classForConversionRequestFor:(Class)aClass
{
	NSAssert(aClass != Nil, @"class was Nil when requesting a conversion class");

	Class icClass = [[self interconversionTable] objectForKey:NSStringFromClass(aClass)];

	// if not found, return input unchanged

	if (icClass == nil)
		return aClass;
	else {
		NSAssert2([icClass isSubclassOfClass:aClass], @"conversion failed - %@ must be a subclass of %@", icClass, aClass);
		return icClass;
	}
}

/** @brief Sets the class to use in place of the a base class when performing a conversion

 This is only used when performing conversions, not when creating new objects in other circumstances.
 <newClass> must be a subclass of <baseClass>
 @param newClass the class which we are converting TO
 @param baseClass the base class
 */
+ (void)substituteClass:(Class)newClass forClass:(Class)baseClass
{
	NSAssert(newClass != Nil, @"class was Nil");
	NSAssert(baseClass != Nil, @"base class was Nil");

	if ([newClass isSubclassOfClass:baseClass]) {
		NSMutableDictionary* dict = [[self interconversionTable] mutableCopy];

		if (dict == nil)
			dict = [[NSMutableDictionary alloc] init];

		[dict setObject:newClass
				 forKey:NSStringFromClass(baseClass)];
		[self setInterconversionTable:dict];
		[dict release];
	} else
		[NSException raise:NSInternalInconsistencyException
					format:@"you must only substitute a subclass for the base class"];
}

/** @brief Initializes the drawable to have the style given

 You can use -init to initialize using the default style. Note that if creating many objects at
 once, supplying the style when initializing is more efficient.
 @param aStyle the initial style for the object
 @return the object
 */
- (instancetype)initWithStyle:(DKStyle*)aStyle
{
	self = [super init];
	if (self) {
		m_visible = YES;
		m_snapEnable = YES;

		[self setStyle:aStyle];
	}

	return self;
}

#pragma mark -
#pragma mark - relationships

/** @brief Returns the layer that this object ultimately belongs to

 This returns the layer even if container isn't the layer, by recursing up the tree as needed
 @return the containing layer
 */
- (DKObjectOwnerLayer*)layer
{
	return (DKObjectOwnerLayer*)[[self container] layer];
}

/** @brief Returns the drawing that owns this object's layer
 @return the drawing
 */
- (DKDrawing*)drawing
{
	return [[self container] drawing];
}

/** @brief Returns the undo manager used to handle undoable actions for this object
 @return the undo manager in use
 */
- (NSUndoManager*)undoManager
{
	return [[self drawing] undoManager];
}

/** @brief Returns the immediate parent of this object

 A parent is usually a layer, same as owner - but can be a group if the object is grouped
 @return the object's parent
 */
- (id<DKDrawableContainer>)container
{
	return mContainerRef;
}

/** @brief Sets the immediate parent of this object (a DKObjectOwnerLayer layer, typically)

 The container itself is responsible for setting this - applications should not use this method. An
 object's container is usually the layer, but can be a group. <aContainer> is not retained. Note that
 a valid container is required for the object to locate an undo manager, so nothing is undoable
 until this is set to a valid object that can supply one.
 @param aContainer the immediate container of this object
 */
- (void)setContainer:(id<DKDrawableContainer>)aContainer
{
	if (aContainer != mContainerRef) {
		// nil is permitted, but if not nil, must conform to container protocol

		if (aContainer) {
			NSAssert1([aContainer conformsToProtocol:@protocol(DKDrawableContainer)], @"object passed (%@) does not conform to the DKDrawableContainer protocol", aContainer);
		}

		mContainerRef = aContainer;

		// make sure any attached style is aware of the undo manager used by the drawing/layers

		if (aContainer)
			[[self style] setUndoManager:[self undoManager]];
		else
			[[self style] setUndoManager:nil];
	}
}

/** @brief Returns the index position of this object in its container layer

 This is intended for debugging and should generally be avoided by user code.
 @return the index position
 */

/** @brief Where object storage stores the Z-index in the object itself, this returns it.

 See DKObjectStorageProtocol.h
 @return the Z value for the object
 */
- (NSUInteger)indexInContainer
{
	if ([[self container] respondsToSelector:@selector(indexOfObject:)])
		return [[self container] indexOfObject:self];
	else
		return NSNotFound;
}

#pragma mark -
#pragma mark - as part of the DKStorableObject protocol

/** @brief Where object storage stores the Z-index in the object itself, this is used to set it.

 Note that this doesn't allow the Z-index to be changed, but merely recorded. This method should only
 be used by storage methods internal to DK and not by external client code. See DKObjectStorageProtocol.h
 @param zIndex the desired Z value for the object
 */
- (void)setIndex:(NSUInteger)zIndex
{
	mZIndex = zIndex;
}

- (NSUInteger)index
{
	return mZIndex;
}

/** @brief Returns the reference to the object's storage

 See DKObjectStorageProtocol.h
 @return the object's storage
 */
- (id<DKObjectStorage>)storage
{
	return mStorageRef;
}

/** @brief Returns the reference to the object's storage

 See DKObjectStorageProtocol.h. Not for client code.
 @param storage the object's storage
 */
- (void)setStorage:(id<DKObjectStorage>)storage
{
	mStorageRef = storage;
}

/** @brief Marks the object

 See DKObjectStorageProtocol.h. Not for client code.
 @param markIt a flag
 */
- (void)setMarked:(BOOL)markIt
{
	mMarked = markIt;
}

/** @brief Marks the object

 See DKObjectStorageProtocol.h. Not for client code.
 @return a flag
 */
- (BOOL)isMarked
{
	return mMarked;
}

#pragma mark -
#pragma mark - state

/** @brief Sets whether the object is drawn (visible) or not

 The visible property is independent of the locked property, i.e. locked objects may be hidden & shown.
 @param vis YES to show the object, NO to hide it
 */
- (void)setVisible:(BOOL)vis
{
	if (m_visible != vis) {
		[[[self undoManager] prepareWithInvocationTarget:self] setVisible:m_visible];
		m_visible = vis;
		[self notifyVisualChange];
		[self notifyStatusChange];

		[[self storage] objectDidChangeVisibility:self];

		[[self undoManager] setActionName:vis ? NSLocalizedString(@"Show", @"undo action for single object show") : NSLocalizedString(@"Hide", @"undo action for single object hide")];
	}
}

/** @brief Is the object visible?
 @return YES if visible, NO if not
 */
- (BOOL)visible
{
	return m_visible;
}

/** @brief Sets whether the object is locked or not

 Locked objects are visible but can't be edited
 @param locked YES to lock, NO to unlock
 */
- (void)setLocked:(BOOL)locked
{
	if (m_locked != locked) {
		[[[self undoManager] prepareWithInvocationTarget:self] setLocked:m_locked];
		m_locked = locked;
		[self notifyVisualChange]; // on the assumption that the locked state is shown differently
		[self notifyStatusChange];
		[[self undoManager] setActionName:locked ? NSLocalizedString(@"Lock", @"undo action for single object lock") : NSLocalizedString(@"Unlock", @"undo action for single object unlock")];
	}
}

/** @brief Is the object locked?
 @return YES if locked, NO if not
 */
- (BOOL)locked
{
	return m_locked;
}

/** @brief Sets whether the object's location is locked or not

 Location may be locked independently of the general lock
 @param lockLocation YES to lock location, NO to unlock
 */
- (void)setLocationLocked:(BOOL)lockLocation
{
	if (mLocationLocked != lockLocation) {
		[[[self undoManager] prepareWithInvocationTarget:self] setLocationLocked:mLocationLocked];
		mLocationLocked = lockLocation;
		[self notifyVisualChange]; // on the assumption that the state is shown differently
		[self notifyStatusChange];
	}
}

/** @brief Whether the object's location is locked or not

 Location may be locked independently of the general lock
 @return YES if locked location, NO to unlock
 */
- (BOOL)locationLocked
{
	return mLocationLocked;
}

/** @brief Enable mouse snapping
 @param ems YES to enable snapping (default), NO to disable it
 */
- (void)setMouseSnappingEnabled:(BOOL)ems
{
	m_snapEnable = ems;
}

/** @brief Is mouse snapping enabled?
 @return YES if will snap on mouse actions, NO if not
 */
- (BOOL)mouseSnappingEnabled
{
	return m_snapEnable;
}

/** @brief Set whether the object is ghosted rather than with its full style

 Ghosting is an alternative to hiding - ghosted objects are still visible but are only drawn using
 a thin outline. See also: +setGhostingColour:
 @param ghosted YES to ghost the object, NO to unghost it
 */
- (void)setGhosted:(BOOL)ghosted
{
	if (mGhosted != ghosted && ![self locked]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setGhosted:mGhosted];
		mGhosted = ghosted;
		[self notifyVisualChange];
		[self notifyStatusChange];

		[[self undoManager] setActionName:ghosted ? NSLocalizedString(@"Ghost", @"undo action for single object ghost") : NSLocalizedString(@"Unghost", @"undo action for single object unghost")];
	}
}

@synthesize ghosted=mGhosted;
@synthesize trackingMouse=m_inMouseOp;
@synthesize mouseDragOffset=m_mouseOffset;
@synthesize mouseHasMovedSinceStartOfTracking=m_mouseEverMoved;

#pragma mark -

/** @brief Returns whether the object is selected 

 Assumes that the owning layer is an object drawing layer (which is a reasonable assumption!)
 @return YES if selected, NO otherwise
 */
- (BOOL)isSelected
{
	return [(DKObjectDrawingLayer*)[self layer] isSelectedObject:self];
}

/** @brief Get notified when the object is selected

 Subclasses can override to take action when they become selected (drawing the selection isn't
 part of this - the layer will do that). Overrides should generally invoke super.
 */
- (void)objectDidBecomeSelected
{
	[self notifyStatusChange];
	[self updateRulerMarkers];
}

/** @brief Get notified when an object is deselected

 Subclasses can override to take action when they are deselected
 */
- (void)objectIsNoLongerSelected
{
	[self notifyStatusChange];

	// override to make use of this notification
}

/** @brief Is the object able to be selected?

 Subclasses can override to disallow selection. By default all objects are selectable, but for some
 specialised use this might be useful.
 @return YES if selectable, NO if not
 */
- (BOOL)objectMayBecomeSelected
{
	return YES;
}

/** @brief Is the object currently a pending object?

 Esoteric. An object is pending while it is being created and not otherwise. There are few reasons
 to need to know, but one might be to implement a special selection highlight for this case.
 @return YES if pending, NO if not
 */
- (BOOL)isPendingObject
{
	return [[self layer] pendingObject] == self;
}

/** @brief Is the object currently the layer's key object?

 DKObjectDrawingLayer maintains a 'key object' for the purposes of alignment operations. The drawable
 could use this information to draw itself in a particular way for example. Note that DK doesn't
 use this information except for object alignment operations.
 @return YES if key, NO if not
 */
- (BOOL)isKeyObject
{
	return [(DKObjectDrawingLayer*)[self layer] keyObject] == self;
}

/** @brief Return the subselection of the object

 DK objects do not have subselections without subclassing, but this method provides a common method
 for subselections to be passed back to a UI, etc. If there is no subselection, this should return
 either the empty set, nil or a set containing self.
 Subclasses will override and return whatever is appropriate. They are also responsible for the complete
 implementation of the selection including hit-testing and highlighting. In addition, the notification
 'kDKDrawableSubselectionChangedNotification' should be sent when this changes.
 @return a set containing the selection within the object. May be empty, nil or contain self.
 */
- (NSSet*)subSelection
{
	return [NSSet setWithObject:self];
}

/** @brief The object was added to a layer

 Purely for information, should an object need to know. Override to make use of this. Subclasses
 should call super.
 @param aLayer the layer this was added to
 */
- (void)objectWasAddedToLayer:(DKObjectOwnerLayer*)aLayer
{
#pragma unused(aLayer)

	// begin observing style changes

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(styleWillChange:)
												 name:kDKStyleWillChangeNotification
											   object:[self style]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(styleDidChange:)
												 name:kDKStyleDidChangeNotification
											   object:[self style]];
}

/** @brief The object was removed from the layer

 Purely for information, should an object need to know. Override to make use of this. Subclasses
 should call super to maintain notifications.
 @param aLayer the layer this was removed from
 */
- (void)objectWasRemovedFromLayer:(DKObjectOwnerLayer*)aLayer
{
#pragma unused(aLayer)

	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:nil
												  object:[self style]];
}

#pragma mark -
#pragma mark - drawing

/** @brief Draw the object and its selection on demand

 The caller will have determined that the object needs drawing, so this will only be called when
 necessary. The default method does nothing - subclasses must override this.
 @param selected YES if the object is to draw itself in the selected state, NO otherwise
 */

/** @brief Draw the content of the object

 This just hands off to the style rendering by default, but subclasses may override it to do more.
 */
- (void)drawContentWithSelectedState:(BOOL)selected
{
	@autoreleasepool {

#ifdef qIncludeGraphicDebugging
		[NSGraphicsContext saveGraphicsState];

		if (m_clipToBBox) {
			NSBezierPath* clipPath = [NSBezierPath bezierPathWithRect:[self bounds]];
			[clipPath addClip];
		}
#endif
		// draw the object's actual content

		mIsHitTesting = NO;
		[self drawContent];

		// draw the selection highlight - other code should have already checked -objectMayBecomeSelected and refused to
		// select the object but if for some reason this wasn't done, this at least supresses the highlight

		if (selected && [self objectMayBecomeSelected])
			[self drawSelectedState];

#ifdef qIncludeGraphicDebugging

		[NSGraphicsContext restoreGraphicsState];

		if (m_showBBox) {
			CGFloat sc = 0.5 / [(DKDrawingView*)[self currentView] scale];

			[[NSColor redColor] set];

			NSRect bb = [self bounds];
			bb = NSInsetRect(bb, sc, sc);
			NSBezierPath* bbox = [NSBezierPath bezierPathWithRect:bb];

			[bbox moveToPoint:bb.origin];
			[bbox lineToPoint:NSMakePoint(NSMaxX(bb), NSMaxY(bb))];
			[bbox moveToPoint:NSMakePoint(NSMaxX(bb), NSMinY(bb))];
			[bbox lineToPoint:NSMakePoint(NSMinX(bb), NSMaxY(bb))];

			[bbox setLineWidth:0.0];
			[bbox stroke];
		}

#endif

	}
}

- (void)drawContent
{
	[self drawContentWithStyle:[self style]];
}

/** @brief Draw the content of the object but using a specific style, which might not be the one attached
 @param aStyle a valid style object, or nil to use the object's current style
 */
- (void)drawContentWithStyle:(DKStyle*)aStyle
{
	if ([self isGhosted])
		[self drawGhostedContent];
	else if (aStyle && ([aStyle countOfRenderList] > 0 || [aStyle hasTextAttributes])) {
		@try
		{
			[aStyle render:self];
		}
		@catch (id exc)
		{
			// exceptions arising within style renderings can cause havoc with the drawing state. To try and gracefully exit,
			// the rogue object is hidden after logging the problem. This is meant as a last resort to keep the document working -
			// styles may need to handle exceptions more gracefully internally. Any such logs must be investigated.

			NSLog(@"object %@ (style = %@) encountered an exception while rendering", self, [self style]);
			//[self setVisible:NO];

			@throw;
		}
	} else {
		// if there's no style, the shape will be invisible. This makes it hard to select for deletion, etc. Thus if
		// drawing to the screen, a visible but feint fill is drawn so that it can be seen and selected. This is not drawn
		// to the printer so the drawing remains correct for printed output.

		if ([NSGraphicsContext currentContextDrawingToScreen]) {
			[[NSColor rgbGrey:0.95
					withAlpha:0.5] set];

			NSBezierPath* rpc = [[self renderingPath] copy];
			[rpc fill];
			[rpc release];
		}
	}
}

/** @brief Draw the ghosted content of the object

 The default simply strokes the rendering path at minimum width using the ghosting colour. Can be
 overridden for more complex appearances. Note that ghosting should deliberately keep the object
 unobtrusive and simple.
 */
- (void)drawGhostedContent
{
	[[[self class] ghostColour] set];
	NSBezierPath* rp = [self renderingPath];
	[rp setLineWidth:0];
	[rp stroke];
}

/** @brief Draw the selection highlight for the object

 The owning layer may call this independently of drawContent~ in some circumstances, so 
 subclasses need to be ready to factor this code as required.
 */
- (void)drawSelectedState
{
	// placeholder - override to implement this
}

/** @brief Stroke the given path using the selection highlight colour for the owning layer

 This is a convenient utility method your subclasses can use as needed to make selections consistent
 among different objects and layers. A side effect is that the line width of the path may be changed.
 @param path the selection highlight path
 */
- (void)drawSelectionPath:(NSBezierPath*)path
{
	if ([self locked])
		[[NSColor lightGrayColor] set];
	else
		[[[self layer] selectionColour] set];

	[path setLineWidth:0.0];
	[path stroke];
}

/** @brief Request a redraw of this object

 Marks the object's bounds as needing updating. Most operations on an object that affect its
 appearance to the user should call this before and after the operation is performed.
 Subclasses that override this for optimisation purposes should make sure that the layer is
 updated through the drawable:needsDisplayInRect: method and that the notification is sent, otherwise
 there may be problems when layer contents are cached.
 */
- (void)notifyVisualChange
{
	if ([self layer])
		[[self layer] drawable:self
			needsDisplayInRect:[self bounds]];
}

/** @brief Notify the drawing and its controllers that a non-visual status change occurred

 The drawing passes this back to any controllers it has
 */
- (void)notifyStatusChange
{
	[[self drawing] objectDidNotifyStatusChange:self];
}

/** @brief Notify that the geomnetry of the object has changed

 Subclasses can override this to make use of the change notification. This is intended to signal
 purely geometric changes which for some objects could be used to invalidate cached information
 that more general changes might not need to invalidate. This also informs the storage about the
 bounds change so that if the storage uses bounds information to optimise storage, it can do
 whatever it needs to to keep the storage correctly organised.
 @param oldBounds the bounds of the object *before* it got changed by whatever is calling this
 */
- (void)notifyGeometryChange:(NSRect)oldBounds
{
	if (!NSEqualRects(oldBounds, [self bounds])) {
		[self invalidateRenderingCache];
		[[self storage] object:self
			didChangeBoundsFrom:oldBounds];
		[self updateRulerMarkers];
	}
}

/** @brief Sets the ruler markers for all of the drawing's views to the logical bounds of this

 This is largely automatic, but if there is an operation that shoul dupdate the markers, you can
 call this to perform it. Also, if a subclass has some special way to set the markers, it may
 override this.
 */
- (void)updateRulerMarkers
{
	[[self layer] updateRulerMarkersForRect:[self logicalBounds]];
}

/** @brief Mark some part of the drawing as needing update

 Usually an object should mark only areas within its bounds using this, to be polite.
 @param rect this area requires an update
 */
- (void)setNeedsDisplayInRect:(NSRect)rect
{
	[[self layer] drawable:self
		needsDisplayInRect:rect];
}

/** @brief Mark multiple parts of the drawing as needing update

 The layer call with NSZeroRect is to ensure the layer's caches work
 */
- (void)setNeedsDisplayInRects:(NSSet*)setOfRects
{
	[[self layer] drawable:self
		needsDisplayInRect:NSZeroRect];
	[[self layer] setNeedsDisplayInRects:setOfRects];
}

/** @brief Mark multiple parts of the drawing as needing update
 <padding> some additional margin added to each rect before marking as needing update

 The layer call with NSZeroRect is to ensure the layer's caches work
 */
- (void)setNeedsDisplayInRects:(NSSet*)setOfRects withExtraPadding:(NSSize)padding
{
	[[self layer] drawable:self
		needsDisplayInRect:NSZeroRect];
	[[self layer] setNeedsDisplayInRects:setOfRects
						withExtraPadding:padding];
}

#pragma mark -
#pragma mark - specialised drawing methods

/**
 Useful for rendering the object into any context at any size. The object is scaled by the ratio
 of srcRect to destRect. <destRect> can't be zero-sized.
 @param destRect the destination rect in the current context
 @param srcRect the srcRect in the same coordinate space as the current bounds, or NSZeroRect to mean the
 @param aStyle currently unused - draws in the object's attached style
 */
- (void)drawContentInRect:(NSRect)destRect fromRect:(NSRect)srcRect withStyle:(DKStyle*)aStyle
{
#pragma unused(aStyle)

	NSAssert(destRect.size.width > 0.0 && destRect.size.height > 0.0, @"destination rect has zero size");

	if (NSEqualRects(srcRect, NSZeroRect))
		srcRect = [self bounds];
	else
		srcRect = NSIntersectionRect(srcRect, [self bounds]);

	if (NSEqualRects(srcRect, NSZeroRect))
		return;

	SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
		[NSBezierPath clipRect : destRect];

	// compute the necessary transform to perform the scaling and translation from srcRect to destRect.

	NSAffineTransform* tfm = [NSAffineTransform transform];
	[tfm mapFrom:srcRect
			  to:destRect];
	[tfm concat];

	[self drawContent];
	RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
}

/** @brief Returns the single object rendered as a PDF image

 This allows the object to be extracted as a single PDF in isolation. It works by creating a
 temporary view that draws just this object.
 @return PDF data of the object
 */
- (NSData*)pdf
{
	NSRect frame = NSZeroRect;
	frame.size = [[self drawing] drawingSize];

	DKDrawablePDFView* pdfView = [[DKDrawablePDFView alloc] initWithFrame:frame
																   object:self];

	NSData* pdfData = [pdfView dataWithPDFInsideRect:[self bounds]];

	[pdfView release];

	return pdfData;
}

#pragma mark -
#pragma mark - style

/** @brief Attaches a style to the object

 It's important to call the inherited method if you override this, as objects generally need to
 subscribe to a style's notifications, and a style needs to know when it is attached to objects.
 @param aStyle the style to attach. The object will be drawn using this style from now on
 */
- (void)setStyle:(DKStyle*)aStyle
{
	// do not allow in any old object

	if (aStyle && ![aStyle isKindOfClass:[DKStyle class]])
		return;

	// important rule: always make a 'copy' of the style to honour its sharable flag:

	DKStyle* newStyle = [aStyle copy];

	if (newStyle != [self style]) {
		[[self undoManager] registerUndoWithTarget:self
										  selector:@selector(setStyle:)
											object:[self style]];
		[self notifyVisualChange];

		NSRect oldBounds = [self bounds];

		// subscribe to change notifications from the style so we can refresh and undo changes

		if (m_style)
			[[NSNotificationCenter defaultCenter] removeObserver:self
															name:nil
														  object:m_style];

		// adding observers is slow, noticeable when creating many objects at a time (for example when reading a file). To help, the observer
		// is not added straight away unless we are already part of a layer. The observation will be established when the object is added to the layer.

		if (newStyle && [self layer]) {
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(styleWillChange:)
														 name:kDKStyleWillChangeNotification
													   object:newStyle];
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(styleDidChange:)
														 name:kDKStyleDidChangeNotification
													   object:newStyle];
		}

		// set up the user info. If newStyle is nil, this will terminate the list after the old style

		NSDictionary* userInfo = @{kDKDrawableOldStyleKey: [self style], kDKDrawableNewStyleKey: newStyle};

		if ([self layer])
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawableStyleWillBeDetachedNotification
																object:self
															  userInfo:userInfo];

		[m_style styleWillBeRemoved:self];
		[m_style release];
		m_style = [newStyle retain];

		// set the style's undo manager to ours if it's actually set

		if ([self undoManager] != nil)
			[m_style setUndoManager:[self undoManager]];

		[m_style styleWasAttached:self];
		[self notifyStatusChange];
		[self notifyVisualChange];
		[self notifyGeometryChange:oldBounds]; // in case the style change affects the bounds

		// notify if we are part of a layer, otherwise don't bother

		if ([self layer])
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawableStyleWasAttachedNotification
																object:self
															  userInfo:userInfo];
	}

	[newStyle release];
}

@synthesize style=m_style;

static NSRect s_oldBounds;

/** @brief Called when the attached style is about to change
 */
- (void)styleWillChange:(NSNotification*)note
{
	if ([note object] == [self style]) {
		s_oldBounds = [self bounds];
		[self notifyVisualChange];
	}
}

/** @brief Called just after the attached style has changed
 */
- (void)styleDidChange:(NSNotification*)note
{
	if ([note object] == [self style]) {
		[self notifyVisualChange];
		[self notifyGeometryChange:s_oldBounds];
	}
}

/** @brief Return all styles used by this object

 This is part of an informal protocol used, among other possible uses, for remerging styles after
 a document load. Objects higher up the chain form the union of all such sets, which is why this
 is returned as a set, even though it contains just one style. Subclasses might also use more than
 one style.
 @return a set, containing the object's style
 */
- (NSSet*)allStyles
{
	if ([self style] != nil)
		return [NSSet setWithObject:[self style]];
	else
		return nil;
}

/** @brief Return all registered styles used by this object

 This is part of an informal protocol used for remerging styles after
 a document load. Objects higher up the chain form the union of all such sets, which is why this
 is returned as a set, even though it contains just one style. Subclasses might also use more than
 one style. After a fresh load from an archive, this returns the style if the remerge flag is set,
 but at all other times it returns the style if registered. The remerge flag is cleared by this
 method, thus you need to make sure to call it just once after a reload if it's the remerge flagged
 styles you want (in general this usage is automatic and is handled at a much higher level - see
 DKDrawingDocument).
 @return a set, containing the object's style if it is registerd or flagged for remerge
 */
- (NSSet*)allRegisteredStyles
{
	if ([self style] != nil) {
		if ([[self style] requiresRemerge] || [[self style] isStyleRegistered]) {
			[[self style] clearRemergeFlag];
			return [NSSet setWithObject:[self style]];
		}
	}

	return nil;
}

/** @brief Replace the object's style from any in th egiven set that have the same ID.

 This is part of an informal protocol used for remerging registered styles after
 a document load. If <aSet> contains a style having the same ID as this object's current style,
 the style is updated with the one from the set.
 @param aSet a set of style objects
 */
- (void)replaceMatchingStylesFromSet:(NSSet*)aSet
{
	NSAssert(aSet != nil, @"style set was nil");

	if ([self style] != nil) {
		NSEnumerator* iter = [aSet objectEnumerator];
		DKStyle* st;

		while ((st = [iter nextObject])) {
			if ([[st uniqueKey] isEqualToString:[[self style] uniqueKey]]) {
				LogEvent_(kStateEvent, @"replacing style with %@ '%@'", st, [st name]);

				[self setStyle:st];
				break;
			}
		}
	}
}

/** @brief If the object's style is currently sharable, copy it and make it non-sharable.

 If the style is already non-sharable, this does nothing. The purpose of this is to detach this
 from it style such that it has its own private copy. It does not change appearance.
 */
- (void)detachStyle
{
	if ([[self style] isStyleSharable]) {
		DKStyle* detachedStyle = [[self style] mutableCopy];

		[detachedStyle setStyleSharable:NO];
		[self setStyle:detachedStyle];
		[detachedStyle release];
	}
}

#pragma mark -
#pragma mark - geometry

/** @brief Sets the object's size to the width and height passed

 Subclasses should override to set the object's size
 @param size the new size
 */
- (void)setSize:(NSSize)size
{
#pragma unused(size)
}

/** @brief Returns the size of the object regardless of angle, etc.

 Subclasses should override and return something sensible
 @return the object's size
 */
- (NSSize)size
{
	NSLog(@"!!! 'size' must be overridden by subclasses of DKDrawableObject (culprit = %@)", self);

	return NSZeroSize;
}

/** @brief Resizes the object by scaling its width and height by thye given factors.

 Factors of 1.0 have no effect; factors must be postive and > 0.
 @param xFactor the width scale
 @param yFactor the height scale
 */
- (void)resizeWidthBy:(CGFloat)xFactor heightBy:(CGFloat)yFactor
{
	NSAssert(xFactor > 0.0, @"x scale must be greater than 0");
	NSAssert(yFactor > 0.0, @"y scale must be greater than 0");

	NSSize newSize = [self size];

	newSize.width *= xFactor;
	newSize.height *= yFactor;

	[self setSize:newSize];
}

/** @brief Returns the visually apparent bounds

 This bounds is intended for use when aligning objects to each other or to guides, etc. By default
 it is the same as the bounds, but subclasses may redefine it to be something else.
 @return the apparent bounds rect
 */
- (NSRect)apparentBounds
{
	return [self bounds];
}

/** @brief Returns the logical bounds

 The logical bounds is the object's bounds ignoring any stylistic effects. Unlike the other bounds,
 it remains constant for a given paht even if styles change. By default it is the same as the bounds,
 but subclasses will probably wish to redefine it.
 @return the logical bounds
 */
- (NSRect)logicalBounds
{
	return [self bounds];
}

#pragma mark -

/** @brief Test whether the object intersects a given rectangle

 Used for selecting using a marquee, and other things. The default hit tests by rendering the object
 into a special 1-byte bitmap and testing its alpha channel - this is fast and efficient and in most
 simple cases doesn't need to be overridden.
 @param rect the rect to test against
 @return YES if the object intersects the rect, NO otherwise
 */
- (BOOL)intersectsRect:(NSRect)rect
{
	NSRect ir, br = [self bounds];

	if ([self visible] && NSIntersectsRect(br, rect)) {
		// if <rect> fully encloses the bounds, no further tests are needed and we can return YES immediately

		ir = NSIntersectionRect(rect, br);

		if (NSEqualRects(ir, br))
			return YES;
		else
			return [self rectHitsPath:rect];
	} else
		return NO; // invisible objects don't intersect anything
}

/** @brief Set the location of the object to the given point

 The object can decide how it aligns itself about its own location in any way that is self-consistent.
 the default is to align the origin of the bounds at the point, but most subclasses do something
 more sophisticated
 @param p the point to locate the object at
 */
- (void)setLocation:(NSPoint)p
{
#pragma unused(p)

	NSLog(@"**** You must override -setLocation: for the object %@ ****", self);
}

/** @brief Offsets the object's position by the values passed
 @param dx add this much to the x coordinate
 @param dy add this much to the y coordinate
 */
- (void)offsetLocationByX:(CGFloat)dx byY:(CGFloat)dy
{
	if (dx != 0 || dy != 0) {
		NSPoint loc = [self location];

		loc.x += dx;
		loc.y += dy;

		[self setLocation:loc];
	}
}

/** @brief Return the object's current location
 @return the object's location
 */
- (NSPoint)location
{
	return [self logicalBounds].origin;
}

/** @brief Return the object's current angle, in radians

 Override if your subclass implements variable angles
 @return the object's angle
 */
- (CGFloat)angle
{
	return 0.0;
}

/** @brief Set the object's current angle in radians
 @param angle the object's angle (radians)
 */
- (void)setAngle:(CGFloat)angle
{
#pragma unused(angle)
}

/** @brief Return the shape's current rotation angle

 This method is primarily to supply the angle for display to the user, rather than for doing angular
 calculations with. It converts negative values -180 to 0 to +180 to 360 degrees.
 @return the shape's angle in degrees
 */
- (CGFloat)angleInDegrees
{
	CGFloat angle = RADIANS_TO_DEGREES([self angle]);

	if (angle < 0)
		angle += 360.0;

	return fmod(angle, 360.0);
}

/** @brief Rotate the shape by adding a delta angle to the current angle

 Da is a value in radians
 @param da add this much to the current angle
 */
- (void)rotateByAngle:(CGFloat)da
{
	if (da != 0)
		[self setAngle:[self angle] + da];
}

/** @brief Discard all cached rendering information

 The rendering cache is simply emptied. The contents of the cache are generally set by individual
 renderers to speed up drawing, and are not known to this object. The cache is invalidated by any
 change that alters the object's appearance - size, position, angle, style, etc.
 */
- (void)invalidateRenderingCache
{
	[mRenderingCache removeAllObjects];
}

/** @brief Returns an image of the object representing its current appearance at 100% scale.

 This image is stored in the rendering cache. If the cache is empty the image is recreated. This
 image can be used to speed up hit testing.
 @return an image of the object
 */
- (NSImage*)cachedImage
{
	NSImage* img = [mRenderingCache objectForKey:kDKDrawableCachedImageKey];

	if (img == nil) {
		img = [self swatchImageWithSize:NSZeroSize];
		[mRenderingCache setObject:img
							forKey:kDKDrawableCachedImageKey];
	}

	return img;
}

#pragma mark -

/** @brief Set the relative offset of the object's anchor point

 Subclasses must override if they support this concept
 @param offs a width and height value relative to the object's bounds
 */
- (void)setOffset:(NSSize)offs
{
#pragma unused(offs)

	// placeholder
}

/** @brief Return the relative offset of the object's anchor point

 Subclasses must override if they support this concept
 @return a width and height value relative to the object's bounds
 */
- (NSSize)offset
{
	return NSZeroSize;
}

/** @brief Reset the relative offset of the object's anchor point to its original value

 Subclasses must override if they support this concept
 */
- (void)resetOffset
{
}

/** @brief Return a transform that maps the object's stored path to its true location in the drawing

 Override for real transforms - the default merely returns the identity matrix
 @return a transform */
- (NSAffineTransform*)transform
{
	return [NSAffineTransform transform];
}

/** @brief Apply the transform to the object

 The object's position, size and path are modified by the transform. This is called by the owning
 layer's applyTransformToObjects method. This ignores locked objects.
 @param transform a transform
 */
- (void)applyTransform:(NSAffineTransform*)transform
{
	NSAssert(transform != nil, @"nil transform in [DKDrawableObject applyTransform:]");

	NSPoint p = [transform transformPoint:[self location]];
	[self setLocation:p];

	NSSize size = [transform transformSize:[self size]];
	[self setSize:size];
}

#pragma mark -
#pragma mark - drawing tool information

/** @brief Called by the creation tool when this object has just beeen created by the tool

 FYI - override to make use of this
 @param tool the tool that created this
 @param p the initial point that the tool will start dragging the object from */
- (void)creationTool:(DKDrawingTool*)tool willBeginCreationAtPoint:(NSPoint)p
{
#pragma unused(tool)
#pragma unused(p)

	// override to make use of this event
}

/** @brief Called by the creation tool when this object has finished being created by the tool

 FYI - override to make use of this
 @param tool the tool that created this
 @param p the point that the tool finished dragging the object to */
- (void)creationTool:(DKDrawingTool*)tool willEndCreationAtPoint:(NSPoint)p
{
#pragma unused(tool)
#pragma unused(p)

	// override to make use of this event
}

/** @brief Return whether the object is valid in terms of having a visible, usable state

 Subclasses must override and implement this appropriately. It is called by the object creation tool
 at the end of a creation operation to determine if what was created is in any way useful. Objects that
 cannot be used will not be added to the drawing. The object type needs to decide what constitutes
 validity - for example shapes with zero size or paths with zero length are likely not valid.
 @return YES if valid, NO otherwise
 */
- (BOOL)objectIsValid
{
	return NO;
}

#pragma mark -
#pragma mark - grouping and ungrouping support

/** @brief This object is being added to a group

 Can be overridden if this event is of interest. Note that for grouping, the object doesn't need
 to do anything special - the group takes care of it.
 @param aGroup the group adding the object
 */
- (void)groupWillAddObject:(DKShapeGroup*)aGroup
{
#pragma unused(aGroup)
}

/** @brief This object is being ungrouped from a group

 When ungrouping, an object must help the group to the right thing by resizing, rotating and repositioning
 itself appropriately. At the time this is called, the object has already has its container set to
 the layer it will be added to but has not actually been added. Must be overridden.
 @param aGroup the group containing the object
 @param aTransform the transform that the group is applying to the object to scale rotate and translate it.
 */
- (void)group:(DKShapeGroup*)aGroup willUngroupObjectWithTransform:(NSAffineTransform*)aTransform
{
#pragma unused(aGroup)
#pragma unused(aTransform)

	NSLog(@"*** you should override -group:willUngroupObjectWithTransform: to correctly ungroup '%@' ***", NSStringFromClass([self class]));
}

/** @brief This object was ungrouped from a group

 This is called when the ungrouping operation has finished entirely. The object will belong to its
 original container and have its location, etc set as required. Override to make use of this notification.
 */
- (void)objectWasUngrouped
{
}

/** @brief Some high-level operations substitute a new object in place of an existing one (or several). In
 those cases this should be called to allow the object to do any special substitution work.

 Subclasses should override this to do additional work during a substitution. Note that user info
 and style is handled for you, this does not need to deal with those properties.
 @param obj the original object his is being substituted for
 @param aLayer the layer this will be added to (but is not yet)
 */
- (void)willBeAddedAsSubstituteFor:(DKDrawableObject*)obj toLayer:(DKObjectOwnerLayer*)aLayer
{
#pragma unused(obj, aLayer)
}

#pragma mark -
#pragma mark - snapping to guides, grid and other objects(utility methods)

/** @brief Offset the point to cause snap to grid + guides accoding to the drawing's settings

 DKObjectOwnerLayer + DKDrawing implements the details of this method. The snapControl flag is
 intended to come from a modifier flag - usually <ctrl>.
 @param mp a point which is the proposed location of the shape
 @return a new point which may be offset from the input enough to snap it to the guides and grid */
- (NSPoint)snappedMousePoint:(NSPoint)mp withControlFlag:(BOOL)snapControl
{
	if ([self mouseSnappingEnabled] && [self layer])
		mp = [(DKObjectOwnerLayer*)[self layer] snappedMousePoint:mp
														forObject:self
												  withControlFlag:snapControl];

	return mp;
}

/** @brief Offset the point to cause snap to grid + guides according to the drawing's settings

 Given a proposed location, this modifies it by checking if any of the points returned by the
 object's snappingPoints method will snap. The result can be passed to moveToPoint:
 @param mp a point which is the proposed location of the shape
 @return a new point which may be offset from the input enough to snap it to the guides and grid
 */
- (NSPoint)snappedMousePoint:(NSPoint)mp forSnappingPointsWithControlFlag:(BOOL)snapControl
{
	if ([self mouseSnappingEnabled] && [self drawing]) {
		// factor in snap to grid + guides

		mp = [[self drawing] snapToGrid:mp
						withControlFlag:snapControl];

		NSSize offs;

		offs.width = mp.x - [self location].x;
		offs.height = mp.y - [self location].y;

		NSSize snapOff = [[self drawing] snapPointsToGuide:[self snappingPointsWithOffset:offs]];

		mp.x += snapOff.width;
		mp.y += snapOff.height;
	}

	return mp;
}

#pragma mark -

/** @brief Return an array of NSpoint values representing points that can be snapped to guides
 @return a list of points (NSValues)
 */
- (NSArray*)snappingPoints
{
	return [self snappingPointsWithOffset:NSZeroSize];
}

/** @brief Return an array of NSpoint values representing points that can be snapped to guides

 Snapping points are locations within an object that will snap to a guide. List can be empty.
 @param offset an offset value that is added to each point
 @return a list of points (NSValues)
 */
- (NSArray<NSValue*>*)snappingPointsWithOffset:(NSSize)offset
{
	NSPoint p = [self location];

	p.x += offset.width;
	p.y += offset.height;

	return @[[NSValue valueWithPoint:p]];
}

/** @brief Returns the offset between the mouse point and the shape's location during a drag

 Result is undefined except during a dragging operation
 @return mouse offset during a drag
 */
- (NSSize)mouseOffset
{
	return m_mouseOffset;
}

#pragma mark -
#pragma mark - getting dimensions in drawing coordinates

/** @brief Convert a distance in quartz coordinates to the units established by the drawing grid

 This is a conveniece API to query the drawing's grid layer
 @param len a distance in pixels
 @return the distance in drawing units
 */
- (CGFloat)convertLength:(CGFloat)len
{
	return [[self drawing] convertLength:len];
}

/** @brief Convert a point in quartz coordinates to the units established by the drawing grid

 This is a conveniece API to query the drawing's grid layer
 @param pt a point value
 @return the equivalent point in drawing units
 */
- (NSPoint)convertPointToDrawing:(NSPoint)pt
{
	return [[self drawing] convertPoint:pt];
}

#pragma mark -
#pragma mark - hit testing

/** @brief Hit test the object

 Part codes are private to the object class, except for 0 = nothing hit and -1 = entire object hit.
 for other parts, the object is free to return any code it likes and attach any meaning it wishes.
 the part code is passed back by the mouse event methods but apart from 0 and -1 is never interpreted
 by any other object
 @param pt the mouse location
 @return a part code representing which part of the object got hit, if any
 */
- (NSInteger)hitPart:(NSPoint)pt
{
	if ([self visible]) {
		NSInteger pc = (NSMouseInRect(pt, [self bounds], [[self drawing] isFlipped]) ? kDKDrawingEntireObjectPart : kDKDrawingNoPart);

		if ((pc == kDKDrawingEntireObjectPart) && [self isSelected] && ![self locked])
			pc = [self hitSelectedPart:pt
					  forSnapDetection:NO];

		return pc;
	} else
		return kDKDrawingNoPart; // can never hit invisible objects
}

/** @brief Hit test the object in the selected state

 This is a factoring of the general hitPart: method to allow parts that only come into play when
 selected to be hit tested. It is also used when snapping to objects. Subclasses should override
 for the partcodes they define such as control knobs that operate when selected.
 @param pt the mouse location
 @param snap is YES if called to detect snap, NO otherwise
 @return a part code representing which part of the selected object got hit, if any */
- (NSInteger)hitSelectedPart:(NSPoint)pt forSnapDetection:(BOOL)snap
{
#pragma unused(pt)
#pragma unused(snap)

	return kDKDrawingEntireObjectPart;
}

/** @brief Return the point associated with the part code

 If partcode is no object, returns {-1,-1}, if entire object, return location. Object classes
 should override this to correctly implement it for partcodes they define
 @param pc a valid partcode for this object
 @return the current point associated with the partcode
 */
- (NSPoint)pointForPartcode:(NSInteger)pc
{
	if (pc == kDKDrawingEntireObjectPart)
		return [self location];
	else
		return NSMakePoint(-1, -1);
}

/** @brief Provide a mapping between the object's partcode and a knob type draw for that part

 Knob types are defined by DKKnob, they describe the functional type of the knob, plus the locked
 state. Concrete subclasses should override this unless the default suffices.
 @param pc a valid partcode for this object
 @return a valid knob type
 */
- (DKKnobType)knobTypeForPartCode:(NSInteger)pc
{
#pragma unused(pc)

	DKKnobType result = kDKControlPointKnobType;

	if ([self locked])
		result |= kDKKnobIsDisabledFlag;

	return result;
}

/** @brief Test if a rect encloses any of the shape's actual pixels

 Note this can be an expensive way to test this - eliminate all obvious trivial cases first.
 @param r the rect to test
 @return YES if at least one pixel enclosed by the rect, NO otherwise
 */
- (BOOL)rectHitsPath:(NSRect)r
{
	NSRect ir = NSIntersectionRect(r, [self bounds]);
	BOOL hit = NO;

	if (ir.size.width > 0.0 && ir.size.height > 0.0) {
		// if ir is equal to our bounds, we know that <r> fully encloses this, so there's no need
		// to perform the expensive bitmap test - just return YES. This assumes that the shape draws *something*
		// somewhere within its bounds, which is not unreasonable.

		if (NSEqualRects(ir, [self bounds]))
			return YES;
		else {
			// this method scales the whole hit rect directly down into a 1x1 bitmap context - if it ends up opaque, it's hit. If transparent, it's not.
			// this method suggested by Ken Ferry (Apple), as it avoids the need for writable access to NSBimapImageRep and so should
			// perform best on most graphics architectures. This also doesn't require any style substitution.

			// since the context is always the same, it's also created as a static var, so only one is ever needed. This removes the overhead of
			// creating it for every test - instead we can simply clear the byte each time.

			static CGContextRef bm = NULL;
			static NSGraphicsContext* bitmapContext = nil;
			static uint8_t byte[8]; // includes some unused padding
			static NSRect srcRect = { { 0, 0 }, { 1, 1 } };

			if (bm == NULL) {
				bm = CGBitmapContextCreate(byte, 1, 1, 8, 1, NULL, kCGImageAlphaOnly);
				CGContextSetInterpolationQuality(bm, kCGInterpolationNone);
				CGContextSetShouldAntialias(bm, NO);
				CGContextSetShouldSmoothFonts(bm, NO);
				bitmapContext = [[NSGraphicsContext graphicsContextWithGraphicsPort:bm
																			flipped:YES] retain];
				[bitmapContext setShouldAntialias:NO];
			}

			SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
				[NSGraphicsContext setCurrentContext : bitmapContext];
			byte[0] = 0;

			// flag that hit-testing is taking place - drawing methods may use quick-and-dirty rendering for better performance.

			mIsHitTesting = YES;

			// try using a cached copy of the object's image:
			/*
			NSImage* cachedImage = [self cachedImage];
			
			if( cachedImage )
			{
				NSRect br = [self bounds];
				
				ir = NSOffsetRect( ir, -br.origin.x, -br.origin.y );
				[cachedImage drawInRect:srcRect fromRect:ir operation:NSCompositeSourceOver fraction:1.0];
			}
			else
			 */
			{
				// draw the object but without any shadows - this both speeds up the hit testing which doesn't care about shadows
				// and avoids a nasty crashing bug in Quartz.

				BOOL drawShadows = [DKStyle setWillDrawShadows:NO];
				[self drawContentInRect:srcRect
							   fromRect:ir
							  withStyle:nil];
				[DKStyle setWillDrawShadows:drawShadows];
			}
			mIsHitTesting = NO;

			RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
				hit = (byte[0] != 0);
		}
	}

	return hit;
}

/** @brief Test a point against the offscreen bitmap representation of the shape

 Special case of the rectHitsPath call, which is now the fastest way to perform this test
 @param p the point to test
 @return YES if the point hit the shape's pixels, NO otherwise
 */
- (BOOL)pointHitsPath:(NSPoint)p
{
	if (NSPointInRect(p, [self bounds])) {
		NSRect pr = NSRectCentredOnPoint(p, NSMakeSize(1e-3, 1e-3));
		return [self rectHitsPath:pr];
	} else
		return NO;
}

/** @brief Is a hit-test in progress

 Drawing methods can check this to see if they can take shortcuts to save time when hit-testing.
 This will only return YES during calls to -drawContent etc when invoked by the rectHitsPath method.
 @return YES if hit-testing is taking place, otherwise NO
 */
- (BOOL)isBeingHitTested
{
	return mIsHitTesting;
}

/** @brief Set whether a hit-test in progress

 Applicaitons should not generally use this. It allows certain container classes (e.g. groups) to
 flag the *they* are being hit tested to provide easier hitting of thin objects in groups.
 @param hitTesting YES if hit-testing, NO otherwise
 */
- (void)setBeingHitTested:(BOOL)hitTesting
{
	mIsHitTesting = hitTesting;
}

#pragma mark -
#pragma mark - basic event handling

/** @brief The mouse went down in this object

 Default method records the mouse offset, but otherwise you will override to make use of this
 @param mp the mouse point (already converted to the relevant view - gives drawing relative coordinates)
 @param partcode the partcode that was returned by hitPart if non-zero.
 @param evt the original event
 */
- (void)mouseDownAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt
{
#pragma unused(evt, partcode)

	m_mouseOffset.width = mp.x - [self location].x;
	m_mouseOffset.height = mp.y - [self location].y;
	[self setMouseHasMovedSinceStartOfTracking:NO];
	[self setTrackingMouse:YES];
}

/** @brief The mouse is dragging within this object

 Default method moves the entire object, and snaps to grid and guides if enabled. Control key disables
 snapping temporarily.
 @param mp the mouse point (already converted to the relevant view - gives drawing relative coordinates)
 @param partcode the partcode that was returned by hitPart if non-zero.
 @param evt the original event
 */
- (void)mouseDraggedAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt
{
#pragma unused(partcode)

	if (![self locationLocked]) {
		mp.x -= [self mouseDragOffset].width;
		mp.y -= [self mouseDragOffset].height;

		BOOL controlKey = (([evt modifierFlags] & NSControlKeyMask) != 0);
		mp = [self snappedMousePoint:mp
			forSnappingPointsWithControlFlag:controlKey];

		[self setLocation:mp];
		[self setMouseHasMovedSinceStartOfTracking:YES];
	}
}

/** @brief The mouse went up in this object
 @param mp the mouse point (already converted to the relevant view - gives drawing relative coordinates)
 @param partcode the partcode that was returned by hitPart if non-zero.
 @param evt the original event
 */
- (void)mouseUpAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt
{
#pragma unused(mp)
#pragma unused(partcode)
#pragma unused(evt)

	if ([self mouseHasMovedSinceStartOfTracking]) {
		[[self undoManager] setActionName:NSLocalizedString(@"Move", @"undo string for move object")];
		[self setMouseHasMovedSinceStartOfTracking:NO];
	}

	[self setTrackingMouse:NO];
}

/** @brief Get the view currently drawing or passing events to this

 The view is only meaningful when called from within a drawing or event handling method.
 */
- (NSView*)currentView
{
	return [[self layer] currentView];
}

/** @brief Return the cursor displayed when a given partcode is hit or entered

 The cursor may be displayed when the mouse hovers over or is clicked in the area indicated by the
 partcode. The default is simply to return the standard arrow - override for others.
 @param partcode the partcode
 @param button YES if the mouse left button is pressed, NO otherwise
 @return a cursor object
 */
- (NSCursor*)cursorForPartcode:(NSInteger)partcode mouseButtonDown:(BOOL)button
{
#pragma unused(partcode)
#pragma unused(button)

	return [NSCursor arrowCursor];
}

/** @brief Inform the object that it was double-clicked

 This is invoked by the select tool and any others that decide to implement it. The object can
 respond however it likes - by default it simply broadcasts a notification. Override for
 different behaviours.
 @param mp the point where it was clicked
 @param partcode the partcode
 @param evt the original mouse event
 */
- (void)mouseDoubleClickedAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt
{
#pragma unused(partcode, evt)

	NSMutableDictionary* userInfo = [NSMutableDictionary dictionary];
	[userInfo setObject:[NSValue valueWithPoint:mp]
				 forKey:kDKDrawableClickedPointKey];

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawableDoubleClickNotification
														object:self
													  userInfo:userInfo];

	// notify the layer directly

	[[self layer] drawable:self
		wasDoubleClickedAtPoint:mp];
}

#pragma mark -
#pragma mark - contextual menu

/** @brief Reurn the menu to use as the object's contextual menu

 The menu is obtained via DKAuxiliaryMenus helper object which in turn loads the menu from a nib,
 overridable by the app. This is the preferred method of supplying the menu. It doesn't need to
 be overridden by subclasses generally speaking, since all menu customisation per class is done in
 the nib.
 @return the menu
 */
- (NSMenu*)menu
{
	return [[[DKAuxiliaryMenus auxiliaryMenus] copyMenuForClass:[self class]] autorelease];
}

/** @brief Allows the object to populate the menu with commands that are relevant to its current state and type

 The default method adds commands to copy and paste the style
 @param theMenu a menu - add items and commands to it as required
 @return YES if any items were added, NO otherwise.
 */
- (BOOL)populateContextualMenu:(NSMenu*)theMenu
{
	// if the object supports any contextual menu commands, it should add them to the menu and return YES. If subclassing,
	// you would usually call the inherited method first so that the menu is the union of all the ancestor's added methods.

	[[theMenu addItemWithTitle:NSLocalizedString(@"Copy Style", @"menu item for copy style")
						action:@selector(copyDrawingStyle:)
				 keyEquivalent:@""] setTarget:self];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Paste Style", @"menu item for paste style")
						action:@selector(pasteDrawingStyle:)
				 keyEquivalent:@""] setTarget:self];

	if ([self locked])
		[[theMenu addItemWithTitle:NSLocalizedString(@"Unlock", @"menu item for unlock")
							action:@selector(unlock:)
					 keyEquivalent:@""] setTarget:self];
	else
		[[theMenu addItemWithTitle:NSLocalizedString(@"Lock", @"menu item for lock")
							action:@selector(lock:)
					 keyEquivalent:@""] setTarget:self];

	return YES;
}

/** @brief Allows the object to populate the menu with commands that are relevant to its current state and type

 The default method adds commands to copy and paste the style. This method allows the point to
 be used by subclasses to refine the menu for special areas within the object.
 @param theMenu a menu - add items and commands to it as required
 @param localPoint the point in local (view) coordinates where the menu click went down
 @return YES if any items were added, NO otherwise.
 */
- (BOOL)populateContextualMenu:(NSMenu*)theMenu atPoint:(NSPoint)localPoint
{
#pragma unused(localPoint)

	return [self populateContextualMenu:theMenu];
}

#pragma mark -
#pragma mark - swatch

/** @brief Returns an image of this object rendered using its current style and path

 If size is NSZeroRect, uses the current bounds size
 @param size desired size of the image - shape is scaled to fit in this size
 @return the image
 */
- (NSImage*)swatchImageWithSize:(NSSize)size
{
	if (NSEqualSizes(size, NSZeroSize))
		size = [self bounds].size;

	if (!NSEqualSizes(size, NSZeroSize)) {
		NSImage* image = [[NSImage alloc] initWithSize:size];
		[image setFlipped:YES];
		[image lockFocus];

		[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceOver];
		NSRect destRect = NSMakeRect(0, 0, size.width, size.height);

		[self drawContentInRect:destRect
					   fromRect:NSZeroRect
					  withStyle:nil];
		[image unlockFocus];
		[image setFlipped:NO];

		return [image autorelease];
	} else
		return nil;
}

#pragma mark -
#pragma mark - user info

/** @brief Attach a dictionary of metadata to the object

 The dictionary replaces the current user info. To merge with any existing user info, use addUserInfo:
 @param info a dictionary containing anything you wish
 */
- (void)setUserInfo:(NSDictionary*)info
{
	if (mUserInfo == nil)
		mUserInfo = [[NSMutableDictionary alloc] init];

	[mUserInfo setDictionary:info];
	[self notifyStatusChange];
}

/** @brief Add a dictionary of metadata to the object

 <info> is merged with the existin gcontent of the user info
 @param info a dictionary containing anything you wish
 */
- (void)addUserInfo:(NSDictionary*)info
{
	if (mUserInfo == nil)
		mUserInfo = [[NSMutableDictionary alloc] init];

	NSDictionary* deepCopy = [info deepCopy];

	[mUserInfo addEntriesFromDictionary:deepCopy];
	[deepCopy release];
	[self notifyStatusChange];
}

/** @brief Return the attached user info

 The user info is returned as a mutable dictionary (which it is), and can thus have its contents
 mutated directly for certain uses. Doing this cannot cause any notification of the status of
 the object however.
 @return the user info
 */
- (NSMutableDictionary*)userInfo
{
	return mUserInfo;
}

/** @brief Return an item of user info
 @param key the key to use to refer to the item
 @return the user info item
 */
- (id)userInfoObjectForKey:(NSString*)key
{
	return [[self userInfo] objectForKey:key];
}

/** @brief Set an item of user info
 @param obj the object to store
 @param key the key to use to refer to the item
 */
- (void)setUserInfoObject:(id)obj forKey:(NSString*)key
{
	NSAssert(obj != nil, @"cannot add nil to the user info");
	NSAssert(key != nil, @"user info key can't be nil");

	if (mUserInfo == nil)
		mUserInfo = [[NSMutableDictionary alloc] init];

	[mUserInfo setObject:obj
				  forKey:key];
	[self notifyStatusChange];
}

#pragma mark -
#pragma mark - pasteboard

/** @brief Write additional data to the pasteboard specific to the object

 The owning layer generally handles the case of writing the selected objects to the pasteboard but
 sometimes an object might wish to supplement that data. For example a text-bearing object might
 add the text to the pasteboard. This is only invoked when the object is the only object selected.
 The default method does nothing - override to make use of this. Also, your override must declare
 the types it's writing using addTypes:owner:
 @param pb the pasteboard to write to
 */
- (void)writeSupplementaryDataToPasteboard:(NSPasteboard*)pb
{
#pragma unused(pb)
	// override to make use of
}

/** @brief Read additional data from the pasteboard specific to the object

 This is invoked by the owning layer after an object has been pasted. Override to make use of. Note
 that this is not necessarily symmetrical with -writeSupplementaryDataToPasteboard: depending on
 what data types the other method actually wrote. For example standard text would not normally
 need to be handled as a special case.
 @param pb the pasteboard to read from
 */
- (void)readSupplementaryDataFromPasteboard:(NSPasteboard*)pb
{
#pragma unused(pb)
	// override to make use of
}

#pragma mark -
#pragma mark - user level commands that can be responded to by this object(and its subclasses)

/** @brief Copies the object's style to the general pasteboard
 @param sender the action's sender
 */
- (IBAction)copyDrawingStyle:(id)sender
{
#pragma unused(sender)

	// allows the attached style to be copied to the clipboard.

	if ([self style] != nil) {
		[[NSPasteboard generalPasteboard] declareTypes:@[]
												 owner:self];
		[[self style] copyToPasteboard:[NSPasteboard generalPasteboard]];
	}
}

/** @brief Pastes a style from the general pasteboard onto the object

 Attempts to maintain shared styles by using the style's name initially.
 @param sender the action's sender
 */
- (IBAction)pasteDrawingStyle:(id)sender
{
#pragma unused(sender)

	if (![self locked]) {
		DKStyle* style = [DKStyle styleFromPasteboard:[NSPasteboard generalPasteboard]];

		if (style != nil) {
			[self setStyle:style];
			[[self undoManager] setActionName:NSLocalizedString(@"Paste Style", "undo string for object paste style")];
		}
	}
}

- (IBAction)lock:(id)sender
{
#pragma unused(sender)
	if (![self locked]) {
		[self setLocked:YES];
	}
}

- (IBAction)unlock:(id)sender
{
#pragma unused(sender)
	if ([self locked]) {
		[self setLocked:NO];
	}
}

- (IBAction)lockLocation:(id)sender
{
#pragma unused(sender)
	if (![self locationLocked]) {
		[self setLocationLocked:YES];
		[[self undoManager] setActionName:NSLocalizedString(@"Lock Location", @"undo action for single object lock location")];
	}
}

- (IBAction)unlockLocation:(id)sender
{
#pragma unused(sender)
	if ([self locationLocked]) {
		[self setLocationLocked:NO];
		[[self undoManager] setActionName:NSLocalizedString(@"Unlock Location", @"undo action for single object unlock location")];
	}
}

#ifdef qIncludeGraphicDebugging
#pragma mark -
#pragma mark - debugging

- (IBAction)toggleShowBBox:(id)sender
{
#pragma unused(sender)

	m_showBBox = !m_showBBox;
	[self notifyVisualChange];
}

- (IBAction)toggleClipToBBox:(id)sender
{
#pragma unused(sender)

	m_clipToBBox = !m_clipToBBox;
	[self notifyVisualChange];
}

- (IBAction)toggleShowPartcodes:(id)sender
{
#pragma unused(sender)

	m_showPartcodes = !m_showPartcodes;
	[self notifyVisualChange];
}

- (IBAction)toggleShowTargets:(id)sender
{
#pragma unused(sender)

	m_showTargets = !m_showTargets;
	[self notifyVisualChange];
}

- (IBAction)logDescription:(id)sender
{
#pragma unused(sender)
	NSLog(@"%@", self);
}

#endif

#pragma mark -
#pragma mark As an NSObject
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if (m_style != nil) {
		[m_style styleWillBeRemoved:self];
		[m_style release];
	}
	[mUserInfo release];
	[mRenderingCache release];
	[super dealloc];
}

- (instancetype)init
{
	return [self initWithStyle:[DKStyle defaultStyle]];
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"%@ size: %@, loc: %@, angle: %.4f, offset: %@, locked: %@, style: %@, container: %p, storage: %@, user info:%@",
									  [super description],
									  NSStringFromSize([self size]),
									  NSStringFromPoint([self location]),
									  [self angle],
									  NSStringFromSize([self offset]),
									  [self locked] ? @"YES" : @"NO",
									  [self style],
									  [self container],
									  [self storage],
									  [self userInfo]];
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");

	[coder encodeConditionalObject:[self container]
							forKey:@"container"];
	[coder encodeObject:[self style]
				 forKey:@"style"];
	[coder encodeObject:[self userInfo]
				 forKey:@"userinfo"];

	[coder encodeBool:[self visible]
			   forKey:@"visible"];
	[coder encodeBool:[self locked]
			   forKey:@"locked"];
	[coder encodeInteger:mZIndex
				  forKey:@"DKDrawableObject_zIndex"];
	[coder encodeBool:[self isGhosted]
			   forKey:@"DKDrawable_ghosted"];
	[coder encodeBool:[self locationLocked]
			   forKey:@"DKDrawable_locationLocked"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	//	LogEvent_(kFileEvent, @"decoding drawable object %@", self);

	self = [self initWithStyle:nil];
	if (self != nil) {
		[self setContainer:[coder decodeObjectForKey:@"container"]];

		// if container is nil, as it could be for very old test files, set it to the same value as the owner.
		// for groups this is incorrect and the file won't open correctly.

		if ([self container] == nil) {
			// more recent older files wrote this key as "parent" - try that

			[self setContainer:[coder decodeObjectForKey:@"parent"]];
		}
		[self setStyle:[coder decodeObjectForKey:@"style"]];
		[self setUserInfo:[coder decodeObjectForKey:@"userinfo"]];
		[self updateMetadataKeys];

		[self setVisible:[coder decodeBoolForKey:@"visible"]];
		mZIndex = [coder decodeIntegerForKey:@"DKDrawableObject_zIndex"];
		m_snapEnable = YES;

		[self setGhosted:[coder decodeBoolForKey:@"DKDrawable_ghosted"]];

		// lock and location lock is not set here, as it prevents subclasses from setting other properties when dearchiving
		// see -awakeAfterUsingCoder:
	}
	return self;
}

- (id)awakeAfterUsingCoder:(NSCoder*)coder
{
	[self setLocationLocked:[coder decodeBoolForKey:@"DKDrawable_locationLocked"]];
	[self setLocked:[coder decodeBoolForKey:@"locked"]];

	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
	DKDrawableObject* copy = [[[self class] allocWithZone:zone] init];

	[copy setContainer:nil]; // we don't know who will own the copy

	DKStyle* styleCopy = [[self style] copy];
	[copy setStyle:styleCopy]; // style will be shared if set to be shared, otherwise copied
	[styleCopy release];

	// ghost setting is copied but lock states are not

	[copy setGhosted:[self isGhosted]];

	// gets a deep copy of the user info

	if ([self userInfo] != nil) {
		NSDictionary* ucopy = [[self userInfo] deepCopy];
		[copy setUserInfo:ucopy];
		[ucopy release];
	}

	return copy;
}

#pragma mark -
#pragma mark As part of NSMenuValidation Protocol
- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	SEL action = [item action];

	if (![self locked]) {
		if (action == @selector(pasteDrawingStyle:)) {
			BOOL canPaste = [DKStyle canInitWithPasteboard:[NSPasteboard generalPasteboard]];
			NSString* itemTitle = NSLocalizedString(@"Paste Style", nil);

			if (canPaste) {
				DKStyle* theStyle = [DKStyle styleFromPasteboard:[NSPasteboard generalPasteboard]];
				NSString* name = [theStyle name];

				if (name && [name length] > 0)
					itemTitle = [NSString stringWithFormat:NSLocalizedString(@"Paste Style '%@'", nil), name];

				// don't bother pasting the same style we already have

				if ([theStyle isEqualToStyle:[self style]])
					canPaste = NO;
			}
			[item setTitle:itemTitle];
			return canPaste;
		}
	}

	// even locked objects can have their style copied

	if (action == @selector(copyDrawingStyle:)) {
		DKStyle* theStyle = [self style];
		NSString* itemTitle = NSLocalizedString(@"Copy Style", nil);

		if (theStyle) {
			NSString* name = [theStyle name];
			if (name && [name length] > 0)
				itemTitle = [NSString stringWithFormat:NSLocalizedString(@"Copy Style '%@'", nil), name];
		}
		[item setTitle:itemTitle];
		return (theStyle != nil);
	}

	if (action == @selector(lock:))
		return ![self locked];

	if (action == @selector(unlock:))
		return [self locked];

	if (action == @selector(lockLocation:))
		return ![self locationLocked] && ![self locked];

	if (action == @selector(unlockLocation:))
		return [self locationLocked] && ![self locked];

#ifdef qIncludeGraphicDebugging
	if (action == @selector(toggleShowBBox:) || action == @selector(toggleClipToBBox:) || action == @selector(toggleShowTargets:) || action == @selector(toggleShowPartcodes:)) {
		// set a checkmark next to those that are turned on

		if (action == @selector(toggleShowBBox:))
			[item setState:m_showBBox ? NSOnState : NSOffState];
		else if (action == @selector(toggleClipToBBox:))
			[item setState:m_clipToBBox ? NSOnState : NSOffState];
		else if (action == @selector(toggleShowTargets:))
			[item setState:m_showTargets ? NSOnState : NSOffState];
		else if (action == @selector(toggleShowPartcodes:))
			[item setState:m_showPartcodes ? NSOnState : NSOffState];

		return YES;
	}

	if (action == @selector(logDescription:))
		return YES;

#endif

	return NO;
}

#pragma mark -
#pragma mark - as an implementer of the DKRenderable protocol

/** @brief Return the full extent of the object within the drawing, including any decoration, etc.

 The object must draw only within its declared bounds. If it draws outside of this, it will leave
 trails and debris when moved, rotated or scaled. All style-based decoration must be contained within
 bounds. The style has the method -extraSpaceNeeded to help you determine the correct bounds.
 subclasses must override this and return a valid, sensible bounds rect
 @return the full bounds of the object
 */
- (NSRect)bounds
{
	NSLog(@"!!! 'bounds' must be overridden by subclasses of DKDrawableObject (culprit = %@)", self);

	return NSZeroRect;
}

/** @brief Returns the extra space needed to display the object graphically. This will usually be the difference
 between the logical and reported bounds.
 @return the extra space required
 */
- (NSSize)extraSpaceNeeded
{
	if ([self style])
		return [[self style] extraSpaceNeeded];
	else
		return NSMakeSize(0, 0);
}

/** @brief Return the container's transform

 The container transform must be taken into account for rendering this object, as it accounts for
 groups and other possible containers.
 @return a transform */
- (NSAffineTransform*)containerTransform
{
	NSAffineTransform* ct = [[self container] renderingTransform];

	if (ct == nil)
		return [NSAffineTransform transform];
	else
		return ct;
}

/** @brief Return the path that represents the final user-visible path of the drawn object

 The default method does nothing. Subclasses should override this and supply the appropriate path,
 which is the one requested by a renderer when the object is actually drawn. See also the
 DKRasterizerProtocol, which makes use of this.
 @return the object's path
 */
- (NSBezierPath*)renderingPath
{
	return nil;
}

/** @brief Return hint to rasterizers that low quality drawing should be used

 Part of the informal rendering protocol used by rasterizers
 @return YES to use low quality drawing, no otherwise
 */
- (BOOL)useLowQualityDrawing
{
	return [[self drawing] lowRenderingQuality];
}

/** @brief Return a number that changes when any aspect of the geometry changes. This can be used to detect
 that a change has taken place since an earlier time.

 Do not rely on what the number is, only whether it has changed. Also, do not persist it in any way.
 @return a number
 */
- (NSUInteger)geometryChecksum
{
	NSUInteger cd = 282735623; // arbitrary
	NSPoint loc;
	NSSize size;
	CGFloat angle;
	NSSize offset;

	loc = [self location];
	size = [self size];
	angle = [self angleInDegrees] * 10;
	offset = [self offset];

	cd ^= roundtol(loc.x) ^ roundtol(loc.y) ^ roundtol(size.width) ^ roundtol(size.height) ^ roundtol(angle) ^ roundtol(offset.width) ^ roundtol(offset.height);

	return cd;
}

- (NSMutableDictionary*)renderingCache
{
	return mRenderingCache;
}

@end
