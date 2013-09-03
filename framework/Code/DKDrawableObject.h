///**********************************************************************************************************************************
///  DKDrawableObject.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 11/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import <Cocoa/Cocoa.h>
#import "DKCommonTypes.h"
#import "DKObjectStorageProtocol.h"
#import "DKRasterizerProtocol.h"
#import "DKDrawableContainerProtocol.h"


@class DKObjectOwnerLayer, DKStyle, DKDrawing, DKDrawingTool, DKShapeGroup;


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

+ (BOOL)				displaysSizeInfoWhenDragging;
+ (void)				setDisplaysSizeInfoWhenDragging:(BOOL) doesDisplay;

+ (NSRect)				unionOfBoundsOfDrawablesInArray:(NSArray*) array;
+ (NSInteger)			initialPartcodeForObjectCreation;
+ (BOOL)				isGroupable;

// ghosting settings:

+ (void)				setGhostColour:(NSColor*) ghostColour;
+ (NSColor*)			ghostColour;

// pasteboard types for drag/drop:

+ (NSArray*)			pasteboardTypesForOperation:(DKPasteboardOperationType) op;
+ (NSArray*)			nativeObjectsFromPasteboard:(NSPasteboard*) pb;
+ (NSUInteger)			countOfNativeObjectsOnPasteboard:(NSPasteboard*) pb;

// interconversion table used when changing one drawable into another - can be customised

+ (NSDictionary*)		interconversionTable;
+ (void)				setInterconversionTable:(NSDictionary*) icTable;
+ (Class)				classForConversionRequestFor:(Class) aClass;
+ (void)				substituteClass:(Class) newClass forClass:(Class) baseClass;

// initializers:

- (id)					initWithStyle:(DKStyle*) aStyle;

// relationships:

- (DKObjectOwnerLayer*)	layer;
- (DKDrawing*)			drawing;
- (NSUndoManager*)		undoManager;
- (id<DKDrawableContainer>)	container;
- (void)				setContainer:(id<DKDrawableContainer>) aContainer;
- (NSUInteger)			indexInContainer;

// state:

- (void)				setVisible:(BOOL) vis;
- (BOOL)				visible;
- (void)				setLocked:(BOOL) locked;
- (BOOL)				locked;
- (void)				setLocationLocked:(BOOL) lockLocation;
- (BOOL)				locationLocked;
- (void)				setMouseSnappingEnabled:(BOOL) ems;
- (BOOL)				mouseSnappingEnabled;
- (void)				setGhosted:(BOOL) ghosted;
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
- (BOOL)				objectMayBecomeSelected;
- (BOOL)				isPendingObject;
- (BOOL)				isKeyObject;

- (NSSet*)				subSelection;

// notification about being added and removed from a layer

- (void)				objectWasAddedToLayer:(DKObjectOwnerLayer*) aLayer;
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
- (NSData*)				pdf;

// style:

- (void)				setStyle:(DKStyle*) aStyle;
- (DKStyle*)			style;
- (void)				styleWillChange:(NSNotification*) note;
- (void)				styleDidChange:(NSNotification*) note;
- (NSSet*)				allStyles;
- (NSSet*)				allRegisteredStyles;
- (void)				replaceMatchingStylesFromSet:(NSSet*) aSet;
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

- (void)				setAngle:(CGFloat) angle;
- (CGFloat)				angle;
- (CGFloat)				angleInDegrees;
- (void)				rotateByAngle:(CGFloat) da;

// relative offset of locus within the object

- (void)				setOffset:(NSSize) offs;
- (NSSize)				offset;
- (void)				resetOffset;

// path transforms

- (NSAffineTransform*)	transform;
- (NSAffineTransform*)	containerTransform;
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

- (void)				groupWillAddObject:(DKShapeGroup*) aGroup;
- (void)				group:(DKShapeGroup*) aGroup willUngroupObjectWithTransform:(NSAffineTransform*) aTransform;
- (void)				objectWasUngrouped;

// post-processing when being substituted for another object (boolean ops, etc)

- (void)				willBeAddedAsSubstituteFor:(DKDrawableObject*) obj toLayer:(DKObjectOwnerLayer*) aLayer;

// snapping to guides, grid and other objects (utility methods)

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
- (BOOL)				rectHitsPath:(NSRect) r;
- (BOOL)				pointHitsPath:(NSPoint) p;
- (BOOL)				isBeingHitTested;
- (void)				setBeingHitTested:(BOOL) hitTesting;

// mouse events:

- (void)				mouseDownAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt;
- (void)				mouseDraggedAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt;
- (void)				mouseUpAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt;
- (NSView*)				currentView;

- (NSCursor*)			cursorForPartcode:(NSInteger) partcode mouseButtonDown:(BOOL) button;
- (void)				mouseDoubleClickedAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt;

// contextual menu:

- (NSMenu*)				menu;
- (BOOL)				populateContextualMenu:(NSMenu*) theMenu;
- (BOOL)				populateContextualMenu:(NSMenu*) theMenu atPoint:(NSPoint) localPoint;

// swatch image of this object:

- (NSImage*)			swatchImageWithSize:(NSSize) size;

// user info:

- (void)				setUserInfo:(NSDictionary*) info;
- (void)				addUserInfo:(NSDictionary*) info;
- (NSMutableDictionary*)userInfo;
- (id)					userInfoObjectForKey:(NSString*) key;
- (void)				setUserInfoObject:(id) obj forKey:(NSString*) key;

// cache management:

- (void)				invalidateRenderingCache;
- (NSImage*)			cachedImage;

// pasteboard:

- (void)				writeSupplementaryDataToPasteboard:(NSPasteboard*) pb;
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

/*
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


