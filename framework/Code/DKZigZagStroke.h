/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKStroke.h"

@interface DKZigZagStroke : DKStroke <NSCoding, NSCopying> {
@private
    CGFloat mWavelength;
    CGFloat mAmplitude;
    CGFloat mSpread;
}

/**  */
- (void)setWavelength:(CGFloat)w;
- (CGFloat)wavelength;

- (void)setAmplitude:(CGFloat)amp;
- (CGFloat)amplitude;

- (void)setSpread:(CGFloat)sp;
- (CGFloat)spread;

@end
