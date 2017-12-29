/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKObjectDrawingLayer.h"

NS_ASSUME_NONNULL_BEGIN
@class DKDrawableObject;

/** @brief Some handy methods for implementing various kinds of object duplications.

Some handy methods for implementing various kinds of object duplications.
*/
@interface DKObjectDrawingLayer (Duplication)

/** @brief Duplicates one or more objects radially around a common centre

 Objects in the result are obtained by copying the objects in the original list, and so will have the
 same types, styles, etc.
 @param objectsToDuplicate a list of DKDrawableObjects which will be copied
 @param centre the location of the centre around which the copies are arranged
 @param nCopies how many copies to make
 @param incRadians the angle in radians between each copy
 @param rotCopies YES to rotate the copies so that they lie on the radial, NO to keep them at their original rotation
 @return A list of DKDrawableObjects representing the copies. The originals are not copied to this array.
 */
- (nullable NSArray<DKDrawableObject*>*)polarDuplicate:(nullable NSArray<DKDrawableObject*>*)objectsToDuplicate
									   centre:(NSPoint)centre
							   numberOfCopies:(NSInteger)nCopies
							   incrementAngle:(CGFloat)incRadians
								 rotateCopies:(BOOL)rotCopies;

/** @brief Duplicates one or more objects linearly

 Objects in the result are obtained by copying the objects in the original list, and so will have the
 same types, styles, etc.
 @param objectsToDuplicate a list of DKDrawableObjects which will be copied
 @param offset each copy is offset this much from the last
 @param nCopies how many copies to make
 @return A list of DKDrawableObjects representing the copies. The originals are not copied to this array.
 */
- (nullable NSArray<DKDrawableObject*>*)linearDuplicate:(nullable NSArray<DKDrawableObject*>*)objectsToDuplicate
										offset:(NSSize)offset
								numberOfCopies:(NSInteger)nCopies;

/** @brief Automatically polar duplicates object to fit a circle exactly

 This computes the increment angle and number of copies needed to fit the object exactly into
 a circle. The angle is that subtended by the object's logical bounds at the centre. The radius
 will be adjusted outwards as necessary so that an integral number of copies fit a complete circle.
 @param object a single opject to be copied
 @param centre the centre around which the object is located
 @return A list of DKDrawableObjects representing the copies. The originals are not copied to this array.
 */
- (nullable NSArray<DKDrawableObject*>*)autoPolarDuplicate:(DKDrawableObject*)object
										   centre:(NSPoint)centre;

/** @brief Duplicates one or more objects concentrically around a common centre

 Objects in the result are obtained by copying the objects in the original list, and so will have the
 same types, styles, etc. While this works with paths, it works best with shapes or groups, because
 paths don't implement setSize: and their location is at their top, left.
 @param objectsToDuplicate a list of DKDrawableObjects which will be copied
 @param centre the location of the centre around which the copies are arranged
 @param nCopies how many copies to make
 @param inset the amount each copy is inset or outset (-ve) by
 @return A list of DKDrawableObjects representing the copies. The originals are not copied to this array.
 */
- (nullable NSArray<DKDrawableObject*>*)concentricDuplicate:(nullable NSArray<DKDrawableObject*>*)objectsToDuplicate
											centre:(NSPoint)centre
									numberOfCopies:(NSInteger)nCopies
										   insetBy:(CGFloat)inset;

@end

NS_ASSUME_NONNULL_END
