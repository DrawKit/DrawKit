///**********************************************************************************************************************************
///  DKLayer.m
///  DrawKit
///
///  Created by graham on 11/08/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************


#import "DKLayer.h"
#import "DKKnob.h"
#import "DKDrawing.h"
#import "DKDrawingView.h"
#import "DKGeometryUtilities.h"
#import "GCInfoFloater.h"
#import "LogEvent.h"


#pragma mark Constants (Non-localized)

NSString*	kDKLayerLockStateDidChange		= @"kDKLayerLockStateDidChange";
NSString*	kDKLayerVisibleStateDidChange	= @"kDKLayerVisibleStateDidChange";


#pragma mark Static Vars
static int	sLayerIndexSeed = 4;


#pragma mark -
@implementation DKLayer
#pragma mark As a DKLayer
///*********************************************************************************************************************
///
/// method:			selectionColourForIndex:
/// scope:			public class method
/// description:	returns a colour that can be used as the selection colour for a layer
/// 
/// parameters:		<index> a positive number
/// result:			a colour
///
/// notes:			this simply returns a colour looked up in a table. It provides a default
///					selection colour for new layers - you can change the layer's selection colour to whatever you like - 
///					this just provides a default
///
///********************************************************************************************************************

+ (NSColor*)		selectionColourForIndex:(unsigned) indx
{
	static float colours[][3] = {{ 0.5,0.9,1 },		// light blue
								 { 1,0,0 },			// red
								 { 0,1,0 },			// green
								 { 0,1,1 },			// cyan
								 { 1,0,1 },			// magenta
								 { 1,0.5,0 }};		// orange
	
	indx = indx % 6;
	
	NSColor* colour = [NSColor colorWithDeviceRed:colours[indx][0] green:colours[indx][1] blue:colours[indx][2] alpha:1.0];
		
	return colour;
}


#pragma mark -
#pragma mark - owning drawing
///*********************************************************************************************************************
///
/// method:			drawing
/// scope:			public instance method
/// description:	returns the drawing that the layer belongs to
/// 
/// parameters:		none
/// result:			the layer's owner drawing
///
/// notes:			the drawing is the root object in a layer hierarchy, it overrides -drawing to return self, which is
///					how this works
///
///********************************************************************************************************************

- (DKDrawing*)		drawing
{
	return [[self layerGroup] drawing];
}


///*********************************************************************************************************************
///
/// method:			drawingHasNewUndoManager:
/// scope:			public instance method
/// description:	called when the drawing's undo manager is changed - this gives objects that cache the UM a chance
///					to update their references
/// 
/// parameters:		<um> the new undo manager
/// result:			none
///
/// notes:			the default implementation does nothing - override to make something of it
///
///********************************************************************************************************************

- (void)			drawingHasNewUndoManager:(NSUndoManager*) um
{
	#pragma unused(um)
	
}


///*********************************************************************************************************************
///
/// method:			undoManager
/// scope:			public instance method
/// description:	obtains the undo manager that is handling undo for the drawing and hence, this layer
/// 
/// parameters:		none
/// result:			the undo manager in use
///
/// notes:			
///
///********************************************************************************************************************

- (NSUndoManager*)	undoManager
{
	// return the nominated undo manager
	
	return [[self drawing] undoManager];
}


#pragma mark -
#pragma mark - layer group hierarchy
///*********************************************************************************************************************
///
/// method:			setGroup:
/// scope:			protected instance method
/// description:	sets the group that the layer is contained in - called automatically when the layer is added to a group
/// 
/// parameters:		<group> the group we belong to
/// result:			none
///
/// notes:			the group retains this, so the group isn't retained here
///
///********************************************************************************************************************

- (void)			setLayerGroup:(DKLayerGroup*) group
{
	m_groupRef = group;
}


///*********************************************************************************************************************
///
/// method:			group
/// scope:			protected instance method
/// description:	gets the group that the layer is contained in
/// 
/// parameters:		none
/// result:			the layer's group
///
/// notes:			the layer's group might be the drawing itself, which is a group
///
///********************************************************************************************************************

- (DKLayerGroup*)	layerGroup
{
	return m_groupRef;
}


#pragma mark -
#pragma mark - drawing
///*********************************************************************************************************************
///
/// method:			drawRect:
/// scope:			public instance method
/// description:	main entry point for drawing the layer and its contents to the drawing's views.
/// 
/// parameters:		<rect> the overall area being updated
///					<aView> the view doing the rendering
/// result:			none
///
/// notes:			can be treated as the similar NSView call - to optimise drawing you can query the view that's doing
///					the drawing and use calls such as needsToDrawRect: etc. Will not be called in
///					cases where the layer is not visible, so you don't need to test for that. Must be overridden.
///
///********************************************************************************************************************

- (void)			drawRect:(NSRect) rect inView:(DKDrawingView*) aView
{
	#pragma unused(rect)
	#pragma unused(aView)
	
	LogEvent_(kWheneverEvent, @"you should override [DKLayer drawRect:inView];");
}


///*********************************************************************************************************************
///
/// method:			isOpaque
/// scope:			public instance method
/// description:	is the layer opaque or transparent?
/// 
/// parameters:		none
/// result:			whether to treat the layer as opaque or not
///
/// notes:			can be overridden to optimise drawing in some cases. Layers below an opaque layer are skipped
///					when drawing, so if you know your layer is opaque, return YES to implement the optimisation.
///					The default is NO, layers are considered to be transparent.
///
///********************************************************************************************************************

- (BOOL)			isOpaque
{
	return NO;
}


///*********************************************************************************************************************
///
/// method:			setNeedsDisplay:
/// scope:			public instance method
/// description:	flags the whole layer as needing redrawing
/// 
/// parameters:		<update> flag whether to update or not
/// result:			none
///
/// notes:			always use this method instead of trying to access the view directly. This ensures that all attached
///					views get refreshed correctly.
///
///********************************************************************************************************************

- (void)			setNeedsDisplay:(BOOL) update
{
	[[self drawing] setNeedsDisplay:update];
}


///*********************************************************************************************************************
///
/// method:			setNeedsDisplayInRect:
/// scope:			public instance method
/// description:	flags part of a layer as needing redrawing
/// 
/// parameters:		<rect> the area that needs to be redrawn
/// result:			none
///
/// notes:			always use this method instead of trying to access the view directly. This ensures that all attached
///					views get refreshed correctly.
///
///********************************************************************************************************************

- (void)			setNeedsDisplayInRect:(NSRect) rect
{
	[[self drawing] setNeedsDisplayInRect:rect];
}


///*********************************************************************************************************************
///
/// method:			setNeedsDisplayInRects:
/// scope:			public instance method
/// description:	marks several areas for update at once
/// 
/// parameters:		<setOfRects> a set containing NSValues with rect values
/// result:			none
///
/// notes:			several update optimising methods return sets of rect values, this allows them to be processed
///					directly.
///
///********************************************************************************************************************

- (void)			setNeedsDisplayInRects:(NSSet*) setOfRects
{
	[[self drawing] setNeedsDisplayInRects:setOfRects];
}


///*********************************************************************************************************************
///
/// method:			setNeedsDisplayInRects:
/// scope:			public instance method
/// description:	marks several areas for update at once
/// 
/// parameters:		<setOfRects> a set containing NSValues with rect values
///					<padding> the width and height will be added to EACH rect before invalidating
/// result:			none
///
/// notes:			several update optimising methods return sets of rect values, this allows them to be processed
///					directly.
///
///********************************************************************************************************************

- (void)			setNeedsDisplayInRects:(NSSet*) setOfRects withExtraPadding:(NSSize) padding
{
	[[self drawing] setNeedsDisplayInRects:setOfRects withExtraPadding:padding];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setSelectionColour:
/// scope:			public instance method
/// description:	sets the colour preference to use for selected objects within this layer
/// 
/// parameters:		<colour> the selection colour preference
/// result:			none
///
/// notes:			different layers may wish to have a different colour for selections to help the user tell which
///					layer they are working in. The layer doesn't enforce this - it's up to objects to make use of
///					this provided colour where necessary.
///
///********************************************************************************************************************

- (void)			setSelectionColour:(NSColor*) colour
{
	[colour retain];
	[m_selectionColour release];
	m_selectionColour = colour;
	[self setNeedsDisplay:YES];
	
	// also set the info window's background to the same colour if it exists
	
	if( m_infoWindow != nil )
		[m_infoWindow setBackgroundColor:colour];
}


///*********************************************************************************************************************
///
/// method:			selectionColour
/// scope:			public instance method
/// description:	returns the currently preferred selection colour for this layer
/// 
/// parameters:		none
/// result:			the colour
///
/// notes:			if the current view is inactive, returns a light gray instead
///
///********************************************************************************************************************

- (NSColor*)		selectionColour
{
	NSView* rView = [[self drawing] currentView];
	
	if ( rView != nil )
	{
		NSWindow* window = [rView window];
		
		if ( window != nil &&  ![window isMainWindow])
			return [NSColor lightGrayColor];
	}
	
	return m_selectionColour;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			thumbnailImageWithSize:
/// scope:			public instance method
/// description:	returns an image of the layer a the given size
/// 
/// parameters:		<size> the desired image size
/// result:			an image of this layer only
///
/// notes:			while the image has the size passed, the rendered content will have the same aspect ratio as the
///					drawing, scaled to fit. Areas left outside of the drawn portion are transparent.
///
///********************************************************************************************************************

- (NSImage*)		thumbnailImageWithSize:(NSSize) size
{
	NSSize		drsize = [[self drawing] drawingSize];

	if ( NSEqualSizes( size, NSZeroSize ))
	{
		size.width = drsize.width / 16.0;
		size.height = drsize.height / 16.0;
	}
	
	//LogEvent_(kReactiveEvent,  @"creating layer thumbnail size: {%f, %f}", size.width, size.height );
	
	NSImage*	thumb = [[NSImage alloc] initWithSize:size];
	NSRect		tr, dr, dest;
	
	[thumb setFlipped:YES];

	tr = NSMakeRect( 0, 0, size.width, size.height );
	dr = NSMakeRect( 0, 0, drsize.width, drsize.height );

	dest = ScaledRectForSize( drsize, tr );
	
	// build a transform to scale the drawing to the destination rect size
	
	float scale = dest.size.width / drsize.width;
	NSAffineTransform*	tfm = [NSAffineTransform transform];
	[tfm scaleBy:scale];
	
	//LogEvent_(kReactiveEvent, @"scale:%f", scale );
	
	[thumb lockFocus];
	[[NSColor clearColor] set];
	NSRectFill( tr );
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	
	[tfm concat];
	[self drawRect:dr inView:nil];
	
	[[NSColor blackColor] set];
	NSFrameRectWithWidth( dr, 3.0 );
	
	[thumb unlockFocus];
	
	return [thumb autorelease];
}


///*********************************************************************************************************************
///
/// method:			thumbnail
/// scope:			public instance method
/// description:	returns an image of the layer at the default size
/// 
/// parameters:		none
/// result:			an image of this layer only
///
/// notes:			the default size is currently 1/16th of the drawing size. See - thumbnailImageWithSize: for details
///
///********************************************************************************************************************

- (NSImage*)		thumbnail
{
	return [self thumbnailImageWithSize:NSZeroSize];
}


#pragma mark -
#pragma mark - states
///*********************************************************************************************************************
///
/// method:			setLocked:
/// scope:			public instance method
/// description:	sets whether the layer is locked or not
/// 
/// parameters:		<locked> YES to lock, NO to unlock
/// result:			none
///
/// notes:			a locked layer will be drawn but cannot be edited. In case the layer's appearance changes
///					according to this state change, a refresh is performed.
///
///********************************************************************************************************************

- (void)			setLocked:(BOOL) locked
{
	if ( locked != m_locked )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setLocked:m_locked]; 
		m_locked = locked;
		[self setNeedsDisplay:YES];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerLockStateDidChange object:self];
		
		if(!([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
			[[self undoManager] setActionName:locked? NSLocalizedString(@"Lock Layer", @"undo for lock layer") : NSLocalizedString( @"Unlock Layer", @"undo for Unlock Layer")];
	}
}


///*********************************************************************************************************************
///
/// method:			locked
/// scope:			public instance method
/// description:	returns whether the layer is locked or not
/// 
/// parameters:		none
/// result:			YES if locked, NO if unlocked
///
/// notes:			locked layers cannot be edited. Also returns YES if the layer belongs to a locked group
///
///********************************************************************************************************************

- (BOOL)			locked
{
	return m_locked || [[self layerGroup] locked];
}


///*********************************************************************************************************************
///
/// method:			setVisible:
/// scope:			public instance method
/// description:	sets whether the layer is visible or not
/// 
/// parameters:		<visible> YES to show the layer, NO to hide it
/// result:			none
///
/// notes:			invisible layers are neither drawn nor can be edited.
///
///********************************************************************************************************************

- (void)			setVisible:(BOOL) visible
{
	if ( visible != m_visible )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setVisible:[self visible]]; 
		m_visible = visible;
		[self setNeedsDisplay:YES];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerVisibleStateDidChange object:self];
		
		if(!([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
			[[self undoManager] setActionName:visible? NSLocalizedString(@"Show Layer", @"undo for show layer") : NSLocalizedString( @"Hide Layer", @"undo for hide Layer")];
	}
}


///*********************************************************************************************************************
///
/// method:			visible
/// scope:			public instance method
/// description:	is the layer visible?
/// 
/// parameters:		none
/// result:			YES if visible, NO if not
///
/// notes:			also returns NO if the layer's group is not visible
///
///********************************************************************************************************************

- (BOOL)			visible
{
	return m_visible && ([self layerGroup] == nil || [[self layerGroup] visible]);
}


///*********************************************************************************************************************
///
/// method:			isActive
/// scope:			public instance method
/// description:	is the layer the active layer?
/// 
/// parameters:		none
/// result:			YES if the active layer, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			isActive
{
	return ([[self drawing] activeLayer] == self);
}


///*********************************************************************************************************************
///
/// method:			lockedOrHidden
/// scope:			public instance method
/// description:	returns whether the layer is locked or hidden
/// 
/// parameters:		none
/// result:			YES if locked or hidden, NO if unlocked and visible
///
/// notes:			locked or hidden layers cannot usually be edited.
///
///********************************************************************************************************************

- (BOOL)			lockedOrHidden
{
	return [self locked] || ![self visible];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setName:
/// scope:			public instance method
/// description:	sets the user-readable name of the layer
/// 
/// parameters:		<name> the layer's name
/// result:			none
///
/// notes:			layer names are a convenience for the user, and can be displayed by a user interface. The name is
///					not significant internally. This copies the name passed for safety.
///
///********************************************************************************************************************

- (void)			setName:(NSString*) name
{
	NSString* nameCopy = [name copy];
	
	[m_name release];
	m_name = nameCopy;
	
	LogEvent_( kStateEvent, @"layer's name was set to '%@'", m_name );
}


///*********************************************************************************************************************
///
/// method:			name
/// scope:			public instance method
/// description:	returns the layer's name
/// 
/// parameters:		none
/// result:			the name
///
/// notes:			
///
///********************************************************************************************************************

- (NSString*)		name
{
	return m_name;
}


#pragma mark -
#pragma mark - print this layer?


///*********************************************************************************************************************
///
/// method:			setShouldDrawToPrinter:
/// scope:			public instance method
/// description:	set whether this layer should be included in printed output
/// 
/// parameters:		<printIt> YES to includethe layer, NO to skip it
/// result:			none
///
/// notes:			default is YES
///
///********************************************************************************************************************

- (void)			setShouldDrawToPrinter:(BOOL) printIt
{
	m_printed = printIt;
}


///*********************************************************************************************************************
///
/// method:			shouldDrawToPrinter
/// scope:			public instance method
/// description:	return whether the layer should be part of the printed output or not
/// 
/// parameters:		none
/// result:			YES to draw to printer, NO to suppress drawing on the printer
///
/// notes:			some layers won't want to be printed - guides for example. Override this to return NO if you
///					don't want the layer to be printed. By default layers are printed.
///
///********************************************************************************************************************

- (BOOL)			shouldDrawToPrinter
{
	return m_printed;
}


#pragma mark -
#pragma mark - becoming/resigning active
///*********************************************************************************************************************
///
/// method:			layerMayBecomeActive
/// scope:			public instance method
/// description:	returns whether the layer can become the active layer
/// 
/// parameters:		none
/// result:			YES if the layer can become active, NO to not become active
///
/// notes:			The default is YES. Layers may override this and return NO if they do not want to ever become active
///
///********************************************************************************************************************

- (BOOL)			layerMayBecomeActive
{
	return YES;
}


///*********************************************************************************************************************
///
/// method:			layerDidBecomeActiveLayer
/// scope:			public instance method
/// description:	the layer was made the active layer by the owning drawing
/// 
/// parameters:		none
/// result:			none
///
/// notes:			layers may want to know when their active state changes. Override to make use of this.
///
///********************************************************************************************************************

- (void)			layerDidBecomeActiveLayer
{
	// override to make use of this message
	
	LogEvent_(kReactiveEvent, @"layer %@ became active", self);
}


///*********************************************************************************************************************
///
/// method:			layerDidResignActiveLayer
/// scope:			public instance method
/// description:	the layer is no longer the active layer
/// 
/// parameters:		none
/// result:			none
///
/// notes:			layers may want to know when their active state changes. Override to make use of this.
///
///********************************************************************************************************************

- (void)			layerDidResignActiveLayer
{
	// override to make use of this message
	
	LogEvent_(kReactiveEvent, @"layer %@ resigned active", self);
}


#pragma mark -
#pragma mark - mouse event handling
///*********************************************************************************************************************
///
/// method:			shouldAutoActivateWithEvent:
/// scope:			public instance method
/// description:	should the layer automatically activate on a click if the view has this behaviour set?
/// 
/// parameters:		<event> the event (usually a mouse down) of the view that is asking
/// result:			YES
///
/// notes:			override to return NO if your layer type should not auto activate. Note that auto-activation also
///					needs to be set for the view. The event is passed so that a sensible decision can be reached.
///
///********************************************************************************************************************

- (BOOL)			shouldAutoActivateWithEvent:(NSEvent*) event
{
	#pragma unused(event)
	
	return YES;
}


///*********************************************************************************************************************
///
/// method:			hitLayer:
/// scope:			public instance method
/// description:	detect whether the layer was "hit" by a point.
/// 
/// parameters:		<p> the point to test
/// result:			YES if the layer was hit, NO otherwise
///
/// notes:			this is used to implement automatic layer activation when the user clicks in a view. This isn't
///					always the most useful behaviour, so by default this returns NO. Subclasses can override to refine
///					the hit test appropriately.
///
///********************************************************************************************************************

- (BOOL)			hitLayer:(NSPoint) p
{
	#pragma unused(p)
	
	return NO;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			mouseDown:inView:
/// scope:			public instance method
/// description:	the mouse went down in this layer
/// 
/// parameters:		<event> the original mouseDown event
///					<view> the view which responded to the event and passed it on to us
/// result:			none
///
/// notes:			override to respond to the event
///
///********************************************************************************************************************

- (void)			mouseDown:(NSEvent*) event inView:(NSView*) view
{
	#pragma unused(event)
	#pragma unused(view)
}


///*********************************************************************************************************************
///
/// method:			mouseDragged:inView:
/// scope:			public instance method
/// description:	
/// 
/// parameters:		<event> the original mouseDragged event
///					<view> the view which responded to the event and passed it on to us
/// result:			none
///
/// notes:			Subclasses must override to be notified of mouse dragged events
///
///********************************************************************************************************************

- (void)			mouseDragged:(NSEvent*) event inView:(NSView*) view;
{
	#pragma unused(event)
	#pragma unused(view)
}


///*********************************************************************************************************************
///
/// method:			mouseUp:inView:
/// scope:			public instance method
/// description:	
/// 
/// parameters:		<event> the original mouseUpevent
///					<view> the view which responded to the event and passed it on to us
/// result:			none
///
/// notes:			override to respond to the event
///
///********************************************************************************************************************

- (void)			mouseUp:(NSEvent*) event inView:(NSView*) view;
{
	#pragma unused(event)
	#pragma unused(view)
}


///*********************************************************************************************************************
///
/// method:			flagsChanged:
/// scope:			public instance method
/// description:	respond to a change in the modifier key state
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			is passed from the key view to the active layer
///
///********************************************************************************************************************

- (void)			flagsChanged:(NSEvent*) event
{
	#pragma unused(event)
	
	// override to do something useful
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			setCurrentView
/// scope:			public instance method
/// description:	set the view that current events are coming from
/// 
/// parameters:		<view> the view
/// result:			none
///
/// notes:			this should not be called by client code - the view controller sets this prior to forwarding events
///					from the view. Note that in general you should use the view parameter passed to you - this allows
///					compatibility with code that pre-existed the parameter.
///
///********************************************************************************************************************

- (void)			setCurrentView:(NSView*) view
{
	m_eventViewRef = view;
}


///*********************************************************************************************************************
///
/// method:			currentView
/// scope:			public instance method
/// description:	returns the view which is either currently drawing the layer, or the one that mouse events are
///					coming from
/// 
/// parameters:		none
/// result:			the currently "important" view
///
/// notes:			this generally does the expected thing. If you're drawing, it returns the view that's doing the drawing
///					but if you are responding to a mouse event (down/dragged/up), this returns the view that received the
///					original event in question. At any other time it will return nil. Wherever possible you should
///					use the view parameter that is passed to you rather than use this.
///
///********************************************************************************************************************

- (NSView*)			currentView
{
	if ( m_eventViewRef )
		return m_eventViewRef;
	else
		return [DKDrawingView currentlyDrawingView];
}


///*********************************************************************************************************************
///
/// method:			cursor
/// scope:			public instance method
/// description:	returns the cursor to display while the mouse is over this layer while it's active
/// 
/// parameters:		none
/// result:			the desired cursor
///
/// notes:			subclasses will usually want to override this and provide a cursor appropriate to the layer or where
///					the mouse is within it, or which tool has been attached.
///
///********************************************************************************************************************

- (NSCursor*)		cursor
{
	return [NSCursor arrowCursor];
}


///*********************************************************************************************************************
///
/// method:			activeCursorRect
/// scope:			public instance method
/// description:	return a rect where the layer's cursor is shown when the mouse is within it
/// 
/// parameters:		none
/// result:			the cursor rect
///
/// notes:			by default the cursor rect is the entire interior area.
///
///********************************************************************************************************************

- (NSRect)			activeCursorRect
{
	return [[self drawing] interior];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			menuForEvent:inView:
/// scope:			public instance method
/// description:	allows a contextual menu to be built for the layer or its contents
/// 
/// parameters:		<theEvent> the original event (a right-click mouse event)
///					<view> the view that received the original event
/// result:			a menu that will be displayed as a contextual menu
///
/// notes:			by default this returns nil, resulting in nothing being displayed. Subclasses can override to build
///					a suitable menu for the point where the layer was clicked.
///
///********************************************************************************************************************

- (NSMenu *)		menuForEvent:(NSEvent *)theEvent inView:(NSView*) view
{
	#pragma unused(theEvent)
	#pragma unused(view)
	
	return nil;
}

#pragma mark -
#pragma mark supporting per-layer knob handling


///*********************************************************************************************************************
///
/// method:			setKnobs:
/// scope:			public method
/// overrides:
/// description:	sets the selection knob helper object used for this drawing and any objects within it
/// 
/// parameters:		<knobs> the knobs objects
/// result:			none
///
/// notes:			selection appearance can be customised for this drawing by setting up the knobs object or subclassing
///					it. This object is propagated down to all objects below this in the system to draw their selection.
///
///********************************************************************************************************************

- (void)				setKnobs:(DKKnob*) knobs
{
	[knobs retain];
	[m_knobs release];
	m_knobs = knobs;
	
	[m_knobs setOwner:self];
}


///*********************************************************************************************************************
///
/// method:			knobs
/// scope:			public method
/// overrides:
/// description:	returns the attached selection knobs helper object
/// 
/// parameters:		none
/// result:			the attached knobs object
///
/// notes:			
///
///********************************************************************************************************************

- (DKKnob*)				knobs
{
	if ( m_knobs != nil )
		return m_knobs;
	else
		return [[self layerGroup] knobs];
}


///*********************************************************************************************************************
///
/// method:			setKnobsShouldAdustToViewScale:
/// scope:			public method
/// overrides:
/// description:	sets whether selection knobs should scale to compensate for the view scale. default is YES.
/// 
/// parameters:		<ka> YES to set knobs to scale, NO to fix their size.
/// result:			none
///
/// notes:			in general it's best to scale the knobs otherwise they tend to overlap and become large at high
///					zoom factors, and vice versa. The knobs objects itself decides exactly how to perform the scaling.
///
///********************************************************************************************************************

- (void)				setKnobsShouldAdustToViewScale:(BOOL) ka
{
	m_knobsAdjustToScale = ka;
}


///*********************************************************************************************************************
///
/// method:			knobsShouldAdjustToViewScale
/// scope:			public method
/// overrides:
/// description:	return whether the drawing will scale its selection knobs to the view or not
/// 
/// parameters:		none
/// result:			YES if knobs ar scaled, NO if not
///
/// notes:			the default setting is YES, knobs should adjust to scale.
///
///********************************************************************************************************************

- (BOOL)				knobsShouldAdjustToViewScale
{
	if ( m_knobs != nil )
		return m_knobsAdjustToScale;
	else
		return NO;
}


#pragma mark -
#pragma mark - pasteboard/drag and drop support


///*********************************************************************************************************************
///
/// method:			pasteboardTypesForOperation:
/// scope:			public method
/// overrides:
/// description:	return the pasteboard types this layer is able to receive in a given operation (drop or paste)
/// 
/// parameters:		<op> the kind of operation we need pasteboard types for
/// result:			an array of pasteboard types
///
/// notes:			subclasses that are interested in receiving drag/drop should return the list of pasteboard types
///					they can handle and also implement the necessary parts of the NSDraggingDestination protocol
///					just as if they were a view.
///
///********************************************************************************************************************

- (NSArray*)		pasteboardTypesForOperation:(DKPasteboardOperationType) op
{
	#pragma unused(op)
	
	return nil;
}


///*********************************************************************************************************************
///
/// method:			pasteboard:hasAvailableTypeForOperation:
/// scope:			public method
/// overrides:
/// description:	tests whether the pasteboard has any of the types the layer is interested in receiving for the given
///					operation
/// 
/// parameters:		<pb> the pasteboard
///					<op> the kind of operation we need pasteboard types for
/// result:			YES if the pasteboard has any of the types of interest, otherwise NO
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			pasteboard:(NSPasteboard*) pb hasAvailableTypeForOperation:(DKPasteboardOperationType) op
{
	// return whether the given pasteboard has an available data type for the given operation on this object
	
	NSAssert( pb != nil, @"pasteboard is nil");
	
	NSArray* types = [self pasteboardTypesForOperation:op];
	
	if ( types != nil )
	{
		NSString* type = [pb availableTypeFromArray:types];
		return ( type != nil );
	}
	else
		return NO;
}


#pragma mark -
#pragma mark - style utilities

///*********************************************************************************************************************
///
/// method:			allStyles
/// scope:			public method
/// overrides:
/// description:	return all of styles used by the layer
/// 
/// parameters:		none
/// result:			nil
///
/// notes:			override if your layer uses styles
///
///********************************************************************************************************************

- (NSSet*)			allStyles
{
	return nil;		// generic layers have no styles
}

///*********************************************************************************************************************
///
/// method:			allRegisteredStyles
/// scope:			public method
/// overrides:
/// description:	return all of registered styles used by the layer
/// 
/// parameters:		none
/// result:			nil
///
/// notes:			override if your layer uses styles
///
///********************************************************************************************************************

- (NSSet*)			allRegisteredStyles
{
	return nil;		// generic layers have no registered styles
}


///*********************************************************************************************************************
///
/// method:			replaceMatchingStylesFromSet:
/// scope:			public method
/// overrides:
/// description:	substitute styles with those in the given set
/// 
/// parameters:		<aSet> a set of style objects
/// result:			none
///
/// notes:			subclasses may implement this to replace styles they use with styles from the set that have matching
///					keys. This is an important step in reconciling the styles loaded from a file with the existing
///					registry. Implemented by DKObjectOwnerLayer, etc. Layer groups also implement this to propagate
///					the change to all sublayers.
///
///********************************************************************************************************************

- (void)			replaceMatchingStylesFromSet:(NSSet*) aSet
{
	#pragma unused(aSet)
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			showInfoWindowWithString:atPoint:
/// scope:			public method
/// overrides:
/// description:	displays a small floating info window near the point p containg the string.
/// 
/// parameters:		<str> a pre-formatted string containg some information to display
///					<p> a point in local drawing coordinates
/// result:			none
///
/// notes:			the window is shown near the point rather than at it. Generally the info window should be used
///					for small, dynamically changing and temporary information, like a coordinate value. The background
///					colour is initially set to the layer's selection colour
///
///********************************************************************************************************************

- (void)			showInfoWindowWithString:(NSString*) str atPoint:(NSPoint) p
{
	if ( m_infoWindow == nil )
	{
		m_infoWindow = [[GCInfoFloater infoFloater] retain];
		[m_infoWindow setFormat:nil];
		[m_infoWindow setBackgroundColor:[self selectionColour]];
		[m_infoWindow setWindowOffset:NSMakeSize( 6, 10 )];
	}
	
	[m_infoWindow setStringValue:str];
	[m_infoWindow positionNearPoint:p inView:[self currentView]];
	[m_infoWindow show];
}



///*********************************************************************************************************************
///
/// method:			setInfoWindowBackgroundColour:
/// scope:			public method
/// overrides:
/// description:	sets the background colour of the small floating info window
/// 
/// parameters:		<colour> a colour for the window
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			setInfoWindowBackgroundColour:(NSColor*) colour
{
	if ( m_infoWindow == nil )
	{
		m_infoWindow = [[GCInfoFloater infoFloater] retain];
		[m_infoWindow setFormat:nil];
		[m_infoWindow setBackgroundColor:[self selectionColour]];
		[m_infoWindow setWindowOffset:NSMakeSize( 6, 10 )];
	}
	
	if ( colour != nil )
		[m_infoWindow setBackgroundColor:colour];
}



///*********************************************************************************************************************
///
/// method:			hideInfoWindow
/// scope:			public method
/// overrides:
/// description:	hides the info window if it's visible
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			hideInfoWindow
{
	[m_infoWindow hide];
}


#pragma mark -
#pragma mark - user actions
///*********************************************************************************************************************
///
/// method:			lockLayer:
/// scope:			public action method
/// description:	
/// 
/// parameters:		<sender> the sender of the action
/// result:			none
///
/// notes:			user interface level method can be linked to a menu or other appropriate UI widget
///
///********************************************************************************************************************

- (IBAction)		lockLayer:(id) sender
{
	#pragma unused(sender)
	
	[self setLocked:YES];
	[[self undoManager] setActionName:NSLocalizedString(@"Lock Layer", @"undo string for lock layer")];
}


///*********************************************************************************************************************
///
/// method:			unlockLayer:
/// scope:			public action method
/// description:	
/// 
/// parameters:		<sender> the sender of the action
/// result:			none
///
/// notes:			user interface level method can be linked to a menu or other appropriate UI widget
///
///********************************************************************************************************************

- (IBAction)		unlockLayer:(id) sender
{
	#pragma unused(sender)
	
	[self setLocked:NO];
	[[self undoManager] setActionName:NSLocalizedString(@"Unlock Layer", @"undo string for unlock layer")];
}


///*********************************************************************************************************************
///
/// method:			toggleLayerLock:
/// scope:			public action method
/// description:	
/// 
/// parameters:		<sender> the sender of the action
/// result:			none
///
/// notes:			user interface level method can be linked to a menu or other appropriate UI widget
///
///********************************************************************************************************************

- (IBAction)		toggleLayerLock:(id) sender
{
	if([self locked])
		[self unlockLayer:sender];
	else
		[self lockLayer:sender];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			showLayer:
/// scope:			public action method
/// description:	
/// 
/// parameters:		<sender> the sender of the action
/// result:			none
///
/// notes:			user interface level method can be linked to a menu or other appropriate UI widget
///
///********************************************************************************************************************

- (IBAction)		showLayer:(id) sender
{
	#pragma unused(sender)
	
	[self setVisible:YES];
	[[self undoManager] setActionName:NSLocalizedString(@"Show Layer", @"undo string for show layer")];
}


///*********************************************************************************************************************
///
/// method:			hideLayer:
/// scope:			public action method
/// description:	
/// 
/// parameters:		<sender> the sender of the action
/// result:			none
///
/// notes:			user interface level method can be linked to a menu or other appropriate UI widget
///
///********************************************************************************************************************

- (IBAction)		hideLayer:(id) sender
{
	#pragma unused(sender)
	
	[self setVisible:NO];
	[[self undoManager] setActionName:NSLocalizedString(@"Hide Layer", @"undo string for hide layer")];
}


///*********************************************************************************************************************
///
/// method:			toggleLayerVisible:
/// scope:			public action method
/// description:	
/// 
/// parameters:		<sender> the sender of the action
/// result:			none
///
/// notes:			user interface level method can be linked to a menu or other appropriate UI widget
///
///********************************************************************************************************************

- (IBAction)		toggleLayerVisible:(id) sender
{
	if([self visible])
		[self hideLayer:sender];
	else
		[self showLayer:sender];
}


#pragma mark -
#pragma mark As an NSObject
- (void)			dealloc
{
	//[[self undoManager] removeAllActionsWithTarget:self];
	
	[m_infoWindow release];
	[m_knobs release];
	[m_selectionColour release];
	[m_name release];
	
	[super dealloc];
}


///*********************************************************************************************************************
///
/// description:	designated initializer for base class of all layers
///
/// notes:			a layer must be added to a group (and ultimately a drawing, which is a group) before it can be used
///
///********************************************************************************************************************

- (id)				init
{
	self = [super init];
	if (self != nil)
	{
		NSAssert(m_groupRef == nil, @"Expected init to zero");
		[self setSelectionColour:[[self class] selectionColourForIndex:sLayerIndexSeed++]];
		[self setKnobsShouldAdustToViewScale:YES];
		m_knobs = nil;
		
		NSAssert(m_eventViewRef == nil, @"Expected init to zero");
		
		[self setVisible:YES];
		[self setLocked:NO];
		[self setShouldDrawToPrinter:YES];
		
		if ( m_selectionColour == nil )
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)			encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[coder encodeConditionalObject:[self layerGroup] forKey:@"group"];
	[coder encodeObject:[self name] forKey:@"name"];
	[coder encodeObject:[self selectionColour] forKey:@"selcolour"];
	
	[coder encodeBool:[self visible] forKey:@"visible"];
	[coder encodeBool:[self locked] forKey:@"locked"];
	[coder encodeBool:YES forKey:@"hasPrintFlag"];
	[coder encodeBool:m_printed forKey:@"printed"];
}


- (id)				initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	LogEvent_(kFileEvent, @"decoding layer %@", self);

	self = [super init];
	if (self != nil)
	{
		[self setLayerGroup:[coder decodeObjectForKey:@"group"]];
		[self setName:[coder decodeObjectForKey:@"name"]];
		
		[self setSelectionColour:[coder decodeObjectForKey:@"selcolour"]];
		[self setKnobsShouldAdustToViewScale:YES];

		NSAssert(m_eventViewRef == nil, @"Expected init to zero");
		
		[self setVisible:[coder decodeBoolForKey:@"visible"]];
		[self setLocked:[coder decodeBoolForKey:@"locked"]];
		// Check older files for presence of flag - if not there, assume YES
		BOOL hasPrintFlag = [coder decodeBoolForKey:@"hasPrintFlag"];
		if ( hasPrintFlag )
			[self setShouldDrawToPrinter:[coder decodeBoolForKey:@"printed"]];
		else
			[self setShouldDrawToPrinter:YES];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol
///*********************************************************************************************************************
///
/// method:			validateMenuItem:
/// scope:			public class method
/// description:	
/// 
/// parameters:		<item> the menu item to validate
/// result:			YES to enable the item, NO to disable it
///
/// notes:			Overrides NSObject
///
///********************************************************************************************************************

- (BOOL)			validateMenuItem:(NSMenuItem*) item
{
	BOOL	enable = NO;	
	SEL		action = [item action];
	
	if ( action == @selector( lockLayer: ))
		enable = ![self locked];
	else if ( action == @selector( unlockLayer: ))
		enable = [self locked];
	else if ( action == @selector( showLayer: ))
		enable = ![self visible];
	else if ( action == @selector( hideLayer: ))
		enable = [self visible];
		
	return enable;
}


#pragma mark -
#pragma mark As part of the DKKnobOwner protocol

- (float)			knobsWantDrawingScale
{
	// query the currently rendering view's scale and pass it back to the knobs
	
	if([self knobsShouldAdjustToViewScale])
		return [(DKDrawingView*)[[self drawing] currentView] scale];
	else
		return 1.0;
}


- (BOOL)			knobsWantDrawingActiveState
{
	// query the currently rendering view's active state and pass it back to the knobs
	
	NSWindow* window = [[[self drawing] currentView] window];
	
	// if there is no window (e.g. for a print or PDF view) assume active
	
	return ( window == nil ) || [window isMainWindow];
}


@end
