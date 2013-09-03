///**********************************************************************************************************************************
///  DKLayer.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 11/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import <Cocoa/Cocoa.h>
#import "DKCommonTypes.h"

@class DKDrawing, DKDrawingView, DKLayerGroup, DKDrawableObject, DKKnob, DKStyle, GCInfoFloater;

// generic layer class:

@interface DKLayer : NSObject <NSCoding, DKKnobOwner, NSUserInterfaceValidations>
{
@private
	NSString*				m_name;					// layer name
	NSColor*				m_selectionColour;		// colour preference for selection highlights in this layer
	DKKnob*					m_knobs;				// knobs helper object if set - normally nil to defer to drawing
	BOOL					m_knobsAdjustToScale;	// YES if knobs allow for the view scale
	BOOL					m_visible;				// is the layer visible?
	BOOL					m_locked;				// is the layer locked?
	BOOL					m_printed;				// is the layer drawn when printing?
	BOOL					mRulerMarkersEnabled;	// YES to pass ruler marker updates to enclosing group, NO to ignore
	GCInfoFloater*			m_infoWindow;			// info window instance that can be used by client objects as they wish
	DKLayerGroup*			m_groupRef;				// group we are contained by (or drawing)
	BOOL					m_clipToInterior;		// YES to clip drawing to inside the interior region
	NSMutableDictionary*	mUserInfo;				// metadata
	NSUInteger				mReserved[3];			// unused
	NSString*				mLayerUniqueKey;		// unique ID for the layer
	CGFloat					mAlpha;					// alpha value applied to layer as a whole
}

+ (void)			setSelectionColours:(NSArray*) listOfColours;
+ (NSArray*)		selectionColours;
+ (NSColor*)		selectionColourForIndex:(NSUInteger) index;

// owning drawing:

- (DKDrawing*)		drawing;
- (void)			drawingHasNewUndoManager:(NSUndoManager*) um;
- (void)			drawingDidChangeToSize:(NSValue*) sizeVal;
- (void)			drawingDidChangeMargins:(NSValue*) newInterior;
- (NSUndoManager*)	undoManager;
- (void)			wasAddedToDrawing:(DKDrawing*) aDrawing;

// layer group hierarchy:

- (void)			setLayerGroup:(DKLayerGroup*) group;
- (DKLayerGroup*)	layerGroup;
- (NSUInteger)		indexInGroup;
- (BOOL)			isChildOfGroup:(DKLayerGroup*) aGroup;
- (NSUInteger)		level;

// drawing:

- (void)			drawRect:(NSRect) rect inView:(DKDrawingView*) aView;
- (BOOL)			isOpaque;
- (void)			setNeedsDisplay:(BOOL) update;
- (void)			setNeedsDisplayInRect:(NSRect) rect;
- (void)			setNeedsDisplayInRects:(NSSet*) setOfRects;
- (void)			setNeedsDisplayInRects:(NSSet*) setOfRects withExtraPadding:(NSSize) padding;

- (void)			beginDrawing;
- (void)			endDrawing;

- (void)			setSelectionColour:(NSColor*) colour;
- (NSColor*)		selectionColour;

- (NSImage*)		thumbnailImageWithSize:(NSSize) size;
- (NSImage*)		thumbnail;
- (NSData*)			pdf;
- (BOOL)			writePDFDataToPasteboard:(NSPasteboard*) pb;
- (NSBitmapImageRep*) bitmapRepresentationWithDPI:(NSUInteger) dpi;

- (void)			setClipsDrawingToInterior:(BOOL) clip;
- (BOOL)			clipsDrawingToInterior;

- (void)			setAlpha:(CGFloat) alpha;
- (CGFloat)			alpha;

// managing ruler markers:

- (void)			updateRulerMarkersForRect:(NSRect) rect;
- (void)			hideRulerMarkers;
- (void)			setRulerMarkerUpdatesEnabled:(BOOL) enable;
- (BOOL)			rulerMarkerUpdatesEnabled;

// states:

- (void)			setLocked:(BOOL) locked;
- (BOOL)			locked;
- (void)			setVisible:(BOOL) visible;
- (BOOL)			visible;
- (BOOL)			isActive;
- (BOOL)			lockedOrHidden;

- (void)			setLayerName:(NSString*) name;
- (NSString*)		layerName;

// user info support

- (void)				setUserInfo:(NSMutableDictionary*) info;
- (void)				addUserInfo:(NSDictionary*) info;
- (NSMutableDictionary*)userInfo;
- (id)					userInfoObjectForKey:(NSString*) key;
- (void)				setUserInfoObject:(id) obj forKey:(NSString*) key;

- (NSString*)		uniqueKey;

// print this layer?

- (void)			setShouldDrawToPrinter:(BOOL) printIt;
- (BOOL)			shouldDrawToPrinter;

// becoming/resigning active:

- (BOOL)			layerMayBecomeActive;
- (void)			layerDidBecomeActiveLayer;
- (void)			layerDidResignActiveLayer;

// permitting deleton:

- (BOOL)			layerMayBeDeleted;

// mouse event handling:

- (BOOL)			shouldAutoActivateWithEvent:(NSEvent*) event;
- (BOOL)			hitLayer:(NSPoint) p;
- (DKDrawableObject*)	hitTest:(NSPoint) p;

- (void)			mouseDown:(NSEvent*) event inView:(NSView*) view;
- (void)			mouseDragged:(NSEvent*) event inView:(NSView*) view;
- (void)			mouseUp:(NSEvent*) event inView:(NSView*) view;
- (void)			flagsChanged:(NSEvent*) event;

- (NSView*)			currentView;
- (NSCursor*)		cursor;
- (NSRect)			activeCursorRect;

- (NSMenu *)		menuForEvent:(NSEvent *)theEvent inView:(NSView*) view;

// supporting per-layer knob handling - default defers to the drawing as before

- (void)			setKnobs:(DKKnob*) knobs;
- (DKKnob*)			knobs;
- (void)			setKnobsShouldAdustToViewScale:(BOOL) ka;
- (BOOL)			knobsShouldAdjustToViewScale;

// pasteboard types for drag/drop etc:

- (NSArray*)		pasteboardTypesForOperation:(DKPasteboardOperationType) op;
- (BOOL)			pasteboard:(NSPasteboard*) pb hasAvailableTypeForOperation:(DKPasteboardOperationType) op;

// style utilities (implemented by subclasses such as DKObjectOwnerLayer)

- (NSSet*)			allStyles;
- (NSSet*)			allRegisteredStyles;
- (void)			replaceMatchingStylesFromSet:(NSSet*) aSet;

// info window utilities:

- (void)			showInfoWindowWithString:(NSString*) str atPoint:(NSPoint) p;
- (void)			hideInfoWindow;
- (void)			setInfoWindowBackgroundColour:(NSColor*) colour;

// user actions:

- (IBAction)		lockLayer:(id) sender;
- (IBAction)		unlockLayer:(id) sender;
- (IBAction)		toggleLayerLock:(id) sender;

- (IBAction)		showLayer:(id) sender;
- (IBAction)		hideLayer:(id) sender;
- (IBAction)		toggleLayerVisible:(id) sender;
- (IBAction)		logDescription:(id) sender;
- (IBAction)		copy:(id) sender;

@end

@interface DKLayer	(OptionalMethods)

- (void)			mouseMoved:(NSEvent*) event inView:(NSView*) view;


@end


extern NSString*	kDKLayerLockStateDidChange;
extern NSString*	kDKLayerVisibleStateDidChange;
extern NSString*	kDKLayerNameDidChange;
extern NSString*	kDKLayerSelectionHighlightColourDidChange;

/*

drawing layers are lightweight objects which represent a layer. They are owned by a DKDrawing which manages the
stacking order and invokes the drawRect: method as needed. The other state variables control whether the layer is
visible, locked, etc.

DKDrawing will not ever call a drawRect: on a layer that returns NO for visible.

if isOpaque returns YES, layers that are stacked below this one will not be drawn, even if they are visible. isOpaque
returns NO by default.

locked layers should not be editable, but this must be enforced by subclasses, as this class contains no editing
features. However, locked layers will never receive mouse event calls so generally this will be enough.

As layers are retained by the drawing, this does not retain the drawing.

By definition the bounds of the layer is the same as the bounds of the drawing.


*/
