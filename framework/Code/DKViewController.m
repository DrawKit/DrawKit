/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKViewController.h"
#import "DKDrawing.h"
#import "DKDrawingView.h"
#import "DKGuideLayer.h"
#import "LogEvent.h"

#pragma mark Static Vars

static NSTimer* s_autoscrollTimer = nil;

@implementation DKViewController

#pragma mark - As a DKViewController
#pragma mark -  designated initializer

/** @brief Initialize the controller
 @param aView the view object that this controller manages
 @return the controller object
 */
- (id)initWithView:(NSView*)aView
{
    NSAssert(aView != nil, @"can't initialize a controller for nil view");

    self = [super init];
    if (self != nil) {
        [self setView:aView];
        [self setActivatesLayersAutomatically:YES];
        [self setContextualMenusEnabled:YES];
    }

    return self;
}

#pragma mark -
#pragma mark -  fundamental objects in the controller's world

/** @brief Return the controller's view
 @return the controller's view
 */
- (NSView*)view
{
    return mViewRef;
}

/** @brief Return the controller's drawing
 @return the controller's drawing
 */
- (DKDrawing*)drawing
{
    return mDrawingRef;
}

#pragma mark -
#pragma mark -  updating the view from the drawing (refresh)

/** @brief Mark the entire view for update
 @note
 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 @param updateBoolValue an NSNumber containing a boolValue, YES to update, NO to not update
 */
- (void)setViewNeedsDisplay:(NSNumber*)updateBoolValue
{
    [[self view] setNeedsDisplay:[updateBoolValue boolValue]];
}

/** @brief Mark part of the view for update
 @note
 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 @param updateRectValue an NSValue containing a rectValue, the area to mark for update
 */
- (void)setViewNeedsDisplayInRect:(NSValue*)updateRectValue
{
    [[self view] setNeedsDisplayInRect:[updateRectValue rectValue]];
}

/** @brief Notify that the drawing has had its size changed
 @note
 The view's bounds and frame are adjusted to enclose the full drawing size and the view is updated
 @param drawingSizeValue an NSValue containing a sizeValue
 */
- (void)drawingDidChangeToSize:(NSValue*)drawingSizeValue
{
    // adjust the bounds to the size given, and the frame too, allowing for the current scale.

    NSSize fr = [drawingSizeValue sizeValue];

    fr.width *= [self viewScale];
    fr.height *= [self viewScale];

    [[self view] setFrameSize:fr];
    [[self view] setBoundsSize:[drawingSizeValue sizeValue]];
    [[self view] setNeedsDisplay:YES];
}

/** @brief Scroll the view so that the given area is visible
 @note
 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 @param rectValue an NSValue containing a rectValue, the rect to scroll into view
 */
- (void)scrollViewToRect:(NSValue*)rectValue
{
    [[self view] scrollRectToVisible:[rectValue rectValue]];
}

/** @brief Set the ruler markers to the given rect
 @note
 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 @param rectValue an NSValue containing a rectValue, the rect to move ruler markers to
 */
- (void)updateViewRulerMarkersForRect:(NSValue*)rectValue
{
    NSRect rect = [rectValue rectValue];
    DKDrawingView* v = nil;

    if ([[self view] isKindOfClass:[DKDrawingView class]])
        v = (DKDrawingView*)[self view];

    if (!NSEqualRects(rect, NSZeroRect)) {
        [v moveRulerMarkerNamed:kDKDrawingViewHorizontalLeftMarkerName
                      toLocation:NSMinX(rect)];
        [v moveRulerMarkerNamed:kDKDrawingViewHorizontalCentreMarkerName
                      toLocation:NSMidX(rect)];
        [v moveRulerMarkerNamed:kDKDrawingViewHorizontalRightMarkerName
                      toLocation:NSMaxX(rect)];

        [v moveRulerMarkerNamed:kDKDrawingViewVerticalTopMarkerName
                      toLocation:NSMinY(rect)];
        [v moveRulerMarkerNamed:kDKDrawingViewVerticalCentreMarkerName
                      toLocation:NSMidY(rect)];
        [v moveRulerMarkerNamed:kDKDrawingViewVerticalBottomMarkerName
                      toLocation:NSMaxY(rect)];
    } else
        [self hideViewRulerMarkers];
}

/** @brief Hide the view's ruler markers
 @note
 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 */
- (void)hideViewRulerMarkers
{
    [self updateViewRulerMarkersForRect:[NSValue valueWithRect:NSMakeRect(-10000, -10000, 0, 0)]];
}

/** @brief Set the rulers to match the unit string
 @note
 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 @param unitString a string used to look up the previously established ruler settings
 */
- (void)synchronizeViewRulersWithUnits:(NSString*)unitString
{
    id grid = [[self drawing] gridLayer];

    if (grid != nil) {
        NSScrollView* enclosing;
        NSRulerView* ruler;

        enclosing = [[self view] enclosingScrollView];

        if (enclosing != nil) {
            ruler = [enclosing horizontalRulerView];
            [ruler setOriginOffset:[[self drawing] leftMargin]];
            [ruler setMeasurementUnits:unitString];
            [ruler setNeedsDisplay:YES];

            ruler = [enclosing verticalRulerView];
            [ruler setOriginOffset:[[self drawing] topMargin]];
            [ruler setMeasurementUnits:unitString];
            [ruler setNeedsDisplay:YES];
        }
    }
}

/** @brief Invalidate the cursor rects for the view
 @note
 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 */
- (void)invalidateCursors
{
    [[[self view] window] invalidateCursorRectsForView:[self view]];
}

/** @brief Stop any text editing that may be taking place in the view
 @note
 This is called by the drawing - generally you shouldn't call it directly, but instead use the
 similar drawing methods that take simple parameter types
 */
- (void)exitTemporaryTextEditingMode
{
    [(DKDrawingView*)[self view] endTextEditing];
}

/** @brief An object in the drawing notified a status (rather than visual) change
 @note
 Override to make use of this - the normal view controller just ignores this
 @param object the object that changed
 */
- (void)objectDidNotifyStatusChange:(id)object
{
#pragma unused(object)
}

#pragma mark -
#pragma mark -  info about current view state

/** @brief Return the current scale of the view
 @return a float value representing the view's zoom scale, 1.0 = 100%, 2.0 = 200% etc.
 */
- (CGFloat)viewScale
{
    if ([[self view] isKindOfClass:[DKDrawingView class]])
        return [(DKDrawingView*)[self view] scale];
    else
        return 1.0;
}

#pragma mark -
#pragma mark - handling mouse input events from the view

/** @brief Handle the mouse down event
 @note
 If set to activate layers automatically, this will do so if the mouse hit something. It also starts
 a timer for autoscrolling, so if you override this, call super to get autoscrolling, or call
 startAutoscrolling on mouseDown.
 @param event the event
 */
- (void)mouseDown:(NSEvent*)event
{
    // if set to activate layers automatically, find the hit layer and activate it

    [self autoActivateLayerWithEvent:event];

    // start the autoscroll timer:

    [self startAutoscrolling];

    // forward the click to the active layer if it is available:

    if (![[self activeLayer] lockedOrHidden]) {
        [[self activeLayer] mouseDown:event
                               inView:[self view]];
    }
}

/** @brief Handle the mouse dragged event
 @param event the event
 */
- (void)mouseDragged:(NSEvent*)event
{
    if (![[self activeLayer] lockedOrHidden])
        [[self activeLayer] mouseDragged:event
                                  inView:[self view]];
}

/** @brief Handle the mouse up event
 @note
 This stops the autoscrolling. If you override it, call super or stopAutoscrolling to ensure auto-
 scrolling works as intended.
 @param event the event
 */
- (void)mouseUp:(NSEvent*)event
{
    if (![[self activeLayer] lockedOrHidden])
        [[self activeLayer] mouseUp:event
                             inView:[self view]];

    // stop the autoscroll timer

    [self stopAutoscrolling];
}

/** @brief Handle the mouse moved event
 @note
 The basic controller ignores this - override to use it. DKDrawingView turns on mouse moved events
 by default but other view types may not.
 @param event the event
 */
- (void)mouseMoved:(NSEvent*)event
{
#pragma unused(event)
}

/** @brief Handle the flags changed event
 @param event the event
 */
- (void)flagsChanged:(NSEvent*)event
{
    if ([[self activeLayer] respondsToSelector:@selector(flagsChanged:)])
        [[self activeLayer] flagsChanged:event];
}

/** @brief Respond to a mouse-down in one of the view's rulers
 @note
 This implements the dragging of a guide "off' a ruler and into place in the drawing's guide layer.
 If there is no guide layer it does nothing. This keeps control during the drag and invokes
 @param aRulerView the ruler view that started the event
 @param event the event
 */
- (void)rulerView:(NSRulerView*)aRulerView handleMouseDown:(NSEvent*)event
{
    // this is our cue to create a new guide, if the drawing has a guide layer.

    DKGuideLayer* gl = [[self drawing] guideLayer];

    if (gl != nil) {
        // add h or v guide depending on ruler orientation

        NSPoint p = [[self view] convertPoint:[event locationInWindow]
                                     fromView:nil];

        if ([aRulerView orientation] == NSVerticalRuler)
            [gl createVerticalGuideAndBeginDraggingFromPoint:p];
        else
            [gl createHorizontalGuideAndBeginDraggingFromPoint:p];

        [(DKDrawingView*)[self view] set];
        [gl mouseDown:event
               inView:[self view]];
        [[gl cursor] set];

        BOOL keepOn = YES;

        while (keepOn) {
            event = [[[self view] window] nextEventMatchingMask:NSLeftMouseUpMask | NSLeftMouseDraggedMask /*| NSPeriodicMask*/];

            switch ([event type]) {
            case NSLeftMouseDragged:
                [(DKDrawingView*)[self view] updateRulerMouseTracking:[event locationInWindow]];
                [gl mouseDragged:event
                          inView:[self view]];
                [[self view] autoscroll:event];
                break;

            case NSLeftMouseUp:
                [gl mouseUp:event
                     inView:[self view]];
                keepOn = NO;
                break;

            default:
                /* Ignore any other kind of event. */
                break;
            }
        }

        [[[self view] window] discardEventsMatchingMask:NSAnyEventMask
                                            beforeEvent:event];
        [DKDrawingView pop];
    }
}

#pragma mark -

/** @brief Return the cursor to display when the mouse is in the view
 @return a cursor
 */
- (NSCursor*)cursor
{
    return [[self activeLayer] cursor];
}

/** @brief Return the active cursor rect
 @note
 Defines the area in which -cursor will be displayed - outside this rect the arrow cursor is
 displayed.
 @return a rect
 */
- (NSRect)activeCursorRect
{
    return [[self activeLayer] activeCursorRect];
}

#pragma mark -
#pragma mark - contextual menu support

/** @brief Set whether the standard contextual menus within DK are enabled or not
 @note
 The default is to enable the menus - some apps may wish to turn off the standard menus altogether
 rather than overriding each point where they are set up.
 @param enable YES to enable the menus, NO to disable them
 */
- (void)setContextualMenusEnabled:(BOOL)enable
{
    mEnableDKMenus = enable;
}

/** @brief Are the standard contextual menus within DK are enabled or not?
 @note
 The default is to enable the menus
 @return YES if standard contextual menus are enabled, NO if not
 */
- (BOOL)contextualMenusEnabled
{
    return mEnableDKMenus;
}

/** @brief Build a menu for a right-click event
 @note
 This just defers to the active layer. If menus are disabled, returns nil. Note that locked layers
 still receive this message - individual items may be sensitive to the lock state.
 @param event the event
 @return a menu, or nil
 */
- (NSMenu*)menuForEvent:(NSEvent*)event
{
    if ([self contextualMenusEnabled] && [[self activeLayer] visible])
        return [[self activeLayer] menuForEvent:event
                                         inView:[self view]];
    else
        return nil;
}

#pragma mark -
#pragma mark - timer stuff for autoscrolling

/** @brief Start the autoscroll timer
 @note
 Starts a timer running at 20fps which will cause autscrolling as long as the mouse is outside
 the view. Normally autoscrolling should start on mouse down and stop on mouse up.
 */
- (void)startAutoscrolling
{
    if (s_autoscrollTimer != nil)
        [self stopAutoscrolling];

    s_autoscrollTimer = [NSTimer timerWithTimeInterval:kDKAutoscrollRate
                                                target:self
                                              selector:@selector(autoscrollTimerCallback:)
                                              userInfo:[self view]
                                               repeats:YES];

    [[NSRunLoop currentRunLoop] addTimer:s_autoscrollTimer
                                 forMode:NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop] addTimer:s_autoscrollTimer
                                 forMode:NSEventTrackingRunLoopMode];
}

/** @brief Stop the autoscroll timer
 @note
 Normally autoscrolling should start on mouse down and stop on mouse up.
 */
- (void)stopAutoscrolling
{
    [s_autoscrollTimer invalidate];
    s_autoscrollTimer = nil;
}

/** @brief Handles autoscrolling
 @note
 Autscrolls the view if the mouse is outside it during a drag, then invokes the controller's
 @param timer the timer
 */
- (void)autoscrollTimerCallback:(NSTimer*)timer
{
#pragma unused(timer)
    // this invokes autoscrolling on the source view based on the current mouse point

    NSEvent* event = (mDragEvent ? mDragEvent : [NSApp currentEvent]);

    //NSLog(@"autoscroll, event = %@", event );

    if ([event type] == NSLeftMouseDragged) {
        if ([[self view] autoscroll:event]) {
            // call back the drag event so that there is no jerkiness as autscrolling commences - objects
            // and so forth should continue to work smoothly during the scroll

            [self mouseDragged:event];
        }
    }
}

#pragma mark -
#pragma mark - layer info

/** @brief Return the drawing's current active layer
 @return the active layer
 */
- (DKLayer*)activeLayer
{
    return [[self drawing] activeLayer];
}

/** @brief Return the drawing's current active layer if it matches the given class, else nil
 @param aClass a layer class
 @return the active layer if it matches the class, otherwise nil
 */
- (id)activeLayerOfClass:(Class)aClass
{
    return [[self drawing] activeLayerOfClass:aClass];
}

/** @brief Should a mouse down activate the layer it hits automatically?
 @note
 The default is YES	
 @param acts YES to auto-activate a layer, NO to leave it to someone else
 */
- (void)setActivatesLayersAutomatically:(BOOL)acts
{
    m_autoLayerSelect = acts;
}

/** @brief Should a mouse down activate the layer it hits automatically?
 @note
 The default is YES	
 @return YES to auto-activate a layer, NO to leave it to someone else
 */
- (BOOL)activatesLayersAutomatically
{
    return m_autoLayerSelect;
}

/** @brief Which layer did the point hit?
 @note
 Test layers top-down. Each layer can decide for itself what constitutes a "hit". Typically a
 layer is hit when any object it contains is hit.
 @param p a point in local coordinates 
 @return the topmost layer hit by the given point, else nil
 */
- (DKLayer*)findLayer:(NSPoint)p
{
    return [[self drawing] findLayerForPoint:p];
}

/** @brief A new layer is about to be activated
 @param aLayer the layer about to be activated 
 */
- (void)activeLayerWillChangeToLayer:(DKLayer*)aLayer
{
#pragma unused(aLayer)

    // the active layer will be changed for <aLayer> - override to make use of this info - the current active
    // layer can be obtained using [self activeLayer];
}

/** @brief A new layer was activated
 @note
 The default method sets up the drag types for the view based on what drag types the layer is
 able to receive. If you override this, call super to ensure dragging still operates correctly.
 @param aLayer the layer that was activated 
 */
- (void)activeLayerDidChangeToLayer:(DKLayer*)aLayer
{
    // when the active layer changes, register the drag types it declares with our view, so that the view
    // can receive drags initially on behalf of the layer (NSView must be the intial receiver of a drag).
    // See DKDrawingView+Drop for how the drags are forwarded to the layer - the controller doesn't
    // currently handle that part.

    NSArray* types = [aLayer pasteboardTypesForOperation:kDKReadableTypesForDrag];

    [[self view] unregisterDraggedTypes];

    if (types != nil && [types count] > 0)
        [[self view] registerForDraggedTypes:types];
}

/** @brief If layers can be automatically activated, perform that switch
 @param event the initiating event - typically a mouseDown event. 
 @return YES if a new layer was actually made active, NO if it remained the same */
- (BOOL)autoActivateLayerWithEvent:(NSEvent*)event
{
    if ([self activatesLayersAutomatically]) {
        NSPoint p = [[self view] convertPoint:[event locationInWindow]
                                     fromView:nil];
        DKLayer* layer = [self findLayer:p];

        // the layer has the final say as to whether it should be activated - it needs to return YES
        // to both -shouldAutoActivateWithEvent: and -layerMayBecomeActive in order to be made the active layer

        if (layer != nil && [layer shouldAutoActivateWithEvent:event]) {
            return [[self drawing] setActiveLayer:layer];
        }
    }

    return NO;
}

#pragma mark -
#pragma mark - user actions for layer stacking

/** @brief Bring the active layer to the front of its group
 @note
 High-level method can be invoked directly from a menu. Undoably moves the layer to front.
 @param sender the sender of the action 
 */
- (IBAction)layerBringToFront:(id)sender
{
#pragma unused(sender)

    DKLayer* active = [self activeLayer];
    DKLayerGroup* group = [active layerGroup];
    [group moveLayerToTop:active];

    [[[self drawing] undoManager] setActionName:NSLocalizedString(@"Bring Layer To Front", @"undo string for layer bring front")];
}

/** @brief Move the active layer 1 position forward within its group
 @note
 High-level method can be invoked directly from a menu. Undoably moves the layer forward.
 @param sender the sender of the action 
 */
- (IBAction)layerBringForward:(id)sender
{
#pragma unused(sender)

    DKLayer* active = [self activeLayer];
    DKLayerGroup* group = [active layerGroup];
    [group moveUpLayer:active];

    [[[self drawing] undoManager] setActionName:NSLocalizedString(@"Bring Layer Forwards", @"undo string for layer bring forwards")];
}

/** @brief Move the active layer to the back within its group
 @note
 High-level method can be invoked directly from a menu. Undoably moves the layer to the back.
 @param sender the sender of the action 
 */
- (IBAction)layerSendToBack:(id)sender
{
#pragma unused(sender)

    DKLayer* active = [self activeLayer];
    DKLayerGroup* group = [active layerGroup];
    [group moveLayerToBottom:active];

    [[[self drawing] undoManager] setActionName:NSLocalizedString(@"Send Layer To Back", @"undo string for layer send back")];
}

/** @brief Move the active layer 1 position towards the back within its group
 @note
 High-level method can be invoked directly from a menu. Undoably moves the layer backwards.
 @param sender the sender of the action 
 */
- (IBAction)layerSendBackward:(id)sender
{
#pragma unused(sender)

    DKLayer* active = [self activeLayer];
    DKLayerGroup* group = [active layerGroup];
    [group moveDownLayer:active];

    [[[self drawing] undoManager] setActionName:NSLocalizedString(@"Send Layer Backwards", @"undo string for layer send backwards")];
}

#pragma mark -

/** @brief Hides all inactive layers and shows the active layer (if it's hidden)
 @note
 High-level method can be invoked directly from a menu.
 @param sender the sender of the action 
 */
- (IBAction)hideInactiveLayers:(id)sender
{
#pragma unused(sender)
    [[self drawing] hideAllExcept:[self activeLayer]];
}

/** @brief Shows all layers
 @note
 High-level method can be invoked directly from a menu.
 @param sender the sender of the action 
 */
- (IBAction)showAllLayers:(id)sender
{
#pragma unused(sender)
    [[self drawing] showAll];
}

#pragma mark -
#pragma mark - user actions pertaining to standard object layers

/** @brief Toggle whether snapping to grid is enabled
 @note
 High-level method can be invoked directly from a menu. Flips the current state of snap to grid.
 @param sender the sender of the action 
 */
- (IBAction)toggleSnapToGrid:(id)sender;
{
#pragma unused(sender)

    [[self drawing] setSnapsToGrid:![[self drawing] snapsToGrid]];
}

/** @brief Toggle whether snapping to guides is enabled
 @note
 High-level method can be invoked directly from a menu. Flips the current state of snap to guides.
 @param sender the sender of the action 
 */
- (IBAction)toggleSnapToGuides:(id)sender
{
#pragma unused(sender)

    [[self drawing] setSnapsToGuides:![[self drawing] snapsToGuides]];
}

/** @brief Toggle whether the grid layer is visible
 @note
 High-level method can be invoked directly from a menu. Flips the current state of grid visible.
 @param sender the sender of the action 
 */
- (IBAction)toggleGridVisible:(id)sender
{
#pragma unused(sender)
    [[[self drawing] gridLayer] setVisible:![[[self drawing] gridLayer] visible]];
}

/** @brief Toggle whether the guide layer is visible
 @note
 High-level method can be invoked directly from a menu. Flips the current state of guide visible.
 @param sender the sender of the action 
 */
- (IBAction)toggleGuidesVisible:(id)sender
{
#pragma unused(sender)
    [[[self drawing] guideLayer] setVisible:![[[self drawing] guideLayer] visible]];
}

#pragma mark -

/** @brief Copies the entire drawing to the general pasteboard
 @note
 High-level method can be invoked directly from a menu. Drawing is copied as a PDF.
 @param sender the sender of the action 
 */
- (IBAction)copyDrawing:(id)sender
{
#pragma unused(sender)

    BOOL saveClip = [[self drawing] clipsDrawingToInterior];
    [[self drawing] setClipsDrawingToInterior:YES];
    [[self drawing] writePDFDataToPasteboard:[NSPasteboard generalPasteboard]];
    [[self drawing] setClipsDrawingToInterior:saveClip];
}

#pragma mark -
#pragma mark - establishing relationships:

/** @brief Set the drawing that the controller is attached to
 @note
 DKDrawing objects own the controllers added to them. You should not call this directly - DKDrawing
 calls this at the appropriate time when the controller is added.
 @param aDrawing the drawing object 
 */
- (void)setDrawing:(DKDrawing*)aDrawing
{
    if (aDrawing != mDrawingRef) {
        LogEvent_(kStateEvent, @"view controller setting drawing: %@, self = %@, view = %@", aDrawing, self, [self view]);

        mDrawingRef = aDrawing;

        if (aDrawing != nil) {
            // first make sure that the view is correctly set up for the drawing size

            [self drawingDidChangeToSize:[NSValue valueWithSize:[aDrawing drawingSize]]];

            // synchronise the view's rulers to the drawing's grid and units

            [self synchronizeViewRulersWithUnits:[aDrawing drawingUnits]];

            // then make the view aware of the current active layer - this sets up drag/drop for example

            [self activeLayerDidChangeToLayer:[aDrawing activeLayer]];
        }
    }
}

/** @brief Set the view that the controller is associated with
 @note
 You should not call this directly, it is called by the designated initializer
 @param aView the view 
 */
- (void)setView:(NSView*)aView
{
    mViewRef = aView;

    if (aView != nil && [aView respondsToSelector:@selector(setController:)])
        [(DKDrawingView*)aView setController:self];
}

#pragma mark -
#pragma mark - As an NSObject

/** @brief Deallocate the controller
 */
- (void)dealloc
{
    //	LogEvent_(kLifeEvent, @"view controller dealloc = %@", self );
    // going away - make sure our view isn't holding a stale reference to this

    if ([self view] != nil) {
        if ([[self view] respondsToSelector:@selector(setController:)])
            [(DKDrawingView*)[self view] setController:nil];

        mViewRef = nil;
    }

    mDrawingRef = nil;
    [super dealloc];
}

/** @brief Forward an invocation to the active layer if it implements it
 @note
 DK makes a lot of use of invocaiton forwarding - views forward to their controllers, which forward
 to the active layer, which may forward to selected objects within the layer. This allows objects
 to respond to action methods and so forth at their own level.
 @param invocation the invocation to forward
 */
- (void)forwardInvocation:(NSInvocation*)invocation
{
    // commands can be implemented by the layer that wants to make use of them - this makes it happen by forwarding unrecognised
    // method calls to the active layer if possible.

    SEL aSelector = [invocation selector];

    if ([[self activeLayer] respondsToSelector:aSelector])
        [invocation invokeWithTarget:[self activeLayer]];
    else
        [self doesNotRecognizeSelector:aSelector];
}

/** @brief Return a method's signature
 @note
 DK makes a lot of use of invocation forwarding - views forward to their controllers, which forward
 to the active layer, which may forward to selected objects within the layer. This allows objects
 to respond to action methods and so forth at their own level.
 @param aSelector the selector
 @return the signature for the method
 */
- (NSMethodSignature*)methodSignatureForSelector:(SEL)aSelector
{
    NSMethodSignature* sig;

    sig = [super methodSignatureForSelector:aSelector];

    if (sig == nil)
        sig = [[self activeLayer] methodSignatureForSelector:aSelector];

    return sig;
}

/** @brief Return whether the selector can be responded to
 @note
 DK makes a lot of use of invocaiton forwarding - views forward to their controllers, which forward
 to the active layer, which may forward to selected objects within the layer. This allows objects
 to respond to action methods and so forth at their own level.
 @param aSelector the selector
 @return YES or NO
 */
- (BOOL)respondsToSelector:(SEL)aSelector
{
    return [super respondsToSelector:aSelector] || [[self activeLayer] respondsToSelector:aSelector];
}

#pragma mark -
#pragma mark As part of NSMenuValidation protocol

/** @brief Enable and set menu item state for actions implemented by the controller
 @param item the menu item to validate
 @return YES or NO
 */
- (BOOL)validateMenuItem:(NSMenuItem*)item
{
    SEL action = [item action];

    DKLayer* active = [self activeLayer];
    DKLayerGroup* group = [active layerGroup];
    BOOL activeLocked = [active locked];

    if (action == @selector(layerBringToFront:) || action == @selector(layerBringForward:)) {
        return (active != [group topLayer] && !activeLocked);
    }

    if (action == @selector(layerSendToBack:) || action == @selector(layerSendBackward:)) {
        return (active != [group bottomLayer] && !activeLocked);
    }

    if (action == @selector(toggleSnapToGrid:)) {
        [item setState:[[self drawing] snapsToGrid] ? NSOnState : NSOffState];
        return YES;
    }

    if (action == @selector(toggleSnapToGuides:)) {
        [item setState:[[self drawing] snapsToGuides] ? NSOnState : NSOffState];
        return YES;
    }

    if (action == @selector(copyDrawing:)) {
        return YES;
    }

    if (action == @selector(toggleGridVisible:)) {
        BOOL vis = [[[self drawing] gridLayer] visible];
        NSString* gridName = [[[self drawing] gridLayer] layerName];
        NSString* itemRoot = vis ? NSLocalizedString(@"Hide %@", "menu item for Hide <layer name>") : NSLocalizedString(@"Show %@", @"menu item for Show <layer name>");
#warning 64BIT: Check formatting arguments
        NSString* title = [NSString stringWithFormat:itemRoot, gridName];

        [item setTitle:title];
        return YES;
    }

    if (action == @selector(toggleGuidesVisible:)) {
        BOOL vis = [[[self drawing] guideLayer] visible];
        NSString* gridName = [[[self drawing] guideLayer] layerName];
        NSString* itemRoot = vis ? NSLocalizedString(@"Hide %@", "menu item for Hide <layer name>") : NSLocalizedString(@"Show %@", @"menu item for Show <layer name>");
#warning 64BIT: Check formatting arguments
        NSString* title = [NSString stringWithFormat:itemRoot, gridName];

        [item setTitle:title];
        return YES;
    }

    if (action == @selector(hideInactiveLayers:)) {
        return [[self drawing] hasVisibleLayersOtherThan:[self activeLayer]];
    }

    if (action == @selector(showAllLayers:)) {
        return [[self drawing] hasHiddenLayers];
    }

    return [[self activeLayer] validateMenuItem:item];
}

@end
