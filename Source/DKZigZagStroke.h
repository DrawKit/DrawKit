/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
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

@property CGFloat wavelength;
@property CGFloat amplitude;
@property CGFloat spread;

@end
