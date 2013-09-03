///**********************************************************************************************************************************
///  DKViewController.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 1/04/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import <Cocoa/Cocoa.h>

@class DKDrawingView, DKDrawing, DKLayer;

// the controller class:

@interface DKViewController : NSObject
{
@private
	NSView*				mViewRef;				// weak ref to the view that is associated with this
	DKDrawing*			mDrawingRef;			// weak ref to the drawing that owns this
	BOOL				m_autoLayerSelect;		// YES to allow mouse to activate layers automatically
	BOOL				mEnableDKMenus;			// YES to enable all standard contextual menus provided by DK.
@protected
	NSEvent*			mDragEvent;				// cached drag event for autoscroll to use
}

// designated initializer

- (id)					initWithView:(NSView*) aView;

// fundamental objects in the controller's world

- (NSView*)				view;
- (DKDrawing*)			drawing;

// updating the view from the drawing (refresh). Note that these are typically invoked via the DKDrawing,
// so you should look there for similarly named methods that take simple types. The object type parameters
// used here allow the drawing to invoke these methods efficiently across multiple controllers.

- (void)				setViewNeedsDisplay:(NSNumber*) updateBoolValue;
- (void)				setViewNeedsDisplayInRect:(NSValue*) updateRectValue;
- (void)				drawingDidChangeToSize:(NSValue*) drawingSizeValue;

- (void)				scrollViewToRect:(NSValue*) rectValue;
- (void)				updateViewRulerMarkersForRect:(NSValue*) rectValue;
- (void)				hideViewRulerMarkers;
- (void)				synchronizeViewRulersWithUnits:(NSString*) unitString;

- (void)				invalidateCursors;
- (void)				exitTemporaryTextEditingMode;

- (void)				objectDidNotifyStatusChange:(id) object;

// info about current view state

- (CGFloat)				viewScale;

// handling mouse input events from the view

- (void)				mouseDown:(NSEvent*) event;
- (void)				mouseDragged:(NSEvent*) event;
- (void)				mouseUp:(NSEvent*) event;
- (void)				mouseMoved:(NSEvent*) event;
- (void)				flagsChanged:(NSEvent*) event;
- (void)				rulerView:(NSRulerView*) aRulerView handleMouseDown:(NSEvent*) event;

- (NSCursor*)			cursor;
- (NSRect)				activeCursorRect;

- (void)				setContextualMenusEnabled:(BOOL) enable;
- (BOOL)				contextualMenusEnabled;
- (NSMenu*)				menuForEvent:(NSEvent*) event;

// autoscrolling:

- (void)				startAutoscrolling;
- (void)				stopAutoscrolling;
- (void)				autoscrollTimerCallback:(NSTimer*) timer;

// layer info

- (DKLayer*)			activeLayer;
- (id)					activeLayerOfClass:(Class) aClass;
- (void)				setActivatesLayersAutomatically:(BOOL) acts;
- (BOOL)				activatesLayersAutomatically;
- (DKLayer*)			findLayer:(NSPoint) p;

- (void)				activeLayerWillChangeToLayer:(DKLayer*) aLayer;
- (void)				activeLayerDidChangeToLayer:(DKLayer*) aLayer;

- (BOOL)				autoActivateLayerWithEvent:(NSEvent*) event;

// user actions for layer stacking

- (IBAction)			layerBringToFront:(id) sender;
- (IBAction)			layerBringForward:(id) sender;
- (IBAction)			layerSendToBack:(id) sender;
- (IBAction)			layerSendBackward:(id) sender;

- (IBAction)			hideInactiveLayers:(id) sender;
- (IBAction)			showAllLayers:(id) sender;

// other user actions

- (IBAction)			toggleSnapToGrid:(id) sender;
- (IBAction)			toggleSnapToGuides:(id) sender;
- (IBAction)			toggleGridVisible:(id) sender;
- (IBAction)			toggleGuidesVisible:(id) sender;
- (IBAction)			copyDrawing:(id) sender;

// establishing relationships:

- (void)				setDrawing:(DKDrawing*) aDrawing;
- (void)				setView:(NSView*) aView;

@end


#define		kDKAutoscrollRate		(1.0/20.0)


/*

DKViewController is a basic controller class that sits between a DKDrawingView and the DKDrawing itself, which implements the data model.

Its job is broadly divided into two areas, input and output.

When part of a drawing needs to be redisplayed in the view, the drawing will pass the area needing update to the controller, which will
set that area for redisplay in the view, if appropriate. The view redisplays the content accordingly (it may call DKDrawing's drawRect:inView: method).
Other subclasses of this might present the drawing differently - for example a layers palette could display the layers as a list in a tableview.

Each view of the drawing has one controller, so the drawing has a to-many relationship with its controllers, but each controller has a
to-one relationship with the view.

An important function of the controller is to receive user input from the view and direct it to the active layer in an appropriate way. This
includes handling the "tool" that a user might select in an interface and applying it to the drawing. See DKToolController (a subclass of this).
This also implements autoscrolling around the mouse down/up calls which by and large "just work". However if you override these methods you should
call super to keep autoscrolling operative.

Ownership: drawings own the controllers which reference the view. Views keep a reference to their controllers. When a view is dealloc'd, its
controller is removed from the drawing. The controller has weak references to both its view and the drawing - this permits a view to own a drawing
without a retain cycle being introduced - whichever of the drawing or the view gets dealloc'd first, the view controller is also dealloc'd. A view can
own a drawing in the special circumstance of a view creating the drawing automatically if none has been set up prior to the first call to -drawRect:

Flow of control: initially all messages that cannot be directly handled by DKDrawingView are forwarded to its controller. The controller can
handle the message or pass it on to the active layer. This is the default behaviour - typically layer subclasses handle most of their own
action messages and some handle their own mouse input. For most object layers, where a "tool" can be applied, the controller works with the tool
to implement the desired behaviour within the target layer. The view and the controller both use invocation forwarding to push messages down
into the DK system via the controller, the active layer, any selection within it, and finally the target object(s) there.

A subclass of this can also implement drawRect: if it needs to, and can thus draw into its view. This is called after all other drawing has been
completed except for page breaks. Tool controllers for example can draw selection rects, etc.

*/
