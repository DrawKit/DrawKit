//
//  DKZigZagFill.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 04/01/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKFill.h"


@interface DKZigZagFill : DKFill <NSCoding, NSCopying>
{
@private
	CGFloat		mWavelength;
	CGFloat		mAmplitude;
	CGFloat		mSpread;
}

- (void)		setWavelength:(CGFloat) w;
- (CGFloat)		wavelength;

- (void)		setAmplitude:(CGFloat) amp;
- (CGFloat)		amplitude;

- (void)		setSpread:(CGFloat) sp;
- (CGFloat)		spread;

@end
