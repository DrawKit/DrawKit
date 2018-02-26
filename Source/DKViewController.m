/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKViewController.h"
#import "DKDrawing.h"
#import "DKDrawingView.h"
#import "DKGridLayer.h"
#import "DKGuideLayer.h"
#import "LogEvent.h"

#pragma mark Static Vars

static NSTimer* s_autoscrollTimer = nil;

@implementation DKViewController

#pragma mark - As a DKViewController
#pragma mark - designated initializer

- (instancetype)initWithView:(NSView*)aView
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
#pragma mark - fundamental objects in the controller's world

@synthesize view = mViewRef;
@synthesize drawing = mDrawingRef;

#pragma mark -
#pragma mark - updating the view from the drawing(refresh)

- (void)setViewNeedsDisplay:(NSNumber*)updateBoolValue
{
	[[self view] setNeedsDisplay:[updateBoolValue boolValue]];
}

- (void)setViewNeedsDisplayInRect:(NSValue*)updateRectValue
{
	[[self view] setNeedsDisplayInRect:[updateRectValue rectValue]];
}

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

- (void)scrollViewToRect:(NSValue*)rectValue
{
	[[self view] scrollRectToVisible:[rectValue rectValue]];
}

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

- (void)hideViewRulerMarkers
{
	[self updateViewRulerMarkersForRect:[NSValue valueWithRect:NSMakeRect(-10000, -10000, 0, 0)]];
}

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

- (void)invalidateCursors
{
	[[[self view] window] invalidateCursorRectsForView:[self view]];
}

- (void)exitTemporaryTextEditingMode
{
	[(DKDrawingView*)[self view] endTextEditing];
}

- (void)objectDidNotifyStatusChange:(id)object
{
#pragma unused(object)
}

#pragma mark -
#pragma mark - info about current view state

- (CGFloat)viewScale
{
	if ([[self view] isKindOfClass:[DKDrawingView class]])
		return [(DKDrawingView*)[self view] scale];
	else
		return 1.0;
}

#pragma mark -
#pragma mark - handling mouse input events from the view

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

- (void)mouseDragged:(NSEvent*)event
{
	if (![[self activeLayer] lockedOrHidden])
		[[self activeLayer] mouseDragged:event
								  inView:[self view]];
}

- (void)mouseUp:(NSEvent*)event
{
	if (![[self activeLayer] lockedOrHidden])
		[[self activeLayer] mouseUp:event
							 inView:[self view]];

	// stop the autoscroll timer

	[self stopAutoscrolling];
}

- (void)mouseMoved:(NSEvent*)event
{
#pragma unused(event)
}

- (void)flagsChanged:(NSEvent*)event
{
	if ([[self activeLayer] respondsToSelector:@selector(flagsChanged:)])
		[[self activeLayer] flagsChanged:event];
}

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

- (NSCursor*)cursor
{
	return [[self activeLayer] cursor];
}

- (NSRect)activeCursorRect
{
	return [[self activeLayer] activeCursorRect];
}

#pragma mark -
#pragma mark - contextual menu support
@synthesize contextualMenusEnabled = mEnableDKMenus;

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

- (void)stopAutoscrolling
{
	[s_autoscrollTimer invalidate];
	s_autoscrollTimer = nil;
}

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

- (id)activeLayerOfClass:(Class)aClass
{
	return [[self drawing] activeLayerOfClass:aClass];
}

@synthesize activatesLayersAutomatically = m_autoLayerSelect;

- (DKLayer*)findLayer:(NSPoint)p
{
	return [[self drawing] findLayerForPoint:p];
}

- (void)activeLayerWillChangeToLayer:(DKLayer*)aLayer
{
#pragma unused(aLayer)

	// the active layer will be changed for <aLayer> - override to make use of this info - the current active
	// layer can be obtained using [self activeLayer];
}

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

- (IBAction)layerBringToFront:(id)sender
{
#pragma unused(sender)

	DKLayer* active = [self activeLayer];
	DKLayerGroup* group = [active layerGroup];
	[group moveLayerToTop:active];

	[[[self drawing] undoManager] setActionName:NSLocalizedString(@"Bring Layer To Front", @"undo string for layer bring front")];
}

- (IBAction)layerBringForward:(id)sender
{
#pragma unused(sender)

	DKLayer* active = [self activeLayer];
	DKLayerGroup* group = [active layerGroup];
	[group moveUpLayer:active];

	[[[self drawing] undoManager] setActionName:NSLocalizedString(@"Bring Layer Forwards", @"undo string for layer bring forwards")];
}

- (IBAction)layerSendToBack:(id)sender
{
#pragma unused(sender)

	DKLayer* active = [self activeLayer];
	DKLayerGroup* group = [active layerGroup];
	[group moveLayerToBottom:active];

	[[[self drawing] undoManager] setActionName:NSLocalizedString(@"Send Layer To Back", @"undo string for layer send back")];
}

- (IBAction)layerSendBackward:(id)sender
{
#pragma unused(sender)

	DKLayer* active = [self activeLayer];
	DKLayerGroup* group = [active layerGroup];
	[group moveDownLayer:active];

	[[[self drawing] undoManager] setActionName:NSLocalizedString(@"Send Layer Backwards", @"undo string for layer send backwards")];
}

#pragma mark -

- (IBAction)hideInactiveLayers:(id)sender
{
#pragma unused(sender)
	[[self drawing] hideAllExcept:[self activeLayer]];
}

- (IBAction)showAllLayers:(id)sender
{
#pragma unused(sender)
	[[self drawing] showAll];
}

#pragma mark -
#pragma mark - user actions pertaining to standard object layers

- (IBAction)toggleSnapToGrid:(id)sender
{
#pragma unused(sender)

	[[self drawing] setSnapsToGrid:![[self drawing] snapsToGrid]];
}

- (IBAction)toggleSnapToGuides:(id)sender
{
#pragma unused(sender)

	[[self drawing] setSnapsToGuides:![[self drawing] snapsToGuides]];
}

- (IBAction)toggleGridVisible:(id)sender
{
#pragma unused(sender)
	[[[self drawing] gridLayer] setVisible:![[[self drawing] gridLayer] visible]];
}

- (IBAction)toggleGuidesVisible:(id)sender
{
#pragma unused(sender)
	[[[self drawing] guideLayer] setVisible:![[[self drawing] guideLayer] visible]];
}

#pragma mark -

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
}

/** @brief Forward an invocation to the active layer if it implements it

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
		NSString* title = [NSString stringWithFormat:itemRoot, gridName];

		[item setTitle:title];
		return YES;
	}

	if (action == @selector(toggleGuidesVisible:)) {
		BOOL vis = [[[self drawing] guideLayer] visible];
		NSString* gridName = [[[self drawing] guideLayer] layerName];
		NSString* itemRoot = vis ? NSLocalizedString(@"Hide %@", "menu item for Hide <layer name>") : NSLocalizedString(@"Show %@", @"menu item for Show <layer name>");
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
