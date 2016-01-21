/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

// objects that can be passed to a renderer must implement the following formal protocol

@protocol DKRenderable <NSObject>

- (NSBezierPath*)renderingPath; // returns the actual path to be rendered, at its final location and size in the base coordinate system
- (CGFloat)angle; // angle in radians - may be 0
- (NSSize)size; // the width and height of the object at the current angle
- (NSPoint)location; // object's location in base coordinates
- (BOOL)useLowQualityDrawing; // return whether current rendering can take shortcuts or must be full quality
- (NSAffineTransform*)containerTransform; // returns the transform applied by the object's container, if any (otherwise the identity transform)
- (NSSize)extraSpaceNeeded; // any extra space needed outside of the renderingPath to accommodate the stylistic effects
- (NSRect)bounds; // the bounds rect of the object
- (NSUInteger)geometryChecksum; // return a checksum for the object's geometry (size, angle and position)

@optional
- (NSMutableDictionary*)renderingCache; // return a mutable dictionary that a renderer can store information into for caching purposes

@end

// renderers must implement the following formal protocol:

@protocol DKRasterizer <NSObject>

- (NSSize)extraSpaceNeeded;
- (void)render:(id<DKRenderable>)object;
- (void)renderPath:(NSBezierPath*)path;
- (BOOL)isFill;

@end
