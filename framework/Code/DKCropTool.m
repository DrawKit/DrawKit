/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKCropTool.h"
#import "DKObjectDrawingLayer.h"
#import "DKObjectDrawingLayer+BooleanOps.h"
#import "DKGeometryUtilities.h"

@implementation DKCropTool

#pragma mark - As a DKDrawingTool

/** @brief Handle the initial mouse down
 @param p the local point where the mouse went down
 @param obj the target object, if there is one
 @param layer the layer in which the tool is being applied
 @param event the original event
 @param aDel an optional delegate
 @return the partcode of the target that was hit, or 0 (no object)
 */
- (NSInteger)mouseDownAtPoint:(NSPoint)p targetObject:(DKDrawableObject*)obj layer:(DKLayer*)layer event:(NSEvent*)event delegate:(id)aDel
{
#pragma unused(obj)
#pragma unused(layer)
#pragma unused(aDel)
#pragma unused(event)

    mAnchor = p;
    mZoomRect = NSZeroRect;
    return 0;
}

/** @brief Handle the mouse dragged event
 @param p the local point where the mouse has been dragged to
 @param partCode the partcode returned by the mouseDown method
 @param layer the layer in which the tool is being applied
 @param event the original event
 @param aDel an optional delegate
 */
- (void)mouseDraggedToPoint:(NSPoint)p partCode:(NSInteger)pc layer:(DKLayer*)layer event:(NSEvent*)event delegate:(id)aDel
{
#pragma unused(pc)
#pragma unused(event)
#pragma unused(aDel)

    [layer setNeedsDisplayInRect:mZoomRect];
    mZoomRect = NSRectFromTwoPoints(mAnchor, p);
    [layer setNeedsDisplayInRect:mZoomRect];
}

/** @brief Handle the mouse up event
 @param p the local point where the mouse went up
 @param partCode the partcode returned by the mouseDown method
 @param layer the layer in which the tool is being applied
 @param event the original event
 @param aDel an optional delegate
 @return YES if the tool did something undoable, NO otherwise
 */
- (BOOL)mouseUpAtPoint:(NSPoint)p partCode:(NSInteger)pc layer:(DKLayer*)layer event:(NSEvent*)event delegate:(id)aDel
{
#pragma unused(pc)
#pragma unused(event)
#pragma unused(aDel)

    mZoomRect = NSRectFromTwoPoints(mAnchor, p);
    [layer setNeedsDisplayInRect:mZoomRect];

    DKObjectDrawingLayer* odl = (DKObjectDrawingLayer*)layer;

    [odl cropToRect:mZoomRect];

    mZoomRect = NSZeroRect;
    return NO;
}

/** @brief Draw the tool's graphic
 @param aRect the rect being redrawn (not used)
 @param aView the view that is doing the drawing
 */
- (void)drawRect:(NSRect)aRect inView:(NSView*)aView
{
#pragma unused(aRect)

    if ([aView needsToDrawRect:mZoomRect]) {
        CGFloat sc = 1.0;

        NSBezierPath* zoomPath = [NSBezierPath bezierPathWithRect:NSInsetRect(mZoomRect, sc, sc)];
        [zoomPath setLineWidth:sc];
        [[NSColor redColor] set];
        [zoomPath stroke];
    }
}

/** @brief Return whether the target layer can be used by this tool
 @param aLayer a layer object
 @return YES if the tool can be used with the given layer, NO otherwise
 */
- (BOOL)isValidTargetLayer:(DKLayer*)aLayer
{
    return [aLayer isKindOfClass:[DKObjectDrawingLayer class]];
}

@end
