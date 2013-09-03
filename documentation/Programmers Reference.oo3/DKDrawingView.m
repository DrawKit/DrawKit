///**********************************************************************************************************************************
///  DKDrawingView.m
///  DrawKit
///
///  Created by graham on 11/08/2006.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************


#import "DKDrawingView.h"
#import "DKToolController.h"
#import "DKDrawing.h"
#import "DKGridLayer.h"
#import "GCThreadQueue.h"

#pragma mark Contants (Non-localized)

NSString* kGCDrawingViewDidBeginTextEditing				= @"kGCDrawingViewDidBeginTextEditing";
NSString* kGCDrawingViewTextEditingContentsDidChange	= @"kGCDrawingViewTextEditingContentsDidChange";
NSString* kGCDrawingViewDidEndTextEditing				= @"kGCDrawingViewDidEndTextEditing";
NSString* kGCDrawingMouseDownLocation					= @"kGCDrawingMouseDownLocation";
NSString* kGCDrawingMouseDraggedLocation				= @"kGCDrawingMouseDraggedLocation";
NSString* kGCDrawingMouseUpLocation						= @"kGCDrawingMouseUpLocation";
NSString* kGCDrawingMouseMovedLocation					= @"kGCDrawingMouseMovedLocation";
NSString* kGCDrawingMouseLocationInView					= @"kGCDrawingMouseLocationInView";
NSString* kGCDrawingMouseLocationInDrawingUnits			= @"kGCDrawingMouseLocationInDrawingUnits";


#pragma mark Static Vars

DKDrawingView*			sCurDView = nil;		// not static to allow +Drop category to access it
static NSColor*			sPageBreakColour = nil;

// handling drawing on a secondary thread:

static BOOL				sThreadedDrawing = NO;
static BOOL				sDrawingThreadShouldRun = NO;
static GCThreadQueue*	sDrawingThreadJobQueue = nil;

#pragma mark -
@implementation DKDrawingView
#pragma mark As a DKDrawingView


///*********************************************************************************************************************
///
/// method:			currentlyDrawingView
/// scope:			public class method
/// overrides:
/// description:	return the view currently drawing
/// 
/// parameters:		none
/// result:			the current view that is drawing
///
/// notes:			this is only valid during a drawRect: call - some internal parts of DK use this to obtain the
///					view doing the drawing when they do not have a direct parameter to it.
///
///********************************************************************************************************************

+ (DKDrawingView*)		currentlyDrawingView
{
	return sCurDView;
}


///*********************************************************************************************************************
///
/// method:			setPageBreakColour:
/// scope:			public class method
/// overrides:
/// description:	set the colour used to draw the page breaks
/// 
/// parameters:		<colour> the colour to draw page breaks with
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

+ (void)				setPageBreakColour:(NSColor*) colour
{
	[colour retain];
	[sPageBreakColour release];
	sPageBreakColour = colour;
}


///*********************************************************************************************************************
///
/// method:			pageBreakColour
/// scope:			public class method
/// overrides:
/// description:	get the colour used to draw the page breaks
/// 
/// parameters:		none
/// result:			a colour
///
/// notes:			
///
///********************************************************************************************************************

+ (NSColor*)			pageBreakColour
{
	if ( sPageBreakColour == nil )
	{
		sPageBreakColour = [[[NSColor lightGrayColor] colorWithAlphaComponent:0.67] retain];
	}
	
	return sPageBreakColour;
}

#pragma mark -
#pragma mark - drawing using a secondary thread (experimental)
///*********************************************************************************************************************
///
/// method:			setDrawUsingSecondaryThread			***** EXPERIMENTAL *****
/// scope:			public class method
/// overrides:
/// description:	set whether all such views should draw using a secondary thread
/// 
/// parameters:		<threaded> YES to use a secondary drawing thread, NO to draw synchronously on the main thread
/// result:			none
///
/// notes:			If <threaded> is YES, this creates and starts the thread, which then sleeps until it needs to do
///					anything. The thread can be stopped by calling again with NO.
///
///					WARNING: Highly experimental, and on current testing, has problems, including causing random
///					crashes deep inside DK, clipping of objects during motion, and others. Use at your own risk!
///
///********************************************************************************************************************

+ (void)				setDrawUsingSecondaryThread:(BOOL) threaded
{
	if ( threaded && !sThreadedDrawing )
	{
		// create a queue for the drawing invocations that are received - this is done to maintain order when
		// several views may be needing update.
		
		sDrawingThreadJobQueue = [[GCThreadQueue alloc] init];
		
		// start the thread

		[NSThread detachNewThreadSelector:@selector(secondaryThreadEntryPoint:) toTarget:self withObject:nil];
		
		sThreadedDrawing = YES;
		
		NSLog(@"main thread returning from starting secondary update thread");
	}
	
	// setting this to NO will terminate the secondary thread after the next job has been processed (if there
	// is no next job, it will not terminate). The terminating thread deletes the queue.
	
	sDrawingThreadShouldRun = threaded;
}




///*********************************************************************************************************************
///
/// method:			drawUsingSecondaryThread
/// scope:			private class method
/// overrides:
/// description:	called by the view instance to see if it should handle drawing itself or signal the thread to do it
/// 
/// parameters:		none
/// result:			YES if another thread is handling the drawing
///
/// notes:			this only returns YES if the thread was successfully created and started
///
///********************************************************************************************************************

+ (BOOL)				drawUsingSecondaryThread
{
	return sThreadedDrawing;
}


///*********************************************************************************************************************
///
/// method:			signalSecondaryThreadShouldDrawInRect:withView:
/// scope:			private class method
/// overrides:
/// description:	called by the view instance when it wants the thread to handle the view update
/// 
/// parameters:		<rect> the update rect
///					<aView> the view to update
/// result:			none
///
/// notes:			flags to the secondary thread that it has work to do. The drawing call is packagaed into an
///					NSInvocation and queued - the thread dequeues the invocation and invokes it. This *must* be
///					called from the drawRect: method.
///
///********************************************************************************************************************

+ (void)				signalSecondaryThreadShouldDrawInRect:(NSRect) rect withView:(DKDrawingView*) aView
{
	if([self drawUsingSecondaryThread])
	{
		NSInvocation*	invocation = [NSInvocation invocationWithMethodSignature:[aView methodSignatureForSelector:@selector(drawContentInRect:withRectsBeingDrawn:count:)]];
		int				rectCount;
		const NSRect*	rectsBeingDrawn = [aView copyRectsBeingDrawn:&rectCount];
		
		[invocation setTarget:aView];
		[invocation setSelector:@selector(drawContentInRect:withRectsBeingDrawn:count:)];
		[invocation setArgument:&rect atIndex:2];
		
		// the ownership of the rects being drawn pointer is passed to NSInvocation - the thread
		// will free this argument when it has finished invoking the invocation
		
		[invocation setArgument:&rectsBeingDrawn atIndex:3];
		[invocation setArgument:&rectCount atIndex:4];
		
		// queue the invocation for processing by the thread
		
		[sDrawingThreadJobQueue enqueue:invocation];
	}
}


///*********************************************************************************************************************
///
/// method:			secondaryThreadShouldRun
/// scope:			private class method
/// overrides:
/// description:	check whetherthe secondary thread should continue processing
/// 
/// parameters:		none
/// result:			YES if the thread should continue
///
/// notes:			called by the secondary thread as necessary - do not call yourself
///
///********************************************************************************************************************

+ (BOOL)				secondaryThreadShouldRun
{
	return sDrawingThreadShouldRun;
}


///*********************************************************************************************************************
///
/// method:			secondaryThreadEntryPoint:
/// scope:			private class method
/// overrides:
/// description:	this method is executed by the secondary thread
/// 
/// parameters:		<obj> not used - nil
/// result:			none
///
/// notes:			this method runs on the secondary thread until terminated by a flag. The thread blocks until there
///					is an invocation in the queue to process.
///
///********************************************************************************************************************

+ (void)				secondaryThreadEntryPoint:(id) obj
{
	#pragma unused(obj)
	
	do
	{
		NSAutoreleasePool*	pool = [[NSAutoreleasePool alloc] init];
	
		// the queue blocks until there is something to process, so this loop doesn't spin
		
		NSInvocation* inv = [sDrawingThreadJobQueue dequeue];
		
		if( inv != nil )
		{
			NSView* aView = [inv target];
			
			if( aView != nil && [aView isKindOfClass:[DKDrawingView class]])
			{
				NSRect			rect;
				NSRect*			rectsToDraw;
				int				i, rectCount;
				NSBezierPath*	clipPath = nil;
				
				[inv getArgument:&rect atIndex:2];
				[inv getArgument:&rectsToDraw atIndex:3];
				[inv getArgument:&rectCount atIndex:4];
				
				// form a clip region that is just these rects rather than their union, to really clip
				// everything that absolutely doesn't have to be updated
				
				if( rectCount > 0 )
				{
					clipPath = [[NSBezierPath alloc] init];
					
					for( i = 0; i < rectCount; ++i )
						[clipPath appendBezierPathWithRect:rectsToDraw[i]];
						
					[clipPath setWindingRule:NSEvenOddWindingRule];
				}
				
				if([aView lockFocusIfCanDraw])
				{
					if( clipPath != nil )
						[clipPath addClip];
					else
						[NSBezierPath clipRect:rect];
					
					[inv invoke];
					[[aView window] flushWindow];
					[aView unlockFocus];
				}
				
				[clipPath release];
				
				// free the memory occupied by the list of rects to draw
				
				free( rectsToDraw );
			}
		}
		
		[pool drain];
	}
	while([self secondaryThreadShouldRun]);
	
	// when the thread terminates, the queue is released
	
	sThreadedDrawing = NO;
		
	[sDrawingThreadJobQueue release];
	sDrawingThreadJobQueue = nil;

	NSLog(@"secondary thread exiting.");
}



#pragma mark -
#pragma mark - the view's controller

///*********************************************************************************************************************
///
/// method:			setController:
/// scope:			public instance method
/// overrides:
/// description:	set the view's controller
/// 
/// parameters:		<aController> the controller for this view
/// result:			none
///
/// notes:			do not call this directly - the controller will call it to set up the relationship at the right
///					time.
///
///********************************************************************************************************************

- (void)				setController:(DKViewController*) aController
{
	mControllerRef = aController;
}


///*********************************************************************************************************************
///
/// method:			controller
/// scope:			public instance method
/// overrides:
/// description:	return the view's controller
/// 
/// parameters:		none
/// result:			the controller
///
/// notes:			
///
///********************************************************************************************************************

- (DKViewController*)	controller
{
	return mControllerRef;
}



#pragma mark -
#pragma mark - drawing info

///*********************************************************************************************************************
///
/// method:			drawing
/// scope:			public instance method
/// overrides:
/// description:	return the drawing that the view will draw
/// 
/// parameters:		none
/// result:			a drawing object
///
/// notes:			the drawing is obtained via the controller, and may be nil if the controller hasn't been added
///					to a drawing yet. Even when the view owns the drawing (for auto back-end) you should use this
///					method to get a view's drawing.
///
///********************************************************************************************************************

- (DKDrawing*)			drawing
{
	return [[self controller] drawing];
}


///*********************************************************************************************************************
///
/// method:			createAutoDrawing
/// scope:			private instance method
/// overrides:
/// description:	create an entire "back end" for the view 
/// 
/// parameters:		none
/// result:			none
///
/// notes:			Normally you create a drawing, and add layers to it. However, you can also let the view create the
///					drawing back-end for you. This will occur when the view is asked to draw and there is no back end. This method
///					does the building. This feature means you can simply drop a drawingView into a NIB and get a
///					functional drawing program. For more sophisticated needs however, you really need to build it yourself.
///
///********************************************************************************************************************

- (void)				createAutoDrawing
{
	NSSize viewSize = [self bounds].size;
	
	mAutoDrawing = [[DKDrawing defaultDrawingWithSize:viewSize] retain];
	m_didCreateDrawing = YES;
	
	// create a suitable controller and add it to the drawing. Note that because the controller holds weak refs to both the view
	// and the drawing (the drawing owns its controllers), there is no retain cycle here even though for auto drawings, the view
	// owns the drawing.
	
	DKViewController* vc = [self makeViewController];
	[mAutoDrawing addController:vc];
	
	// set the undo manager for the drawing to be the view's undo manager. This is the right thing for drawings created by the view, but
	// for hand-built drawings, the owning document's undo manager is more appropriate. This also sets the undo limit to 24 - which helps
	// to prevent excessive memory use when editing a drawing, but you can adjust it to something else if you want; 0 = unlimited.
	
	[mAutoDrawing setUndoManager:[self undoManager]];
	[[self undoManager] setLevelsOfUndo:24];
}


///*********************************************************************************************************************
///
/// method:			makeViewController
/// scope:			public instance method
/// overrides:
/// description:	creates a controller for this view that can be added to a drawing
/// 
/// parameters:		none
/// result:			a controller, an instance of DKViewController or one of its subclasses
///
/// notes:			Normally you wouldn't call this yourself unless you are building the entire DK system by hand rather
///					than using DKDrawDocument or automatic drawing creation. You can override it to create different
///					kinds of controller however. Th edefault controller is DKToolController so that DK provides you
///					with a set of working drawing tools by default.
///
///********************************************************************************************************************

- (DKViewController*)	makeViewController
{
	//DKViewController*	aController = [[DKViewController alloc] initWithView:self];
	
	DKToolController* aController = [[DKToolController alloc] initWithView:self];
	return [aController autorelease];
}


#pragma mark -
#pragma mark - drawing page breaks

///*********************************************************************************************************************
///
/// method:			drawPageBreaks
/// scope:			protected method
/// overrides:
/// description:	draw page breaks based on the page break print info
/// 
/// parameters:		none
/// result:			none
///
/// notes:			called from drawRect if a p/b print info is set
///
///********************************************************************************************************************

- (void)				drawPageBreaks
{
	NSRect	pr;
	int		pagesAcross, pagesDown;
	NSSize	ds = [[self drawing] drawingSize];
	NSSize	ps = [m_pageBreakPrintInfo paperSize];
	
	ps.width -= ([m_pageBreakPrintInfo leftMargin] + [m_pageBreakPrintInfo rightMargin]);
	ps.height -= ([m_pageBreakPrintInfo topMargin] + [m_pageBreakPrintInfo bottomMargin]);

	pagesAcross = MAX( 1, truncf( ds.width / ps.width ));
	pagesDown = MAX( 1, truncf( ds.height / ps.height ));
	
	if ( fmodf( ds.width, ps.width ) > 2.0 )
		++pagesAcross;
	
	if ( fmodf( ds.height, ps.height ) > 2.0 )
		++pagesDown;

	pr.size = ps;
	
	int		page;
	
	NSBezierPath* pbPath = [NSBezierPath bezierPath];
	
	for( page = 0; page < (pagesAcross * pagesDown); ++page )
	{
		pr.origin.y = ( page / pagesAcross ) * ps.height;
		pr.origin.x = ( page % pagesAcross ) * ps.width;

		[pbPath appendBezierPathWithRect:pr];
	}
	
	[pbPath setLineWidth:2];
	[[[self class] pageBreakColour] setStroke];
	[pbPath stroke];
}


///*********************************************************************************************************************
///
/// method:			setPageBreakInfo:
/// scope:			public method
/// overrides:
/// description:	sets the print info to use for drawing the page breaks
/// 
/// parameters:		<pbpi> the print info
/// result:			none
///
/// notes:			set to nil to turn off page break drawing
///
///********************************************************************************************************************

- (void)				setPageBreakInfo:(NSPrintInfo*) pbpi
{
	[pbpi retain];
	[m_pageBreakPrintInfo release];
	m_pageBreakPrintInfo = pbpi;
	[self setNeedsDisplay:YES];
}


///*********************************************************************************************************************
///
/// method:			pageBreaksVisible
/// scope:			public action method
/// overrides:		
/// description:	are page breaks vissble?
/// 
/// parameters:		none
/// result:			YES if page breaks are visible
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				pageBreaksVisible
{
	return (m_pageBreakPrintInfo != nil);
}



///*********************************************************************************************************************
///
/// method:			toggleShowPageBreaks:
/// scope:			public action method
/// overrides:		
/// description:	show or hide the page breaks
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)				toggleShowPageBreaks:(id) sender
{
	#pragma unused(sender)
	
	if ( m_pageBreakPrintInfo )
		[self setPageBreakInfo:nil];
	else
	{
		NSDocument* doc = [[[self window] windowController] document];
	
		[self setPageBreakInfo:[doc printInfo]];
	}
}



#pragma mark -
#pragma mark - editing text directly in the drawing

///*********************************************************************************************************************
///
/// method:			editText:inRect:delegate:
/// scope:			public instance method
/// overrides:		
/// description:	start editing text in a box within the view
/// 
/// parameters:		<text> the text to edit
///					<rect> the position and size of the text box to edit within
///					<del> a delegate object
/// result:			the temporary text view created to handle the job
///
/// notes:			When an object in the drawing wishes to allow the user to edit some text, it can use this utility
///					to set up the editor. This creates a subview for text editing with the nominated text and the
///					bounds rect given within the drawing. The text is installed, selected and activated. User actions
///					then edit that text. When done, call endTextEditing. To get the text edited, call editedText
///					before ending the mode. You can only set one item at a time to be editable.
///
///********************************************************************************************************************

- (NSTextView*)			editText:(NSTextStorage*) text inRect:(NSRect) rect delegate:(id) del
{
	NSAssert( text != nil, @"text was nil when trying to start a text editing operation");
	NSAssert( rect.size.width > 0, @"editing rect has 0 or -ve width");
	NSAssert( rect.size.height > 0, @"editing rect has 0 or -ve height");

	if ( m_textEditViewRef != nil )
		[self endTextEditing];
		
	m_textEditViewRef = [[NSTextView alloc] initWithFrame:rect];
	NSLayoutManager*	lm = [m_textEditViewRef layoutManager];
	
	[lm replaceTextStorage:text];
	
	[m_textEditViewRef setDrawsBackground:NO];
	[m_textEditViewRef setFieldEditor:NO];
	[m_textEditViewRef setSelectedRange:NSMakeRange( 0, [text length])];
    [m_textEditViewRef setAllowsUndo:YES];
	[m_textEditViewRef setDelegate:del];
	
	// register self as an observer of frame change notification, so that as the view expands and shrinks, it gets refreshed and doesn't leave bits of
	// itself visible
	
	[m_textEditViewRef setPostsFrameChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editorFrameChangedNotification:) name:NSViewFrameDidChangeNotification object:m_textEditViewRef];
	
	// add the subview and make it first responder
	
	[self addSubview:m_textEditViewRef];
	[m_textEditViewRef release];
	[[self window] makeFirstResponder:m_textEditViewRef];

	[m_textEditViewRef setNeedsDisplay:YES];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCDrawingViewDidBeginTextEditing object:self];
	
	return m_textEditViewRef;
}


///*********************************************************************************************************************
///
/// method:			endTextEditing
/// scope:			public instance method
/// overrides:		
/// description:	stop the temporary text editing and get rid of the editing view
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				endTextEditing
{
	if ( m_textEditViewRef != nil )
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:m_textEditViewRef];
		
		[m_textEditViewRef setNeedsDisplay:YES];
		[m_textEditViewRef removeFromSuperview];
		m_textEditViewRef = nil;
		[self resetRulerClientView];
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCDrawingViewDidEndTextEditing object:self];
		[[self window] makeFirstResponder:self];
	}
}


///*********************************************************************************************************************
///
/// method:			editedText
/// scope:			public instance method
/// overrides:		
/// description:	return the text from the temporary editing view
/// 
/// parameters:		none
/// result:			the text
///
/// notes:			
///
///********************************************************************************************************************

- (NSTextStorage*)		editedText
{
	return [[m_textEditViewRef layoutManager] textStorage];
}


///*********************************************************************************************************************
///
/// method:			textEditingView
/// scope:			public instance method
/// overrides:		
/// description:	return the current temporary text editing view
/// 
/// parameters:		none
/// result:			the text editing view, or nil
///
/// notes:			
///
///********************************************************************************************************************

- (NSTextView*)			textEditingView
{
	return m_textEditViewRef;
}


- (void)				editorFrameChangedNotification:(NSNotification*) note
{
	[self setNeedsDisplayInRect:mEditorFrame];
	mEditorFrame = [[note object] frame];
}





#pragma mark -
#pragma mark - ruler stuff

///*********************************************************************************************************************
///
/// method:			updateRulerMouseTracking:
/// scope:			protected instance method
/// overrides:		
/// description:	set the ruler lines to the current mouse point
/// 
/// parameters:		<mouse> the current mouse poin tin local coordinates
/// result:			none
///
/// notes:			n.b. on 10.4 and earlier, there is a bug in NSRulerView that prevents both h and v ruler lines
///					showing up correctly at the same time. No workaround is known.
///
///********************************************************************************************************************

- (void)				updateRulerMouseTracking:(NSPoint) mouse
{
	// updates the mouse tracking marks on the rulers, if they are visible. Note that the point parameter is the location in the view's window
	// as obtained from an event - not the location in the drawing or view.
	
	static float ox = -1.0;
	static float oy = -1.0;

	NSRulerView*	rh;
	NSRulerView*	rv;
	NSPoint			rp;
		
	if ([[self enclosingScrollView] rulersVisible])
	{
		rv = [[self enclosingScrollView] verticalRulerView];
		rp = [rv convertPoint:mouse fromView:nil];
		
		[rv moveRulerlineFromLocation:oy toLocation:rp.y];
		oy = rp.y;

		rh = [[self enclosingScrollView] horizontalRulerView];
		rp = [rh convertPoint:mouse fromView:nil];
		
		[rh moveRulerlineFromLocation:ox toLocation:rp.x];
		ox = rp.x;
	}
}


///*********************************************************************************************************************
///
/// method:			moveRulerMarkerRepresentingObject:toLocation:
/// scope:			public instance method
/// overrides:		
/// description:	set a ruler marker to a given position
/// 
/// parameters:		<obj> an object, which is the representedObject of the marker
///					<loc> a position value to move the ruler marker to
/// result:			none
///
/// notes:			the <obj> parameter is actually the name of the image of the marker, used here as a key to
///					identify that particular marker.
///
///********************************************************************************************************************

- (void)				moveRulerMarkerRepresentingObject:(id) obj toLocation:(float) loc
{
	NSScrollView*	sv = [self enclosingScrollView];
	NSRulerView*	rv;
	NSRulerMarker*	rm;
	NSArray*		markers;
	unsigned		i;
		
	rv = [sv horizontalRulerView];
	markers = [rv markers];
	
	for( i = 0; i < [markers count]; i++ )
	{
		rm = [markers objectAtIndex:i];
		
		if ([obj isEqual:[rm representedObject]])
		{
			[rv setNeedsDisplayInRect:[rm imageRectInRuler]];
			[rm setMarkerLocation:loc];
			[rv setNeedsDisplayInRect:[rm imageRectInRuler]];
			return;
		}
	}
	
	rv = [sv verticalRulerView];
	markers = [rv markers];
	
	for( i = 0; i < [markers count]; i++ )
	{
		rm = [markers objectAtIndex:i];
		
		if ([obj isEqual:[rm representedObject]])
		{
			[rv setNeedsDisplayInRect:[rm imageRectInRuler]];
			[rm setMarkerLocation:loc];
			[rv setNeedsDisplayInRect:[rm imageRectInRuler]];
			return;
		}
	}
}


///*********************************************************************************************************************
///
/// method:			imageResourceNamed:
/// scope:			public instance method
/// overrides:		
/// description:	return an image resource.
/// 
/// parameters:		<name> the resource name
/// result:			none
///
/// notes:			utility method gets the image from the app or framework bundle.
///
///********************************************************************************************************************

- (NSImage*)			imageResourceNamed:(NSString*)name
{
	NSString *path = [[NSBundle bundleForClass:[self class]] pathForImageResource:name];
	NSImage *image = [[NSImage alloc] initByReferencingFile:path];
	return [image autorelease];
}

///*********************************************************************************************************************
///
/// method:			createRulerMarkers
/// scope:			public instance method
/// overrides:		
/// description:	set up th emarkers for the rulers.
/// 
/// parameters:		none
/// result:			none
///
/// notes:			done as part of the view's initialization - markers are initially created offscreen.
///
///********************************************************************************************************************

- (void)				createRulerMarkers
{
	NSScrollView*	sv = [self enclosingScrollView];
	NSRulerView*	rv;
	NSRulerMarker*	rm;
	NSImage*		markerImg;
	
	rv = [sv horizontalRulerView];

	markerImg = [self imageResourceNamed:@"marker_h_left"];
	rm = [[NSRulerMarker alloc] initWithRulerView:rv markerLocation:-10000.0 image:markerImg imageOrigin:NSMakePoint(7.0, 0.0)];
	[rm setRepresentedObject:@"marker_h_left"];
	[rv addMarker:rm];
	
	markerImg = [self imageResourceNamed:@"marker_h_centre"];
	rm = [[NSRulerMarker alloc] initWithRulerView:rv markerLocation:-10000.0 image:markerImg imageOrigin:NSMakePoint(4.0, 0.0)];
	[rm setRepresentedObject:@"marker_h_centre"];
	[rv addMarker:rm];
	
	markerImg = [self imageResourceNamed:@"marker_h_right"];
	rm = [[NSRulerMarker alloc] initWithRulerView:rv markerLocation:-10000.0 image:markerImg imageOrigin:NSMakePoint(0.0, 0.0)];
	[rm setRepresentedObject:@"marker_h_right"];
	[rv addMarker:rm];
	
	rv = [sv verticalRulerView];
	
	markerImg = [self imageResourceNamed:@"marker_v_top"];
	rm = [[NSRulerMarker alloc] initWithRulerView:rv markerLocation:-10000.0 image:markerImg imageOrigin:NSMakePoint(8.0, 1.0)];
	[rm setRepresentedObject:@"marker_v_top"];
	[rv addMarker:rm];
	
	markerImg = [self imageResourceNamed:@"marker_v_centre"];
	rm = [[NSRulerMarker alloc] initWithRulerView:rv markerLocation:-10000.0 image:markerImg imageOrigin:NSMakePoint(5.0, 5.0)];
	[rm setRepresentedObject:@"marker_v_centre"];
	[rv addMarker:rm];
	
	markerImg = [self imageResourceNamed:@"marker_v_bottom"];
	rm = [[NSRulerMarker alloc] initWithRulerView:rv markerLocation:-10000.0 image:markerImg imageOrigin:NSMakePoint(8.0, 8.0)];
	[rm setRepresentedObject:@"marker_v_bottom"];
	[rv addMarker:rm];
}


///*********************************************************************************************************************
///
/// method:			removeRulerMarkers
/// scope:			public instance method
/// overrides:		
/// description:	remove the markers from the rulers.
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeRulerMarkers
{
	NSRulerView*	rv = [[self enclosingScrollView] horizontalRulerView];
	[rv setMarkers:nil];
	
	rv = [[self enclosingScrollView] verticalRulerView];
	[rv setMarkers:nil];
}


///*********************************************************************************************************************
///
/// method:			resetRulerClientView
/// scope:			public instance method
/// overrides:		
/// description:	set up the client view for the rulers.
/// 
/// parameters:		none
/// result:			none
///
/// notes:			done as part of the view's initialization
///
///********************************************************************************************************************

- (void)				resetRulerClientView
{
	NSRulerView* ruler;
	
	ruler = [[self enclosingScrollView] horizontalRulerView];
	[ruler setClientView:self];
	[ruler setReservedThicknessForAccessoryView:8.0];
	[ruler setAccessoryView:nil];
	
	ruler = [[self enclosingScrollView] verticalRulerView];
	[ruler setClientView:self];
	[ruler setReservedThicknessForAccessoryView:2.0];
	
	[self createRulerMarkers];
}


///*********************************************************************************************************************
///
/// method:			toggleRuler:
/// scope:			public action method
/// overrides:		
/// description:	show or hide the ruler.
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			toggleRuler:(id) sender
{
	#pragma unused(sender)
	
	BOOL rvis = [[self enclosingScrollView] rulersVisible];
	[[self enclosingScrollView] setRulersVisible:!rvis];
}



#pragma mark -
#pragma mark - monitoring the mouse location

///*********************************************************************************************************************
///
/// method:			postMouseLocationInfo:event:
/// scope:			private instance method
/// overrides:		
/// description:	broadcast the current mouse position in both native and drawing coordinates.
/// 
/// parameters:		<operation> the name of the notification
///					<event> the event associated with this
/// result:			none
///
/// notes:			A UI that displays the current mouse position could use this notification to keep itself updated.
///
///********************************************************************************************************************

- (void)				postMouseLocationInfo:(NSString*) operation event:(NSEvent*) event
{
	NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:2];
	NSPoint	p = [self convertPoint:[event locationInWindow] fromView:nil];
	NSPoint cp = [[[self drawing] gridLayer] gridLocationForPoint:p];
	
	[dict setObject:[NSValue valueWithPoint:p] forKey:kGCDrawingMouseLocationInView];
	[dict setObject:[NSValue valueWithPoint:cp] forKey:kGCDrawingMouseLocationInDrawingUnits];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:operation object:self userInfo:dict];
}


#pragma mark -
#pragma mark window activations

///*********************************************************************************************************************
///
/// method:			windowActiveStateChanged
/// scope:			private notificaiton callback
/// overrides:		
/// description:	invalidate the view when window active state changes.
/// 
/// parameters:		<note> the notification
/// result:			none
///
/// notes:			drawings can change appearance when the active state changes, for example selections are drawn
///					in inactive colour, etc. This makes sure that the drawing is refreshed when the state does change.
///
///********************************************************************************************************************

- (void)				windowActiveStateChanged:(NSNotification*) note
{
	#pragma unused(note)
	[self setNeedsDisplay:YES];
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			drawContentInRect:withRectsBeingDrawn:
/// scope:			public instance method
/// overrides:		
/// description:	draw the content of the drawing.
/// 
/// parameters:		<rect> the rect to update
/// result:			none
///
/// notes:			draws the entire drawing content, then any controller-based content, then finally the pagebreaks.
///					This is factored from drawRect: to permit calling it from a secondary worker thread.
///
///********************************************************************************************************************

- (void)				drawContentInRect:(NSRect) rect withRectsBeingDrawn:(const NSRect*) rectList count:(int) count
{
	#pragma unused(rectList)
	
	//NSLog(@"rectList = %p", rectList );
	
	mRectDrawingList = rectList;
	mRectCount = count;
	
	// draw the entire content of the drawing:
	
	sCurDView = self;
	[[self drawing] drawRect:rect inView:self];
	
	// if our controller implements a drawRect: method, call it - the default controller doesn't but subclasses can.
	// any drawing done by a controller will be "on top" of any drawing content. Typically this is used by tools
	// that draw something, such as a selection rect, etc.
	
	if([[self controller] respondsToSelector:@selector(drawRect:)])
		[(id)[self controller] drawRect:rect];
	
	sCurDView = nil;
	
	// draw page breaks on top of everything else if enabled
	
	if([NSGraphicsContext currentContextDrawingToScreen] && [self pageBreaksVisible])
		[self drawPageBreaks];
		
	mRectDrawingList = NULL;
	mRectCount = 0;
}


///*********************************************************************************************************************
///
/// method:			copyRectsBeingDrawn:
/// scope:			public instance method
/// overrides:		
/// description:	copies the current rects being drawn into a buffer and returns a pointer to it
/// 
/// parameters:		none
/// result:			a pointer to a buffer containing NSRect objects. The caller is responsible for freeing the buffer
///					when needed.
///
/// notes:			this should only be called within a drawRect: call - at other times the rects are not valid. It can
///					be used to cache the state of the update rects to pass them to the secondary drawing thread.
///
///********************************************************************************************************************

- (NSRect*)				copyRectsBeingDrawn:(int*) count
{
	const NSRect*	originals;
	NSRect*			copy = NULL;
	int				rectCount;
	size_t			bytes = 0;
	
	[self getRectsBeingDrawn:&originals count:&rectCount];
	
	if( rectCount > 0 )
	{
		bytes = sizeof( NSRect ) * rectCount;
		copy = malloc( bytes );
		memcpy( copy, originals, bytes );
	}
	
	if( count )
		*count = rectCount;
	
	//NSLog(@"copied %d rects, bytes = %d, ptr = %p", count, bytes, copy );

	return copy;
}


#pragma mark -
#pragma mark As an NSView

- (BOOL)				needsToDrawRect:(NSRect) aRect
{
	if( mRectDrawingList == NULL )
		return [super needsToDrawRect:aRect];
	else
	{
		// using the cached rects from the secondary thread, so need to go through and test them
		
		int i;
		
		//NSLog(@"testing %d rects for intersection", mRectCount );
		
		for( i = 0; i < mRectCount; ++i )
		{
			NSRect r = mRectDrawingList[i];
			
			//NSLog(@"update rect = %@", NSStringFromRect( r ));
		
			if( NSIntersectsRect( aRect, r ))
				return YES;
		}
	}
	
	return NO;
}


///*********************************************************************************************************************
///
/// method:			drawRect:
/// scope:			public instance method
/// overrides:		NSView
/// description:	draw the content of the drawing.
/// 
/// parameters:		<rect> the rect to update
/// result:			none
///
/// notes:			draws the entire drawing content, then any controller-based content, then finally the pagebreaks.
///					If at this point there is no drawing, one is automatically created so that you can get a working
///					DK system simply by dropping a DKDrawingView into a window in a nib, and away you go.
///
///********************************************************************************************************************

- (void)				drawRect:(NSRect) rect
{
	// if at the point where the view is asked to draw something, there is no "back end", it creates one
	// automatically on the basis of its current bounds. In this case, the view owns the drawing.
	
	if ([self drawing] == nil )
		[self createAutoDrawing];
	
	// draw everything, possibly using the secondary update thread:

	if([[self class] drawUsingSecondaryThread])
		[[self class] signalSecondaryThreadShouldDrawInRect:rect withView:self];
	else
		[self drawContentInRect:rect withRectsBeingDrawn:NULL count:0];
}


///*********************************************************************************************************************
///
/// method:			isFlipped
/// scope:			public instance method
/// overrides:		NSView
/// description:	is the view flipped.
/// 
/// parameters:		none
/// result:			returns the flipped state of the drawing itself (which actually only affects the views, but
///					the drawing holds this state because all views should be consistent)
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				isFlipped
{
	if([self drawing] != nil )
		return [[self drawing] isFlipped];
	else
		return YES;
}


///*********************************************************************************************************************
///
/// method:			isOpaque
/// scope:			public instance method
/// overrides:		NSView
/// description:	is the view opaque, yes.
/// 
/// parameters:		none
/// result:			always YES
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				isOpaque
{
	return YES;
}


///*********************************************************************************************************************
///
/// method:			resetCursorRects
/// scope:			public instance method
/// overrides:		NSView
/// description:	invalidate the cursor rects and set up new ones
/// 
/// parameters:		none
/// result:			none
///
/// notes:			the controller will supply a cursor and an active rect to apply it in
///
///********************************************************************************************************************

- (void)				resetCursorRects
{
	NSCursor*	curs = [[self controller] cursor];
	NSRect		cr = [[self controller] activeCursorRect];
	
	cr = NSIntersectionRect( cr, [self visibleRect]);
	
	[self addCursorRect:cr cursor:curs];
	[curs setOnMouseEntered:YES];
}



///*********************************************************************************************************************
///
/// method:			menuForEvent:
/// scope:			public instance method
/// overrides:		
/// description:	create a menu that is used for a right-click in the view
/// 
/// parameters:		<event> the event
/// result:			a menu, or nil
///
/// notes:			initially defers to the controller, then to super
///
///********************************************************************************************************************

- (NSMenu *)			menuForEvent:(NSEvent*) event
{
	NSMenu* menu = [[self controller] menuForEvent:event];
	
	if ( menu == nil )
		menu = [super menuForEvent:event];
		
	return menu;
}


#pragma mark -
#pragma mark As an NSResponder

///*********************************************************************************************************************
///
/// method:			acceptsFirstResponder
/// scope:			public instance method
/// overrides:		
/// description:	can the view be 1st R?
/// 
/// parameters:		none
/// result:			always YES
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				acceptsFirstResponder
{
	return YES;
}


///*********************************************************************************************************************
///
/// method:			keyDown:
/// scope:			public instance method
/// overrides:		
/// description:	handle the key down event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			key down events are preprocessed in the usual way and end up getting forwarded down through
///					the controller and active layer because of invocation forwarding. Thus you can respond to
///					normal NSResponder methods at any level that makes sense within DK. The controller is however
///					given first shot at the raw event, in case it does something special (like DKToolController does
///					for selecting a tool using a keyboard shortcut).
///
///********************************************************************************************************************

- (void)				keyDown:(NSEvent*) event
{
	if([[self controller] respondsToSelector:@selector(keyDown:)])
		[(NSResponder*)[self controller] keyDown:event];
	else
		[self interpretKeyEvents:[NSArray arrayWithObject:event]];
}


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
/// notes:			the view defers to its controller after broadcasting the mouse position info
///
///********************************************************************************************************************

- (void)				mouseDown:(NSEvent*) event
{
	[self postMouseLocationInfo:kGCDrawingMouseDownLocation event:event];
	[[self controller] mouseDown:event];
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
/// notes:			the view defers to its controller after broadcasting the mouse position info
///
///********************************************************************************************************************

- (void)				mouseDragged:(NSEvent*) event
{
	[self updateRulerMouseTracking:[event locationInWindow]];
	[self postMouseLocationInfo:kGCDrawingMouseDraggedLocation event:event];
	[[self controller] mouseDragged:event];
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
/// notes:			the view defers to its controller after updating the ruler lines and broadcasting the mouse position info
///
///********************************************************************************************************************

- (void)				mouseMoved:(NSEvent*) event
{
	// update the ruler mouse tracking lines if the rulers are visible.

	[self updateRulerMouseTracking:[event locationInWindow]];
	[self postMouseLocationInfo:kGCDrawingMouseMovedLocation event:event];
	[[self controller] mouseMoved:event];
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
/// notes:			the view defers to its controller after broadcasting the mouse position info
///
///********************************************************************************************************************

- (void)				mouseUp:(NSEvent*) event
{
	[self postMouseLocationInfo:kGCDrawingMouseUpLocation event:event];
	[[self controller] mouseUp:event];
}


///*********************************************************************************************************************
///
/// method:			flagsChanged:
/// scope:			public instance method
/// overrides:		NSResponder
/// description:	handle the flags changed event
/// 
/// parameters:		<event> the event
/// result:			none
///
/// notes:			the view simply defers to its controller
///
///********************************************************************************************************************

- (void)				flagsChanged:(NSEvent*) event
{
	[[self controller] flagsChanged:event];
}


///*********************************************************************************************************************
///
/// method:			doCommandBySelector:
/// scope:			public instance method
/// overrides:		NSResponder
/// description:	do the command requested
/// 
/// parameters:		<aSelector> the selector for a command
/// result:			none
///
/// notes:			this overrides the default implementation to send itself as the <sender> parameter. Because in
///					fact the selector is actually forwarded down to some other objects deep inside DK, this is a very
///					easy way for them to get passed the view from whence the event came. NSResponder methods such
///					as moveLeft: are called by this.
///
///********************************************************************************************************************

- (void)				doCommandBySelector:(SEL) aSelector
{
	if([self respondsToSelector:aSelector])
		[self tryToPerform:aSelector with:self];
	else
		[super doCommandBySelector:aSelector];
}


#pragma mark -
#pragma mark As an NSObject

///*********************************************************************************************************************
///
/// method:			dealloc
/// scope:			public instance method
/// overrides:		NSObject
/// description:	deallocate the view
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				dealloc
{
	// going away - make sure our controller is removed from the drawing
	
	if([self controller] != nil)
	{
		[[self controller] setView:nil];
		[[self drawing] removeController:[self controller]];
		[self setController:nil];
	}
		
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[m_pageBreakPrintInfo release];
	
	// if the view automatically created its own "back-end", release all of that now - the drawing owns the controllers so
	// they are also disposed of.

	if ( m_didCreateDrawing && mAutoDrawing != nil )
		[mAutoDrawing release];

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

    if ([[self controller] respondsToSelector:aSelector])
        [invocation invokeWithTarget:[self controller]];
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
		sig = [[self controller] methodSignatureForSelector:aSelector];

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
	BOOL responds = [super respondsToSelector:aSelector];
	
	if( !responds )
		responds = [[self controller] respondsToSelector:aSelector];
		
	return responds;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol

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

- (BOOL)					validateMenuItem:(NSMenuItem*) item
{
	BOOL	enable = YES;
	SEL		action = [item action];
	
	if ( action == @selector(toggleRuler:))
	{
		BOOL rvis = [[self enclosingScrollView] rulersVisible];
		[item setTitle:NSLocalizedString( rvis? @"Hide Rulers" : @"Show Rulers", @"" )];
	}
	else if ( action == @selector(toggleShowPageBreaks:))
	{
		[item setTitle:NSLocalizedString((m_pageBreakPrintInfo != nil)? @"Hide Page Breaks" : @"Show Page Breaks", @"page break menu items")];
	}
	else
		enable = [[self controller] validateMenuItem:item] | [super validateMenuItem:item];
	
	return enable;
}


#pragma mark -
#pragma mark As part of NSNibAwaking Protocol

///*********************************************************************************************************************
///
/// method:			awakeFromNib
/// scope:			public instance method
/// overrides:		NSNibAwaking
/// description:	set up the rulers and other defaults when the view is first created
/// 
/// parameters:		none
/// result:			none
///
/// notes:			Typically you should create your views from a NIB, it's just much easier that way. If you decide to
///					do it the hard way you'll have to do this set up yourself.
///
///********************************************************************************************************************

- (void)				awakeFromNib
{
	//[[self class] setDrawUsingSecondaryThread:YES];
	
	NSScrollView*		sv = [self enclosingScrollView];
	
	if ( sv )
	{
		[sv setHasHorizontalRuler:YES];
		[sv setHasVerticalRuler:YES];
		[sv setRulersVisible:YES];
		[sv setDrawsBackground:YES];
		[sv setBackgroundColor:[NSColor lightGrayColor]];
		
		[[sv horizontalRulerView] setClientView:self];
		[[sv horizontalRulerView] setReservedThicknessForMarkers:10.0];
		
		[[sv verticalRulerView] setClientView:self];
		[[sv verticalRulerView] setReservedThicknessForMarkers:10.0];
		
		[self resetRulerClientView];
	}
	[[self window] setAcceptsMouseMovedEvents:YES];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowActiveStateChanged:) name:NSWindowDidResignMainNotification object:[self window]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowActiveStateChanged:) name:NSWindowDidBecomeMainNotification object:[self window]];
}


@end
