/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKPathDecorator.h"

/** @brief This object represents a pattern consisting of a repeated motif spaced out at intervals within a larger shape.

This object represents a pattern consisting of a repeated motif spaced out at intervals within a larger shape.

This subclasses DKPathDecorator which carries out the bulk of the work - it stores the image and caches it, this
just sets up the path clipping and calls the rendering method for each location of the repeating pattern.
*/
@interface DKFillPattern : DKPathDecorator <NSCoding, NSCopying> {
@private
	CGFloat m_altYOffset;
	CGFloat m_altXOffset;
	CGFloat m_angle;
	CGFloat m_objectAngle;
	CGFloat m_motifAngle;
	CGFloat mMotifAngleRandomness;
	BOOL m_angleRelativeToObject;
	BOOL m_motifAngleRelativeToPattern;
	BOOL m_noClippedElements;
	NSMutableArray* mMotifAngleRandCache;
}

/**  */
+ (instancetype)defaultPattern;
+ (instancetype)fillPatternWithImage:(NSImage*)image;

/** @brief the vertical and horizontal offset of odd rows/columns to a proportion of the interval, [0...1]
 */
@property NSSize patternAlternateOffset;

- (void)fillRect:(NSRect)rect;
- (void)drawPatternInPath:(NSBezierPath*)aPath;

@property CGFloat angle;
@property CGFloat angleInDegrees;

@property BOOL angleIsRelativeToObject;

@property CGFloat motifAngle;
@property CGFloat motifAngleInDegrees;
@property (nonatomic) CGFloat motifAngleRandomness;

@property BOOL motifAngleIsRelativeToPattern;

/** setting this causes a test for intersection of the motif's bounds with the object's path. If there is an intersection, the motif is not drawn. This makes patterns
 appear tidier for certain applications (such as GIS/mapping) but adds a substantial performance overhead. \c NO by default.
 */
@property BOOL drawingOfClippedElementsSupressed;

@end

extern NSNotificationName kDKDrawingViewDidChangeScale;
