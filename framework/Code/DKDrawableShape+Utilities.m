/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKDrawableShape+Utilities.h"

@implementation DKDrawableShape (Utilities)

/** @brief Return a rectangular path with given size and origin

 Not affected by the object's current offset
 @param relRect a rectangle expressed relative to the unit square
 @return a rectangular path transformed to the current true size, position and angle of the shape
 */
- (NSBezierPath*)pathWithRelativeRect:(NSRect)relRect
{
	NSBezierPath* path = [NSBezierPath bezierPathWithRect:relRect];
	NSAffineTransform* transform = [self transformIncludingParent];
	[path transformUsingAffineTransform:transform];

	return path;
}

/** @brief Return a rectangular path with given relative origin but absolute final size

 Not affected by the object's current offset. By specifying a final size the resulting path can
 represent a fixed-sized region independent of the object's current size.
 @param relLoc a point expressed relative to the unit square
 @param size the final desired size o fthe rectangle
 @return a rectangular path transformed to the current true size, position and angle of the shape
 */
- (NSBezierPath*)pathWithRelativePosition:(NSPoint)relLoc finalSize:(NSSize)size
{
	// work out a fully relative rect

	NSRect relRect;

	relRect.origin = relLoc;
	relRect.size.width = size.width / [self size].width;
	relRect.size.height = size.height / [self size].height;

	return [self pathWithRelativeRect:relRect];
}

/** @brief Return a rectangular path offset from a given partcode

 The resulting path is positioned at a fixed offset and size relative to a partcode (a corner, say)
 in such a way that the object's size and angle set the positioning and orientation of the path
 but not its actual size. This is useful for adding an adornment to the shape that is unscaled
 by the object, such as the text indicator shown by DKTextShape
 @param size the final desired size of the rectangle
 @param offset an offset in absolute units from the nominated partcode position
 @param pc the partcode that the path is positioned relative to
 @return a rectangular path transformed to the current true size, position and angle of the shape
 */
- (NSBezierPath*)pathWithFinalSize:(NSSize)size offsetBy:(NSPoint)offset fromPartcode:(NSInteger)pc
{
	NSSize ss = [self size];

	if (ss.width > 0.0 && ss.height > 0.0) {
		NSPoint p = [self pointForPartcode:pc];
		NSAffineTransform* transform = [self transformIncludingParent];
		[transform invert];
		p = [transform transformPoint:p];

		p.x += (offset.x / ss.width);
		p.y += (offset.y / ss.height);

		return [self pathWithRelativePosition:p
									finalSize:size];
	} else
		return nil;
}

/** @brief Transforms a path to the final size and position relative to a partcode

 The resulting path is positioned at a fixed offset and size relative to a partcode (a corner, say)
 in such a way that the object's size and angle set the positioning and orientation of the path
 but not its actual size. This is useful for adding an adornment to the shape that is unscaled
 by the object, such as the text indicator shown by DKTextShape
 @param path the path to transform
 @param size the final desired size of the rectangle
 @param offset an offset in absolute units from the nominated partcode position
 @param pc the partcode that the path is positioned relative to
 @return the transformed path
 */
- (NSBezierPath*)path:(NSBezierPath*)inPath withFinalSize:(NSSize)size offsetBy:(NSPoint)offset fromPartcode:(NSInteger)pc
{
	NSAssert(inPath != nil, @"can't do this with a nil path");

	// eliminate the path's origin offset and size it to the desired final size

	NSSize ss = [self size];

	if (ss.width > 0 && ss.height > 0) {
		NSPoint p = [self pointForPartcode:pc];
		NSAffineTransform* transform = [self transformIncludingParent];
		[transform invert];
		p = [transform transformPoint:p];

		p.x += (offset.x / ss.width);
		p.y += (offset.y / ss.height);

		NSRect pr = [inPath bounds];

		NSAffineTransform* tfm = [NSAffineTransform transform];
		[tfm translateXBy:p.x
					  yBy:p.y];
		[tfm scaleXBy:size.width / (pr.size.width * ss.width)
				  yBy:size.height / (pr.size.height * ss.height)];
		[tfm translateXBy:-pr.origin.x
					  yBy:-pr.origin.y];

		NSBezierPath* newPath = [tfm transformBezierPath:inPath];

		[newPath transformUsingAffineTransform:[self transformIncludingParent]];

		return newPath;
	} else
		return nil;
}

/** @brief Convert a point from relative coordinates to absolute coordinates

 Not affected by the object's current offset
 @param relLoc a point expressed relative to the unit square
 @return the absolute point taking into account scale, position and angle
 */
- (NSPoint)pointForRelativeLocation:(NSPoint)relLoc
{
	NSAffineTransform* transform = [self transformIncludingParent];
	return [transform transformPoint:relLoc];
}

@end
