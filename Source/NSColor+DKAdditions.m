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

+ (NSColor*)rgbWhite
{
	return [self rgbGrey:1.0];
}

+ (NSColor*)rgbBlack
{
	return [self rgbGrey:0.0];
}

+ (NSColor*)rgbGrey:(CGFloat)grayscale
{
	return [self rgbGrey:grayscale
			   withAlpha:1.0];
}

+ (NSColor*)rgbGrey:(CGFloat)grayscale withAlpha:(CGFloat)alpha
{
	return [self colorWithCalibratedRed:grayscale
								  green:grayscale
								   blue:grayscale
								  alpha:alpha];
}

+ (NSColor*)rgbGreyWithLuminosityFrom:(NSColor*)colour withAlpha:(CGFloat)alpha
{
	return [self rgbGrey:[colour luminosity]
			   withAlpha:alpha];
}

+ (NSColor*)veryLightGrey
{
	return [self rgbGrey:0.9];
}

#pragma mark -

+ (NSColor*)contrastingColor:(NSColor*)Color
{
	if ([Color luminosity] >= 0.5)
		return [NSColor blackColor];
	else
		return [NSColor whiteColor];
}

+ (NSColor*)colorWithWavelength:(CGFloat)lambda
{
	CGFloat gama = 0.8;
	NSInteger wave;
	double red = 0.0;
	double green = 0.0;
	double blue = 0.0;
	double factor;

	wave = trunc(lambda);

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

+ (NSColor*)colorWithHexString:(NSString*)hex
{
	if (hex == nil || [hex length] < 7)
		return nil;

	CGFloat rgb[3]={0};
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

- (NSColor*)colorWithHueFrom:(NSColor*)color
{
	return [NSColor colorWithCalibratedHue:[color hueComponent]
								saturation:[self saturationComponent]
								brightness:[self brightnessComponent]
									 alpha:[self alphaComponent]];
}

- (NSColor*)colorWithHueAndSaturationFrom:(NSColor*)color
{
	return [NSColor colorWithCalibratedHue:[color hueComponent]
								saturation:[color saturationComponent]
								brightness:[self brightnessComponent]
									 alpha:[self alphaComponent]];
}

- (NSColor*)colorWithRGBAverageFrom:(NSColor*)color
{
	CGFloat ba[4] = { 0.5, 0.5, 0.5, 0.5 };

	return [self colorWithRGBBlendFrom:color
					   blendingAmounts:ba];
}

- (NSColor*)colorWithHSBAverageFrom:(NSColor*)color
{
	CGFloat ba[4] = { 0.5, 0.5, 0.5, 0.5 };

	return [self colorWithHSBBlendFrom:color
					   blendingAmounts:ba];
}

#pragma mark -

- (NSColor*)colorWithRGBBlendFrom:(NSColor*)color blendingAmounts:(const CGFloat[])blends
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

- (NSColor*)colorWithHSBBlendFrom:(NSColor*)color blendingAmounts:(const CGFloat[])blends
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

- (CGFloat)luminosity
{
	NSColor* rgb = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

#ifdef NTSC_1953_STANDARD
	return [rgb redComponent] * 0.299 + [rgb greenComponent] * 0.587 + [rgb blueComponent] * 0.114;
#else
	return [rgb redComponent] * 0.212671 + [rgb greenComponent] * 0.715160 + [rgb blueComponent] * 0.072169;
#endif
}

- (NSColor*)colorWithLuminosity
{
	return [NSColor rgbGrey:[self luminosity]];
}

- (NSColor*)contrastingColor
{
	return [NSColor contrastingColor:self];
}

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

- (NSColor*)lighterColorWithLevel:(CGFloat)amount
{
	NSColor* rgb = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	CGFloat bl[4];

	bl[0] = bl[1] = bl[2] = amount;
	bl[3] = 0.0;

	return [rgb colorWithRGBBlendFrom:[NSColor rgbWhite]
					  blendingAmounts:bl];
}

- (NSColor*)darkerColorWithLevel:(CGFloat)amount
{
	NSColor* rgb = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	CGFloat bl[4];

	bl[0] = bl[1] = bl[2] = amount;
	bl[3] = 0.0;

	return [rgb colorWithRGBBlendFrom:[NSColor rgbBlack]
					  blendingAmounts:bl];
}

- (NSColor*)interpolatedColorToColor:(NSColor*)secondColor atValue:(CGFloat)interpValue
{
	return [NSColor colorByInterpolatingFrom:self
										  to:secondColor
									 atValue:interpValue];
}

#pragma mark -

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
