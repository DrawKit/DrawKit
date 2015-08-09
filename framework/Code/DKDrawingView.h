/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import "GCZoomView.h"

@class DKDrawing, DKLayer, DKViewController;

typedef enum {
	DKCropMarksNone = 0,
	DKCropMarksCorners = 1,
	DKCropMarksEdges = 2
} DKCropMarkKind;

/** @brief DKDrawingView is the visible "front end" for the DKDrawing architecture.

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
@interface DKDrawingView : GCZoomView {
@private
	NSTextView* m_textEditViewRef; /**< if valid, set to text editing view */
	BOOL mTextEditViewInUse; /**< YES if editor in use */
	BOOL mPageBreaksVisible; /**< YES if page breaks are drawn in the view */
	NSPrintInfo* mPrintInfo; /**< print info used to draw page breaks and paginate, etc */
	DKCropMarkKind mCropMarkKind; /**< what kind of crop marks to add to the printed output */
	DKViewController* mControllerRef; /**< the view's controller (weak ref) */
	DKDrawing* mAutoDrawing; /**< the drawing we created automatically (if we did so - typically nil for doc-based apps) */
	BOOL m_didCreateDrawing; /**< YES if the window built the back end itself */
	NSRect mEditorFrame; /**< tracks current frame of text editor */
	NSTimeInterval mLastMouseDragTime; /**< time of last mouseDragged: event */
	NSDictionary* mRulerMarkersDict; /**< tracks ruler markers */
}

/** @brief Return the view currently drawing

 This is only valid during a drawRect: call - some internal parts of DK use this to obtain the
 view doing the drawing when they do not have a direct parameter to it.
 @return the current view that is drawing
 */
+ (DKDrawingView*)currentlyDrawingView;
+ (void)pop;

/** @brief Set the colour used to draw the page breaks
 @param colour the colour to draw page breaks with
 */
+ (void)setPageBreakColour:(NSColor*)colour;

/** @brief Get the colour used to draw the page breaks
 @return a colour
 */
+ (NSColor*)pageBreakColour;

/** @brief Return the colour used to draw the background area of the scrollview outside the drawing area
 @return a colour
 */
+ (NSColor*)backgroundColour;

/** @brief Get the point for the initial mouse down that last opened a contextual menu
 @return a point in the drawing's coordinates
 */
+ (NSPoint)pointForLastContextualMenuEvent;

/** @brief Return an image resource from the framework bundle
 @param name the image name
 @return the image, if available
 */
+ (NSImage*)imageResourceNamed:(NSString*)name;

/** @name Temporary Text Editor
 @brief Setting the class to use for the temporary text editor
 @{ */

+ (Class)classForTextEditor;
+ (void)setClassForTextEditor:(Class)aClass;
+ (void)setTextEditorAllowsTypingUndo:(BOOL)allowUndo;
+ (BOOL)textEditorAllowsTypingUndo;

/** @} */

// the view's controller

/** @brief Creates a controller for this view that can be added to a drawing

 Normally you wouldn't call this yourself unless you are building the entire DK system by hand rather
 than using DKDrawDocument or automatic drawing creation. You can override it to create different
 kinds of controller however. Th edefault controller is DKToolController so that DK provides you
 with a set of working drawing tools by default.
 @return a controller, an instance of DKViewController or one of its subclasses
 */
- (DKViewController*)makeViewController;

/** @brief Set the view's controller

 Do not call this directly - the controller will call it to set up the relationship at the right
 time.
 @param aController the controller for this view
 */
- (void)setController:(DKViewController*)aController;

/** @brief Return the view's controller
 @return the controller
 */
- (DKViewController*)controller;

/** @brief Sea new controller for this view

 This is a convenience that allows a controller to be simply instantiated and passed in, replacing
 the existing controller. Note that -setController: does NOT achieve that. The drawing must
 already exist for this to work.
 @param newController the new controller
 */
- (void)replaceControllerWithController:(DKViewController*)newController;

// automatic drawing info

/** @brief Return the drawing that the view will draw

 The drawing is obtained via the controller, and may be nil if the controller hasn't been added
 to a drawing yet. Even when the view owns the drawing (for auto back-end) you should use this
 method to get a view's drawing.
 @return a drawing object
 */
- (DKDrawing*)drawing;

/** @brief Create an entire "back end" for the view 

 Normally you create a drawing, and add layers to it. However, you can also let the view create the
 drawing back-end for you. This will occur when the view is asked to draw and there is no back end. This method
 does the building. This feature means you can simply drop a drawingView into a NIB and get a
 functional drawing program. For more sophisticated needs however, you really need to build it yourself.
 */
- (void)createAutomaticDrawing;

// drawing page breaks & crop marks

/** @brief Returns a path which represents all of the printed page rectangles

 Any extension may not end up visible when printed depending on the printer's margin settings, etc.
 The only supported option currently is kDKCornerOnly, which generates corner crop marks rather
 than the full rectangles.
 @param amount the extension amount by which each line is extended beyond the end of the corner. May be 0.
 @param options crop marks kind
 @return a bezier path, may be stroked in various ways to show page breaks, crop marks, etc. */
- (NSBezierPath*)pageBreakPathWithExtension:(CGFloat)amount options:(DKCropMarkKind)options;

/** @brief Sets whether the page breaks are shown or not

 Page breaks also need a valid printInfo object set
 @param pbVisible YES to show the page breaks, NO otherwise
 */
- (void)setPageBreaksVisible:(BOOL)pbVisible;

/** @brief Are page breaks vissble?
 @return YES if page breaks are visible
 */
- (BOOL)pageBreaksVisible;

/** @brief Draw page breaks based on the page break print info */
- (void)drawPageBreaks;

/** @brief Set what kind of crop marks printed output includes

 Default is no crop marks
 @param kind the kind of crop mark (including none)
 */
- (void)setPrintCropMarkKind:(DKCropMarkKind)kind;

/** @brief What sort of crop mark sare applied to printed output

 Default is no crop marks
 @return the crop mark kind
 */
- (DKCropMarkKind)printCropMarkKind;

/** @brief Draws the crop marks if set to do so and the view is being printed */
- (void)drawCropMarks;

- (void)setPrintInfo:(NSPrintInfo*)printInfo;

/** @brief Return the print info to use for drawing the page breaks, paginating and general printing operations
 @return a NSPrintInfo object
 */
- (NSPrintInfo*)printInfo;

- (void)set;

// editing text directly in the drawing:

/** @brief Start editing text in a box within the view

 When an object in the drawing wishes to allow the user to edit some text, it can use this utility
 to set up the editor. This creates a subview for text editing with the nominated text and the
 bounds rect given within the drawing. The text is installed, selected and activated. User actions
 then edit that text. When done, call endTextEditing. To get the text edited, call editedText
 before ending the mode. You can only set one item at a time to be editable.
 @param text the text to edit
 @param rect the position and size of the text box to edit within
 @param del a delegate object
 @return the temporary text view created to handle the job
 */
- (NSTextView*)editText:(NSAttributedString*)text inRect:(NSRect)rect delegate:(id)del;

/** @brief Start editing text in a box within the view

 When an object in the drawing wishes to allow the user to edit some text, it can use this utility
 to set up the editor. This creates a subview for text editing with the nominated text and the
 bounds rect given within the drawing. The text is installed, selected and activated. User actions
 then edit that text. When done, call endTextEditing. To get the text edited, call editedText
 before ending the mode. You can only set one item at a time to be editable.
 @param text the text to edit
 @param rect the position and size of the text box to edit within
 @param del a delegate object
 @param drawBkGnd YES to draw a background, NO to have transparent text
 @return the temporary text view created to handle the job
 */
- (NSTextView*)editText:(NSAttributedString*)text inRect:(NSRect)rect delegate:(id)del drawsBackground:(BOOL)drawBkGnd;

/** @brief Stop the temporary text editing and get rid of the editing view
 */
- (void)endTextEditing;

/** @brief Return the text from the temporary editing view

 This must be called prior to calling -endTextEditing, because the storage is made empty at that time
 @return the text
 */
- (NSTextStorage*)editedText;

/** @brief Return the current temporary text editing view
 @return the text editing view, or nil
 */
- (NSTextView*)textEditingView;

/** @brief Respond to frame size changes in the text editor view

 This tidies up the display when the editor frame changes size. The frame can change
 during editing depending on how the client has configured it, but to prevent bits from being
 left behind when the frame is made smaller, this simply invalidates the previous frame rect.
 @param note the notification
 */
- (void)editorFrameChangedNotification:(NSNotification*)note;

/** @brief Is the text editor visible and active?

 Clients should not generally start a text editing operation if there is already one in progress,
 though if they do the old one is immediately ended anyway.
 @return YES if text editing is in progress, NO otherwise
 */
- (BOOL)isTextBeingEdited;

// ruler stuff

/** @brief Set a ruler marker to a given position

 Generally called from the view's controller
 @param markerName the name of the marker to move
 @param loc a position value to move the ruler marker to
 */
- (void)moveRulerMarkerNamed:(NSString*)markerName toLocation:(CGFloat)loc;

/** @brief Set up the markers for the rulers.

 Done as part of the view's initialization - markers are initially created offscreen.
 */
- (void)createRulerMarkers;

/** @brief Remove the markers from the rulers.
 */
- (void)removeRulerMarkers;

/** @brief Set up the client view for the rulers.

 Done as part of the view's initialization
 */
- (void)resetRulerClientView;

/** @brief Set the ruler lines to the current mouse point

 N.b. on 10.4 and earlier, there is a bug in NSRulerView that prevents both h and v ruler lines
 showing up correctly at the same time. No workaround is known. Fixed in 10.5+
 @param mouse the current mouse poin tin local coordinates */
- (void)updateRulerMouseTracking:(NSPoint)mouse;

// user actions

/** @brief Show or hide the ruler.
 @param sender the action's sender
 */
- (IBAction)toggleRuler:(id)sender;
- (IBAction)toggleShowPageBreaks:(id)sender;

// window activations

/** @brief Invalidate the view when window active state changes.

 Drawings can change appearance when the active state changes, for example selections are drawn
 in inactive colour, etc. This makes sure that the drawing is refreshed when the state does change.
 @param note the notification
 */
- (void)windowActiveStateChanged:(NSNotification*)note;

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
