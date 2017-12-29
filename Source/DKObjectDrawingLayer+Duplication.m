/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKObjectDrawingLayer+Duplication.h"

#import "DKDrawableObject.h"
#import "LogEvent.h"

@implementation DKObjectDrawingLayer (Duplication)
#pragma mark As a DKObjectDrawingLayer

/** @brief Duplicates one or more objects radially around a common centre

 Objects in the result are obtained by copying the objects in the original list, and so will have the
 same types, styles, etc.
 @param objectsToDuplicate a list of DKDrawableObjects which will be copied
 @param centre the location of the centre around which the copies are arranged
 @param numberOfCopies how many copies to make
 @param incrementAngle the angle in radians between each copy
 @param rotateCopies YES to rotate the copies so that they lie on the radial, NO to keep them at their original rotation
 @return A list of DKDrawableObjects representing the copies. The originals are not copied to this array.
 */
- (NSArray*)polarDuplicate:(NSArray*)objectsToDuplicate
					centre:(NSPoint)centre
			numberOfCopies:(NSInteger)nCopies
			incrementAngle:(CGFloat)incRadians
			  rotateCopies:(BOOL)rotCopies
{
	if (objectsToDuplicate == nil || [objectsToDuplicate count] < 1 || nCopies < 1)
		return nil; // nothing to copy

	NSMutableArray* result = [[NSMutableArray alloc] init];
	NSInteger i;

	for (i = 0; i < nCopies; ++i) {
		// copy each object

		for (DKDrawableObject* o in objectsToDuplicate) {
			DKDrawableObject* copy = [o copy];
			NSPoint location = [copy location];

			CGFloat relAngle = incRadians * (i + 1);
			CGFloat radius = hypot(location.x - centre.x, location.y - centre.y);
			CGFloat angle = atan2(location.y - centre.y, location.x - centre.x) + relAngle;

			location.x = centre.x + cos(angle) * radius;
			location.y = centre.y + sin(angle) * radius;

			[copy setLocation:location];

			if (rotCopies) {
				[copy setAngle:[o angle] + relAngle];
			}

			[result addObject:copy];
		}
	}

	return result;
}

/** @brief Duplicates one or more objects linearly

 Objects in the result are obtained by copying the objects in the original list, and so will have the
 same types, styles, etc.
 @param objectsToDuplicate a list of DKDrawableObjects which will be copied
 @param offset each copy is offset this much from the last
 @param numberOfCopies how many copies to make
 @return A list of DKDrawableObjects representing the copies. The originals are not copied to this array.
 */
- (NSArray*)linearDuplicate:(NSArray*)objectsToDuplicate
					 offset:(NSSize)offset
			 numberOfCopies:(NSInteger)nCopies
{
	if (objectsToDuplicate == nil || [objectsToDuplicate count] < 1 || nCopies < 1)
		return nil; // nothing to copy

	NSMutableArray* result = [[NSMutableArray alloc] init];
	NSInteger i;

	for (i = 0; i < nCopies; ++i) {
		// copy each object

		for (DKDrawableObject* o in objectsToDuplicate) {
			DKDrawableObject *copy = [o copy];
			NSPoint location = [copy location];

			location.x += offset.width * (i + 1);
			location.y += offset.height * (i + 1);
			[copy setLocation:location];

			[result addObject:copy];
		}
	}

	return result;
}

/** @brief Automatically polar duplicates object to fit a circle exactly

 This computes the increment angle and number of copies needed to fit the object exactly into
 a circle. The angle is that subtended by the object's logical bounds at the centre. The radius
 will be adjusted outwards as necessary so that an integral number of copies fit a complete circle.
 @param object a single opject to be copied
 @param centre the centre around which the object is located
 @return A list of DKDrawableObjects representing the copies. The originals are not copied to this array.
 */
- (NSArray*)autoPolarDuplicate:(DKDrawableObject*)object
						centre:(NSPoint)centre
{
	NSRect lb = [object logicalBounds];
	NSPoint ocp = [object location]; //NSMakePoint( NSMidX( lb ), NSMidY( lb ));
	CGFloat objAngle = atan2([object location].y - centre.y, [object location].x - centre.x);
	CGFloat r, radius, incAngle;

	// r is radius of a circle that encloses the object

	r = hypot(lb.size.width, lb.size.height) / 2.0;

	radius = hypot(ocp.x - centre.x, ocp.y - centre.y);
	incAngle = atan(r / radius) * 2.0;

	// how many fit in a circle?

	NSInteger number = (NSInteger)((2 * M_PI) / incAngle) + 1;

	// to fit this many exactly will require a small increase in radius

	incAngle = (2 * M_PI) / (CGFloat)number;
	radius = r / tan(incAngle * 0.5);

	// set the duplication master at this radius from centre

	ocp.x = centre.x + radius * cos(objAngle);
	ocp.y = centre.y + radius * sin(objAngle);

	[object setLocation:ocp];

	LogEvent_(kReactiveEvent, @"auto polar, copies = %ld, inc = %f", (long)number, incAngle);

	return [self polarDuplicate:@[object]
						 centre:centre
				 numberOfCopies:number - 1
				 incrementAngle:incAngle
				   rotateCopies:YES];
}

/** @brief Duplicates one or more objects concentrically around a common centre

 Objects in the result are obtained by copying the objects in the original list, and so will have the
 same types, styles, etc. While this works with paths, it works best with shapes or groups, because
 paths don't implement setSize: and their location is at their top, left.
 @param objectsToDuplicate a list of DKDrawableObjects which will be copied
 @param centre the location of the centre around which the copies are arranged
 @param numberOfCopies how many copies to make
 @param insetBy the amount each copy is inset or outset (-ve) by
 @return A list of DKDrawableObjects representing the copies. The originals are not copied to this array.
 */
- (NSArray*)concentricDuplicate:(NSArray*)objectsToDuplicate
						 centre:(NSPoint)centre
				 numberOfCopies:(NSInteger)nCopies
						insetBy:(CGFloat)inset
{
	if (objectsToDuplicate == nil || [objectsToDuplicate count] < 1 || nCopies < 1)
		return nil; // nothing to copy

	NSMutableArray* result = [NSMutableArray array];

	for (NSInteger i = 0; i < nCopies; ++i) {
		CGFloat di = -inset * (i + 1) * 2.0;

		for (DKDrawableObject* o in objectsToDuplicate) {
			DKDrawableObject* copy = [o copy];
			NSPoint location = [copy location];
			NSSize size = [copy size];

			CGFloat radius = hypot(location.x - centre.x, location.y - centre.y);
			CGFloat angle = atan2(location.y - centre.y, location.x - centre.x);
			size.width += di;
			size.height += di;

			CGFloat scale = (size.width / [copy size].width);

			location.x = centre.x + cos(angle) * radius * scale;
			location.y = centre.y + sin(angle) * radius * scale;

			[copy setSize:size];
			[copy setLocation:location];

			[result addObject:copy];
		}
	}

	return result;
}

@end
