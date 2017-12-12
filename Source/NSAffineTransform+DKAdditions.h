/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

/** stolen from Apple sample code "speedy categories"
 */
@interface NSAffineTransform (DKAdditions)

/**  */
- (NSAffineTransform*)mapFrom:(NSRect)src to:(NSRect)dst;
- (NSAffineTransform*)mapFrom:(NSRect)src to:(NSRect)dst dstAngle:(CGFloat)radians;

- (NSAffineTransform*)scaleBounds:(NSRect)bounds toHeight:(CGFloat)height centeredDistance:(CGFloat)distance abovePoint:(NSPoint)location;
- (NSAffineTransform*)scaleBounds:(NSRect)bounds toHeight:(CGFloat)height centeredAboveOrigin:(CGFloat)distance;
- (NSAffineTransform*)flipVertical:(NSRect)bounds;

@end
