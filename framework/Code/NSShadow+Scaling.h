/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

typedef enum {
    kDKShadowDrawFill = (1 << 0),
    kDKShadowDrawStroke = (1 << 1)
} DKShadowDrawingOperation;

/**
a big annoyance with NSShadow is that it ignores the current CTM when it is set, meaning that as a drawing is scaled,
the shadow stays fixed. This is a solution. Here, if you call setAbsolute instead of set, the parameters of the shadow are
used to set a different shadow that is scaled using the current CTM, so the original shadow appears to remain at the right size
as you scale.
*/
@interface NSShadow (DKAdditions)

- (void)setAbsolute;
- (void)setAbsoluteFlipped:(BOOL)flipped;

#ifdef DRAWKIT_DEPRECATED
- (void)setShadowAngle:(CGFloat)radians distance:(CGFloat)dist;
- (void)setShadowAngleInDegrees:(CGFloat)degrees distance:(CGFloat)dist;
- (CGFloat)shadowAngle;
- (CGFloat)shadowAngleInDegrees;
#endif

- (void)setAngle:(CGFloat)radians;
- (void)setAngleInDegrees:(CGFloat)degrees;
- (CGFloat)angle;
- (CGFloat)angleInDegrees;

- (void)setDistance:(CGFloat)distance;
- (CGFloat)distance;
- (CGFloat)extraSpace;

- (void)drawApproximateShadowWithPath:(NSBezierPath*)path operation:(DKShadowDrawingOperation)op strokeWidth:(NSInteger)sw;

@end
