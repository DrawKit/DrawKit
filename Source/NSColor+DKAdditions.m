/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "NSColor+DKAdditions.h"

#import "LogEvent.h"
#include <tgmath.h>

@implementation NSColor (DKAdditions)
#pragma mark As an NSColor

/** @brief Returns the colour white as an RGB Color

 Uses the RGB Color space, not the greyscale Colorspace you get with NSColor's whiteColor
 method.
 @return the colour white
 */
+ (NSColor*)rgbWhite
{
	return [self rgbGrey:1.0];
}

/** @brief Returns the colour black as an RGB Color

 Uses the RGB Color space, not the greyscale Colorspace you get with NSColor's blackColor
 method.
 @return the colour black
 */
+ (NSColor*)rgbBlack
{
	return [self rgbGrey:0.0];
}

/** @brief Returns a grey RGB colour

 Uses the RGB Color space, not the greyscale Colorspace you get with NSColor's grey
 method. 
 @param grayscale 0 to 1.0
 @return a grey colour
 */
+ (NSColor*)rgbGrey:(CGFloat)grayscale
{
	return [self rgbGrey:grayscale
			   withAlpha:1.0];
}

/** @brief Returns a grey RGB colour

 Uses the RGB Color space, not the greyscale Colorspace you get with NSColor's grey
 method.
 @param grayscale 0 to 1.0
 @param alpha 0 to 1.0
 @return a grey colour with variable opacity
 */
+ (NSColor*)rgbGrey:(CGFloat)grayscale withAlpha:(CGFloat)alpha
{
	return [self colorWithCalibratedRed:grayscale
								  green:grayscale
								   blue:grayscale
								  alpha:alpha];
}

/** @brief Returns a grey RGB colour with the same perceived brightness as the source colour
 @param colour any colour
 @param alpha 0 to 1.0
 @return a grey colour in rgb space of equivalent luminosity
 */
+ (NSColor*)rgbGreyWithLuminosityFrom:(NSColor*)colour withAlpha:(CGFloat)alpha
{
	return [self rgbGrey:[colour luminosity]
			   withAlpha:alpha];
}

/** @brief A very light grey colour
 @return a very light grey colour in rgb space
 */
+ (NSColor*)veryLightGrey
{
	return [self rgbGrey:0.9];
}

#pragma mark -

/** @brief Returns black or white depending on input colour - dark colours give white, else black.

 Colour returned is in grayscale colour space
 @return black or white
 */
+ (NSColor*)contrastingColor:(NSColor*)Color
{
	if ([Color luminosity] >= 0.5)
		return [NSColor blackColor];
	else
		return [NSColor whiteColor];
}

/** @brief Returns an RGB colour approximating the wavelength.

 Lambda range outside 380 to 780 (nm) returns black
 @param lambda the wavelength in nanometres
 @return approximate rgb equivalent colour
 */
+ (NSColor*)colorWithWavelength:(CGFloat)lambda
{
	CGFloat gama = 0.8;
	NSInteger wave;
	double red = 0.0;
	double green = 0.0;
	double blue = 0.0;
	double factor;

	wave = _CGFloatTrunc(lambda);

	if (wave < 380 || wave > 780)
		return [NSColor blackColor];

	if (wave >= 380 && wave < 440) {
		red = -(lambda - 440.0) / (440.0 - 380.0);
		green = 0.0;
		blue = 1.0;
	} else if (wave >= 440 && wave < 490) {
		red = 0.0;
		green = (lambda - 440.0) / (490.0f - 440.0);
		blue = 1.0;
	} else if (wave > 490 && wave < 510) {
		red = 0.0;
		green = 1.0;
		blue = -(lambda - 510.0) / (510.0 - 490.0);
	} else if (wave >= 510 && wave < 580) {
		red = (lambda - 510.0) / (580.0 - 510.0);
		green = 1.0;
		blue = 0.0;
	} else if (wave >= 580 && wave < 645) {
		red = 1.0;
		green = -(lambda - 645.0) / (645.0f - 580.0);
		blue = 0.0;
	} else if (wave >= 645 && wave <= 780) {
		red = 1.0;
		green = 0.0;
		blue = 0.0;
	}
	// Let the intensity fall off near the vision limits

	if (wave >= 380 && wave < 420)
		factor = 0.3 + 0.7 * (lambda - 380.0) / (420.0 - 380.0);
	else if (wave >= 420 && wave < 700)
		factor = 1.0;
	else if (wave >= 700 && wave <= 780)
		factor = 0.3 + 0.7 * (780.0 - lambda) / (780.0 - 700.0);
	else
		factor = 0.0;

	// adjust rgb for gamma and factor:

	red = pow(red * factor, gama);
	green = pow(green * factor, gama);
	blue = pow(blue * factor, gama);

	LogEvent_(kInfoEvent, @"red: %f, green: %f, blue: %f", red, green, blue);

	return [NSColor colorWithCalibratedRed:red
									 green:green
									  blue:blue
									 alpha:1.0];
}

/** @brief Returns an RGB colour corresponding to the standard-formatted HTML hexadecimal colour string.
 @param hex a string formatted '#RRGGBB'
 @return rgb equivalent colour
 */
+ (NSColor*)colorWithHexString:(NSString*)hex
{
	if (hex == nil || [hex length] < 7)
		return nil;

	CGFloat rgb[3];
	const char* p = [[hex lowercaseString] cStringUsingEncoding:NSUTF8StringEncoding];
	NSColor* c = nil;
	NSInteger h, k = 0;
	char v;

	if (*p++ == '#' && [hex length] >= 7) {
		while (k < 3 && *p != 0) {
			v = *p++;
			if (v > '9')
				h = (NSInteger)((v - 'a') + 10) * 16;
			else
				h = (NSInteger)v * 16;

			v = *p++;
			if (v > '9')
				h += (NSInteger)(v - 'a') + 10;
			else
				h += (NSInteger)v;

			rgb[k++] = (CGFloat)h / 255.0;
		}

		c = [NSColor colorWithCalibratedRed:rgb[0]
									  green:rgb[1]
									   blue:rgb[2]
									  alpha:1.0];
	}

	return c;
}

/** @brief Returns a colour by interpolating between two colours
 @param startColor a colour
 @param endColor a second colour
 @param interpValue a value between 0 and 1
 @return a colour that is intermediate between startColor and endColor, in RGB space
 */
+ (NSColor*)colorByInterpolatingFrom:(NSColor*)startColor to:(NSColor*)endColor atValue:(CGFloat)interpValue
{
	// returns an RGB color that interpolates between <start> and <end> given a value from 0..1.

	NSColor* rgb1 = [startColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor* rgb2 = [endColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

	if (interpValue <= 0.0)
		return rgb1;
	else if (interpValue >= 1.0)
		return rgb2;
	else {
		CGFloat r, g, b, a;

		r = ([rgb2 redComponent] * interpValue) + ([rgb1 redComponent] * (1.0 - interpValue));
		g = ([rgb2 greenComponent] * interpValue) + ([rgb1 greenComponent] * (1.0 - interpValue));
		b = ([rgb2 blueComponent] * interpValue) + ([rgb1 blueComponent] * (1.0 - interpValue));
		a = ([rgb2 alphaComponent] * interpValue) + ([rgb1 alphaComponent] * (1.0 - interpValue));

		return [NSColor colorWithCalibratedRed:r
										 green:g
										  blue:b
										 alpha:a];
	}
}

#pragma mark -

/** @brief Returns a copy ofthe receiver but substituting the hue from the given colour.

 If the receiver is black or white or otherwise fully unsaturated, colourization may not produce visible
 results. Input colours must be in RGB colour space
 @param color donates hue
 @return a colour with the hue of <color> but the receiver's saturation and brightness
 */
- (NSColor*)colorWithHueFrom:(NSColor*)color
{
	return [NSColor colorWithCalibratedHue:[color hueComponent]
								saturation:[self saturationComponent]
								brightness:[self brightnessComponent]
									 alpha:[self alphaComponent]];
}

/** @brief Returns a copy ofthe receiver but substituting the hue and saturation from the given colour.

 Input colours must be in RGB colour space
 @param color donates hue and saturation
 @return a colour with the hue, sat of <color> but the receiver's brightness
 */
- (NSColor*)colorWithHueAndSaturationFrom:(NSColor*)color
{
	return [NSColor colorWithCalibratedHue:[color hueComponent]
								saturation:[color saturationComponent]
								brightness:[self brightnessComponent]
									 alpha:[self alphaComponent]];
}

/** @brief Returns a colour by averaging the receiver with <color> in rgb space

 Input colours must be in RGB colour space
 @param color average with this colour
 @return average of the two colours
 */
- (NSColor*)colorWithRGBAverageFrom:(NSColor*)color
{
	CGFloat ba[4] = { 0.5, 0.5, 0.5, 0.5 };

	return [self colorWithRGBBlendFrom:color
					   blendingAmounts:ba];
}

/** @brief Returns a colour by averaging the receiver with <color> in hsb space

 Input colours must be in RGB colour space
 @param color average with this colour
 @return average of the two colours
 */
- (NSColor*)colorWithHSBAverageFrom:(NSColor*)color
{
	CGFloat ba[4] = { 0.5, 0.5, 0.5, 0.5 };

	return [self colorWithHSBBlendFrom:color
					   blendingAmounts:ba];
}

#pragma mark -

/** @brief Returns a colour by blending the receiver with <color> in rgb space
 @param color blend with this colour
 @param blendingAmounts an array of four values, each 0..1, specifies how components from each colour are
 @return blend of the two colours
 */
- (NSColor*)colorWithRGBBlendFrom:(NSColor*)color blendingAmounts:(CGFloat[])blends
{
	NSColor* sc = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor* dc = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

	CGFloat r, g, b, a;

	r = ([sc redComponent] * (1.0 - blends[0])) + ([dc redComponent] * blends[0]);
	g = ([sc greenComponent] * (1.0 - blends[1])) + ([dc greenComponent] * blends[1]);
	b = ([sc blueComponent] * (1.0 - blends[2])) + ([dc blueComponent] * blends[2]);
	a = ([sc alphaComponent] * (1.0 - blends[3])) + ([dc alphaComponent] * blends[3]);

	return [NSColor colorWithCalibratedRed:r
									 green:g
									  blue:b
									 alpha:a];
}

/** @brief Returns a colour by blending the receiver with <color> in hsb space
 @param color blend with this colour
 @param blendingAmounts an array of four values, each 0..1, specifies how components from each colour are
 @return blend of the two colours
 */
- (NSColor*)colorWithHSBBlendFrom:(NSColor*)color blendingAmounts:(CGFloat[])blends
{
	NSColor* sc = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor* dc = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

	CGFloat h, s, b, a;

	h = ([sc hueComponent] * (1.0 - blends[0])) + ([dc hueComponent] * blends[0]);
	s = ([sc saturationComponent] * (1.0 - blends[1])) + ([dc saturationComponent] * blends[1]);
	b = ([sc brightnessComponent] * (1.0 - blends[2])) + ([dc brightnessComponent] * blends[2]);
	a = ([sc alphaComponent] * (1.0 - blends[3])) + ([dc alphaComponent] * blends[3]);

	return [NSColor colorWithCalibratedHue:h
								saturation:s
								brightness:b
									 alpha:a];
}

#pragma mark -

/** @brief Returns the luminosity value of the receiver

 Luminosity of a colour is both subjective and dependent on the display characteristics of particular
 monitors, etc. A frequently used formula can be traced to experiments done by the NTSC television
 standards committee in 1953, which was based on tube phosphors in common use at that time. A more
 modern formula is applicable for LCD monitors. This method uses the NTSC formula if
 NTSC_1953_STANDARD is defined, otherwise the modern one.
 @return a value 0..1 that is the colour's luminosity
 */
- (CGFloat)luminosity
{
	NSColor* rgb = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

#ifdef NTSC_1953_STANDARD
	return [rgb redComponent] * 0.299 + [rgb greenComponent] * 0.587 + [rgb blueComponent] * 0.114;
#else
	return [rgb redComponent] * 0.212671 + [rgb greenComponent] * 0.715160 + [rgb blueComponent] * 0.072169;
#endif
}

/** @brief Returns a grey rgb colour having the same luminosity as the receiver
 @return a grey colour having the same luminosity
 */
- (NSColor*)colorWithLuminosity
{
	return [NSColor rgbGrey:[self luminosity]];
}

/** @brief Returns black or white to give best contrast with the receiver's colour
 @return black or white
 */
- (NSColor*)contrastingColor
{
	return [NSColor contrastingColor:self];
}

/** @brief Returns the colour with each colour component subtracted from 1

 The alpha value is not inverted
 @return the "inverse" of the receiver
 */
- (NSColor*)invertedColor
{
	NSColor* rgb = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

	CGFloat r, g, b;

	r = 1.0 - [rgb redComponent];
	g = 1.0 - [rgb greenComponent];
	b = 1.0 - [rgb blueComponent];

	return [NSColor colorWithCalibratedRed:r
									 green:g
									  blue:b
									 alpha:[rgb alphaComponent]];
}

/** @brief Returns a lighter colour based on a blend between the receiver and white

 The alpha value is unchanged
 @param amount a value 0.0..1.0, 0 returns the original colour, 1 returns white.
 @return a lightened version of the receiver
 */
- (NSColor*)lighterColorWithLevel:(CGFloat)amount
{
	NSColor* rgb = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	CGFloat bl[4];

	bl[0] = bl[1] = bl[2] = amount;
	bl[3] = 0.0;

	return [rgb colorWithRGBBlendFrom:[NSColor rgbWhite]
					  blendingAmounts:bl];
}

/** @brief Returns a darker colour based on a blend between the receiver and black

 The alpha value is unchanged
 @param amount a value 0.0..1.0, 0 returns the original colour, 1 returns black.
 @return a darkened version of the receiver
 */
- (NSColor*)darkerColorWithLevel:(CGFloat)amount
{
	NSColor* rgb = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	CGFloat bl[4];

	bl[0] = bl[1] = bl[2] = amount;
	bl[3] = 0.0;

	return [rgb colorWithRGBBlendFrom:[NSColor rgbBlack]
					  blendingAmounts:bl];
}

/** @brief Returns a colour by interpolating between the receiver and a second colour
 @param secondColour another colour
 @param interpValue a value between 0 and 1
 @return a colour that is intermediate between the receiver and secondColor, in RGB space
 */
- (NSColor*)interpolatedColorToColor:(NSColor*)secondColor atValue:(CGFloat)interpValue
{
	return [NSColor colorByInterpolatingFrom:self
										  to:secondColor
									 atValue:interpValue];
}

#pragma mark -

/** @brief Returns a standard web-formatted hexadecimal representation of the receiver's colour

 Format is '#000000' (black) to '#FFFFFF' (white)
 @return hexadecimal string
 */
- (NSString*)hexString
{
	NSColor* rgb = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

	CGFloat r, g, b, a;
	NSInteger hr, hb, hg;

	[rgb getRed:&r
		  green:&g
		   blue:&b
		  alpha:&a];

	hr = (NSInteger)floor(r * 255.0);
	hg = (NSInteger)floor(g * 255.0);
	hb = (NSInteger)floor(b * 255.0);

	NSString* s = [NSString stringWithFormat:@"#%02lX%02lX%02lX", (long)hr, (long)hg, (long)hb];

	return s;
}

#pragma mark -

/** @brief Returns a quartz CGColorRef corresponding to the receiver's colours

 Returned colour uses the generic RGB colour space, regardless of the receivers colourspace. Caller
 is responsible for releasing the colour ref when done.
 @return CGColorRef
 */
- (CGColorRef)newQuartzColor
{
	NSColor* deviceColor = [self colorUsingColorSpaceName:NSDeviceRGBColorSpace];

	CGFloat components[4];

	[deviceColor getRed:&components[0]
				  green:&components[1]
				   blue:&components[2]
				  alpha:&components[3]];

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGColorRef cgColor = CGColorCreate(colorSpace, components);
	CGColorSpaceRelease(colorSpace);

	return cgColor;
}

@end
