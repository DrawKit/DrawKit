/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKSelectionPDFView.h"
#import "DKDrawing.h"
#import "DKObjectDrawingLayer.h"
#import "DKShapeGroup.h"
#import "DKViewController.h"

@implementation DKSelectionPDFView

/**  */
- (void)drawRect:(NSRect)rect
{
#pragma unused(rect)

	//[[NSColor clearColor] set];
	//NSRectFill([self bounds]);

	NSUInteger mask = (NSAlternateKeyMask | NSShiftKeyMask | NSCommandKeyMask);
	BOOL drawSelected = (([[NSApp currentEvent] modifierFlags] & mask) == mask);

	DKObjectDrawingLayer* layer = (DKObjectDrawingLayer*)[[self controller] activeLayer];

	if ([layer isKindOfClass:[DKObjectDrawingLayer class]]) {
		[self set];
		[layer drawSelectedObjectsWithSelectionState:drawSelected];
		[[self class] pop];
	}
}

@end

#pragma mark -
@implementation DKLayerPDFView : DKDrawingView

- (instancetype)initWithFrame:(NSRect)frame withLayer:(DKLayer*)aLayer
{
	self = [super initWithFrame:frame];
	if (self != nil) {
		mLayerRef = aLayer;
	}

	return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
	return self = [self initWithFrame:frameRect withLayer:nil];
}

- (BOOL)isFlipped
{
	return YES;
}

- (void)drawRect:(NSRect)rect
{
#pragma unused(rect)

	//[[NSColor clearColor] set];
	//NSRectFill([self bounds]);

	if (mLayerRef != nil) {
		[self set];

		[mLayerRef beginDrawing];
		[mLayerRef drawRect:[self bounds]
					 inView:self];
		[mLayerRef endDrawing];

		[[self class] pop];
	}
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	return self = [super initWithCoder:decoder];
}

@end

#pragma mark -

@implementation DKDrawablePDFView

- (instancetype)initWithFrame:(NSRect)frame object:(DKDrawableObject*)obj
{
	self = [super initWithFrame:frame];
	if (self != nil) {
		mObjectRef = obj;
	}

	return self;
}

-(instancetype)initWithFrame:(NSRect)frameRect
{
	return self = [self initWithFrame:frameRect object:nil];
}

- (BOOL)isFlipped
{
	return YES;
}

- (void)drawRect:(NSRect)rect
{
#pragma unused(rect)

	[[NSColor clearColor] set];
	NSRectFill([self bounds]);

	if (mObjectRef)
		[mObjectRef drawContentWithSelectedState:NO];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	return self = [super initWithCoder:decoder];
}

@end
