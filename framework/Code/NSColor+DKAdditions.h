///**********************************************************************************************************************************
///  NSColor+DKAdditions.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 26/03/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import <Cocoa/Cocoa.h>


@interface NSColor (DKAdditions)

+ (NSColor*)			rgbWhite;
+ (NSColor*)			rgbBlack;
+ (NSColor*)			rgbGrey:(CGFloat) grayscale;
+ (NSColor*)			rgbGrey:(CGFloat) grayscale withAlpha:(CGFloat) alpha;
+ (NSColor*)			rgbGreyWithLuminosityFrom:(NSColor*) colour withAlpha:(CGFloat) alpha;

+ (NSColor*)			veryLightGrey;

+ (NSColor*)			contrastingColor:(NSColor*) color;
+ (NSColor*)			colorWithWavelength:(CGFloat) lambda;
+ (NSColor*)			colorWithHexString:(NSString*) hex;

+ (NSColor*)			colorByInterpolatingFrom:(NSColor*) startColor to:(NSColor*) endColor atValue:(CGFloat) interpValue;

- (NSColor*)			colorWithHueFrom:(NSColor*) color;
- (NSColor*)			colorWithHueAndSaturationFrom:(NSColor*) color;
- (NSColor*)			colorWithRGBAverageFrom:(NSColor*) color;
- (NSColor*)			colorWithHSBAverageFrom:(NSColor*) color;

- (NSColor*)			colorWithRGBBlendFrom:(NSColor*) color blendingAmounts:(CGFloat[]) blends;
- (NSColor*)			colorWithHSBBlendFrom:(NSColor*) color blendingAmounts:(CGFloat[]) blends;

- (CGFloat)				luminosity;
- (NSColor*)			colorWithLuminosity;
- (NSColor*)			contrastingColor;
- (NSColor*)			invertedColor;

- (NSColor*)			lighterColorWithLevel:(CGFloat) amount;
- (NSColor*)			darkerColorWithLevel:(CGFloat) amount;

- (NSColor*)			interpolatedColorToColor:(NSColor*) secondColor atValue:(CGFloat) interpValue;

- (NSString*)			hexString;

- (CGColorRef)			newQuartzColor;

@end
