//
//  DKGradient+UISupport.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 26/03/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKGradient+UISupport.h"

static void		glossInterpolation(void *info, const CGFloat *input, CGFloat *output);
static CGFloat	perceptualGlossFractionForColor(CGFloat *inputComponents);
static void		perceptualCausticColorForColor(CGFloat *inputComponents, CGFloat *outputComponents);


@implementation DKGradient (UISupport)


+ (DKGradient*)		aquaSelectedGradient
{
	DKGradient* grad = [[DKGradient alloc] init];
	
	[grad addColor:[NSColor colorWithCalibratedRed:0.58 green:0.86 blue:0.98 alpha:1.00] at:0.0];
	[grad addColor:[NSColor colorWithCalibratedRed:0.42 green:0.68 blue:0.90 alpha:1.00] at:11.5/23];
	[grad addColor:[NSColor colorWithCalibratedRed:0.64 green:0.80 blue:0.94 alpha:1.00] at:11.5/23];
	[grad addColor:[NSColor colorWithCalibratedRed:0.56 green:0.70 blue:0.90 alpha:1.00] at:1.0];
	[grad setAngleInDegrees:90];
	
	return [grad autorelease];
}


+ (DKGradient*)		aquaNormalGradient
{
	DKGradient* grad = [[DKGradient alloc] init];
	
	[grad addColor:[NSColor colorWithCalibratedRed:0.95 green:0.95 blue:0.95 alpha:1.00] at:0.0];
	[grad addColor:[NSColor colorWithCalibratedRed:0.83 green:0.83 blue:0.83 alpha:1.00] at:11.5/23];
	[grad addColor:[NSColor colorWithCalibratedRed:0.95 green:0.95 blue:0.95 alpha:1.00] at:11.5/23];
	[grad addColor:[NSColor colorWithCalibratedRed:0.92 green:0.92 blue:0.92 alpha:1.00] at:1.0];
	[grad setAngleInDegrees:90];
	
	return [grad autorelease];
}


+ (DKGradient*)		aquaPressedGradient
{
	DKGradient* grad = [[DKGradient alloc] init];
	
	[grad addColor:[NSColor colorWithCalibratedRed:0.80 green:0.80 blue:0.80 alpha:1.00] at:0.0];
	[grad addColor:[NSColor colorWithCalibratedRed:0.64 green:0.64 blue:0.64 alpha:1.00] at:11.5/23];
	[grad addColor:[NSColor colorWithCalibratedRed:0.80 green:0.80 blue:0.80 alpha:1.00] at:11.5/23];
	[grad addColor:[NSColor colorWithCalibratedRed:0.77 green:0.77 blue:0.77 alpha:1.00] at:1.0];	
	[grad setAngleInDegrees:90];
	
	return [grad autorelease];
}


+ (DKGradient*)		unifiedSelectedGradient
{
	DKGradient* grad = [[DKGradient alloc] init];
	
	[grad addColor:[NSColor colorWithCalibratedRed:0.85 green:0.85 blue:0.85 alpha:1.00] at:0.0];
	[grad addColor:[NSColor colorWithCalibratedRed:0.95 green:0.95 blue:0.95 alpha:1.00] at:1.0];	
	[grad setAngleInDegrees:90];
	
	return [grad autorelease];
}


+ (DKGradient*)		unifiedNormalGradient
{
	DKGradient* grad = [[DKGradient alloc] init];
	
	[grad addColor:[NSColor colorWithCalibratedRed:0.75 green:0.75 blue:0.75 alpha:1.00] at:0.0];
	[grad addColor:[NSColor colorWithCalibratedRed:0.90 green:0.90 blue:0.90 alpha:1.00] at:1.0];	
	[grad setAngleInDegrees:90];
	
	return [grad autorelease];
}


+ (DKGradient*)		unifiedPressedGradient
{
	DKGradient* grad = [[DKGradient alloc] init];
	
	[grad addColor:[NSColor colorWithCalibratedRed:0.60 green:0.60 blue:0.60 alpha:1.00] at:0.0];	
	[grad addColor:[NSColor colorWithCalibratedRed:0.75 green:0.75 blue:0.75 alpha:1.00] at:1.0];
	[grad setAngleInDegrees:90];
	
	return [grad autorelease];
}

+ (DKGradient*)		unifiedDarkGradient
{
	DKGradient* grad = [[DKGradient alloc] init];
	
	[grad addColor:[NSColor colorWithCalibratedRed:0.68 green:0.68 blue:0.68 alpha:1.00] at:0.0];	
	[grad addColor:[NSColor colorWithCalibratedRed:0.83 green:0.83 blue:0.83 alpha:1.00] at:1.0];
	[grad setAngleInDegrees:90];
	
	return [grad autorelease];
}


+ (DKGradient*)		sourceListSelectedGradient
{
	DKGradient* grad = [[DKGradient alloc] init];
	[grad addColor:[NSColor colorWithCalibratedRed:0.06 green:0.37 blue:0.85 alpha:1.00] at:0.0];	
	[grad addColor:[NSColor colorWithCalibratedRed:0.30 green:0.60 blue:0.92 alpha:1.00] at:1.0];
	[grad setAngleInDegrees:90];

	return [grad autorelease];
}

+ (DKGradient*)		sourceListUnselectedGradient
{
	DKGradient* grad = [[DKGradient alloc] init];
	
	[grad addColor:[NSColor colorWithCalibratedRed:0.43 green:0.43 blue:0.43 alpha:1.00] at:0.0];	
	[grad addColor:[NSColor colorWithCalibratedRed:0.60 green:0.60 blue:0.60 alpha:1.00] at:1.0];
	[grad setAngleInDegrees:90];
	
	return [grad autorelease];
}


+ (void)				drawShinyGradientInRect:(NSRect) inRect withColour:(NSColor*) colour
{
	// convenient method to create a shiny effect for button backgrounds, etc. This is closely based on the code my Matt Gallagher
	// http://cocoawithlove.com/2008/09/drawing-gloss-gradients-in-coregraphics.html whose work is fully acknowledged.
	
	NSAssert( colour != nil, @"can't draw shiny gradient for nil colour");
	
	const CGFloat EXP_COEFFICIENT = 1.2;
    const CGFloat REFLECTION_MAX = 0.60;
    const CGFloat REFLECTION_MIN = 0.20;
    
    GlossParameters params;
    
    params.expCoefficient = EXP_COEFFICIENT;
    params.expOffset = _CGFloatExp(-params.expCoefficient);
    params.expScale = 1.0 / (1.0 - params.expOffset);
	
    NSColor *source = [colour colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    [source getComponents:params.color];
    if ([source numberOfComponents] == 3)
    {
        params.color[3] = 1.0;
    }
	
	//NSLog(@"source colour %@", source );
    
    perceptualCausticColorForColor( params.color, params.caustic );
    
    CGFloat glossScale = perceptualGlossFractionForColor( params.color );
	
    params.initialWhite = glossScale * REFLECTION_MAX;
    params.finalWhite = glossScale * REFLECTION_MIN;
	
    static const CGFloat input_value_range[2] = {0, 1};
    static const CGFloat output_value_ranges[8] = {0, 1, 0, 1, 0, 1, 0, 1};
    CGFunctionCallbacks callbacks = {0, glossInterpolation, NULL};
    
    CGFunctionRef gradientFunction = CGFunctionCreate((void *)&params,
													  1, // number of input values to the callback
													  input_value_range,
													  4, // number of components (r, g, b, a)
													  output_value_ranges,
													  &callbacks);
    
    CGPoint startPoint; 
    CGPoint endPoint; 
	
	if([[NSGraphicsContext currentContext] isFlipped])
	{
		startPoint = CGPointMake(NSMinX(inRect), NSMinY(inRect));
		endPoint = CGPointMake(NSMinX(inRect), NSMaxY(inRect));
	}
	else
	{
		startPoint = CGPointMake(NSMinX(inRect), NSMaxY(inRect));
		endPoint = CGPointMake(NSMinX(inRect), NSMinY(inRect));
	}
	
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGShadingRef shading = CGShadingCreateAxial(colorspace, startPoint,
												endPoint, gradientFunction, FALSE, FALSE);
	
	CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
    
    CGContextSaveGState(context);
	CGContextSetBlendMode(context,kCGBlendModeNormal);
    CGContextClipToRect(context, NSRectToCGRect(inRect));
	CGContextSetAlpha(context, 1.0);
    CGContextDrawShading(context, shading);
    CGContextRestoreGState(context);
    
    CGShadingRelease(shading);
    CGColorSpaceRelease(colorspace);
    CGFunctionRelease(gradientFunction);
}


@end




static void glossInterpolation(void *info, const CGFloat *input, CGFloat *output)
{
    GlossParameters *params = (GlossParameters *)info;
	
    CGFloat progress = *input;
    if (progress < 0.5)
    {
        progress = progress * 2.0;
        progress = 1.0 - params->expScale * (_CGFloatExp(progress * -params->expCoefficient) - params->expOffset);
		
        CGFloat currentWhite = progress * (params->finalWhite - params->initialWhite) + params->initialWhite;
        
        output[0] = params->color[0] * (1.0 - currentWhite) + currentWhite;
        output[1] = params->color[1] * (1.0 - currentWhite) + currentWhite;
        output[2] = params->color[2] * (1.0 - currentWhite) + currentWhite;
        output[3] = params->color[3] * (1.0 - currentWhite) + currentWhite;
    }
    else
    {
        progress = (progress - 0.5) * 2.0;
		
        progress = params->expScale *
		(_CGFloatExp((1.0 - progress) * -params->expCoefficient) - params->expOffset);
		
        output[0] = params->color[0] * (1.0 - progress) + params->caustic[0] * progress;
        output[1] = params->color[1] * (1.0 - progress) + params->caustic[1] * progress;
        output[2] = params->color[2] * (1.0 - progress) + params->caustic[2] * progress;
        output[3] = params->color[3] * (1.0 - progress) + params->caustic[3] * progress;
    }
}



static void perceptualCausticColorForColor(CGFloat *inputComponents, CGFloat *outputComponents)
{
    const CGFloat CAUSTIC_FRACTION = 0.6;
    const CGFloat COSINE_ANGLE_SCALE = 1.4;
    const CGFloat MIN_RED_THRESHOLD = 0.95;
    const CGFloat MAX_BLUE_THRESHOLD = 0.7;
    const CGFloat GRAYSCALE_CAUSTIC_SATURATION = 0.1;
    
    NSColor *source = [NSColor colorWithCalibratedRed:inputComponents[0] green:inputComponents[1] blue:inputComponents[2] alpha:inputComponents[3]];
	
    CGFloat hue, saturation, brightness, alpha;
    [source getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
	
    CGFloat targetHue, targetSaturation, targetBrightness;
    [[NSColor yellowColor] getHue:&targetHue saturation:&targetSaturation brightness:&targetBrightness alpha:&alpha];
    
    if (saturation < 1e-3)
    {
        hue = targetHue;
        saturation = GRAYSCALE_CAUSTIC_SATURATION;
    }
	
    if (hue > MIN_RED_THRESHOLD)
    {
        hue -= 1.0;
    }
    else if (hue > MAX_BLUE_THRESHOLD)
    {
        [[NSColor magentaColor] getHue:&targetHue saturation:&targetSaturation brightness:&targetBrightness alpha:&alpha];
    }
	
    CGFloat scaledCaustic = CAUSTIC_FRACTION * 0.5 * (1.0 + cos(COSINE_ANGLE_SCALE * M_PI * (hue - targetHue)));
	
    NSColor *targetColor = [NSColor  colorWithCalibratedHue:hue * (1.0 - scaledCaustic) + targetHue * scaledCaustic
										saturation:saturation
										brightness:brightness * (1.0 - scaledCaustic) + targetBrightness * scaledCaustic
										alpha:inputComponents[3]];
    [targetColor getComponents:outputComponents];
}


static CGFloat perceptualGlossFractionForColor(CGFloat *inputComponents)
{
    const CGFloat REFLECTION_SCALE_NUMBER = 0.2;
    const CGFloat NTSC_RED_FRACTION = 0.299;
    const CGFloat NTSC_GREEN_FRACTION = 0.587;
    const CGFloat NTSC_BLUE_FRACTION = 0.114;
	
    CGFloat glossScale = NTSC_RED_FRACTION * inputComponents[0] + NTSC_GREEN_FRACTION * inputComponents[1] + NTSC_BLUE_FRACTION * inputComponents[2];
    glossScale = powf(glossScale, REFLECTION_SCALE_NUMBER);
    return glossScale;
}


