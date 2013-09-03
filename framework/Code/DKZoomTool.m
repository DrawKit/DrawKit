///**********************************************************************************************************************************
///  DKZoomTool.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 25/03/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************


#import "DKZoomTool.h"
#import "DKLayer.h"
#import "DKDrawingView.h"
#import "DKGeometryUtilities.h"

@implementation DKZoomTool



- (void)	setZoomsOut:(BOOL) zoomOut
{
	mMode = zoomOut;
	
	if( zoomOut )
		mModeModifierMask = 0;
}


- (BOOL)	zoomsOut
{
	return mMode;
}


- (void)		setModeModifierMask:(NSUInteger) msk
{
	mModeModifierMask = msk;
}


- (NSUInteger)	modeModifierMask
{
	return mModeModifierMask;
}

#pragma mark - As a DKDrawingTool

///*********************************************************************************************************************
///
/// method:			mouseDownAtPoint:targetObject:layer:event:delegate:
/// scope:			public instance method
///	overrides:		
/// description:	handle the initial mouse down
/// 
/// parameters:		<p> the local point where the mouse went down
///					<obj> the target object, if there is one
///					<layer> the layer in which the tool is being applied
///					<event> the original event
///					<aDel> an optional delegate
/// result:			the partcode of the target that was hit, or 0 (no object)
///
/// notes:			
///
///********************************************************************************************************************

- (NSInteger)				mouseDownAtPoint:(NSPoint) p targetObject:(DKDrawableObject*) obj layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(obj)
	#pragma unused(layer)
	#pragma unused(aDel)
	
	if([self modeModifierMask] != 0)
		mMode = (([event modifierFlags] & [self modeModifierMask]) != 0 );
	
	mAnchor = p;
	mZoomRect = NSZeroRect;
	return 0;
}


///*********************************************************************************************************************
///
/// method:			mouseDraggedToPoint:partCode:layer:event:delegate:
/// scope:			public instance method
///	overrides:		
/// description:	handle the mouse dragged event
/// 
/// parameters:		<p> the local point where the mouse has been dragged to
///					<partCode> the partcode returned by the mouseDown method
///					<layer> the layer in which the tool is being applied
///					<event> the original event
///					<aDel> an optional delegate
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			mouseDraggedToPoint:(NSPoint) p partCode:(NSInteger) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(pc)
	#pragma unused(event)
	#pragma unused(aDel)
	
	if ( !mMode )
	{
		[layer setNeedsDisplayInRect:mZoomRect];
		mZoomRect = NSRectFromTwoPoints( mAnchor, p );
		[layer setNeedsDisplayInRect:mZoomRect];
	}
}


///*********************************************************************************************************************
///
/// method:			mouseUpAtPoint:partCode:layer:event:delegate:
/// scope:			public instance method
///	overrides:		
/// description:	handle the mouse up event
/// 
/// parameters:		<p> the local point where the mouse went up
///					<partCode> the partcode returned by the mouseDown method
///					<layer> the layer in which the tool is being applied
///					<event> the original event
///					<aDel> an optional delegate
/// result:			YES if the tool did something undoable, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			mouseUpAtPoint:(NSPoint) p partCode:(NSInteger) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(pc)
	#pragma unused(event)
	#pragma unused(aDel)
	
	DKDrawingView* zv = (DKDrawingView*)[layer currentView];

	if ( !mMode )
	{
		NSRect temp = mZoomRect;
		mZoomRect = NSZeroRect;
		
		[layer setNeedsDisplayInRect:temp];
		temp = NSRectFromTwoPoints( mAnchor, p );
		[layer setNeedsDisplayInRect:temp];
		
		// if dragged area < 4 pixels, treat as click
		
		if ( NSIsEmptyRect( NSInsetRect( temp, 2.0, 2.0 )))
			[zv zoomViewByFactor:2.0 andCentrePoint:p];
		else
			[zv zoomViewToRect:temp];
	}
	else
		[zv zoomViewByFactor:0.5 andCentrePoint:p];
	
	mZoomRect = NSZeroRect;
	return NO;
}


///*********************************************************************************************************************
///
/// method:			drawRect:InView:
/// scope:			public instance method
///	overrides:		
/// description:	draw the tool's graphic
/// 
/// parameters:		<aRect> the rect being redrawn (not used)
///					<aView> the view that is doing the drawing
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			drawRect:(NSRect) aRect inView:(NSView*) aView
{
	#pragma unused(aRect)
	
	if (!NSIsEmptyRect(mZoomRect) && [aView needsToDrawRect:mZoomRect])
	{
		CGFloat sc = 1.0 / [(DKDrawingView*)aView scale];
		CGFloat dash[] = { 4.0 * sc, 3.0 * sc };
		
		NSBezierPath* zoomPath = [NSBezierPath bezierPathWithRect:NSInsetRect( mZoomRect, sc, sc )];
		[zoomPath setLineWidth:sc];
		[zoomPath setLineDash:dash count:2 phase:0.0];
		[[NSColor grayColor] set];
		[zoomPath stroke];
	}
}


///*********************************************************************************************************************
///
/// method:			flagsChanged:inLayer:
/// scope:			public instance method
///	overrides:		
/// description:	the state of the modifier keys changed
/// 
/// parameters:		<event> the event
///					<layer> the current layer that the tool is being applied to
/// result:			none
///
/// notes:			

///
///********************************************************************************************************************

- (void)			flagsChanged:(NSEvent*) event inLayer:(DKLayer*) layer
{
	if([self modeModifierMask] != 0)
	{
		mMode = (([event modifierFlags] & [self modeModifierMask]) != 0 );
		[[self cursor] set];
		
		if ( mMode )
		{
			[layer setNeedsDisplayInRect:mZoomRect];
			mZoomRect = NSZeroRect;
		}
	}
}


///*********************************************************************************************************************
///
/// method:			isValidTargetLayer:
/// scope:			public instance method
///	overrides:		
/// description:	return whether the target layer can be used by this tool
/// 
/// parameters:		<aLayer> a layer object
/// result:			YES if the tool can be used with the given layer, NO otherwise
///
/// notes:			Zoom tools can always work, even in hidden layers - so always returns YES
///
///********************************************************************************************************************

- (BOOL)			isValidTargetLayer:(DKLayer*) aLayer
{
	#pragma unused(aLayer)
	
	return YES;
}



///*********************************************************************************************************************
///
/// method:			cursor
/// scope:			public instance method
///	overrides:		
/// description:	return the tool's cursor
/// 
/// parameters:		none
/// result:			the arrow cursor
///
/// notes:			
///
///********************************************************************************************************************

- (NSCursor*)		cursor
{
	NSImage* img;
	
	if ( mMode )
		img = [NSImage imageNamed:@"mag_minus"];
	else
		img = [NSImage imageNamed:@"mag_plus"];
	
	NSCursor* curs = [[NSCursor alloc] initWithImage:img hotSpot:NSMakePoint( 12, 12 )];	
	return [curs autorelease];
}


#pragma mark -
#pragma mark - as a NSObject

- (id)				init
{
	self = [super init];
	if( self )
	{
		mModeModifierMask = NSAlternateKeyMask;
	}
	
	return self;
}

@end
