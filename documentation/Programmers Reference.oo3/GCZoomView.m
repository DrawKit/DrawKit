///**********************************************************************************************************************************
///  GCZoomView.h
///  DrawKit
///
///  Created by graham on 1/08/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "GCZoomView.h"

#import "LogEvent.h"


#pragma mark Contants (Non-localized)
NSString* kGCDrawingViewDidChangeScale = @"kGCDrawingViewDidChangeScale";
NSString* kGCDrawingViewWillChangeScale = @"kGCDrawingViewWillChangeScale";


#pragma mark -
@implementation GCZoomView
#pragma mark As a GCZoomView

///*********************************************************************************************************************
///
/// method:			zoomIn:
/// scope:			public action method
/// description:	zoom in (scale up) by a factor of 2
/// 
/// parameters:		<sender> - the sender of the action
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			zoomIn: (id) sender
{
	#pragma unused(sender)
	
	[self zoomViewByFactor:2.0];
}


///*********************************************************************************************************************
///
/// method:			zoomOut:
/// scope:			public action method
/// description:	zoom out (scale down) by a factor of 2
/// 
/// parameters:		<sender> - the sender of the action
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			zoomOut: (id) sender
{
	#pragma unused(sender)
	
	[self zoomViewByFactor:0.5];
}


///*********************************************************************************************************************
///
/// method:			zoomToActualSize:
/// scope:			public action method
/// description:	restore the zoom to 100%
/// 
/// parameters:		<sender> - the sender of the action
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			zoomToActualSize: (id) sender
{
	#pragma unused(sender)
	
	[self zoomViewToAbsoluteScale:1.0];
}


///*********************************************************************************************************************
///
/// method:			zoomFitInWindow:
/// scope:			public action method
/// description:	zoom so that the entire extent of the enclosing frame is visible
/// 
/// parameters:		<sender> - the sender of the action
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			zoomFitInWindow: (id) sender
{
	#pragma unused(sender)
	
	// zooms the view to fit within the current window (command/action)
	NSRect  sfr = [[self superview] frame];
	[self zoomViewToFitRect:sfr];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			zoomViewByFactor:
/// scope:			public method
/// description:	zoom by the desired scaling factor
/// 
/// parameters:		<factor> - how much to change the current scale by
/// result:			none
///
/// notes:			a factor of 2.0 will double the zoom scale, from 100% to 200% say, a factor of 0.5 will zoom out.
///					This also maintains the current visible centre point of the view so the zoom remains stable.
///
///********************************************************************************************************************

- (void)				zoomViewByFactor: (float) factor
{
	NSPoint p = [self centredPointInDocView];
	[self zoomViewByFactor:factor andCentrePoint:p];
}


///*********************************************************************************************************************
///
/// method:			zoomViewToAbsoluteScale:
/// scope:			public method
/// description:	zoom to a given absolute value
/// 
/// parameters:		<newScale> - the desired scaling factor
/// result:			none
///
/// notes:			a scale of 1.0 sets 100% zoom
///
///********************************************************************************************************************

- (void)				zoomViewToAbsoluteScale: (float) newScale
{
	float factor = newScale / [self scale];
	[self zoomViewByFactor:factor];
}


///*********************************************************************************************************************
///
/// method:			zoomViewToFitRect:
/// scope:			public method
/// description:	zooms so that the passed rect will fit in the view
/// 
/// parameters:		<aRect> - a rect
/// result:			none
///
/// notes:			In general this should be used for a zoom OUT, such as a "fit to window" command, though it will
///					zoom in if the view is smaller than the current frame.
///
///********************************************************************************************************************

- (void)				zoomViewToFitRect: (NSRect) aRect
{
	NSRect  fr = [self frame];
	
	float sx, sy;
	
	sx = aRect.size.width / fr.size.width;
	sy = aRect.size.height / fr.size.height;
	
	[self zoomViewByFactor:MIN( sx, sy )];
}


///*********************************************************************************************************************
///
/// method:			zoomViewToRect:
/// scope:			public method
/// description:	zooms so that the passed rect fills the view
/// 
/// parameters:		<aRect> - a rect
/// result:			none
///
/// notes:			The centre of the rect is centred in the view. In general this should be used for a zoom IN to a
///					specific smaller rectange. <aRect> is in current view coordinates. This is good for a dragged rect
///					zoom tool.
///
///********************************************************************************************************************

- (void)				zoomViewToRect: (NSRect) aRect;
{
	NSRect  fr = [(NSClipView*)[self superview] documentVisibleRect];
	NSPoint cp;
	
	float sx, sy;
	
	sx = fr.size.width / aRect.size.width;
	sy = fr.size.height / aRect.size.height;
	
	cp.x = aRect.origin.x + aRect.size.width / 2.0;
	cp.y = aRect.origin.y + aRect.size.height / 2.0;
	
	[self zoomViewByFactor:MIN( sx, sy ) andCentrePoint:cp];
}


///*********************************************************************************************************************
///
/// method:			zoomViewToRect:
/// scope:			protected method
/// description:	zooms the view by the given factor and centres the passed point.
/// 
/// parameters:		<factor> - relative zoom factor
///					<p> a point within the view that should be scrolled to the centre of the zoomed view.
/// result:			none
///
/// notes:			all zooms bottleneck through here
///
///********************************************************************************************************************

- (void)				zoomViewByFactor: (float) factor andCentrePoint:(NSPoint) p
{
	if ( factor != 1.0 )
	{
		NSSize  newSize;
		NSRect  fr;
		float   sc;
		
		sc = factor * [self scale];
		
		if ( sc < [self minimumScale])
		{
			sc = [self minimumScale];
			factor = sc / [self scale];
		}
		
		if ( sc > [self maximumScale])
		{
			sc = [self maximumScale];
			factor = sc / [self scale];
		}
		
		if ( sc != [self scale])
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:kGCDrawingViewWillChangeScale object:self];
			m_scale = sc;
			fr = [self frame];
			
			newSize.width = newSize.height = factor;
			
			[self scaleUnitSquareToSize:newSize];
			
			fr.size.width *= factor;
			fr.size.height *= factor;
			[self setFrameSize:fr.size];

			[self scrollPointToCentre:p];
			[self setNeedsDisplay:YES];
			
		//	LogEvent_(kStateEvent, @"new scale = %f", m_scale );
			
			[[NSNotificationCenter defaultCenter] postNotificationName:kGCDrawingViewDidChangeScale object:self];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			zoomWithScrollWheelDelta:
/// scope:			protected method
/// description:	converts the scrollwheel delta value into a zoom factor and performs the zoom.
/// 
/// parameters:		<delta> - scrollwheel delta value
///					<cp> a point within the view that should be scrolled to the centre of the zoomed view.
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				zoomWithScrollWheelDelta:(float) delta toCentrePoint:(NSPoint) cp
{
	float factor = ( delta > 0 )? 0.9 : 1.1;
	
	[self zoomViewByFactor:factor andCentrePoint:cp ];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			centredPointInDocView
/// scope:			protected method
/// description:	calculates the coordinates of the point that is visually centred in the view at the current scroll
///					position and zoom.
/// 
/// parameters:		none
/// result:			the visually centred point
///
/// notes:			
///
///********************************************************************************************************************

- (NSPoint)				centredPointInDocView
{
	NSRect  fr = [(NSClipView*)[self superview] documentVisibleRect];
	NSPoint cp;
	
	cp.x = fr.origin.x + fr.size.width / 2.0;
	cp.y = fr.origin.y + fr.size.height / 2.0;
	
	return cp;
}


///*********************************************************************************************************************
///
/// method:			scrollPointToCentre:
/// scope:			protected method
/// description:	scrolls the view so that the point ends up visually centred
/// 
/// parameters:		<aPoint> the desired centre point
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				scrollPointToCentre:(NSPoint) aPoint
{
	// given a point in view coordinates, the view is scrolled so that the point is centred in the
	// current document view
	
	NSRect  fr = [(NSClipView*)[self superview] documentVisibleRect];
	NSPoint sp;
	
	sp.x = aPoint.x - ( fr.size.width / 2.0 );
	sp.y = aPoint.y - ( fr.size.height / 2.0 );
	
	[self scrollPoint:sp];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			scale
/// scope:			public method
/// description:	returns the current view scale (zoom)
/// 
/// parameters:		none
/// result:			the current scale
///
/// notes:			
///
///********************************************************************************************************************

- (float)				scale
{
	return m_scale;
}


///*********************************************************************************************************************
///
/// method:			minimumScale
/// scope:			public method
/// description:	returns the minimum permitted view scale (zoom)
/// 
/// parameters:		none
/// result:			the minimum scale
///
/// notes:			override this to return some other minimum
///
///********************************************************************************************************************

- (float)				minimumScale
{
	return 0.25;
}


///*********************************************************************************************************************
///
/// method:			maximumScale
/// scope:			public method
/// description:	returns the maximum permitted view scale (zoom)
/// 
/// parameters:		none
/// result:			the maximum scale
///
/// notes:			override this to return some other maximum
///
///********************************************************************************************************************

- (float)				maximumScale
{
	return 25.0;
}


#pragma mark -
#pragma mark As an NSResponder
///*********************************************************************************************************************
///
/// method:			scrollWheel:
/// scope:			overidden method
/// description:	allows the scrollwheel to change the zoom.
/// 
/// parameters:		<theEvent> - scrollwheel event
/// result:			none
///
/// notes:			overrides NSResponder. The scrollwheel works normally unless the option key is down, in which case
///					it performs a zoom.
///
///********************************************************************************************************************

- (void)				scrollWheel:(NSEvent *)theEvent
{
	if (([theEvent modifierFlags] & NSAlternateKeyMask) != 0 )
	{   
		// note to self - using the current mouse position here makes zooming really difficult, contrary
		// to what you might think. It's more intuitive if the centre point remains constant
		
		NSPoint p = [self centredPointInDocView];
		[self zoomWithScrollWheelDelta:[theEvent deltaY] toCentrePoint:p];
	}
	else
		[super scrollWheel: theEvent];
}


#pragma mark -
#pragma mark As an NSView
- (id)					initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self != nil)
    {
		m_scale = 1.0;
	}
    return self;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol
- (BOOL)				validateMenuItem:(NSMenuItem*) item
{
	BOOL	enable = NO;
	SEL		action = [item action];
	
	if( action == @selector( zoomIn: ))
		enable = [self scale] < [self maximumScale];
	else if ( action == @selector( zoomOut: ))
		enable = [self scale] > [self minimumScale];
	else if ( action == @selector( zoomToActualSize: ))
		enable = [self scale] != 1.0;
	else if ( action == @selector( zoomFitInWindow: ))
		enable = YES;
		
	return enable;
}


@end
