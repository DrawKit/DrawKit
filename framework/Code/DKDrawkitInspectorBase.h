///**********************************************************************************************************************************
///  DKDrawkitInspectorBase.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 06/05/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import <Cocoa/Cocoa.h>


@class DKDrawing, DKLayer, DKDrawableObject, DKDrawingDocument, DKViewController;


@interface DKDrawkitInspectorBase : NSWindowController

- (void)				documentDidChange:(NSNotification*) note;
- (void)				layerDidChange:(NSNotification*) note;
- (void)				selectedObjectDidChange:(NSNotification*) note;
- (void)				subSelectionDidChange:(NSNotification*) note;

- (void)				redisplayContentForSelection:(NSArray*) selection;
- (void)				redisplayContentForSubSelection:(NSSet*) subsel ofObject:(DKDrawableObject*) object;

- (id)					selectedObjectForCurrentTarget;
- (id)					selectedObjectForTargetWindow:(NSWindow*) window;
- (DKDrawing*)			drawingForTargetWindow:(NSWindow*) window;

// these return what they say when the app is in a static state. When responding to documentDidChange:, they can return nil
// because Cocoa's notifications are sent too early. In that case you should respond to the notification directly and
// extract the relevant DK objects working back from the window. It sucks, I know.

- (DKDrawingDocument*)	currentDocument;
- (DKDrawing*)			currentDrawing;
- (DKLayer*)			currentActiveLayer;

- (DKViewController*)	currentMainViewController;

@end



/*

This is a base class for any inspector for looking at DrawKit. All it does is respond to the various selection changed
notifications at the document, layer and object levels, and call a method which you can override to set up the displayed
content.


*/
