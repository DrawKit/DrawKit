//
//  DKCropTool.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 24/06/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKCropTool.h"
#import "DKObjectDrawingLayer.h"
#import "DKObjectDrawingLayer+BooleanOps.h"
#import "DKGeometryUtilities.h"


@implementation DKCropTool

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
	#pragma unused(event)
	
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
	
	[layer setNeedsDisplayInRect:mZoomRect];
	mZoomRect = NSRectFromTwoPoints( mAnchor, p );
	[layer setNeedsDisplayInRect:mZoomRect];
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
	
	
	mZoomRect = NSRectFromTwoPoints( mAnchor, p );
	[layer setNeedsDisplayInRect:mZoomRect];
	
	DKObjectDrawingLayer* odl = (DKObjectDrawingLayer*)layer;
	
	[odl cropToRect:mZoomRect];
	
	
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
	
	if ([aView needsToDrawRect:mZoomRect])
	{
		CGFloat sc = 1.0;
		
		NSBezierPath* zoomPath = [NSBezierPath bezierPathWithRect:NSInsetRect( mZoomRect, sc, sc )];
		[zoomPath setLineWidth:sc];
		[[NSColor redColor] set];
		[zoomPath stroke];
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
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			isValidTargetLayer:(DKLayer*) aLayer
{
	return [aLayer isKindOfClass:[DKObjectDrawingLayer class]];
}


@end
