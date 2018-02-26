/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKZoomTool.h"
#import "DKDrawingView.h"
#import "DKGeometryUtilities.h"
#import "DKLayer.h"

@implementation DKZoomTool

- (void)setZoomsOut:(BOOL)zoomOut
{
	mMode = zoomOut;

	if (zoomOut)
		mModeModifierMask = 0;
}

@synthesize zoomsOut = mMode;
@synthesize modeModifierMask = mModeModifierMask;

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

	if ([self modeModifierMask] != 0)
		mMode = (([event modifierFlags] & [self modeModifierMask]) != 0);

	mAnchor = p;
	mZoomRect = NSZeroRect;
	return 0;
}

/** @brief Handle the mouse dragged event
 @param p the local point where the mouse has been dragged to
 @param pc the partcode returned by the mouseDown method
 @param layer the layer in which the tool is being applied
 @param event the original event
 @param aDel an optional delegate
 */
- (void)mouseDraggedToPoint:(NSPoint)p partCode:(NSInteger)pc layer:(DKLayer*)layer event:(NSEvent*)event delegate:(id)aDel
{
#pragma unused(pc)
#pragma unused(event)
#pragma unused(aDel)

	if (!mMode) {
		[layer setNeedsDisplayInRect:mZoomRect];
		mZoomRect = NSRectFromTwoPoints(mAnchor, p);
		[layer setNeedsDisplayInRect:mZoomRect];
	}
}

/** @brief Handle the mouse up event
 @param p the local point where the mouse went up
 @param pc the partcode returned by the mouseDown method
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

	DKDrawingView* zv = (DKDrawingView*)[layer currentView];

	if (!mMode) {
		NSRect temp = mZoomRect;
		mZoomRect = NSZeroRect;

		[layer setNeedsDisplayInRect:temp];
		temp = NSRectFromTwoPoints(mAnchor, p);
		[layer setNeedsDisplayInRect:temp];

		// if dragged area < 4 pixels, treat as click

		if (NSIsEmptyRect(NSInsetRect(temp, 2.0, 2.0)))
			[zv zoomViewByFactor:2.0
				  andCentrePoint:p];
		else
			[zv zoomViewToRect:temp];
	} else
		[zv zoomViewByFactor:0.5
			  andCentrePoint:p];

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

	if (!NSIsEmptyRect(mZoomRect) && [aView needsToDrawRect:mZoomRect]) {
		CGFloat sc = 1.0 / [(DKDrawingView*)aView scale];
		CGFloat dash[] = { 4.0 * sc, 3.0 * sc };

		NSBezierPath* zoomPath = [NSBezierPath bezierPathWithRect:NSInsetRect(mZoomRect, sc, sc)];
		[zoomPath setLineWidth:sc];
		[zoomPath setLineDash:dash
						count:2
						phase:0.0];
		[[NSColor grayColor] set];
		[zoomPath stroke];
	}
}

/** @brief The state of the modifier keys changed
 @param event the event
 @param layer the current layer that the tool is being applied to
 */
- (void)flagsChanged:(NSEvent*)event inLayer:(DKLayer*)layer
{
	if ([self modeModifierMask] != 0) {
		mMode = (([event modifierFlags] & [self modeModifierMask]) != 0);
		[[self cursor] set];

		if (mMode) {
			[layer setNeedsDisplayInRect:mZoomRect];
			mZoomRect = NSZeroRect;
		}
	}
}

/** @brief Return whether the target layer can be used by this tool

 Zoom tools can always work, even in hidden layers - so always returns YES
 @param aLayer a layer object
 @return YES if the tool can be used with the given layer, NO otherwise
 */
- (BOOL)isValidTargetLayer:(DKLayer*)aLayer
{
#pragma unused(aLayer)

	return YES;
}

/** @brief Return the tool's cursor
 @return the arrow cursor
 */
- (NSCursor*)cursor
{
	NSImage* img;

	if (mMode)
		img = [NSImage imageNamed:@"mag_minus"];
	else
		img = [NSImage imageNamed:@"mag_plus"];

	NSCursor* curs = [[NSCursor alloc] initWithImage:img
											 hotSpot:NSMakePoint(12, 12)];
	return curs;
}

#pragma mark -
#pragma mark - as a NSObject

- (instancetype)init
{
	self = [super init];
	if (self) {
		mModeModifierMask = NSAlternateKeyMask;
	}

	return self;
}

@end
