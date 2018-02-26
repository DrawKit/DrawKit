/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawableObject.h"
#import "DKAuxiliaryMenus.h"
#import "DKDrawKitMacros.h"
#import "DKDrawableContainerProtocol.h"
#import "DKDrawableObject+Metadata.h"
#import "DKDrawing.h"
#import "DKGeometryUtilities.h"
#import "DKKnob.h"
#import "DKObjectDrawingLayer+Alignment.h"
#import "DKObjectDrawingLayer.h"
#import "DKPasteboardInfo.h"
#import "DKSelectionPDFView.h"
#import "DKStyle.h"
#import "LogEvent.h"
#import "NSAffineTransform+DKAdditions.h"
#import "NSBezierPath+Combinatorial.h"
#import "NSColor+DKAdditions.h"
#import "NSDictionary+DeepCopy.h"

#ifdef qIncludeGraphicDebugging
#import "DKDrawingView.h"
#include <tgmath.h>
#endif

#pragma mark Contants(Non - localized)
NSString* const kDKDrawableDidChangeNotification = @"kDKDrawableDidChangeNotification";
NSString* const kDKDrawableStyleWillBeDetachedNotification = @"kDKDrawableStyleWillBeDetachedNotification";
NSString* const kDKDrawableStyleWasAttachedNotification = @"kDKDrawableStyleWasAttachedNotification";
NSString* const kDKDrawableDoubleClickNotification = @"kDKDrawableDoubleClickNotification";
NSString* const kDKDrawableSubselectionChangedNotification = @"kDKDrawableSubselectionChangedNotification";

NSString* const kDKDrawableOldStyleKey = @"old_style";
NSString* const kDKDrawableNewStyleKey = @"new_style";
NSString* const kDKDrawableClickedPointKey = @"click_point";

NSString* const kDKGhostColourPreferencesKey = @"kDKGhostColourPreferencesKey";
NSString* const kDKDragFeedbackEnabledPreferencesKey = @"kDKDragFeedbackEnabledPreferencesKey";

NSString* const kDKDrawableCachedImageKey = @"DKD_Cached_Img";

#pragma mark Static vars

static NSColor* s_ghostColour = nil;
static NSDictionary<NSString*, Class>* s_interconversionTable = nil;

#pragma mark -
@implementation DKDrawableObject
#pragma mark As a DKDrawableObject

+ (BOOL)displaysSizeInfoWhenDragging
{
	return ![[NSUserDefaults standardUserDefaults] boolForKey:kDKDragFeedbackEnabledPreferencesKey];
}

+ (void)setDisplaysSizeInfoWhenDragging:(BOOL)doesDisplay
{
	[[NSUserDefaults standardUserDefaults] setBool:!doesDisplay
											forKey:kDKDragFeedbackEnabledPreferencesKey];
}

+ (NSRect)unionOfBoundsOfDrawablesInArray:(NSArray*)array
{
	NSAssert(array != nil, @"array cannot be nil");

	NSRect u = NSZeroRect;

	for (id dko in array) {
		if (![dko isKindOfClass:[DKDrawableObject class]])
			[NSException raise:NSInternalInconsistencyException
						format:@"objects must all derive from DKDrawableObject"];

		u = UnionOfTwoRects(u, [dko bounds]);
	}

	return u;
}

+ (NSArray*)pasteboardTypesForOperation:(DKPasteboardOperationType)op
{
#pragma unused(op)
	return nil;
}

+ (NSInteger)initialPartcodeForObjectCreation
{
	return kDKDrawingNoPart;
}

+ (BOOL)isGroupable
{
	return YES;
}

+ (NSArray*)nativeObjectsFromPasteboard:(NSPasteboard*)pb
{
	NSData* pbdata = [pb dataForType:kDKDrawableObjectPasteboardType];
	NSArray* objects = nil;

	if (pbdata != nil)
		objects = [NSKeyedUnarchiver unarchiveObjectWithData:pbdata];

	return objects;
}

+ (NSUInteger)countOfNativeObjectsOnPasteboard:(NSPasteboard*)pb
{
	DKPasteboardInfo* info = [DKPasteboardInfo pasteboardInfoWithPasteboard:pb];
	return [info count];
}

+ (void)setGhostColour:(NSColor*)ghostColour
{
	s_ghostColour = ghostColour;

	[[NSUserDefaults standardUserDefaults] setObject:[ghostColour hexString]
											  forKey:kDKGhostColourPreferencesKey];
}

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

+ (NSDictionary*)interconversionTable
{
	return s_interconversionTable;
}

+ (void)setInterconversionTable:(NSDictionary*)icTable
{
	s_interconversionTable = [icTable copy];
}

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
	} else
		[NSException raise:NSInternalInconsistencyException
					format:@"you must only substitute a subclass for the base class"];
}

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

- (DKObjectOwnerLayer*)layer
{
	return (DKObjectOwnerLayer*)[[self container] layer];
}

- (DKDrawing*)drawing
{
	return [[self container] drawing];
}

- (NSUndoManager*)undoManager
{
	return [[self drawing] undoManager];
}

@synthesize container = mContainerRef;

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

- (NSUInteger)indexInContainer
{
	if ([[self container] respondsToSelector:@selector(indexOfObject:)])
		return [[self container] indexOfObject:self];
	else
		return NSNotFound;
}

#pragma mark -
#pragma mark - as part of the DKStorableObject protocol

@synthesize index = mZIndex;
@synthesize storage = mStorageRef;
@synthesize marked = mMarked;

#pragma mark -
#pragma mark - state

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

@synthesize visible = m_visible;

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

@synthesize locked = m_locked;

- (void)setLocationLocked:(BOOL)lockLocation
{
	if (mLocationLocked != lockLocation) {
		[[[self undoManager] prepareWithInvocationTarget:self] setLocationLocked:mLocationLocked];
		mLocationLocked = lockLocation;
		[self notifyVisualChange]; // on the assumption that the state is shown differently
		[self notifyStatusChange];
	}
}

@synthesize locationLocked = mLocationLocked;
@synthesize mouseSnappingEnabled = m_snapEnable;

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

@synthesize ghosted = mGhosted;
@synthesize trackingMouse = m_inMouseOp;
@synthesize mouseDragOffset = m_mouseOffset;
@synthesize mouseHasMovedSinceStartOfTracking = m_mouseEverMoved;

#pragma mark -

- (BOOL)isSelected
{
	return [(DKObjectDrawingLayer*)[self layer] isSelectedObject:self];
}

- (void)objectDidBecomeSelected
{
	[self notifyStatusChange];
	[self updateRulerMarkers];
}

- (void)objectIsNoLongerSelected
{
	[self notifyStatusChange];

	// override to make use of this notification
}

- (BOOL)objectMayBecomeSelected
{
	return YES;
}

- (BOOL)isPendingObject
{
	return [[self layer] pendingObject] == self;
}

- (BOOL)isKeyObject
{
	return [(DKObjectDrawingLayer*)[self layer] keyObject] == self;
}

- (NSSet*)subSelection
{
	return [NSSet setWithObject:self];
}

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

- (void)objectWasRemovedFromLayer:(DKObjectOwnerLayer*)aLayer
{
#pragma unused(aLayer)

	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:nil
												  object:[self style]];
}

#pragma mark -
#pragma mark - drawing

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

- (void)drawContentWithStyle:(DKStyle*)aStyle
{
	if ([self isGhosted])
		[self drawGhostedContent];
	else if (aStyle && ([aStyle countOfRenderList] > 0 || [aStyle hasTextAttributes])) {
		@try {
			[aStyle render:self];
		}
		@catch (id exc) {
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
		}
	}
}

- (void)drawGhostedContent
{
	[[[self class] ghostColour] set];
	NSBezierPath* rp = [self renderingPath];
	[rp setLineWidth:0];
	[rp stroke];
}

- (void)drawSelectedState
{
	// placeholder - override to implement this
}

- (void)drawSelectionPath:(NSBezierPath*)path
{
	if ([self locked])
		[[NSColor lightGrayColor] set];
	else
		[[[self layer] selectionColour] set];

	[path setLineWidth:0.0];
	[path stroke];
}

- (void)notifyVisualChange
{
	if ([self layer])
		[[self layer] drawable:self
			needsDisplayInRect:[self bounds]];
}

- (void)notifyStatusChange
{
	[[self drawing] objectDidNotifyStatusChange:self];
}

- (void)notifyGeometryChange:(NSRect)oldBounds
{
	if (!NSEqualRects(oldBounds, [self bounds])) {
		[self invalidateRenderingCache];
		[[self storage] object:self
			didChangeBoundsFrom:oldBounds];
		[self updateRulerMarkers];
	}
}

- (void)updateRulerMarkers
{
	[[self layer] updateRulerMarkersForRect:[self logicalBounds]];
}

- (void)setNeedsDisplayInRect:(NSRect)rect
{
	[[self layer] drawable:self
		needsDisplayInRect:rect];
}

- (void)setNeedsDisplayInRects:(NSSet*)setOfRects
{
	[[self layer] drawable:self
		needsDisplayInRect:NSZeroRect];
	[[self layer] setNeedsDisplayInRects:setOfRects];
}

- (void)setNeedsDisplayInRects:(NSSet*)setOfRects withExtraPadding:(NSSize)padding
{
	[[self layer] drawable:self
		needsDisplayInRect:NSZeroRect];
	[[self layer] setNeedsDisplayInRects:setOfRects
						withExtraPadding:padding];
}

#pragma mark -
#pragma mark - specialised drawing methods

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
		[NSBezierPath clipRect:destRect];

	// compute the necessary transform to perform the scaling and translation from srcRect to destRect.

	NSAffineTransform* tfm = [NSAffineTransform transform];
	[tfm mapFrom:srcRect
			  to:destRect];
	[tfm concat];

	[self drawContent];
	RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
}

- (NSData*)pdf
{
	NSRect frame = NSZeroRect;
	frame.size = [[self drawing] drawingSize];

	DKDrawablePDFView* pdfView = [[DKDrawablePDFView alloc] initWithFrame:frame
																   object:self];

	NSData* pdfData = [pdfView dataWithPDFInsideRect:[self bounds]];

	return pdfData;
}

#pragma mark -
#pragma mark - style

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

		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[self style], kDKDrawableOldStyleKey, newStyle, kDKDrawableNewStyleKey, nil];

		if ([self layer])
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawableStyleWillBeDetachedNotification
																object:self
															  userInfo:userInfo];

		[m_style styleWillBeRemoved:self];
		m_style = newStyle;

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
}

@synthesize style = m_style;

static NSRect s_oldBounds;

- (void)styleWillChange:(NSNotification*)note
{
	if ([note object] == [self style]) {
		s_oldBounds = [self bounds];
		[self notifyVisualChange];
	}
}

- (void)styleDidChange:(NSNotification*)note
{
	if ([note object] == [self style]) {
		[self notifyVisualChange];
		[self notifyGeometryChange:s_oldBounds];
	}
}

- (NSSet*)allStyles
{
	if ([self style] != nil)
		return [NSSet setWithObject:[self style]];
	else
		return nil;
}

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

- (void)replaceMatchingStylesFromSet:(NSSet*)aSet
{
	NSAssert(aSet != nil, @"style set was nil");

	if ([self style] != nil) {
		for (DKStyle* st in aSet) {
			if ([[st uniqueKey] isEqualToString:[[self style] uniqueKey]]) {
				LogEvent_(kStateEvent, @"replacing style with %@ '%@'", st, [st name]);

				[self setStyle:st];
				break;
			}
		}
	}
}

- (void)detachStyle
{
	if ([[self style] isStyleSharable]) {
		DKStyle* detachedStyle = [[self style] mutableCopy];

		[detachedStyle setStyleSharable:NO];
		[self setStyle:detachedStyle];
	}
}

#pragma mark -
#pragma mark - geometry

- (void)setSize:(NSSize)size
{
#pragma unused(size)
}

- (NSSize)size
{
	NSLog(@"!!! 'size' must be overridden by subclasses of DKDrawableObject (culprit = %@)", NSStringFromClass([self class]));

	return NSZeroSize;
}

- (void)resizeWidthBy:(CGFloat)xFactor heightBy:(CGFloat)yFactor
{
	NSAssert(xFactor > 0.0, @"x scale must be greater than 0");
	NSAssert(yFactor > 0.0, @"y scale must be greater than 0");

	NSSize newSize = [self size];

	newSize.width *= xFactor;
	newSize.height *= yFactor;

	[self setSize:newSize];
}

- (NSRect)apparentBounds
{
	return [self bounds];
}

- (NSRect)logicalBounds
{
	return [self bounds];
}

#pragma mark -

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

- (void)setLocation:(NSPoint)p
{
#pragma unused(p)

	NSLog(@"**** You must override -setLocation: for the object %@ ****", NSStringFromClass([self class]));
}

- (void)offsetLocationByX:(CGFloat)dx byY:(CGFloat)dy
{
	if (dx != 0 || dy != 0) {
		NSPoint loc = [self location];

		loc.x += dx;
		loc.y += dy;

		[self setLocation:loc];
	}
}

- (NSPoint)location
{
	return [self logicalBounds].origin;
}

- (CGFloat)angle
{
	return 0.0;
}

- (void)setAngle:(CGFloat)angle
{
#pragma unused(angle)
}

- (CGFloat)angleInDegrees
{
	CGFloat angle = RADIANS_TO_DEGREES([self angle]);

	if (angle < 0)
		angle += 360.0;

	return fmod(angle, 360.0);
}

- (void)rotateByAngle:(CGFloat)da
{
	if (da != 0)
		[self setAngle:[self angle] + da];
}

- (void)invalidateRenderingCache
{
	[mRenderingCache removeAllObjects];
}

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

- (void)setOffset:(NSSize)offs
{
#pragma unused(offs)

	// placeholder
}

- (NSSize)offset
{
	return NSZeroSize;
}

- (void)resetOffset
{
}

- (NSAffineTransform*)transform
{
	return [NSAffineTransform transform];
}

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

- (void)creationTool:(DKDrawingTool*)tool willBeginCreationAtPoint:(NSPoint)p
{
#pragma unused(tool)
#pragma unused(p)

	// override to make use of this event
}

- (void)creationTool:(DKDrawingTool*)tool willEndCreationAtPoint:(NSPoint)p
{
#pragma unused(tool)
#pragma unused(p)

	// override to make use of this event
}

- (BOOL)objectIsValid
{
	return NO;
}

#pragma mark -
#pragma mark - grouping and ungrouping support

- (void)groupWillAddObject:(DKShapeGroup*)aGroup
{
#pragma unused(aGroup)
}

- (void)group:(DKShapeGroup*)aGroup willUngroupObjectWithTransform:(NSAffineTransform*)aTransform
{
#pragma unused(aGroup)
#pragma unused(aTransform)

	NSLog(@"*** you should override -group:willUngroupObjectWithTransform: to correctly ungroup '%@' ***", NSStringFromClass([self class]));
}

- (void)objectWasUngrouped
{
}

- (void)willBeAddedAsSubstituteFor:(DKDrawableObject*)obj toLayer:(DKObjectOwnerLayer*)aLayer
{
#pragma unused(obj, aLayer)
}

#pragma mark -
#pragma mark - snapping to guides, grid and other objects(utility methods)

- (NSPoint)snappedMousePoint:(NSPoint)mp withControlFlag:(BOOL)snapControl
{
	if ([self mouseSnappingEnabled] && [self layer])
		mp = [(DKObjectOwnerLayer*)[self layer] snappedMousePoint:mp
														forObject:self
												  withControlFlag:snapControl];

	return mp;
}

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

- (NSArray*)snappingPoints
{
	return [self snappingPointsWithOffset:NSZeroSize];
}

- (NSArray<NSValue*>*)snappingPointsWithOffset:(NSSize)offset
{
	NSPoint p = [self location];

	p.x += offset.width;
	p.y += offset.height;

	return @[[NSValue valueWithPoint:p]];
}

- (NSSize)mouseOffset
{
	return m_mouseOffset;
}

#pragma mark -
#pragma mark - getting dimensions in drawing coordinates

- (CGFloat)convertLength:(CGFloat)len
{
	return [[self drawing] convertLength:len];
}

- (NSPoint)convertPointToDrawing:(NSPoint)pt
{
	return [[self drawing] convertPoint:pt];
}

#pragma mark -
#pragma mark - hit testing

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

- (NSInteger)hitSelectedPart:(NSPoint)pt forSnapDetection:(BOOL)snap
{
#pragma unused(pt)
#pragma unused(snap)

	return kDKDrawingEntireObjectPart;
}

- (NSPoint)pointForPartcode:(NSInteger)pc
{
	if (pc == kDKDrawingEntireObjectPart)
		return [self location];
	else
		return NSMakePoint(-1, -1);
}

- (DKKnobType)knobTypeForPartCode:(NSInteger)pc
{
#pragma unused(pc)

	DKKnobType result = kDKControlPointKnobType;

	if ([self locked])
		result |= kDKKnobIsDisabledFlag;

	return result;
}

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
				bitmapContext = [NSGraphicsContext graphicsContextWithGraphicsPort:bm
																		   flipped:YES];
				[bitmapContext setShouldAntialias:NO];
			}

			SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
				[NSGraphicsContext setCurrentContext:bitmapContext];
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
				hit
				= (byte[0] != 0);
		}
	}

	return hit;
}

- (BOOL)pointHitsPath:(NSPoint)p
{
	if (NSPointInRect(p, [self bounds])) {
		NSRect pr = NSRectCentredOnPoint(p, NSMakeSize(1e-3, 1e-3));
		return [self rectHitsPath:pr];
	} else
		return NO;
}

@synthesize beingHitTested = mIsHitTesting;

#pragma mark -
#pragma mark - basic event handling

- (void)mouseDownAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt
{
#pragma unused(evt, partcode)

	m_mouseOffset.width = mp.x - [self location].x;
	m_mouseOffset.height = mp.y - [self location].y;
	[self setMouseHasMovedSinceStartOfTracking:NO];
	[self setTrackingMouse:YES];
}

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

- (NSView*)currentView
{
	return [[self layer] currentView];
}

- (NSCursor*)cursorForPartcode:(NSInteger)partcode mouseButtonDown:(BOOL)button
{
#pragma unused(partcode)
#pragma unused(button)

	return [NSCursor arrowCursor];
}

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

- (NSMenu*)menu
{
	return [[DKAuxiliaryMenus auxiliaryMenus] copyMenuForClass:[self class]];
}

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

- (BOOL)populateContextualMenu:(NSMenu*)theMenu atPoint:(NSPoint)localPoint
{
#pragma unused(localPoint)

	return [self populateContextualMenu:theMenu];
}

#pragma mark -
#pragma mark - swatch

- (NSImage*)swatchImageWithSize:(NSSize)size
{
	if (NSEqualSizes(size, NSZeroSize))
		size = [self bounds].size;

	if (!NSEqualSizes(size, NSZeroSize)) {
		NSImage* image = [[NSImage alloc] initWithSize:size];
		[image lockFocusFlipped:YES];

		[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceOver];
		NSRect destRect = NSMakeRect(0, 0, size.width, size.height);

		[self drawContentInRect:destRect
					   fromRect:NSZeroRect
					  withStyle:nil];
		[image unlockFocus];

		return image;
	} else
		return nil;
}

#pragma mark -
#pragma mark - user info

- (void)setUserInfo:(NSDictionary*)info
{
	if (mUserInfo == nil)
		mUserInfo = [[NSMutableDictionary alloc] init];

	[mUserInfo setDictionary:info];
	[self notifyStatusChange];
}

- (void)addUserInfo:(NSDictionary*)info
{
	if (mUserInfo == nil)
		mUserInfo = [[NSMutableDictionary alloc] init];

	NSDictionary* deepCopy = [info deepCopy];

	[mUserInfo addEntriesFromDictionary:deepCopy];
	[self notifyStatusChange];
}

- (NSMutableDictionary*)userInfo
{
	return mUserInfo;
}

- (id)userInfoObjectForKey:(NSString*)key
{
	return [[self userInfo] objectForKey:key];
}

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

- (void)writeSupplementaryDataToPasteboard:(NSPasteboard*)pb
{
#pragma unused(pb)
	// override to make use of
}

- (void)readSupplementaryDataFromPasteboard:(NSPasteboard*)pb
{
#pragma unused(pb)
	// override to make use of
}

#pragma mark -
#pragma mark - user level commands that can be responded to by this object(and its subclasses)

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
	}
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

	// ghost setting is copied but lock states are not

	[copy setGhosted:[self isGhosted]];

	// gets a deep copy of the user info

	if ([self userInfo] != nil) {
		NSDictionary* ucopy = [[self userInfo] deepCopy];
		[copy setUserInfo:ucopy];
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
	NSLog(@"!!! 'bounds' must be overridden by subclasses of DKDrawableObject (culprit = %@)", NSStringFromClass([self class]));

	return NSZeroRect;
}

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

	cd ^= lround(loc.x) ^ lround(loc.y) ^ lround(size.width) ^ lround(size.height) ^ lround(angle) ^ lround(offset.width) ^ lround(offset.height);

	return cd;
}

- (NSMutableDictionary*)renderingCache
{
	return mRenderingCache;
}

@end
