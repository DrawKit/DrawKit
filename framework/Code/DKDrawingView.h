///**********************************************************************************************************************************
///  DKDrawingView.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 11/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "GCZoomView.h"


@class DKDrawing, DKLayer, DKViewController;


typedef enum
{
	DKCropMarksNone		= 0,
	DKCropMarksCorners	= 1,
	DKCropMarksEdges	= 2
}
DKCropMarkKind;


@interface DKDrawingView : GCZoomView
{
@private
	NSTextView*			m_textEditViewRef;		// if valid, set to text editing view
	BOOL				mTextEditViewInUse;		// YES if editor in use
	BOOL				mPageBreaksVisible;		// YES if page breaks are drawn in the view
	NSPrintInfo*		mPrintInfo;				// print info used to draw page breaks and paginate, etc
	DKCropMarkKind		mCropMarkKind;			// what kind of crop marks to add to the printed output
	DKViewController*	mControllerRef;			// the view's controller (weak ref)
	DKDrawing*			mAutoDrawing;			// the drawing we created automatically (if we did so - typically nil for doc-based apps)
	BOOL				m_didCreateDrawing;		// YES if the window built the back end itself
	NSRect				mEditorFrame;			// tracks current frame of text editor
	NSTimeInterval		mLastMouseDragTime;		// time of last mouseDragged: event
	NSDictionary*		mRulerMarkersDict;		// tracks ruler markers
}

+ (DKDrawingView*)		currentlyDrawingView;
+ (void)				pop;
+ (void)				setPageBreakColour:(NSColor*) colour;
+ (NSColor*)			pageBreakColour;
+ (NSColor*)			backgroundColour;
+ (NSPoint)				pointForLastContextualMenuEvent;
+ (NSImage*)			imageResourceNamed:(NSString*) name;

// setting the class to use for the temporary text editor

+ (Class)				classForTextEditor;
+ (void)				setClassForTextEditor:(Class) aClass;
+ (void)				setTextEditorAllowsTypingUndo:(BOOL) allowUndo;
+ (BOOL)				textEditorAllowsTypingUndo;

// the view's controller

- (DKViewController*)	makeViewController;
- (void)				setController:(DKViewController*) aController;
- (DKViewController*)	controller;
- (void)				replaceControllerWithController:(DKViewController*) newController;

// automatic drawing info

- (DKDrawing*)			drawing;
- (void)				createAutomaticDrawing;

// drawing page breaks & crop marks

- (NSBezierPath*)		pageBreakPathWithExtension:(CGFloat) amount options:(DKCropMarkKind) options;

- (void)				setPageBreaksVisible:(BOOL) pbVisible;
- (BOOL)				pageBreaksVisible;
- (void)				drawPageBreaks;

- (void)				setPrintCropMarkKind:(DKCropMarkKind) kind;
- (DKCropMarkKind)		printCropMarkKind;
- (void)				drawCropMarks;

- (void)				setPrintInfo:(NSPrintInfo*) printInfo;
- (NSPrintInfo*)		printInfo;

- (void)				set;

// editing text directly in the drawing:

- (NSTextView*)			editText:(NSAttributedString*) text inRect:(NSRect) rect delegate:(id) del;
- (NSTextView*)			editText:(NSAttributedString*) text inRect:(NSRect) rect delegate:(id) del drawsBackground:(BOOL) drawBkGnd;
- (void)				endTextEditing;
- (NSTextStorage*)		editedText;
- (NSTextView*)			textEditingView;
- (void)				editorFrameChangedNotification:(NSNotification*) note;
- (BOOL)				isTextBeingEdited;

// ruler stuff

- (void)				moveRulerMarkerNamed:(NSString*) markerName toLocation:(CGFloat) loc;
- (void)				createRulerMarkers;
- (void)				removeRulerMarkers;
- (void)				resetRulerClientView;
- (void)				updateRulerMouseTracking:(NSPoint) mouse;

// user actions

- (IBAction)			toggleRuler:(id) sender;
- (IBAction)			toggleShowPageBreaks:(id) sender;

// window activations

- (void)				windowActiveStateChanged:(NSNotification*) note;


@end



extern NSString* kDKDrawingViewDidBeginTextEditing;
extern NSString* kDKDrawingViewTextEditingContentsDidChange;
extern NSString* kDKDrawingViewDidEndTextEditing;
extern NSString* kDKDrawingViewWillCreateAutoDrawing;
extern NSString* kDKDrawingViewDidCreateAutoDrawing;

extern NSString* kDKDrawingMouseDownLocation;
extern NSString* kDKDrawingMouseDraggedLocation;
extern NSString* kDKDrawingMouseUpLocation;
extern NSString* kDKDrawingMouseMovedLocation;
extern NSString* kDKDrawingViewRulersChanged;

extern NSString* kDKDrawingMouseLocationInView;
extern NSString* kDKDrawingMouseLocationInDrawingUnits;

extern NSString* kDKDrawingRulersVisibleDefaultPrefsKey;
extern NSString* kDKTextEditorSmartQuotesPrefsKey;
extern NSString* kDKTextEditorUndoesTypingPrefsKey;

extern NSString* kDKDrawingViewHorizontalLeftMarkerName;
extern NSString* kDKDrawingViewHorizontalCentreMarkerName;
extern NSString* kDKDrawingViewHorizontalRightMarkerName;
extern NSString* kDKDrawingViewVerticalTopMarkerName;
extern NSString* kDKDrawingViewVerticalCentreMarkerName;
extern NSString* kDKDrawingViewVerticalBottomMarkerName;

/*

DKDrawingView is the visible "front end" for the DKDrawing architecture.

A drawing can have multiple views into the same drawing data model, each with independent scales, scroll positions and so forth, but
all showing the same drawing. Manipulating the drawing through any view updates all of the views. In many cases there will only be
one view. The views are not required to be in the same window.

The actual contents of the drawing are all supplied by DKDrawing - all this does is call it to render its contents.

If the drawing system is built by hand, the drawing owns the view controller(s), and some other object (a document for example) will own the
drawing. However, like NSTextView, if you don't build a system by hand, this creates a default one for you which it takes ownership
of. By default this consists of 3 layers - a grid layer, a guide layer and a standard object layer. You can change this however you like, it's
there just as a construction convenience.

Note that because the controllers are owned by the drawing, there is no retain cycle even when the view owns the drawing. Views are owned by
their parent view or window, not by their controller.

*/
