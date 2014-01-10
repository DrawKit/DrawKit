/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

/** @brief This class provides a number of standard shareable paths that can be utilsed by DKDrawableShape.

This class provides a number of standard shareable paths that can be utilsed by DKDrawableShape. These are all
bounded by the standard unit square 1.0 on each side and centered at the origin. The DKDrawableShape class
provides rotation, scaling and offset for each shape that it draws.

Note that for efficiency many of the path objects returned here are shared. That means that if you change a shape
with the path editor you MUST copy it first.

The other job of this class is to provide shapes for reshapable shapes on demand. In that case, an instance of
the shape factory is used (usually sharedShapeFactory) and the instance methods which conform to the reshapable informal
protocol are used as shape providers. See DKReshapableShape for more details.
*/
@interface DKShapeFactory : NSObject <NSCoding>

/**  */
+ (DKShapeFactory*)sharedShapeFactory;

+ (NSRect)rectOfUnitSize;

+ (NSBezierPath*)rect;
+ (NSBezierPath*)oval;
+ (NSBezierPath*)roundRect;
+ (NSBezierPath*)roundRectWithCornerRadius:(CGFloat)radius;
+ (NSBezierPath*)roundRectInRect:(NSRect)rect andCornerRadius:(CGFloat)radius;

+ (NSBezierPath*)regularPolygon:(NSInteger)numberOfSides;

+ (NSBezierPath*)equilateralTriangle;
+ (NSBezierPath*)rightTriangle;

+ (NSBezierPath*)pentagon;
+ (NSBezierPath*)hexagon;
+ (NSBezierPath*)heptagon;
+ (NSBezierPath*)octagon;

+ (NSBezierPath*)star:(NSInteger)numberOfPoints innerDiameter:(CGFloat)diam;
+ (NSBezierPath*)regularStar:(NSInteger)numberOfPoints;

+ (NSBezierPath*)cross;
+ (NSBezierPath*)diagonalCross;

+ (NSBezierPath*)ring:(CGFloat)innerDiameter;

+ (NSBezierPath*)roundRectSpeechBalloon:(NSInteger)sbParams cornerRadius:(CGFloat)cr;
+ (NSBezierPath*)roundRectSpeechBalloonInRect:(NSRect)rect params:(NSInteger)sbParams cornerRadius:(CGFloat)cr;
+ (NSBezierPath*)ovalSpeechBalloon:(NSInteger)sbParams;

+ (NSBezierPath*)arrowhead;
+ (NSBezierPath*)arrowTailFeather;
+ (NSBezierPath*)arrowTailFeatherWithRake:(CGFloat)rakeFactor;
+ (NSBezierPath*)inflectedArrowhead;

+ (NSBezierPath*)roundEndedRect:(NSRect)rect;

+ (NSBezierPath*)pathFromGlyph:(NSString*)glyph inFontWithName:(NSString*)fontName;

- (NSBezierPath*)roundRectInRect:(NSRect)bounds objParam:(id)param;
- (NSBezierPath*)roundEndedRect:(NSRect)rect objParam:(id)param;
- (NSBezierPath*)speechBalloonInRect:(NSRect)rect objParam:(id)param;

@end

// params for speech balloon shapes:

enum {
    kDKSpeechBalloonPointsLeft = 0,
    kDKSpeechBalloonPointsRight = 1,
    kDKSpeechBalloonPointsDown = 0,
    kDKSpeechBalloonPointsUp = 1,
    kDKSpeechBalloonLeftEdge = 2,
    kDKSpeechBalloonRightEdge = 4,
    kDKSpeechBalloonTopEdge = 6,
    kDKSpeechBalloonBottomEdge = 8,
    kDKStandardSpeechBalloon = kDKSpeechBalloonTopEdge | kDKSpeechBalloonPointsLeft,
    kDKSpeechBalloonEdgeMask = 0x0E
};

// param keys for dictionary passed to provider methods:

extern NSString* kDKSpeechBalloonType;
extern NSString* kDKSpeechBalloonCornerRadius;
