/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/** @brief Stolen from Apple sample code "speedy categories".
 */
@interface NSAffineTransform (DKAdditions)

- (NSAffineTransform*)mapFrom:(NSRect)src to:(NSRect)dst;
- (NSAffineTransform*)mapFrom:(NSRect)src to:(NSRect)dst dstAngle:(CGFloat)radians;

/** @brief Create a transform that proportionately scales \c bounds to a rectangle of \c height
 centered \c distance units above a particular point.
 */
- (NSAffineTransform*)scaleBounds:(NSRect)bounds toHeight:(CGFloat)height centeredDistance:(CGFloat)distance abovePoint:(NSPoint)location;

/** @brief Create a transform that proportionately scales \c bounds to a rectangle of \c height
 centered \c distance units above the origin.
 */
- (NSAffineTransform*)scaleBounds:(NSRect)bounds toHeight:(CGFloat)height centeredAboveOrigin:(CGFloat)distance;

/** @brief Initialize the \c NSAffineTransform so it will flip the contents of bounds
 vertically.
 */
- (NSAffineTransform*)flipVertical:(NSRect)bounds;

@end

NS_ASSUME_NONNULL_END
