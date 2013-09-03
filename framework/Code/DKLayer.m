///**********************************************************************************************************************************
///  DKLayer.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 11/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************


#import "DKLayer.h"
#import "DKKnob.h"
#import "DKDrawing.h"
#import "DKDrawingView.h"
#import "DKSelectionPDFView.h"
#import "DKGeometryUtilities.h"
#import "GCInfoFloater.h"
#import "LogEvent.h"
#import "DKLayer+Metadata.h"
#import "DKUniqueID.h"
#import "NSDictionary+DeepCopy.h"

#pragma mark Constants (Non-localized)

NSString*	kDKLayerLockStateDidChange					= @"kDKLayerLockStateDidChange";
NSString*	kDKLayerVisibleStateDidChange				= @"kDKLayerVisibleStateDidChange";
NSString*	kDKLayerNameDidChange						= @"kDKLayerNameDidChange";
NSString*	kDKLayerSelectionHighlightColourDidChange	= @"kDKLayerSelectionHighlightColourDidChange";


#pragma mark Static Vars
static NSInteger	sLayerIndexSeed = 4;


#pragma mark -
@implementation DKLayer
#pragma mark As a DKLayer


static NSArray*	s_selectionColours = nil;


///*********************************************************************************************************************
///
/// method:			setSelectionColours:
/// scope:			public class method
/// description:	allows a list of colours to be set for supplying the selection colours
/// 
/// parameters:		<listOfColours> an array containing NSColor objects
/// result:			none
///
/// notes:			the list is used to supply colours in rotation when new layers are instantiated
///
///********************************************************************************************************************

+ (void)			setSelectionColours:(NSArray*) listOfColours
{
	[listOfColours retain];
	[s_selectionColours release];
	s_selectionColours = listOfColours;
}


///*********************************************************************************************************************
///
/// method:			selectionColours
/// scope:			public class method
/// description:	returns the list of colours used for supplying the selection colours
/// 
/// parameters:		none
/// result:			an array containing NSColor objects
///
/// notes:			If never specifically set, this returns a very simple list of basic colours which is what DK has
///					traditionally used.
///
///********************************************************************************************************************

+ (NSArray*)		selectionColours
{
	if( s_selectionColours == nil )
	{
		NSMutableArray* list = [NSMutableArray array];

		static CGFloat colours[][3] = {{ 0.5,0.9,1 },	// light blue
									{ 1,0,0 },			// red
									{ 0,1,0 },			// green
									{ 0,0.7,0.7 },		// cyanish
									{ 1,0,1 },			// magenta
									{ 1,0.5,0 }};		// orange
		
		NSInteger i;
		
		for( i = 0; i < 6; i++ )
		{
			NSColor* colour = [NSColor colorWithDeviceRed:colours[i][0] green:colours[i][1] blue:colours[i][2] alpha:1.0];
			[list addObject:colour];
		}
		
		[self setSelectionColours:list];
	}
	
	return s_selectionColours;
}


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

+ (NSColor*)		selectionColourForIndex:(NSUInteger) indx
{
	NSArray* selColours = [self selectionColours];
	
	if( selColours && [selColours count] > 0 )
	{
		indx = indx % [selColours count];
		return [selColours objectAtIndex:indx];
	}
	else
		return nil;
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
/// method:			drawingDidChangeToSize:
/// scope:			public instance method
/// description:	called when the drawing's size is changed - this gives layers that need to know about this a
///					direct notification
/// 
/// parameters:		<sizeVal> the new size of the drawing - extract -sizeValue.
/// result:			none
///
/// notes:			if you need to know before and after sizes, you'll need to subscribe to the relevant notifications.
///
///********************************************************************************************************************

- (void)			drawingDidChangeToSize:(NSValue*) sizeVal
{
	#pragma unused(sizeVal)

}


///*********************************************************************************************************************
///
/// method:			drawingDidChangeMargins:
/// scope:			public instance method
/// description:	called when the drawing's margins changed - this gives layers that need to know about this a
///					direct notification
/// 
/// parameters:		<oldInterior> the old interior rect of the drawing - extract -rectValue.
/// result:			none
///
/// notes:			the old interior is passed - you can get the new one directly from the drawing
///
///********************************************************************************************************************

- (void)			drawingDidChangeMargins:(NSValue*) oldInterior
{
	#pragma unused(oldInterior)
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


///*********************************************************************************************************************
///
/// method:			wasAddedToDrawing:
/// scope:			public instance method
/// description:	notifies the layer that it or a group containing it was added to a drawing.
/// 
/// parameters:		<aDrawing> the drawing that added the layer
/// result:			none
///
/// notes:			this can be used to perform additional setup that requires knowledge of the drawing such as its
///					size. The default method does nothing - override to use.
///
///********************************************************************************************************************

- (void)			wasAddedToDrawing:(DKDrawing*) aDrawing
{
#pragma unused(aDrawing)
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


///*********************************************************************************************************************
///
/// method:			group
/// scope:			public instance method
/// description:	gets the layer's index within the group that the layer is contained in
/// 
/// parameters:		none
/// result:			an integer, the layer's index
///
/// notes:			if the layer isn't in a group yet, result is 0. This is intended for debugging mostly.
///
///********************************************************************************************************************

- (NSUInteger)		indexInGroup
{
	return [[self layerGroup] indexOfLayer:self];
}


///*********************************************************************************************************************
///
/// method:			isChildOfGroup:
/// scope:			public instance method
/// description:	determine whether a given group is the parent of this layer, or anywhere above it in the hierarchy
/// 
/// parameters:		<aGroup> a layer group
/// result:			YES if the group sits above this in the hierarchy, NO otherwise
///
/// notes:			intended to check for absurd operations, such as moving a parent group into one of its own children.
///
///********************************************************************************************************************

- (BOOL)			isChildOfGroup:(DKLayerGroup*) aGroup
{
	if([self layerGroup] == aGroup)
		return YES;
	else if([self layerGroup] == nil )
		return NO;
	else
		return [[self layerGroup] isChildOfGroup:aGroup];
}


///*********************************************************************************************************************
///
/// method:			level
/// scope:			public method
/// overrides:
/// description:	returns the hierarchical level of this layer, i.e. how deeply nested it is
/// 
/// parameters:		none
/// result:			the layer's level
///
/// notes:			layers in the root group return 1. A layer's level is its group's level + 1 
///
///********************************************************************************************************************

- (NSUInteger)		level
{
	return [[self layerGroup] level] + 1;
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
	
	NSLog(@"you should override [DKLayer drawRect:inView];");
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


///*********************************************************************************************************************
///
/// method:			beginDrawing
/// scope:			public instance method
/// description:	called before the layer starts drawing its content
/// 
/// parameters:		none
/// result:			none
///
/// notes:			can be used to hook into the start of drawing - by default does nothing
///
///********************************************************************************************************************

- (void)			beginDrawing
{
	// override to make something useful of this
}


///*********************************************************************************************************************
///
/// method:			endDrawing
/// scope:			public instance method
/// description:	called after the layer has finished drawing its content
/// 
/// parameters:		none
/// result:			none
///
/// notes:			can be used to hook into the end of drawing - by default does nothing
///
///********************************************************************************************************************

- (void)			endDrawing
{
	// override to make something useful of this
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
	if( ![self locked] && ![colour isEqual:[self selectionColour]])
	{
		LogEvent_( kReactiveEvent, @"<%@ 0x%x> setting selection colour: %@", NSStringFromClass([self class]), self, colour );
		
		[[[self undoManager] prepareWithInvocationTarget:self] setSelectionColour:[self selectionColour]];
		
		[colour retain];
		[m_selectionColour release];
		m_selectionColour = colour;
		[self setNeedsDisplay:YES];
		
		// also set the info window's background to the same colour if it exists
		
		if( m_infoWindow != nil )
			[m_infoWindow setBackgroundColor:colour];
		
		// tell anyone who's interested:
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerSelectionHighlightColourDidChange object:self];
		[[self undoManager] setActionName:NSLocalizedString(@"Selection Colour", nil)];
	}
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
/// notes:			
///
///********************************************************************************************************************

- (NSColor*)		selectionColour
{
	return m_selectionColour;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			thumbnailImageWithSize:
/// scope:			public instance method
/// description:	returns an image of the layer a the given size
/// 
/// parameters:		<size> the desired image size, or pass NSZeroSize for the default (1/8th drawing size)
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
		size.width = drsize.width / 8.0;
		size.height = drsize.height / 8.0;
	}
	
	//LogEvent_(kReactiveEvent,  @"creating layer thumbnail size: {%f, %f}", size.width, size.height );
	
	NSImage*	thumb = [[NSImage alloc] initWithSize:size];
	NSRect		tr, dr, dest;
	
	[thumb setFlipped:[[self drawing] isFlipped]];

	tr = NSMakeRect( 0, 0, size.width, size.height );
	dr = NSMakeRect( 0, 0, drsize.width, drsize.height );

	dest = ScaledRectForSize( drsize, tr );
	
	// build a transform to scale the drawing to the destination rect size
	
	CGFloat scale = dest.size.width / drsize.width;
	NSAffineTransform*	tfm = [NSAffineTransform transform];
	[tfm scaleBy:scale];
	
	[thumb lockFocus];
	[[NSColor clearColor] set];
	NSRectFill( tr );
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	
	[tfm concat];
	[self drawRect:dr inView:nil];
	
	[[NSColor blackColor] set];
	NSFrameRectWithWidth( dr, 2.0 );
	
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
/// notes:			the default size is currently 1/8th of the drawing size. See - thumbnailImageWithSize: for details
///
///********************************************************************************************************************

- (NSImage*)		thumbnail
{
	return [self thumbnailImageWithSize:NSZeroSize];
}


///*********************************************************************************************************************
///
/// method:			pdf
/// scope:			public instance method
/// description:	returns the content of the layer as a pdf
/// 
/// parameters:		none
/// result:			NSData containing the pdf representation of the layer and its contents
///
/// notes:			by default the pdf contains the entire layer's visible content exactly as drawn to a printer.
///
///********************************************************************************************************************

- (NSData*)			pdf
{
	NSRect frame = NSZeroRect;
	frame.size = [[self drawing] drawingSize];
	
	DKLayerPDFView*		pdfView = [[DKLayerPDFView alloc] initWithFrame:frame withLayer:self];
	DKViewController*	vc = [pdfView makeViewController];
	
	[[self drawing] addController:vc];
	
	NSData* pdfData = [pdfView dataWithPDFInsideRect:frame];
	[pdfView release];	// removes the controller
	
	return pdfData;
}


///*********************************************************************************************************************
///
/// method:			writePDFContentToPasteboard:
/// scope:			public instance method
/// description:	writes the content of the layer as a pdf to a nominated pasteboard
/// 
/// parameters:		<pb> the pasteboard
/// result:			YES if written OK, NO otherwise
///
/// notes:			becomes the new pasteboard owner and removes any existing declared types
///
///********************************************************************************************************************

- (BOOL)			writePDFDataToPasteboard:(NSPasteboard*) pb
{
	NSAssert( pb != nil, @"Cannot write to a nil pasteboard");
	
	[pb declareTypes:[NSArray arrayWithObject:NSPDFPboardType] owner:self];
	return [pb setData:[self pdf] forType:NSPDFPboardType];
}


///*********************************************************************************************************************
///
/// method:			bitmapRepresentationWithDPI:
/// scope:			public instance method
/// description:	returns the layer's content as a transparent bitmap having the given DPI.
/// 
/// parameters:		<dpi> image resolution in dots per inch
/// result:			the bitmap
///
/// notes:			a dpi of 0 uses the default, which is 72 dpi. The image pixel size is calculated from the drawing
///					size and the dpi. The layer is imaged onto a transparent background with alpha.
///
///********************************************************************************************************************

- (NSBitmapImageRep*) bitmapRepresentationWithDPI:(NSUInteger) dpi
{
	if( dpi == 0 )
		dpi = 72;
	
	NSSize		imageSize = [[self drawing] drawingSize];
	NSUInteger	pixelsAcross, pixelsDown;
	
	pixelsAcross = ceil( imageSize.width * dpi / 72.0);
	pixelsDown = ceil( imageSize.height * dpi / 72.0);
	
	NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
																	pixelsWide:pixelsAcross
																	pixelsHigh:pixelsDown
																 bitsPerSample:8
															   samplesPerPixel:4
																	  hasAlpha:YES
																	  isPlanar:NO
																colorSpaceName:NSCalibratedRGBColorSpace
																   bytesPerRow:0
																  bitsPerPixel:0];
	
	NSAssert( rep != nil, @"bitmap rep could not be created");
	
	NSData* pdf = [self pdf];
	
	NSAssert( pdf != nil, @"unable to get pdf data");
	
	// create a second rep from the pdf data
	
	NSPDFImageRep* pdfRep = [NSPDFImageRep imageRepWithData:pdf];
	
	NSAssert( pdfRep != nil, @"unable to create pdf representation");

	// set up a graphics context
	
	NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
	[context setImageInterpolation:NSImageInterpolationHigh];
	[context setShouldAntialias:YES];
	
	SAVE_GRAPHICS_CONTEXT
	
	[NSGraphicsContext setCurrentContext:context];
	
	// focus on the image and draw the content
	
	NSRect layerRect = NSMakeRect( 0, 0, pixelsAcross, pixelsDown );
	
	[pdfRep drawInRect:layerRect];
	
	RESTORE_GRAPHICS_CONTEXT
	
	return [rep autorelease];
}


///*********************************************************************************************************************
///
/// method:			setClipsDrawingToInterior:
/// scope:			public method
/// overrides:
/// description:	sets whether drawing is limited to the interior area or not
/// 
/// parameters:		<clip> YES to limit drawing to the interior, NO to allow drawing to be visible in the margins.
/// result:			none
///
/// notes:			default is NO, so drawings show in the margins.
///
///********************************************************************************************************************

- (void)			setClipsDrawingToInterior:(BOOL) clip
{
	if( clip != [self clipsDrawingToInterior])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setClipsDrawingToInterior:m_clipToInterior]; 
		m_clipToInterior = clip;
		[self setNeedsDisplay:YES];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerLockStateDidChange object:self];

		if(!([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
			[[self undoManager] setActionName:NSLocalizedString(@"Clip To Margin", @"undo for layer clipping")];
	}
}


///*********************************************************************************************************************
///
/// method:			clipsDrawingToInterior
/// scope:			public method
/// overrides:
/// description:	whether the drawing will be clipped to the interior or not
/// 
/// parameters:		none
/// result:			YES if clipping, NO if not.
///
/// notes:			default is NO.
///
///********************************************************************************************************************

- (BOOL)			clipsDrawingToInterior
{
	return m_clipToInterior;
}


///*********************************************************************************************************************
///
/// method:			setAlpha:
/// scope:			public method
/// overrides:
/// description:	sets the alpha level for the layer
/// 
/// parameters:		<alpha> the alpha level, 0..1
/// result:			none
///
/// notes:			default is 1.0 (fully opaque objects). Note that alpha must be implemented by a layer's
///					-drawRect:inView: method to have an actual effect, and unless compositing to a CGLayer or other
///					graphics surface, may not have the expected effect (just setting the context's alpha before
///					drawing renders each individual object with the given alpha, for example).
///
///********************************************************************************************************************

- (void)			setAlpha:(CGFloat) alpha
{
	if( ![self locked] && alpha != mAlpha )
	{
		[(DKLayer*)[[self undoManager] prepareWithInvocationTarget:self] setAlpha:mAlpha];
		
		mAlpha = LIMIT( alpha, 0.0, 1.0 );
		[self setNeedsDisplay:YES];
	}
}


///*********************************************************************************************************************
///
/// method:			alpha
/// scope:			public method
/// overrides:
/// description:	returns the alpha level for the layer as a whole
/// 
/// parameters:		none
/// result:			the current alpha level
///
/// notes:			default is 1.0 (fully opaque objects)
///
///********************************************************************************************************************

- (CGFloat)			alpha
{
	return mAlpha;
}


- (void)			updateRulerMarkersForRect:(NSRect) rect
{
	if([self rulerMarkerUpdatesEnabled])
		[[self layerGroup] updateRulerMarkersForRect:rect];
}


- (void)			hideRulerMarkers
{
	if([self rulerMarkerUpdatesEnabled])
		[[self layerGroup] hideRulerMarkers];
}


- (void)			setRulerMarkerUpdatesEnabled:(BOOL) enable
{
	mRulerMarkersEnabled = enable;
}


- (BOOL)			rulerMarkerUpdatesEnabled
{
	return mRulerMarkersEnabled;
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
 		[[self drawing] invalidateCursors];
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


///*********************************************************************************************************************
///
/// method:			uniqueKey
/// scope:			public instance method
/// overrides:
/// description:	returns the layer's unique key
/// 
/// parameters:		none
/// result:			the unique key
///
/// notes:			
///
///********************************************************************************************************************

- (NSString*)		uniqueKey
{
	return mLayerUniqueKey;
}

#pragma mark -
///*********************************************************************************************************************
///
/// method:			setLayerName:
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

- (void)			setLayerName:(NSString*) name
{
	if(![name isEqualToString:[self layerName]])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setLayerName:[self layerName]];
		
		NSString* nameCopy = [name copy];
		
		[m_name release];
		m_name = nameCopy;
		
		LogEvent_( kStateEvent, @"layer's name was set to '%@'", m_name );
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKLayerNameDidChange object:self];
		
		if(! ([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
			[[self undoManager] setActionName:NSLocalizedString(@"Change Layer Name", @"undo action for change layer name")];
	}
}


///*********************************************************************************************************************
///
/// method:			layerName
/// scope:			public instance method
/// description:	returns the layer's name
/// 
/// parameters:		none
/// result:			the name
///
/// notes:			
///
///********************************************************************************************************************

- (NSString*)		layerName
{
	return m_name;
}



#pragma mark -
#pragma mark - user info

///*********************************************************************************************************************
///
/// method:			setUserInfo:
/// scope:			public instance method
/// overrides:
/// description:	attach a dictionary of user data to the object
/// 
/// parameters:		<info> a dictionary containing anything you wish
/// result:			none
///
/// notes:			The dictionary replaces the current user info. To merge with any existing user info, use addUserInfo:
///					For the more specific metadata attachemnts, refer to DKLayer+Metadata. Metadata is stored within the
///					user info dictionary as a subdictionary.
///
///********************************************************************************************************************

- (void)			setUserInfo:(NSMutableDictionary*) info
{
	[info retain];
	[mUserInfo release];
	mUserInfo = info;
}


///*********************************************************************************************************************
///
/// method:			addUserInfo:
/// scope:			public instance method
/// overrides:
/// description:	add a dictionary of metadata to the object
/// 
/// parameters:		<info> a dictionary containing anything you wish
/// result:			none
///
/// notes:			<info> is merged with the existin gcontent of the user info
///
///********************************************************************************************************************

- (void)			addUserInfo:(NSDictionary*) info
{
	if( mUserInfo == nil )
		mUserInfo = [[NSMutableDictionary alloc] init];
	
	NSDictionary* deepCopy = [info deepCopy];
	
	[mUserInfo addEntriesFromDictionary:deepCopy];
	[deepCopy release];
}


///*********************************************************************************************************************
///
/// method:			userInfo
/// scope:			public instance method
/// overrides:
/// description:	return the attached user info
/// 
/// parameters:		none
/// result:			the user info
///
/// notes:			The user info is returned as a mutable dictionary (which it is), and can thus have its contents
///					mutated directly for certain uses. Doing this cannot cause any notification of the status of
///					the object however.
///
///********************************************************************************************************************

- (NSMutableDictionary*)userInfo
{
	return mUserInfo;
}


///*********************************************************************************************************************
///
/// method:			userInfoObjectForKey:
/// scope:			public instance method
/// overrides:
/// description:	return an item of user info
/// 
/// parameters:		<key> the key to use to refer to the item
/// result:			the user info item
///
/// notes:			
///
///********************************************************************************************************************

- (id)					userInfoObjectForKey:(NSString*) key
{
	return [[self userInfo] objectForKey:key];
}


///*********************************************************************************************************************
///
/// method:			setUserInfoObject:forKey:
/// scope:			public instance method
/// overrides:
/// description:	set an item of user info
/// 
/// parameters:		<obj> the object to store
///					<key> the key to use to refer to the item
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			setUserInfoObject:(id) obj forKey:(NSString*) key
{
	NSAssert( obj != nil, @"cannot add nil to the user info");
	NSAssert( key != nil, @"user info key can't be nil");
	
	if( mUserInfo == nil )
		mUserInfo = [[NSMutableDictionary alloc] init];
	
	[[self userInfo] setObject:obj forKey:key];
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


///*********************************************************************************************************************
///
/// method:			layerMayBeDeleted
/// scope:			public instance method
/// description:	return whether the layer can be deleted
/// 
/// parameters:		none
/// result:			YES if layer can be deleted, override to return NO to prevent this
///
/// notes:			This setting is intended to be checked by UI-level code to prevent deletion of layers within the UI.
///					It does not prevent code from directly removing the layer.
///
///********************************************************************************************************************

- (BOOL)			layerMayBeDeleted
{
	return ![self locked];
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
/// result:			YES if the layer is unlocked, NO otherwise
///
/// notes:			override to return NO if your layer type should not auto activate. Note that auto-activation also
///					needs to be set for the view. The event is passed so that a sensible decision can be reached.
///
///********************************************************************************************************************

- (BOOL)			shouldAutoActivateWithEvent:(NSEvent*) event
{
	#pragma unused(event)
	
	return ![self locked];
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


///*********************************************************************************************************************
///
/// method:			hitTest:
/// scope:			public instance method
/// description:	detect what object was hit by a point.
/// 
/// parameters:		<p> the point to test
/// result:			the object hit, or nil
///
/// notes:			layers that support objects implement this meaningfully. A non-object layer returns nil which
///					simplifies the design of certain tools that look for targets to operate on, without the need
///					to ascertain the layer class first.
///
///********************************************************************************************************************

- (DKDrawableObject*)	hitTest:(NSPoint) p
{
#pragma unused(p)
	
	return nil;
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
/// notes:			override to respond to the event. Note that where tool controllers and tools are used, these
///					methods may never be called, as the tool will operate on target objects within the layer directly.
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
///					See also: -setSelectionColour, -selectionColour.
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
/// notes:			if custom knobs have been set for the layer, they are returned. Otherwise, the knobs for the group
///					or ultimately the drawing will be returned.
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


///*********************************************************************************************************************
///
/// method:			logDescription:
/// scope:			public action method
/// description:	
/// 
/// parameters:		<sender> the sender of the action
/// result:			none
///
/// notes:			debugging method
///
///********************************************************************************************************************

- (IBAction)		logDescription:(id) sender
{
#pragma unused(sender)
	NSLog(@"%@", self );
}

///*********************************************************************************************************************
///
/// method:			copy:
/// scope:			public action method
/// overrides:
/// description:	places the layer on the clipboard as a PDF
/// 
/// parameters:		<sender> the sender of the action
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)				copy:(id) sender
{
#pragma unused(sender)
	
	// export the layer's content as a PDF
	
	[self writePDFDataToPasteboard:[NSPasteboard generalPasteboard]];
}


#pragma mark -
#pragma mark As an NSObject
- (void)			dealloc
{
	LogEvent_( kLifeEvent, @"deallocating DKLayer %p", self);
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[self undoManager] removeAllActionsWithTarget:self];
	
	[m_infoWindow release];
	[m_knobs release];
	[m_selectionColour release];
	[m_name release];
	[mUserInfo release];
	[mLayerUniqueKey release];
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
		[self setVisible:YES];
		[self setLocked:NO];
		[self setKnobsShouldAdustToViewScale:YES];
		[self setShouldDrawToPrinter:YES];
		[self setSelectionColour:[[self class] selectionColourForIndex:sLayerIndexSeed++]];
		mLayerUniqueKey = [[DKUniqueID uniqueKey] retain];
		mRulerMarkersEnabled = YES;
		mAlpha = 1.0;
	}
	return self;
}


- (NSString*)		description
{
	return [NSString stringWithFormat:@"%@; name = '%@',\nuser info = %@,\ngroup = %@", [super description], [self layerName], [self userInfo], [self layerGroup]];
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)			encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[coder encodeConditionalObject:[self layerGroup] forKey:@"group"];
	[coder encodeObject:[self layerName] forKey:@"name"];
	[coder encodeObject:[self selectionColour] forKey:@"selcolour"];
	[coder encodeObject:[self knobs] forKey:@"DKLayer_knobs"];
	
	[coder encodeBool:[self visible] forKey:@"visible"];
	[coder encodeBool:[self locked] forKey:@"locked"];
	[coder encodeBool:YES forKey:@"hasPrintFlag"];
	[coder encodeBool:m_printed forKey:@"printed"];
	[coder encodeBool:m_clipToInterior forKey:@"DKLayer_clipToInterior"];
	[coder encodeObject:[self userInfo] forKey:@"DKLayer_userInfo"];
	[coder encodeFloat:[self alpha] forKey:@"DKLayer_alpha"];
	
	[coder encodeBool:![self rulerMarkerUpdatesEnabled] forKey:@"DKLayer_disableRulerMarkerUpdates"];
}


- (id)				initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	LogEvent_(kFileEvent, @"decoding layer %@", self);

	self = [self init];
	if ( self )
	{
		[self setLayerGroup:[coder decodeObjectForKey:@"group"]];
		[self setLayerName:[coder decodeObjectForKey:@"name"]];
		
		NSColor* selColour = [coder decodeObjectForKey:@"selcolour"];
		
		if( selColour )
			[self setSelectionColour:selColour];
		
		[self setKnobs:[coder decodeObjectForKey:@"DKLayer_knobs"]];
		[self setKnobsShouldAdustToViewScale:YES];

		[self setVisible:[coder decodeBoolForKey:@"visible"]];
		// Check older files for presence of flag - if not there, assume YES
		BOOL hasPrintFlag = [coder decodeBoolForKey:@"hasPrintFlag"];
		if ( hasPrintFlag )
			[self setShouldDrawToPrinter:[coder decodeBoolForKey:@"printed"]];
		else
			[self setShouldDrawToPrinter:YES];
			
		[self setClipsDrawingToInterior:[coder decodeBoolForKey:@"DKLayer_clipToInterior"]];
		[self setUserInfo:[coder decodeObjectForKey:@"DKLayer_userInfo"]];
		
		mLayerUniqueKey = [[DKUniqueID uniqueKey] retain];
		
		// alpha was added in 1.0.7 - if not present, default to 1.0
		
		if([coder containsValueForKey:@"DKLayer_alpha"])
			mAlpha = [coder decodeFloatForKey:@"DKLayer_alpha"];
		else	
			mAlpha = 1.0;
		
		[self setRulerMarkerUpdatesEnabled:![coder decodeBoolForKey:@"DKLayer_disableRulerMarkerUpdates"]];
	}
	return self;
}


- (id)				awakeAfterUsingCoder:(NSCoder*) coder
{
	[self setLocked:[coder decodeBoolForKey:@"locked"]];
	[self updateMetadataKeys];	
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
	SEL		action = [item action];
	
	if ( action == @selector( lockLayer: ))
		return ![self locked];
	
	if ( action == @selector( unlockLayer: ))
		return [self locked];
	
	if ( action == @selector( showLayer: ))
		return ![self visible];
	
	if ( action == @selector( hideLayer: ))
		return [self visible];
	
	if( action == @selector(toggleLayerLock:) ||
	   action == @selector(toggleLayerVisible:))
		return YES;
	
	if( action == @selector(logDescription:))
		return YES;
		
	return NO;
}


- (BOOL)			validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >) anItem
{
	if([(id)anItem isKindOfClass:[NSMenuItem class]])
		return [self validateMenuItem:(NSMenuItem*)anItem];
	
	// Temporary hack: find out what the old menu validation would return for the same action and
	// use that result.
	
	NSMenuItem* temp = [[NSMenuItem alloc] initWithTitle:@"NEVER_SEEN" action:[anItem action] keyEquivalent:@""];
	BOOL oldResult = [self validateMenuItem:temp];
	[temp release];
	
	return oldResult;
}



#pragma mark -
#pragma mark As part of the DKKnobOwner protocol

- (CGFloat)			knobsWantDrawingScale
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
