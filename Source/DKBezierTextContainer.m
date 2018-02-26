/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKBezierTextContainer.h"
#import "NSBezierPath+Text.h"

@implementation DKBezierTextContainer
@synthesize bezierPath = mPath;

- (void)setBezierPath:(NSBezierPath*)aPath
{
	// copy the path and store it offset to its top, left corner - this saves
	// having to adjust the line fragment rects to the path for every call.

	NSRect pb = [aPath bounds];
	NSAffineTransform* tfm = [NSAffineTransform transform];

	[tfm translateXBy:-pb.origin.x
				  yBy:-pb.origin.y];
	aPath = [tfm transformBezierPath:aPath];

	mPath = aPath;
}

- (BOOL)isSimpleRegularTextContainer
{
	return (mPath == nil);
}

- (NSRect)lineFragmentRectForProposedRect:(NSRect)proposedRect
						   sweepDirection:(NSLineSweepDirection)sweepDirection
						movementDirection:(NSLineMovementDirection)movementDirection
							remainingRect:(NSRectPointer)remainingRect
{
	if (mPath == nil)
		return [super lineFragmentRectForProposedRect:proposedRect
									   sweepDirection:sweepDirection
									movementDirection:movementDirection
										remainingRect:remainingRect];
	else
		return [mPath lineFragmentRectForProposedRect:proposedRect
										remainingRect:remainingRect];
}

@end
