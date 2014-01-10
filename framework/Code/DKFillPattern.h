/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

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
+ (DKFillPattern*)defaultPattern;
+ (DKFillPattern*)fillPatternWithImage:(NSImage*)image;

- (void)setPatternAlternateOffset:(NSSize)altOffset;
- (NSSize)patternAlternateOffset;

- (void)fillRect:(NSRect)rect;
- (void)drawPatternInPath:(NSBezierPath*)aPath;

- (void)setAngle:(CGFloat)radians;
- (CGFloat)angle;
- (void)setAngleInDegrees:(CGFloat)degrees;
- (CGFloat)angleInDegrees;

- (void)setAngleIsRelativeToObject:(BOOL)relAngle;
- (BOOL)angleIsRelativeToObject;

- (void)setMotifAngle:(CGFloat)radians;
- (CGFloat)motifAngle;
- (void)setMotifAngleInDegrees:(CGFloat)degrees;
- (CGFloat)motifAngleInDegrees;
- (void)setMotifAngleRandomness:(CGFloat)maRand;
- (CGFloat)motifAngleRandomness;

- (void)setMotifAngleIsRelativeToPattern:(BOOL)mrel;
- (BOOL)motifAngleIsRelativeToPattern;

- (void)setDrawingOfClippedElementsSupressed:(BOOL)suppress;
- (BOOL)drawingOfClippedElementsSupressed;

@end

extern NSString* kDKDrawingViewDidChangeScale;
