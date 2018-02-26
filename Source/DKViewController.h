/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKDrawing.h"

NS_ASSUME_NONNULL_BEGIN

@class DKDrawingView, DKDrawing, DKLayer;

// the controller class:

/** @brief A basic controller class that sits between a \c DKDrawingView and the \c DKDrawing itself, which implements the data model.

 \c DKViewController is a basic controller class that sits between a \c DKDrawingView and the \c DKDrawing itself, which implements the data model.

 Its job is broadly divided into two areas, input and output.

 When part of a drawing needs to be redisplayed in the view, the drawing will pass the area needing update to the controller, which will
 set that area for redisplay in the view, if appropriate. The view redisplays the content accordingly (it may call DKDrawing's drawRect:inView: method).
 Other subclasses of this might present the drawing differently - for example a layers palette could display the layers as a list in a tableview.

 Each view of the drawing has one controller, so the drawing has a to-many relationship with its controllers, but each controller has a
 to-one relationship with the view.

 An important function of the controller is to receive user input from the view and direct it to the active layer in an appropriate way. This
 includes handling the "tool" that a user might select in an interface and applying it to the drawing. See DKToolController (a subclass of this).
 This also implements autoscrolling around the mouse down/up calls which by and large "just work". However if you override these methods you should
 call \c super to keep autoscrolling operative.

 Ownership: drawings own the controllers which reference the view. Views keep a reference to their controllers. When a view is dealloc'd, its
 controller is removed from the drawing. The controller has weak references to both its view and the drawing - this permits a view to own a drawing
 without a retain cycle being introduced - whichever of the drawing or the view gets dealloc'd first, the view controller is also dealloc'd. A view can
 own a drawing in the special circumstance of a view creating the drawing automatically if none has been set up prior to the first call to \c -drawRect:

 Flow of control: initially all messages that cannot be directly handled by DKDrawingView are forwarded to its controller. The controller can
 handle the message or pass it on to the active layer. This is the default behaviour - typically layer subclasses handle most of their own
 action messages and some handle their own mouse input. For most object layers, where a "tool" can be applied, the controller works with the tool
 to implement the desired behaviour within the target layer. The view and the controller both use invocation forwarding to push messages down
 into the DK system via the controller, the active layer, any selection within it, and finally the target object(s) there.

 A subclass of this can also implement \c drawRect: if it needs to, and can thus draw into its view. This is called after all other drawing has been
 completed except for page breaks. Tool controllers for example can draw selection rects, etc.
*/
@interface DKViewController : NSObject {
@private
	NSView* __weak mViewRef; //!< weak ref to the view that is associated with this
	DKDrawing* __weak mDrawingRef; //!< weak ref to the drawing that owns this
	BOOL m_autoLayerSelect; //!< YES to allow mouse to activate layers automatically
	BOOL mEnableDKMenus; //!< YES to enable all standard contextual menus provided by DK.
@protected
	NSEvent* mDragEvent; //!< cached drag event for autoscroll to use
}

- (instancetype)init UNAVAILABLE_ATTRIBUTE;

// designated initializer

/** @brief Initialize the controller
 @param aView The view object that this controller manages.
 @return The controller object.
 */
- (instancetype)initWithView:(NSView*)aView NS_DESIGNATED_INITIALIZER;

// fundamental objects in the controller's world / establishing relationships:

/** @brief The view the controller is associated with.
 
 You should not set this directly, it is set by the designated initializer.
 */
@property (nonatomic, weak, nullable) NSView* view;

/** @brief Set the drawing that the controller is attached to
 
 \c DKDrawing objects own the controllers added to them. You should not set this directly - \c DKDrawing
 sets this at the appropriate time when the controller is added.
 */
@property (nonatomic, weak, nullable) DKDrawing* drawing;

/** @name Updating The View
 @brief Updating the view from the drawing (refresh).
 @discussion Updating the view from the drawing (refresh). Note that these are typically invoked via the
 <code>DKDrawing</code>, so you should look there for similarly named methods that take simple types. The
 object type parameters used here allow the drawing to invoke these methods efficiently across multiple
 controllers.
 @{ */

/** @brief Mark the entire view for update

 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 @param updateBoolValue an NSNumber containing a boolValue, \c YES to update, \c NO to not update
 */
- (void)setViewNeedsDisplay:(NSNumber*)updateBoolValue;

/** @brief Mark part of the view for update

 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 @param updateRectValue An \c NSValue containing a rectValue, the area to mark for update
 */
- (void)setViewNeedsDisplayInRect:(NSValue*)updateRectValue;

/** @brief Notify that the drawing has had its size changed

 The view's bounds and frame are adjusted to enclose the full drawing size and the view is updated
 @param drawingSizeValue an NSValue containing a sizeValue
 */
- (void)drawingDidChangeToSize:(NSValue*)drawingSizeValue;

/** @brief Scroll the view so that the given area is visible

 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 @param rectValue an NSValue containing a rectValue, the rect to scroll into view
 */
- (void)scrollViewToRect:(NSValue*)rectValue;

/** @brief Set the ruler markers to the given rect

 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 @param rectValue an NSValue containing a rectValue, the rect to move ruler markers to
 */
- (void)updateViewRulerMarkersForRect:(NSValue*)rectValue;

/** @} */

/** @brief Hide the view's ruler markers

 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 */
- (void)hideViewRulerMarkers;

/** @brief Set the rulers to match the unit string

 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 @param unitString a string used to look up the previously established ruler settings
 */
- (void)synchronizeViewRulersWithUnits:(DKDrawingUnits)unitString;

/** @brief Invalidate the cursor rects for the view

 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 */
- (void)invalidateCursors;

/** @brief Stop any text editing that may be taking place in the view

 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 */
- (void)exitTemporaryTextEditingMode;

/** @brief An object in the drawing notified a status (rather than visual) change

 Override to make use of this - the normal view controller just ignores this
 @param object the object that changed
 */
- (void)objectDidNotifyStatusChange:(nullable id)object;

// info about current view state

/** @brief Return the current scale of the view.
 
 A float value representing the view's zoom scale, 1.0 = 100%, 2.0 = 200% etc.
 */
@property (readonly) CGFloat viewScale;

// handling mouse input events from the view

/** @brief Handle the mouse down event

 If set to activate layers automatically, this will do so if the mouse hit something. It also starts
 a timer for autoscrolling, so if you override this, call super to get autoscrolling, or call
 startAutoscrolling on mouseDown.
 @param event the event
 */
- (void)mouseDown:(NSEvent*)event;

/** @brief Handle the mouse dragged event
 @param event the event
 */
- (void)mouseDragged:(NSEvent*)event;

/** @brief Handle the mouse up event

 This stops the autoscrolling. If you override it, call super or stopAutoscrolling to ensure auto-
 scrolling works as intended.
 @param event the event
 */
- (void)mouseUp:(NSEvent*)event;

/** @brief Handle the mouse moved event

 The basic controller ignores this - override to use it. DKDrawingView turns on mouse moved events
 by default but other view types may not.
 @param event the event
 */
- (void)mouseMoved:(NSEvent*)event;

/** @brief Handle the flags changed event
 @param event the event
 */
- (void)flagsChanged:(NSEvent*)event;

/** @brief Respond to a mouse-down in one of the view's rulers

 This implements the dragging of a guide "off' a ruler and into place in the drawing's guide layer.
 If there is no guide layer it does nothing. This keeps control during the drag and invokes
 @param aRulerView the ruler view that started the event
 @param event the event
 */
- (void)rulerView:(NSRulerView*)aRulerView handleMouseDown:(NSEvent*)event;

/** @brief Return the cursor to display when the mouse is in the view
 */
@property (readonly, retain) NSCursor* cursor;

/** @brief Return the active cursor rect

 Defines the area in which \c -cursor will be displayed - outside this rect the arrow cursor is
 displayed.
 */
@property (readonly) NSRect activeCursorRect;

/** @brief Set whether the standard contextual menus within DK are enabled or not.
 
 The default is to enable the menus - some apps may wish to turn off the standard menus altogether
 rather than overriding each point where they are set up.
 \c YES to enable the menus, \c NO to disable them.
 */
@property BOOL contextualMenusEnabled;

/** @brief Build a menu for a right-click event.
 
 This just defers to the active layer. If menus are disabled, returns <code>nil</code>. Note that locked layers
 still receive this message - individual items may be sensitive to the lock state.
 @param event The event.
 @return A menu, or \c nil
 */
- (nullable NSMenu*)menuForEvent:(NSEvent*)event;

/** @name autoscrolling:
 @{ */

/** @brief Start the autoscroll timer

 Starts a timer running at 20fps which will cause autscrolling as long as the mouse is outside
 the view. Normally autoscrolling should start on mouse down and stop on mouse up.
 */
- (void)startAutoscrolling;

/** @brief Stop the autoscroll timer

 Normally autoscrolling should start on mouse down and stop on mouse up.
 */
- (void)stopAutoscrolling;
- (void)autoscrollTimerCallback:(NSTimer*)timer;

/** @}
 @name layer info
 @{ */

/** @brief The drawing's current active layer.
 */
@property (readonly, weak) DKLayer* activeLayer;

/** @brief Return the drawing's current active layer if it matches the given class, else nil
 @param aClass a layer class
 @return the active layer if it matches the class, otherwise nil
 */
- (nullable DKLayer*)activeLayerOfClass:(Class)aClass NS_REFINED_FOR_SWIFT;

/** @brief Should a mouse down activate the layer it hits automatically?
 
 The default is YES
 */
@property (nonatomic) BOOL activatesLayersAutomatically;

/** @brief Which layer did the point hit?

 Test layers top-down. Each layer can decide for itself what constitutes a "hit". Typically a
 layer is hit when any object it contains is hit.
 @param p A point in local coordinates.
 @return The topmost layer hit by the given point, else \c nil
 */
- (nullable DKLayer*)findLayer:(NSPoint)p;

/** @brief A new layer is about to be activated
 @param aLayer the layer about to be activated
 */
- (void)activeLayerWillChangeToLayer:(DKLayer*)aLayer;

/** @brief A new layer was activated

 The default method sets up the drag types for the view based on what drag types the layer is
 able to receive. If you override this, call super to ensure dragging still operates correctly.
 @param aLayer the layer that was activated
 */
- (void)activeLayerDidChangeToLayer:(nullable DKLayer*)aLayer;

/** @brief If layers can be automatically activated, perform that switch
 @param event the initiating event - typically a mouseDown event.
 @return YES if a new layer was actually made active, NO if it remained the same */
- (BOOL)autoActivateLayerWithEvent:(NSEvent*)event;

/** @}
 @name Layer Stacking
 @brief User actions for layer stacking.
 @{ */

/** @brief Bring the active layer to the front of its group

 High-level method can be invoked directly from a menu. Undoably moves the layer to front.
 @param sender the sender of the action
 */
- (IBAction)layerBringToFront:(nullable id)sender;

/** @brief Move the active layer 1 position forward within its group

 High-level method can be invoked directly from a menu. Undoably moves the layer forward.
 @param sender the sender of the action
 */
- (IBAction)layerBringForward:(nullable id)sender;

/** @brief Move the active layer to the back within its group

 High-level method can be invoked directly from a menu. Undoably moves the layer to the back.
 @param sender the sender of the action
 */
- (IBAction)layerSendToBack:(nullable id)sender;

/** @brief Move the active layer 1 position towards the back within its group

 High-level method can be invoked directly from a menu. Undoably moves the layer backwards.
 @param sender the sender of the action
 */
- (IBAction)layerSendBackward:(nullable id)sender;

/** @brief Hides all inactive layers and shows the active layer (if it's hidden)

 High-level method can be invoked directly from a menu.
 @param sender the sender of the action
 */
- (IBAction)hideInactiveLayers:(nullable id)sender;

/** @brief Shows all layers

 High-level method can be invoked directly from a menu.
 @param sender the sender of the action
 */
- (IBAction)showAllLayers:(nullable id)sender;

/** @}
 @name Other User Actions
 @brief Other user actions.
 @{ */

/** @brief Toggle whether snapping to grid is enabled
 
 High-level method can be invoked directly from a menu. Flips the current state of snap to grid.
 @param sender the sender of the action
 */
- (IBAction)toggleSnapToGrid:(nullable id)sender;

/** @brief Toggle whether snapping to guides is enabled
 
 High-level method can be invoked directly from a menu. Flips the current state of snap to guides.
 @param sender the sender of the action
 */
- (IBAction)toggleSnapToGuides:(nullable id)sender;

/** @brief Toggle whether the grid layer is visible
 
 High-level method can be invoked directly from a menu. Flips the current state of grid visible.
 @param sender the sender of the action
 */
- (IBAction)toggleGridVisible:(nullable id)sender;

/** @brief Toggle whether the guide layer is visible
 
 High-level method can be invoked directly from a menu. Flips the current state of guide visible.
 @param sender the sender of the action
 */
- (IBAction)toggleGuidesVisible:(nullable id)sender;

/** @brief Copies the entire drawing to the general pasteboard
 
 High-level method can be invoked directly from a menu. Drawing is copied as a PDF.
 @param sender the sender of the action
 */
- (IBAction)copyDrawing:(nullable id)sender;

/** @} */

@end

#define kDKAutoscrollRate (1.0 / 20.0)

NS_ASSUME_NONNULL_END
