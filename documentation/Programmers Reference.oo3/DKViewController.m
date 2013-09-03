///**********************************************************************************************************************************
///  DKViewController.m
///  DrawKit
///
///  Created by graham on 1/04/2008.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************



#import "DKViewController.h"
#import	"DKDrawing.h"
#import "DKDrawingView.h"
#import "DKGuideLayer.h"
#import "LogEvent.h"

#pragma mark Static Vars

static NSTimer* s_autoscrollTimer = nil;


@implementation DKViewController

#pragma mark - As a DKViewController
#pragma mark -  designated initializer

///*********************************************************************************************************************
///
/// method:			initWithView:
/// scope:			public instance method - designated initializer
/// description:	initialize the controller
/// 
/// parameters:		<aView> the view object that this controller manages
/// result:			the controller object
///
/// notes:			
///
///********************************************************************************************************************

- (id)					initWithView:(NSView*) aView
{
	NSAssert( aView != nil, @"can't initialize a controller for nil view");
	
	self = [super init];
	if ( self != nil )
	{
		[self setView:aView];
		[self setActivatesLayersAutomatically:YES];
	}
	
	return self;
}




#pragma mark -
#pragma mark -  fundamental objects in the controller's world

///*********************************************************************************************************************
///
/// method:			view
/// scope:			public instance method
/// description:	return the controller's view
/// 
/// parameters:		none
/// result:			the controller's view
///
/// notes:			
///
///********************************************************************************************************************

- (NSView*)				view
{
	return mViewRef;
}



///*********************************************************************************************************************
///
/// method:			drawing
/// scope:			public instance method
/// description:	return the controller's drawing
/// 
/// parameters:		none
/// result:			the controller's drawing
///
/// notes:			
///
///********************************************************************************************************************

- (DKDrawing*)			drawing
{
	return mDrawingRef;
}




#pragma mark -
#pragma mark -  updating the view from the drawing (refresh)

///*********************************************************************************************************************
///
/// method:			setViewNeedsDisplay:
/// scope:			public instance method
/// description:	mark the entire view for update
/// 
/// parameters:		<updateBoolValue> an NSNumber containing a boolValue, YES to update, NO to not update
/// result:			none
///
/// notes:			this is called by the drawing - generally you shouldn't call it directly, but instead use the
///					similar drawing methods that take simple parameter types
///
///********************************************************************************************************************

- (void)				setViewNeedsDisplay:(NSNumber*) updateBoolValue
{
	[[self view] setNeedsDisplay:[updateBoolValue boolValue]];
}


///*********************************************************************************************************************
///
/// method:			setViewNeedsDisplayInRect:
/// scope:			public instance method
/// description:	mark part of the view for update
/// 
/// parameters:		<updateRectValue> an NSValue containing a rectValue, the area to mark for update
/// result:			none
///
/// notes:			this is called by the drawing - generally you shouldn't call it directly, but instead use the
///					similar drawing methods that take simple parameter types
///
///********************************************************************************************************************

- (void)				setViewNeedsDisplayInRect:(NSValue*) updateRectValue
{
	[[self view] setNeedsDisplayInRect:[updateRectValue rectValue]];
}



///*********************************************************************************************************************
///
/// method:			drawingDidChangeToSize:
/// scope:			public instance method
/// description:	notify that the drawing has had its size changed
/// 
/// parameters:		<drawingSizeValue> an NSValue containing a sizeValue
/// result:			none
///
/// notes:			the view's bounds and frame are adjusted to enclose the full drawing size and the view is updated
///
///********************************************************************************************************************

- (void)				drawingDidChangeToSize:(NSValue*) drawingSizeValue
{
	// adjust the bounds to the size given, and the frame too, allowing for the current scale.
	
	NSSize fr = [drawingSizeValue sizeValue];
	
	fr.width *= [self viewScale];
	fr.height *= [self viewScale];
	
	[[self view] setFrameSize:fr];
	[[self view] setBoundsSize:[drawingSizeValue sizeValue]];
	[[self view] setNeedsDisplay:YES];
}


///*********************************************************************************************************************
///
/// method:			scrollViewToRect:
/// scope:			public instance method
/// description:	scroll the view so that the given area is visible
/// 
/// parameters:		<rectValue> an NSValue containing a rectValue, the rect to scroll into view
/// result:			none
///
/// notes:			this is called by the drawing - generally you shouldn't call it directly, but instead use the
///					similar drawing methods that take simple parameter types
///
///********************************************************************************************************************

- (void)				scrollViewToRect:(NSValue*) rectValue
{
	[[self view] scrollRectToVisible:[rectValue rectValue]];
}



///*********************************************************************************************************************
///
/// method:			updateViewRulerMarkersForRect:
/// scope:			public instance method
/// description:	set the ruler markers to the given rect
/// 
/// parameters:		<rectValue> an NSValue containing a rectValue, the rect to move ruler markers to
/// result:			none
///
/// notes:			this is called by the drawing - generally you shouldn't call it directly, but instead use the
///					similar drawing methods that take simple parameter types
///
///********************************************************************************************************************

- (void)				updateViewRulerMarkersForRect:(NSValue*) rectValue
{
	NSRect			rect = [rectValue rectValue];
	DKDrawingView*	v = nil;
	
	if([[self view] isKindOfClass:[DKDrawingView class]])
		v = (DKDrawingView*)[self view];
	
	if ( ! NSEqualRects( rect, NSZeroRect ) && v != nil )
	{
		[v moveRulerMarkerRepresentingObject:@"marker_h_left" toLocation:NSMinX( rect )];
		[v moveRulerMarkerRepresentingObject:@"marker_h_centre" toLocation:NSMidX( rect )];
		[v moveRulerMarkerRepresentingObject:@"marker_h_right" toLocation:NSMaxX( rect )];

		[v moveRulerMarkerRepresentingObject:@"marker_v_top" toLocation:NSMinY( rect )];
		[v moveRulerMarkerRepresentingObject:@"marker_v_centre" toLocation:NSMidY( rect )];
		[v moveRulerMarkerRepresentingObject:@"marker_v_bottom" toLocation:NSMaxY( rect )];
	}
}


///*********************************************************************************************************************
///
/// method:			hideViewRulerMarkers
/// scope:			public instance method
/// description:	hide the view's ruler markers
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this is called by the drawing - generally you shouldn't call it directly, but instead use the
///					similar drawing methods that take simple parameter types
///
///********************************************************************************************************************

- (void)				hideViewRulerMarkers
{
	[self updateViewRulerMarkersForRect:[NSValue valueWithRect:NSMakeRect( -10000, -10000, 0, 0 )]];
}



///*********************************************************************************************************************
///
/// method:			synchronizeViewRulersWithUnits:
/// scope:			public instance method
/// description:	set the rulers to match the unit string
/// 
/// parameters:		<unitString> a string used to look up the previously established ruler settings
/// result:			none
///
/// notes:			this is called by the drawing - generally you shouldn't call it directly, but instead use the
///					similar drawing methods that take simple parameter types
///
///********************************************************************************************************************

- (void)				synchronizeViewRulersWithUnits:(NSString*) unitString
{
	NSScrollView*	enclosing;
	NSRulerView*	ruler;
	
	enclosing = [[self view] enclosingScrollView];
	
	if( enclosing != nil )
	{
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


///*********************************************************************************************************************
///
/// method:			invalidateCursors
/// scope:			public instance method
/// description:	invalidate the cursor rects for the view
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this is called by the drawing - generally you shouldn't call it directly, but instead use the
///					similar drawing methods that take simple parameter types
///
///********************************************************************************************************************

- (void)				invalidateCursors
{
	[[[self view] window] invalidateCursorRectsForView:[self view]];
}


///*********************************************************************************************************************
///
/// method:			exitTemporaryTextEditingMode
/// scope:			public instance method
/// description:	stop any text editing that may be taking place in the view
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this is called by the drawing - generally you shouldn't call it directly, but instead use the
///					similar drawing methods that take simple parameter types
///
///********************************************************************************************************************

- (void)				exitTemporaryTextEditingMode
{
	[(DKDrawingView*)[self view] endTextEditing];
}


///*********************************************************************************************************************
///
/// method:			objectDidNotifyStatusChange:
/// scope:			public instance method
/// description:	an object in the drawing notified a status (rather than visual) change
/// 
/// parameters:		<object> the object that changed
/// result:			none
///
/// notes:			override to make use of this - the normal view controller just ignores this
///
///********************************************************************************************************************

- (void)				objectDidNotifyStatusChange:(id) object
{
	#pragma unused(object)
}

#pragma mark -
#pragma mark -  info about current view state

///*********************************************************************************************************************
///
/// method:			viewScale:
/// scope:			public instance method
/// description:	return the current scale of the view
/// 
/// parameters:		none
/// result:			a float value representing the view's zoom scale, 1.0 = 100%, 2.0 = 200% etc.
///
/// notes:			
///
///********************************************************************************************************************

- (float)				viewScale
{
	if([[self view] isKindOfClass:[DKDrawingView class]])
		return [(DKDrawingView*)[self view] scale];
	else
		return 1.0;
}


#pragma mark -
#pragma mark - handling mouse input events from the view

///*********************************************************************************************************************
///
/// method:			mouseDown:
/// scope:			public instance method
/// overrides:		
/// description:	handle the mouse down event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			if set to activate layers automatically, this will do so if the mouse hit something. It also starts
///					a timer for autoscrolling, so if you override this, call super to get autoscrolling, or call
///					startAutoscrolling on mouseDown.
///
///********************************************************************************************************************

- (void)				mouseDown:(NSEvent*) event
{
	// if set to activate layers automatically, find the hit layer and activate it
	
	[self autoActivateLayerWithEvent:event];
	
	// start the autoscroll timer:
	
	[self startAutoscrolling];
	
	// forward the click to the active layer if it is available:
	
	if (![[self activeLayer] lockedOrHidden])
	{
		// set layer's current view - allows compatibility with older code not expecting the view parameter
		
		[[self activeLayer] setCurrentView:[self view]];
		[[self activeLayer] mouseDown:event inView:[self view]];
	}
}



///*********************************************************************************************************************
///
/// method:			mouseDragged:
/// scope:			public instance method
/// overrides:		
/// description:	handle the mouse dragged event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				mouseDragged:(NSEvent*) event
{
	if (![[self activeLayer] lockedOrHidden])
		[[self activeLayer] mouseDragged:event inView:[self view]];
}


///*********************************************************************************************************************
///
/// method:			mouseUp:
/// scope:			public instance method
/// overrides:		
/// description:	handle the mouse up event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			this stops the autoscrolling. If you override it, call super or stopAutoscrolling to ensure auto-
///					scrolling works as intended.
///
///********************************************************************************************************************

- (void)				mouseUp:(NSEvent*) event
{
	if (![[self activeLayer] lockedOrHidden])
		[[self activeLayer] mouseUp:event inView:[self view]];

	// stop the autoscroll timer
	
	[self stopAutoscrolling];
}


///*********************************************************************************************************************
///
/// method:			mouseMoved:
/// scope:			public instance method
/// overrides:		
/// description:	handle the mouse moved event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			the basic controller ignores this - override to use it. DKDrawingView turns on mouse moved events
///					by default but other view types may not.
///
///********************************************************************************************************************

- (void)				mouseMoved:(NSEvent*) event
{
	#pragma unused(event)
}


///*********************************************************************************************************************
///
/// method:			flagsChanged:
/// scope:			public instance method
/// overrides:		
/// description:	handle the flags changed event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				flagsChanged:(NSEvent*) event
{
	if ([[self activeLayer] respondsToSelector:@selector(flagsChanged:)])
		[[self activeLayer] flagsChanged:event];
}


///*********************************************************************************************************************
///
/// method:			menuForEvent:
/// scope:			public instance method
/// overrides:		
/// description:	build a menu for a right-click event
/// 
/// parameters:		<event> the event
/// result:			a menu, or nil
///
/// notes:			this just defers to the active layer
///
///********************************************************************************************************************

- (NSMenu *)			menuForEvent:(NSEvent*) event
{
	if (![[self activeLayer] locked])
		return [[self activeLayer] menuForEvent:event inView:[self view]];
	else
		return nil;
}


///*********************************************************************************************************************
///
/// method:			rulerView:handleMouseDown:
/// scope:			public instance method
/// overrides:		NSView
/// description:	respond to a mouse-down in one of the view's rulers
/// 
/// parameters:		<aRulerView> the ruler view that started the event
///					<event> the event
/// result:			none
///
/// notes:			this implements the dragging of a guide "off' a ruler and into place in the drawing's guide layer.
///					If there is no guide layer it does nothing. This keeps control during the drag and invokes
///					the guide layer's mouseDown/dragged/up methods directly.
///
///********************************************************************************************************************

- (void)				rulerView:(NSRulerView*) aRulerView handleMouseDown:(NSEvent*) event
{
	// this is our cue to create a new guide, if the drawing has a guide layer.
	
	DKGuideLayer* gl = [[self drawing] guideLayer];
	
	if ( gl != nil )
	{
		// add h or v guide depending on ruler orientation
		
		NSPoint p = [[self view] convertPoint:[event locationInWindow] fromView:nil];
		
		[gl setCurrentView:[self view]];
		
		if ([aRulerView orientation] == NSVerticalRuler)
			[gl createVerticalGuideAndBeginDraggingFromPoint:p];
		else
			[gl createHorizontalGuideAndBeginDraggingFromPoint:p];
	
		[gl mouseDown:event inView:[self view]];
		
		BOOL keepOn = YES;
 
		while (keepOn)
		{
			event = [[[self view] window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask /*| NSPeriodicMask*/ ];
 
			switch ([event type])
			{
				case NSLeftMouseDragged:
					[(DKDrawingView*)[self view] updateRulerMouseTracking:[event locationInWindow]];
                    [gl mouseDragged:event inView:[self view]];
					[[self view] autoscroll:event];
                    break;
				
				case NSLeftMouseUp:
                    [gl mouseUp:event inView:[self view]];
                    keepOn = NO;
                    break;

				default:
                    /* Ignore any other kind of event. */
                    break;
			}
		}
	}
}

#pragma mark -

///*********************************************************************************************************************
///
/// method:			cursor
/// scope:			public instance method
/// overrides:		
/// description:	return te cursor to display when the mouse is in the view
/// 
/// parameters:		none
/// result:			a cursor
///
/// notes:			
///
///********************************************************************************************************************

- (NSCursor*)			cursor
{
	return [[self activeLayer] cursor];
}


///*********************************************************************************************************************
///
/// method:			activeCursorRect
/// scope:			public instance method
/// overrides:		
/// description:	return the active cursor rect
/// 
/// parameters:		none
/// result:			a rect
///
/// notes:			defines the area in which -cursor will be displayed - outside this rect the arrow cursor is
///					displayed.
///
///********************************************************************************************************************

- (NSRect)				activeCursorRect
{
	return [[self activeLayer] activeCursorRect];
}


#pragma mark -
#pragma mark - timer stuff for autoscrolling


///*********************************************************************************************************************
///
/// method:			startAutoscrolling
/// scope:			public instance method
/// overrides:		
/// description:	start the autoscroll timer
/// 
/// parameters:		none
/// result:			none
///
/// notes:			starts a timer running at 20fps which will cause autscrolling as long as the mouse is outside
///					the view. Normally autoscrolling should start on mouse down and stop on mouse up.
///
///********************************************************************************************************************

- (void)				startAutoscrolling
{
	if ( s_autoscrollTimer != nil )
		[self stopAutoscrolling];
	
	s_autoscrollTimer = [[NSTimer scheduledTimerWithTimeInterval:kDKAutoscrollRate
				target:self
				selector:@selector( autoscrollTimerCallback: )
				userInfo:[self view]
				repeats:YES] retain];
}


///*********************************************************************************************************************
///
/// method:			stopAutoscrolling
/// scope:			public instance method
/// overrides:		
/// description:	stop the autoscroll timer
/// 
/// parameters:		none
/// result:			none
///
/// notes:			Normally autoscrolling should start on mouse down and stop on mouse up.
///
///********************************************************************************************************************

- (void)				stopAutoscrolling
{
	[s_autoscrollTimer invalidate];
	[s_autoscrollTimer release];
	s_autoscrollTimer = nil;
}


///*********************************************************************************************************************
///
/// method:			autoscrollTimerCallback:
/// scope:			private instance method
/// description:	handles autoscrolling
/// 
/// parameters:		<timer> the timer
/// result:			none
///
/// notes:			autscrolls the view if the mouse is outside it during a drag, then invokes the controller's
//					mouseDragged: method.
///
///********************************************************************************************************************

- (void)			autoscrollTimerCallback:(NSTimer*) timer
{
	#pragma unused(timer)
	// this invokes autoscrolling on the source view based on the current mouse point 
	
	NSEvent* event = [NSApp currentEvent];
	
	if ([event type] == NSLeftMouseDragged )
	{
		if([[self view] autoscroll:event])
		{
			// call back the drag event so that there is no jerkiness as autscrolling commences - objects
			// and so forth should continue to work smoothly during the scroll
		
			[self mouseDragged:event];
		}
	}
}

#pragma mark -
#pragma mark - layer info

///*********************************************************************************************************************
///
/// method:			activeLayer
/// scope:			public instance method
/// description:	return the drawing's current active layer
/// 
/// parameters:		none
/// result:			the active layer
///
/// notes:			
///
///********************************************************************************************************************

- (DKLayer*)			activeLayer
{
	return [[self drawing] activeLayer];
}



///*********************************************************************************************************************
///
/// method:			activeLayerOfClass:
/// scope:			public instance method
/// description:	return the drawing's current active layer if it matches the given class, else nil
/// 
/// parameters:		<aClass> a layer class
/// result:			the active layer if it matches the class, otherwise nil
///
/// notes:			 
///
///********************************************************************************************************************

- (id)					activeLayerOfClass:(Class) aClass
{
	return [[self drawing] activeLayerOfClass:aClass];
}


///*********************************************************************************************************************
///
/// method:			setActivatesLayersAutomatically:
/// scope:			public instance method
/// description:	should a mouse down activate the layer it hits automatically?
/// 
/// parameters:		<acts> YES to auto-activate a layer, NO to leave it to someone else
/// result:			none
///
/// notes:			the default is YES	
///
///********************************************************************************************************************

- (void)				setActivatesLayersAutomatically:(BOOL) acts
{
	m_autoLayerSelect = acts;
}


///*********************************************************************************************************************
///
/// method:			activatesLayersAutomatically
/// scope:			public instance method
/// description:	should a mouse down activate the layer it hits automatically?
/// 
/// parameters:		none 
/// result:			YES to auto-activate a layer, NO to leave it to someone else
///
/// notes:			the default is YES	
///
///********************************************************************************************************************

- (BOOL)				activatesLayersAutomatically
{
	return m_autoLayerSelect;
}


///*********************************************************************************************************************
///
/// method:			findLayer:
/// scope:			public instance method
/// description:	which layer did the point hit?
/// 
/// parameters:		<p> a point in local coordinates 
/// result:			the topmost layer hit by the given point, else nil
///
/// notes:			test layers top-down. Each layer can decide for itself what constitutes a "hit". Typically a
///					layer is hit when any object it contains is hit.
///
///********************************************************************************************************************

- (DKLayer*)			findLayer:(NSPoint) p
{
	NSEnumerator*	iter = [[self drawing] layerTopToBottomEnumerator];
	DKLayer*	layer;
	
	while(( layer = [iter nextObject]))
	{
		if ([layer hitLayer:p] && [layer visible])
			return layer;
	}
	
	return nil;
}


///*********************************************************************************************************************
///
/// method:			activeLayerWillChangeToLayer:
/// scope:			public instance method
/// description:	a new layer is about to be activated
/// 
/// parameters:		<aLayer> the layer about to be activated 
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				activeLayerWillChangeToLayer:(DKLayer*) aLayer
{
	#pragma unused(aLayer)
	
	// the active layer will be changed for <aLayer> - override to make use of this info - the current active
	// layer can be obtained using [self activeLayer];
}


///*********************************************************************************************************************
///
/// method:			activeLayerDidChangeToLayer:
/// scope:			public instance method
/// description:	a new layer was activated
/// 
/// parameters:		<aLayer> the layer that was activated 
/// result:			none
///
/// notes:			the default method sets up the drag types for the view based on what drag types the layer is
///					able to receive. If you override this, call super to ensure dragging still operates correctly.
///
///********************************************************************************************************************

- (void)				activeLayerDidChangeToLayer:(DKLayer*) aLayer
{
	#pragma unused(aLayer)
	
	// when the active layer changes, register the drag types it declares with our view, so that the view
	// can receive drags initially on behalf of the layer (NSView must be the intial receiver of a drag).
	// See DKDrawingView+Drop for how the drags are forwarded to the layer - the controller doesn't
	// currently handle that part.

	NSArray* types = [[self activeLayer] pasteboardTypesForOperation:kDKReadableTypesForDrag];
	
	[[self view] unregisterDraggedTypes];
	
	if ( types != nil && [types count] > 0 )
		[[self view] registerForDraggedTypes:types];
}


///*********************************************************************************************************************
///
/// method:			autoActivateLayerWithEvent:
/// scope:			protected instance method
/// description:	if layers can be automatically activated, perform that switch
/// 
/// parameters:		<event> the initiating event - typically a mouseDown event. 
/// result:			YES if a new layer was actually made active, NO if it remained the same
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				autoActivateLayerWithEvent:(NSEvent*) event
{
	if ([self activatesLayersAutomatically])
	{
		NSPoint p = [[self view] convertPoint:[event locationInWindow] fromView:nil];
		DKLayer* layer = [self findLayer:p];
		
		// the layer has the final say as to whether it should be activated - it needs to return YES
		// to both -shouldAutoActivateWithEvent: and -layerMayBecomeActive in order to be made the active layer
		
		if ( layer != nil && [layer shouldAutoActivateWithEvent:event])
		{
			return [[self drawing] setActiveLayer:layer];
		}
	}

	return NO;
}

#pragma mark -
#pragma mark - user actions for layer stacking

///*********************************************************************************************************************
///
/// method:			layerBringToFront:
/// scope:			public action method
/// description:	bring the active layer to the front
/// 
/// parameters:		<sender> the sender of the action 
/// result:			none
///
/// notes:			high-level method can be invoked directly from a menu. Undoably moves the layer to front.
///
///********************************************************************************************************************

- (IBAction)			layerBringToFront:(id) sender
{
	#pragma unused(sender)
	
	// brings the active layer to the front
			
	[[self drawing] moveLayerToTop:[self activeLayer]];
	[[[self drawing] undoManager] setActionName:NSLocalizedString( @"Bring Layer To Front", @"undo string for layer bring front")];
}


///*********************************************************************************************************************
///
/// method:			layerBringForward:
/// scope:			public action method
/// description:	move the active layer 1 position forward
/// 
/// parameters:		<sender> the sender of the action 
/// result:			none
///
/// notes:			high-level method can be invoked directly from a menu. Undoably moves the layer forward.
///
///********************************************************************************************************************

- (IBAction)			layerBringForward:(id) sender
{
	#pragma unused(sender)
	
	// brings the active layer forward

	[[self drawing] moveUpLayer:[self activeLayer]];
	[[[self drawing] undoManager] setActionName:NSLocalizedString( @"Bring Layer Forwards", @"undo string for layer bring forwards")];
}


///*********************************************************************************************************************
///
/// method:			layerSendToBack:
/// scope:			public action method
/// description:	move the active layer to the back
/// 
/// parameters:		<sender> the sender of the action 
/// result:			none
///
/// notes:			high-level method can be invoked directly from a menu. Undoably moves the layer to the back.
///
///********************************************************************************************************************

- (IBAction)			layerSendToBack:(id) sender
{
	#pragma unused(sender)
	
	// sends the active layer to the back

	[[self drawing] moveLayerToBottom:[self activeLayer]];
	[[[self drawing] undoManager] setActionName:NSLocalizedString( @"Send Layer To Back", @"undo string for layer send back")];
}


///*********************************************************************************************************************
///
/// method:			layerSendBackward:
/// scope:			public action method
/// description:	move the active layer 1 position towards the back
/// 
/// parameters:		<sender> the sender of the action 
/// result:			none
///
/// notes:			high-level method can be invoked directly from a menu. Undoably moves the layer backwards.
///
///********************************************************************************************************************

- (IBAction)			layerSendBackward:(id) sender
{
	#pragma unused(sender)
	
	// sends the active layer backward

	[[self drawing] moveDownLayer:[self activeLayer]];
	[[[self drawing] undoManager] setActionName:NSLocalizedString( @"Send Layer Backwards", @"undo string for layer send backwards")];
}

#pragma mark -
#pragma mark - user actions pertaining to standard object layers

///*********************************************************************************************************************
///
/// method:			toggleSnapToGrid:
/// scope:			public action method
/// description:	toggle whether snapping to grid is enabled
/// 
/// parameters:		<sender> the sender of the action 
/// result:			none
///
/// notes:			high-level method can be invoked directly from a menu. Flips the current state of snap to grid.
///
///********************************************************************************************************************

- (IBAction)				toggleSnapToGrid:(id) sender;
{
	#pragma unused(sender)
	
	[[self drawing] setSnapsToGrid:![[self drawing] snapsToGrid]];
}


///*********************************************************************************************************************
///
/// method:			toggleSnapToGuides:
/// scope:			public action method
/// description:	toggle whether snapping to guides is enabled
/// 
/// parameters:		<sender> the sender of the action 
/// result:			none
///
/// notes:			high-level method can be invoked directly from a menu. Flips the current state of snap to guides.
///
///********************************************************************************************************************

- (IBAction)				toggleSnapToGuides:(id) sender
{
	#pragma unused(sender)
	
	[[self drawing] setSnapsToGuides:![[self drawing] snapsToGuides]];
}


///*********************************************************************************************************************
///
/// method:			toggleGridVisible:
/// scope:			public action method
/// description:	toggle whether the grid layer is visible
/// 
/// parameters:		<sender> the sender of the action 
/// result:			none
///
/// notes:			high-level method can be invoked directly from a menu. Flips the current state of grid visible.
///
///********************************************************************************************************************

- (IBAction)				toggleGridVisible:(id) sender
{
	#pragma unused(sender)
	[[[self drawing] gridLayer] setVisible:![[[self drawing] gridLayer] visible]];
}


///*********************************************************************************************************************
///
/// method:			toggleGuidesVisible:
/// scope:			public action method
/// description:	toggle whether the guide layer is visible
/// 
/// parameters:		<sender> the sender of the action 
/// result:			none
///
/// notes:			high-level method can be invoked directly from a menu. Flips the current state of guide visible.
///
///********************************************************************************************************************

- (IBAction)				toggleGuidesVisible:(id) sender
{
	#pragma unused(sender)
	[[[self drawing] guideLayer] setVisible:![[[self drawing] guideLayer] visible]];
}



#pragma mark -

///*********************************************************************************************************************
///
/// method:			copyDrawing:
/// scope:			public action method
/// description:	copies the entire drawing to the general pasteboard
/// 
/// parameters:		<sender> the sender of the action 
/// result:			none
///
/// notes:			high-level method can be invoked directly from a menu. Drawing is copied as a PDF.
///
///********************************************************************************************************************

- (IBAction)				copyDrawing:(id) sender
{
	#pragma unused(sender)
	
	BOOL saveClip = [[self drawing] clipsDrawingToInterior];
	[[self drawing] setClipsDrawingToInterior:YES];
	[[self drawing] writePDFDataToPasteboard:[NSPasteboard generalPasteboard]];
	[[self drawing] setClipsDrawingToInterior:saveClip];
}


#pragma mark -
#pragma mark - establishing relationships:

///*********************************************************************************************************************
///
/// method:			setDrawing:
/// scope:			public instance method
/// description:	set the drawin gthat the controller is attached to
/// 
/// parameters:		<aDrawing> the drawing object 
/// result:			none
///
/// notes:			DKDrawing objects own the controllers added to them. You should not call this directly - DKDrawing
///					calls this at the appropriate time when the controller is added.
///
///********************************************************************************************************************

- (void)				setDrawing:(DKDrawing*) aDrawing
{
	// called by the drawing when the controller is attached to it - do not call it directly
	
	LogEvent_(kStateEvent, @"view controller setting drawing: %@, self = %@, view = %@", aDrawing, self, [self view]);
	
	mDrawingRef = aDrawing;
	
	if ( aDrawing != nil )
	{
		// first make sure that the view is correctly set up for the drawing size
		
		[self drawingDidChangeToSize:[NSValue valueWithSize:[aDrawing drawingSize]]];
		
		// synchronise the view's rulers to the drawing's grid and units
		
		[self synchronizeViewRulersWithUnits:[aDrawing drawingUnits]];
		
		// then make the view aware of the current active layer - this sets up drag/drop for example
		
		[self activeLayerDidChangeToLayer:[aDrawing activeLayer]];
	}
}


///*********************************************************************************************************************
///
/// method:			setView:
/// scope:			public instance method
/// description:	set the view that the controller is associated with
/// 
/// parameters:		<aView> the view 
/// result:			none
///
/// notes:			You should not call this directly, it is called by the designated initializer
///
///********************************************************************************************************************

- (void)				setView:(NSView*) aView
{
	mViewRef = aView;
	
	if ( aView != nil && [aView respondsToSelector:@selector(setController:)])
		[(DKDrawingView*)aView setController:self];
}


#pragma mark -
#pragma mark - As an NSObject

///*********************************************************************************************************************
///
/// method:			dealloc
/// scope:			public instance method
/// overrides:		NSObject
/// description:	deallocate the controller
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				dealloc
{
//	LogEvent_(kLifeEvent, @"view controller dealloc = %@", self );
	// going away - make sure our view isn't holding a stale reference to this
	
	if ([self view] != nil )
	{
		if ([[self view] respondsToSelector:@selector(setController:)])
			[(DKDrawingView*)[self view] setController:nil];

		mViewRef = nil;
	}
	
	mDrawingRef = nil;
	[super dealloc];
}



///*********************************************************************************************************************
///
/// method:			forwardInvocation
/// scope:			public instance method
/// overrides:		NSObject
/// description:	forward an invocation to the active layer if it implements it
/// 
/// parameters:		<invocation> the invocation to forward
/// result:			none
///
/// notes:			DK makes a lot of use of invocaiton forwarding - views forward to their controllers, which forward
///					to the active layer, which may forward to selected objects within the layer. This allows objects
///					to respond to action methods and so forth at their own level.
///
///********************************************************************************************************************

- (void)				forwardInvocation:(NSInvocation*) invocation
{
    // commands can be implemented by the layer that wants to make use of them - this makes it happen by forwarding unrecognised
	// method calls to the active layer if possible.
	
	SEL aSelector = [invocation selector];
 
    if ([[self activeLayer] respondsToSelector:aSelector])
        [invocation invokeWithTarget:[self activeLayer]];
    else
        [self doesNotRecognizeSelector:aSelector];
}


///*********************************************************************************************************************
///
/// method:			methodSignatureForSelector:
/// scope:			public instance method
/// overrides:		NSObject
/// description:	return a method's signature
/// 
/// parameters:		<aSelector> the selector
/// result:			the signature for the method
///
/// notes:			DK makes a lot of use of invocaiton forwarding - views forward to their controllers, which forward
///					to the active layer, which may forward to selected objects within the layer. This allows objects
///					to respond to action methods and so forth at their own level.
///
///********************************************************************************************************************

- (NSMethodSignature *)	methodSignatureForSelector:(SEL) aSelector
{
	NSMethodSignature* sig;
	
	sig = [super methodSignatureForSelector:aSelector];
	
	if ( sig == nil )
		sig = [[self activeLayer] methodSignatureForSelector:aSelector];
		
	return sig;
}


///*********************************************************************************************************************
///
/// method:			respondsToSelector:
/// scope:			public instance method
/// overrides:		NSObject
/// description:	return whether the selector can be responded to
/// 
/// parameters:		<aSelector> the selector
/// result:			YES or NO
///
/// notes:			DK makes a lot of use of invocaiton forwarding - views forward to their controllers, which forward
///					to the active layer, which may forward to selected objects within the layer. This allows objects
///					to respond to action methods and so forth at their own level.
///
///********************************************************************************************************************

- (BOOL)				respondsToSelector:(SEL) aSelector
{
	return [super respondsToSelector:aSelector] || [[self activeLayer] respondsToSelector:aSelector];
}


#pragma mark -
#pragma mark As part of NSMenuValidation protocol

///*********************************************************************************************************************
///
/// method:			validateMenuItem:
/// scope:			public instance method
/// overrides:		NSObject
/// description:	enable and set menu item state for actions implemented by the controller
/// 
/// parameters:		<item> the menu item to validate
/// result:			YES or NO
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				validateMenuItem:(NSMenuItem*) item
{
	BOOL	enable = NO;
	SEL		action = [item action];
	BOOL	activeLocked = [[self activeLayer] locked] || [[self drawing] locked];
	
	if ( action == @selector( layerBringToFront: ) ||
		 action == @selector( layerBringForward: ))
	{
		enable = ([self activeLayer] != [[self drawing] topLayer] && !activeLocked);
	}
	else if ( action == @selector( layerSendToBack: ) ||
			  action == @selector( layerSendBackward: ))
	{
		enable = ([self activeLayer] != [[self drawing] bottomLayer] && !activeLocked);
	}
	else if ( action == @selector( toggleSnapToGrid: ))
	{
		enable = YES;
		[item setState:[[self drawing] snapsToGrid]? NSOnState : NSOffState];
	}
	else if ( action == @selector( toggleSnapToGuides: ))
	{
		enable = YES;
		[item setState:[[self drawing] snapsToGuides]? NSOnState : NSOffState];
	}
	else if ( action == @selector( copyDrawing: ))
	{
		enable = YES;
	}
	else if( action == @selector( toggleGridVisible: ))
	{
		enable = YES;
		BOOL vis = [[[self drawing] gridLayer] visible];
		[item setTitle:vis? NSLocalizedString(@"Hide Grid", @"menu item for Hide Grid") : NSLocalizedString(@"Show Grid", @"menu item for Show Grid")];
	}
	else if( action == @selector( toggleGuidesVisible: ))
	{
		enable = YES;
		BOOL vis = [[[self drawing] guideLayer] visible];
		[item setTitle:vis? NSLocalizedString(@"Hide Guides", @"menu item for Hide Guides") : NSLocalizedString(@"Show Guides", @"menu item for Show Guides")];
	}
	else
		enable = [[self activeLayer] validateMenuItem:item];

	return enable;
}

@end
