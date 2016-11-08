/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

@class DKDrawing, DKLayer, DKDrawableObject, DKDrawingDocument, DKViewController;

/** @brief This is a base class for any inspector for looking at DrawKit.

This is a base class for any inspector for looking at DrawKit. All it does is respond to the various selection changed
notifications at the document, layer and object levels, and call a method which you can override to set up the displayed
content.
*/
@interface DKDrawkitInspectorBase : NSWindowController

- (void)documentDidChange:(NSNotification*)note;
- (void)layerDidChange:(NSNotification*)note;
- (void)selectedObjectDidChange:(NSNotification*)note;
- (void)subSelectionDidChange:(NSNotification*)note;

- (void)redisplayContentForSelection:(NSArray*)selection;
- (void)redisplayContentForSubSelection:(NSSet*)subsel ofObject:(DKDrawableObject*)object;

- (id)selectedObjectForCurrentTarget;
- (id)selectedObjectForTargetWindow:(NSWindow*)window;
- (DKDrawing*)drawingForTargetWindow:(NSWindow*)window;

// these return what they say when the app is in a static state. When responding to documentDidChange:, they can return nil
// because Cocoa's notifications are sent too early. In that case you should respond to the notification directly and
// extract the relevant DK objects working back from the window. It sucks, I know.

- (DKDrawingDocument*)currentDocument;
- (DKDrawing*)currentDrawing;
- (DKLayer*)currentActiveLayer;

- (DKViewController*)currentMainViewController;

@end
