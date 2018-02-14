/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

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

- (void)redisplayContentForSelection:(nullable NSArray<DKDrawableObject*>*)selection;
- (void)redisplayContentForSubSelection:(NSSet<DKDrawableObject*>*)subsel ofObject:(DKDrawableObject*)object;

- (nullable id)selectedObjectForCurrentTarget;
- (nullable id)selectedObjectForTargetWindow:(NSWindow*)window;
- (nullable DKDrawing*)drawingForTargetWindow:(NSWindow*)window;

// these return what they say when the app is in a static state. When responding to documentDidChange:, they can return nil
// because Cocoa's notifications are sent too early. In that case you should respond to the notification directly and
// extract the relevant DK objects working back from the window. It sucks, I know.

@property (readonly, retain, nullable) DKDrawingDocument *currentDocument;
@property (readonly, retain, nullable) DKDrawing *currentDrawing;
@property (readonly, retain, nullable) DKLayer *currentActiveLayer;

@property (readonly, retain, nullable) DKViewController *currentMainViewController;

@end

NS_ASSUME_NONNULL_END
