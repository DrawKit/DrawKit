/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/** Objects that can be passed to a renderer must implement the following formal protocol.
 */
@protocol DKRenderable <NSObject>

/** Returns the actual path to be rendered, at its final location and size in the base coordinate system.
 */
- (nullable NSBezierPath*)renderingPath;

/** Angle in radians - may be 0
 */
@property (readonly) CGFloat angle;

/** The width and height of the object at the current angle.
 */
@property (readonly) NSSize size;

/** Object's location in base coordinates.
 */
@property (readonly) NSPoint location;

/** Return whether current rendering can take shortcuts or must be full quality.
 */
@property (readonly) BOOL useLowQualityDrawing;

/** Returns the transform applied by the object's container, if any (otherwise the identity transform).
 */
@property (readonly, copy) NSAffineTransform* containerTransform;

/** Any extra space needed outside of the renderingPath to accommodate the stylistic effects.
 */
@property (readonly) NSSize extraSpaceNeeded;

/** the bounds rect of the object
 */
@property (readonly) NSRect bounds;

/** return a checksum for the object's geometry (size, angle and position)
 
 Do not rely on what the number is, only whether it has changed. Also, do not persist it in any way.
 */
@property (readonly) NSUInteger geometryChecksum;

@optional
/** return a mutable dictionary that a renderer can store information into for caching purposes
 */
- (nullable NSMutableDictionary*)renderingCache;

@end

/** renderers must implement the following formal protocol:
 */
NS_SWIFT_NAME(DKRasterizerProtocol)
@protocol DKRasterizer <NSObject>

@property (readonly) NSSize extraSpaceNeeded;
- (void)render:(id<DKRenderable>)object;
- (void)renderPath:(nullable NSBezierPath*)path;
@property (readonly) BOOL isFill;

@end

NS_ASSUME_NONNULL_END
