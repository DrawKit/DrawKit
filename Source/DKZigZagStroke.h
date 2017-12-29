/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKStroke.h"

@interface DKZigZagStroke : DKStroke <NSCoding, NSCopying> {
@private
	CGFloat mWavelength;
	CGFloat mAmplitude;
	CGFloat mSpread;
}

@property (nonatomic) CGFloat wavelength;
@property CGFloat amplitude;
@property CGFloat spread;

@end
