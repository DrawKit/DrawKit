/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawablePath.h"

// shape types this class supports:

typedef enum {
	kDKArcPathOpenArc = 0,
	kDKArcPathWedge,
	kDKArcPathCircle
} DKArcPathType;

// the class:

@interface DKArcPath : DKDrawablePath <NSCopying, NSCoding> {
@private
	CGFloat mRadius;
	CGFloat mStartAngle;
	CGFloat mEndAngle;
	NSPoint mCentre;
	DKArcPathType mArcType;
}

- (void)setRadius:(CGFloat)rad;
- (CGFloat)radius;

- (void)setStartAngle:(CGFloat)sa;
- (CGFloat)startAngle;

- (void)setEndAngle:(CGFloat)ea;
- (CGFloat)endAngle;

/** @brief Sets the arc type, which affects the path geometry
 @param arcType the required type
 */
- (void)setArcType:(DKArcPathType)arcType;

/** @brief Returns the arc type, which affects the path geometry
 @return the current arc type
 */
- (DKArcPathType)arcType;

- (IBAction)convertToPath:(id)sender;

@end

// partcodes this class defines - note that the implicit partcodes used by DKDrawablePath are not used by this class,
// so we don't need to ensure these are out of range. The numbers here are entirely arbitrary, but the code does assume
// they are consecutive, continuous, and ordered thus:

enum {
	kDKArcPathRadiusPart = 2,
	kDKArcPathStartAnglePart,
	kDKArcPathEndAnglePart,
	kDKArcPathRotationKnobPart,
	kDKArcPathCentrePointPart,
};

// the simple creation mode can be set (rather than, say, kDKPathCreateModeArcSegment) to create arcs in a one-step process
// which simply drags out the radius of an arc 45 degrees centred on the horizontal axis. The arc is editable in
// exactly the same way afterwards so there is no functionality lost doing it this way. It might be found to be easier to use
// than the 2-stage arc creation process.

enum {
	kDKArcSimpleCreationMode = 7
};
