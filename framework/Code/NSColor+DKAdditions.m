///**********************************************************************************************************************************
///  NSColor+DKAdditions.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 26/03/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "NSColor+DKAdditions.h"

#import "LogEvent.h"


@implementation NSColor (DKAdditions)
#pragma mark As an NSColor
///*********************************************************************************************************************
///
/// method:			rgbWhite
/// scope:			public class method
/// overrides:		
/// description:	returns the colour white as an RGB Color
/// 
/// parameters:		none
/// result:			the colour white
///
/// notes:			uses the RGB Color space, not the greyscale Colorspace you get with NSColor's whiteColor
///					method.
///
///********************************************************************************************************************

+ (NSColor*)			rgbWhite
{
	return [self rgbGrey:1.0];
}


///*********************************************************************************************************************
///
/// method:			rgbBlack
/// scope:			public class method
/// overrides:		
/// description:	returns the colour black as an RGB Color
/// 
/// parameters:		none
/// result:			the colour black
///
/// notes:			uses the RGB Color space, not the greyscale Colorspace you get with NSColor's blackColor
///					method.
///
///********************************************************************************************************************

+ (NSColor*)			rgbBlack
{
	return [self rgbGrey:0.0];
}


///*********************************************************************************************************************
///
/// method:			rgbGrey:
/// scope:			public class method
/// overrides:		
/// description:	returns a grey RGB colour
/// 
/// parameters:		<grayscale> 0 to 1.0
/// result:			a grey colour
///
/// notes:			uses the RGB Color space, not the greyscale Colorspace you get with NSColor's grey
///					method. 
///
///********************************************************************************************************************

+ (NSColor*)			rgbGrey:(CGFloat) grayscale
{
	return [self rgbGrey:grayscale withAlpha:1.0];
}


///*********************************************************************************************************************
///
/// method:			rgbGrey:withAlpha:
/// scope:			public class method
/// overrides:		
/// description:	returns a grey RGB colour
/// 
/// parameters:		<grayscale> 0 to 1.0
///					<alpha> 0 to 1.0
/// result:			a grey colour with variable opacity
///
/// notes:			uses the RGB Color space, not the greyscale Colorspace you get with NSColor's grey
///					method.
///
///********************************************************************************************************************

+ (NSColor*)			rgbGrey:(CGFloat) grayscale withAlpha:(CGFloat) alpha
{
	return [self colorWithCalibratedRed:grayscale green:grayscale blue:grayscale alpha:alpha];
}


///*********************************************************************************************************************
///
/// method:			rgbGreyWithLuminosityFrom:withAlpha:
/// scope:			public class method
/// overrides:		
/// description:	returns a grey RGB colour with the same perceived brightness as the source colour
/// 
/// parameters:		<colour> any colour
///					<alpha> 0 to 1.0
/// result:			a grey colour in rgb space of equivalent luminosity
///
/// notes:			
///
///********************************************************************************************************************

+ (NSColor*)			rgbGreyWithLuminosityFrom:(NSColor*) colour withAlpha:(CGFloat) alpha
{
	return [self rgbGrey:[colour luminosity] withAlpha:alpha];
}


///*********************************************************************************************************************
///
/// method:			veryLightGrey
/// scope:			public class method
/// overrides:		
/// description:	a very light grey colour
/// 
/// parameters:		none
/// result:			a very light grey colour in rgb space
///
/// notes:			
///
///********************************************************************************************************************

+ (NSColor*)			veryLightGrey
{
	return [self rgbGrey:0.9];
}

#pragma mark -
///*********************************************************************************************************************
///
/// method:			contrastingColor
/// scope:			public class method
/// overrides:		
/// description:	returns black or white depending on input colour - dark colours give white, else black.
/// 
/// parameters:		none
/// result:			black or white
///
/// notes:			colour returned is in grayscale colour space
///
///********************************************************************************************************************

+ (NSColor*)			contrastingColor:(NSColor*) Color
{
	if ([Color luminosity] >= 0.5 )
		return [NSColor blackColor];
	else
		return [NSColor whiteColor];
}


///*********************************************************************************************************************
///
/// method:			colorWithWavelength:
/// scope:			public class method
/// overrides:		
/// description:	returns an RGB colour approximating the wavelength.
/// 
/// parameters:		<lambda> the wavelength in nanometres
/// result:			approximate rgb equivalent colour
///
/// notes:			lambda range outside 380 to 780 (nm) returns black
///
///********************************************************************************************************************

+ (NSColor*)			colorWithWavelength:(CGFloat) lambda
{
	CGFloat   gama = 0.8;
	NSInteger		wave;
	double  red = 0.0;
	double  green = 0.0;
	double  blue = 0.0;
	double  factor;
	
	wave = _CGFloatTrunc(lambda);
	
	if ( wave < 380 || wave > 780 )
		return [NSColor blackColor];
		
	if ( wave >= 380 && wave < 440 )
	{
		red = -(lambda - 440.0f)/(440.0f - 380.0f);
		green = 0.0;
		blue = 1.0;
	}
	else if ( wave >= 440 && wave < 490 )
	{
		red = 0.0;
		green = (lambda - 440.0f)/(490.0f - 440.0f);
		blue = 1.0;
	}
	else if ( wave > 490 && wave < 510 )
	{
		red = 0.0;
		green = 1.0;
		blue = -(lambda - 510.0f)/(510.0f - 490.0f);
	}
	else if ( wave >= 510 && wave < 580 )
	{
		red = (lambda - 510.0f)/(580.0f - 510.0f);
		green = 1.0;
		blue = 0.0;
	}
	else if ( wave >= 580 && wave < 645 )
	{
		red = 1.0;
		green = -(lambda - 645.0f)/(645.0f - 580.0f);
		blue = 0.0;
	}
	else if ( wave >= 645 && wave <= 780 )
	{
		red = 1.0;
		green = 0.0;
		blue = 0.0;
	}
	// Let the intensity fall off near the vision limits
 
	if ( wave >= 380 && wave < 420 )
		factor = 0.3 + 0.7 * (lambda - 380.0f) / (420.0f - 380.0f);
	else if ( wave >= 420 && wave < 700 )
		factor = 1.0;
	else if ( wave >= 700 && wave <= 780 )
		factor = 0.3 + 0.7 * (780.0f - lambda) / (780.0f - 700.0f);
	else
		factor = 0.0;
		
	// adjust rgb for gamma and factor:
	
	red		= powf( red * factor, gama );
	green   = powf( green * factor, gama );
	blue	= powf( blue * factor, gama );
	
	LogEvent_(kInfoEvent, @"red: %f, green: %f, blue: %f", red, green, blue );

	return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0];
}


///*********************************************************************************************************************
///
/// method:			colorWithHexString:
/// scope:			public class method
/// overrides:		
/// description:	returns an RGB colour corresponding to the standard-formatted HTML hexadecimal colour string.
/// 
/// parameters:		<hex> a string formatted '#RRGGBB'
/// result:			rgb equivalent colour
///
/// notes:			
///
///********************************************************************************************************************

+ (NSColor*)			colorWithHexString:(NSString*) hex
{
	if( hex == nil || [hex length] < 7 )
		return nil;
	
	CGFloat		rgb[3];
	const char* p = [[hex lowercaseString] cStringUsingEncoding:NSUTF8StringEncoding];
	NSColor*	c = nil;
	NSInteger	h, k = 0;
	char		v;
	
	if (*p++ == '#' && [hex length] >= 7 )
	{
		while( k < 3 && *p != 0 )
		{
			v = *p++;
			if ( v > '9' )
				h = (NSInteger)((v - 'a') + 10) * 16;
			else
				h = (NSInteger)v * 16;
				
			v = *p++;
			if ( v > '9' )
				h += (NSInteger)(v - 'a') + 10;
			else
				h += (NSInteger)v;
			
			rgb[k++] = (CGFloat)h / 255.0f;
		}
	
		c = [NSColor colorWithCalibratedRed:rgb[0] green:rgb[1] blue:rgb[2] alpha:1.0];
	}
	
	return c;
}


///*********************************************************************************************************************
///
/// method:			colorByInterpolatingFrom:to:atValue:
/// scope:			public class method
/// overrides:		
/// description:	returns a colour by interpolating between two colours
/// 
/// parameters:		<startColor> a colour
///					<endColor> a second colour
///					<interpValue> a value between 0 and 1
/// result:			a colour that is intermediate between startColor and endColor, in RGB space
///
/// notes:			
///
///********************************************************************************************************************

+ (NSColor*)			colorByInterpolatingFrom:(NSColor*) startColor to:(NSColor*) endColor atValue:(CGFloat) interpValue
{
	// returns an RGB color that interpolates between <start> and <end> given a value from 0..1.
	
	NSColor* rgb1 = [startColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor* rgb2 = [endColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	if( interpValue <= 0.0 )
		return rgb1;
	else if ( interpValue >= 1.0 )
		return rgb2;
	else
	{
		CGFloat r, g, b, a;
		
		r = ([rgb2 redComponent] * interpValue) + ([rgb1 redComponent] * (1.0 - interpValue));
		g = ([rgb2 greenComponent] * interpValue) + ([rgb1 greenComponent] * (1.0 - interpValue));
		b = ([rgb2 blueComponent] * interpValue) + ([rgb1 blueComponent] * (1.0 - interpValue));
		a = ([rgb2 alphaComponent] * interpValue) + ([rgb1 alphaComponent] * (1.0 - interpValue));
		
		return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a];
	}
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			colorWithHueFrom:
/// scope:			public instance method
/// overrides:		
/// description:	returns a copy ofthe receiver but substituting the hue from the given colour.
/// 
/// parameters:		<color> donates hue
/// result:			a colour with the hue of <color> but the receiver's saturation and brightness
///
/// notes:			if the receiver is black or white or otherwise fully unsaturated, colourization may not produce visible
///					results. Input colours must be in RGB colour space
///
///********************************************************************************************************************

- (NSColor*)			colorWithHueFrom:(NSColor*) color
{
	return [NSColor colorWithCalibratedHue:[color hueComponent] saturation:[self saturationComponent] brightness:[self brightnessComponent] alpha:[self alphaComponent]];
}


///*********************************************************************************************************************
///
/// method:			colorWithHueAndSaturationFrom:
/// scope:			public instance method
/// overrides:		
/// description:	returns a copy ofthe receiver but substituting the hue and saturation from the given colour.
/// 
/// parameters:		<color> donates hue and saturation
/// result:			a colour with the hue, sat of <color> but the receiver's brightness
///
/// notes:			Input colours must be in RGB colour space
///
///********************************************************************************************************************

- (NSColor*)			colorWithHueAndSaturationFrom:(NSColor*) color
{
	return [NSColor colorWithCalibratedHue:[color hueComponent] saturation:[color saturationComponent] brightness:[self brightnessComponent] alpha:[self alphaComponent]];
}


///*********************************************************************************************************************
///
/// method:			colorWithRGBAverageFrom:
/// scope:			public instance method
/// overrides:		
/// description:	returns a colour by averaging the receiver with <color> in rgb space
/// 
/// parameters:		<color> average with this colour
/// result:			average of the two colours
///
/// notes:			Input colours must be in RGB colour space
///
///********************************************************************************************************************

- (NSColor*)			colorWithRGBAverageFrom:(NSColor*) color
{
	CGFloat ba[4] = {0.5, 0.5, 0.5, 0.5};
	
	return [self colorWithRGBBlendFrom:color blendingAmounts:ba];
}


///*********************************************************************************************************************
///
/// method:			colorWithHSBAverageFrom:
/// scope:			public instance method
/// overrides:		
/// description:	returns a colour by averaging the receiver with <color> in hsb space
/// 
/// parameters:		<color> average with this colour
/// result:			average of the two colours
///
/// notes:			Input colours must be in RGB colour space
///
///********************************************************************************************************************

- (NSColor*)			colorWithHSBAverageFrom:(NSColor*) color
{
	CGFloat ba[4] = {0.5, 0.5, 0.5, 0.5};
	
	return [self colorWithHSBBlendFrom:color blendingAmounts:ba];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			colorWithRGBBlendFrom:blendingAmounts:
/// scope:			public instance method
/// overrides:		
/// description:	returns a colour by blending the receiver with <color> in rgb space
/// 
/// parameters:		<color> blend with this colour
///					<blendingAmounts> an array of four values, each 0..1, specifies how components from each colour are
///					blended
/// result:			blend of the two colours
///
/// notes:			
///
///********************************************************************************************************************

- (NSColor*)			colorWithRGBBlendFrom:(NSColor*) color blendingAmounts:(CGFloat[]) blends
{
	NSColor* sc = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor* dc = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	CGFloat r, g, b, a;
	
	r = ([sc redComponent] * ( 1.0 - blends[0])) + ([dc redComponent] * blends[0]);
	g = ([sc greenComponent] * ( 1.0 - blends[1])) + ([dc greenComponent] * blends[1]);
	b = ([sc blueComponent] * ( 1.0 - blends[2])) + ([dc blueComponent] * blends[2]);
	a = ([sc alphaComponent] * ( 1.0 - blends[3])) + ([dc alphaComponent] * blends[3]);
	
	return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a];
}


///*********************************************************************************************************************
///
/// method:			colorWithHSBBlendFrom:blendingAmounts:
/// scope:			public instance method
/// overrides:		
/// description:	returns a colour by blending the receiver with <color> in hsb space
/// 
/// parameters:		<color> blend with this colour
///					<blendingAmounts> an array of four values, each 0..1, specifies how components from each colour are
///					blended
/// result:			blend of the two colours
///
/// notes:			
///
///********************************************************************************************************************

- (NSColor*)			colorWithHSBBlendFrom:(NSColor*) color blendingAmounts:(CGFloat[]) blends
{
	NSColor* sc = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSColor* dc = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

	CGFloat h, s, b, a;
	
	h = ([sc hueComponent] * ( 1.0 - blends[0])) + ([dc hueComponent] * blends[0]);
	s = ([sc saturationComponent] * ( 1.0 - blends[1])) + ([dc saturationComponent] * blends[1]);
	b = ([sc brightnessComponent] * ( 1.0 - blends[2])) + ([dc brightnessComponent] * blends[2]);
	a = ([sc alphaComponent] * ( 1.0 - blends[3])) + ([dc alphaComponent] * blends[3]);
	
	return [NSColor colorWithCalibratedHue:h saturation:s brightness:b alpha:a];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			luminosity
/// scope:			public instance method
/// overrides:		
/// description:	returns the luminosity value of the receiver
/// 
/// parameters:		none
/// result:			a value 0..1 that is the colour's luminosity
///
/// notes:			luminosity of a colour is both subjective and dependent on the display characteristics of particular
///					monitors, etc. A frequently used formula can be traced to experiments done by the NTSC television
///					standards committee in 1953, which was based on tube phosphors in common use at that time. A more
///					modern formula is applicable for LCD monitors. This method uses the NTSC formula if
///					NTSC_1953_STANDARD is defined, otherwise the modern one.
///
///********************************************************************************************************************

- (CGFloat)				luminosity
{
	NSColor* rgb = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];

#ifdef NTSC_1953_STANDARD
	return [rgb redComponent] * 0.299 + [rgb greenComponent] * 0.587 + [rgb blueComponent] * 0.114;
#else
	return [rgb redComponent] * 0.212671 + [rgb greenComponent] * 0.715160 + [rgb blueComponent] * 0.072169;
#endif
}


///*********************************************************************************************************************
///
/// method:			colorWithLuminosity:
/// scope:			public instance method
/// overrides:		
/// description:	returns a grey rgb colour having the same luminosity as the receiver
/// 
/// parameters:		none
/// result:			a grey colour having the same luminosity
///
/// notes:			
///
///********************************************************************************************************************

- (NSColor*)			colorWithLuminosity
{
	return [NSColor rgbGrey:[self luminosity]];
}


///*********************************************************************************************************************
///
/// method:			contrastingColor
/// scope:			public instance method
/// overrides:		
/// description:	returns black or white to give best contrast with the receiver's colour
/// 
/// parameters:		none
/// result:			black or white
///
/// notes:			
///
///********************************************************************************************************************

- (NSColor*)			contrastingColor
{
	return [NSColor contrastingColor:self];
}


///*********************************************************************************************************************
///
/// method:			invertedColor
/// scope:			public instance method
/// overrides:		
/// description:	returns the colour with each colour component subtracted from 1
/// 
/// parameters:		none
/// result:			the "inverse" of the receiver
///
/// notes:			the alpha value is not inverted
///
///********************************************************************************************************************

- (NSColor*)			invertedColor
{
	NSColor* rgb = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	CGFloat r, g, b;
	
	r = 1.0 - [rgb redComponent];
	g = 1.0 - [rgb greenComponent];
	b = 1.0 - [rgb blueComponent];
	
	return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:[rgb alphaComponent]];
}


///*********************************************************************************************************************
///
/// method:			lighterColorWithLevel:
/// scope:			public instance method
/// overrides:		
/// description:	returns a lighter colour based on a blend between the receiver and white
/// 
/// parameters:		<amount> a value 0.0..1.0, 0 returns the original colour, 1 returns white.
/// result:			a lightened version of the receiver
///
/// notes:			the alpha value is unchanged
///
///********************************************************************************************************************

- (NSColor*)			lighterColorWithLevel:(CGFloat) amount
{
	NSColor* rgb = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	CGFloat	 bl[4];
	
	bl[0] = bl[1] = bl[2] = amount;
	bl[3] = 0.0;
	
	return [rgb colorWithRGBBlendFrom:[NSColor rgbWhite] blendingAmounts:bl]; 
}


///*********************************************************************************************************************
///
/// method:			darkerColorWithLevel:
/// scope:			public instance method
/// overrides:		
/// description:	returns a darker colour based on a blend between the receiver and black
/// 
/// parameters:		<amount> a value 0.0..1.0, 0 returns the original colour, 1 returns black.
/// result:			a darkened version of the receiver
///
/// notes:			the alpha value is unchanged
///
///********************************************************************************************************************

- (NSColor*)			darkerColorWithLevel:(CGFloat) amount
{
	NSColor* rgb = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	CGFloat	 bl[4];
	
	bl[0] = bl[1] = bl[2] = amount;
	bl[3] = 0.0;
	
	return [rgb colorWithRGBBlendFrom:[NSColor rgbBlack] blendingAmounts:bl]; 
}


///*********************************************************************************************************************
///
/// method:			interpolatedColorToColor:atValue:
/// scope:			public instance method
/// overrides:		
/// description:	returns a colour by interpolating between the receiver and a second colour
/// 
/// parameters:		<secondColour> another colour
///					<interpValue> a value between 0 and 1
/// result:			a colour that is intermediate between the receiver and secondColor, in RGB space
///
/// notes:			
///
///********************************************************************************************************************

- (NSColor*)			interpolatedColorToColor:(NSColor*) secondColor atValue:(CGFloat) interpValue;
{
	return [NSColor colorByInterpolatingFrom:self to:secondColor atValue:interpValue];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			hexString
/// scope:			public instance method
/// overrides:		
/// description:	returns a standard web-formatted hexadecimal representation of the receiver's colour
/// 
/// parameters:		none
/// result:			hexadecimal string
///
/// notes:			format is '#000000' (black) to '#FFFFFF' (white)
///
///********************************************************************************************************************

- (NSString*)			hexString
{
	NSColor* rgb = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	CGFloat	r, g, b, a;
	NSInteger		hr, hb, hg;
	
	[rgb getRed:&r green:&g blue:&b alpha:&a];
	
	hr = (NSInteger) floor( r * 255.0f );
	hg = (NSInteger) floor( g * 255.0f );
	hb = (NSInteger) floor( b * 255.0f );
	
	NSString* s = [NSString stringWithFormat:@"#%02X%02X%02X", hr, hg, hb ];

	return s;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			quartzColor
/// scope:			public instance method
/// overrides:		
/// description:	returns a quartz CGColorRef corresponding to the receiver's colours
/// 
/// parameters:		none
/// result:			CGColorRef
///
/// notes:			returned colour uses the generic RGB colour space, regardless of the receivers colourspace. Caller
///					is responsible for releasing the colour ref when done.
///
///********************************************************************************************************************

- (CGColorRef)			newQuartzColor
{
    NSColor* deviceColor = [self colorUsingColorSpaceName:NSDeviceRGBColorSpace];
   
    CGFloat components[4];
	
	[deviceColor getRed:&components[0] green:&components[1] blue:&components[2] alpha:&components[3]];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGColorRef cgColor = CGColorCreate(colorSpace, components);
    CGColorSpaceRelease(colorSpace);

    return cgColor;
}


@end


