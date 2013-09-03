///**********************************************************************************************************************************
///  DKGradient.m
///  DrawKit
///
///  Created by graham on 2/03/05.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKGradient.h"

#import "DKDrawKitMacros.h"
#import "DKGradientExtensions.h"
#import "LogEvent.h"
#import "NSColor+DKAdditions.h"

#ifndef __STANDALONE__
#import "DKDrawableObject+Metadata.h"
#import "DKScriptingAdditions.h"
#import "NSObject+GraphicsAttributes.h"

#endif


#pragma mark Contants (Non-localized)
NSString*	kGCNotificationGradientWillAddColorStop		= @"kGCNotificationGradientWillAddColorStop";
NSString*	kGCNotificationGradientDidAddColorStop		= @"kGCNotificationGradientDidAddColorStop";
NSString*	kGCNotificationGradientWillRemoveColorStop	= @"kGCNotificationGradientWillRemoveColorStop";
NSString*	kGCNotificationGradientDidRemoveColorStop	= @"kGCNotificationGradientDidRemoveColorStop";
NSString*	kGCNotificationGradientWillChange			= @"kGCNotificationGradientWillChange";
NSString*	kGCNotificationGradientDidChange			= @"kGCNotificationGradientDidChange";


#pragma mark Static Vars


#pragma mark Function Declarations
static inline void  shaderCallback (void *info, const float *in, float *out);
static CGFunctionRef makeShaderFunction( DKGradient* object );
static int cmpColorStops (id lh, id rh, void *ctx);
static inline double		powerMap( double x, double y );
static inline double		sineMap( double x, double y );
static inline void			transformHSV_RGB(float *components);
static inline void			transformRGB_HSV(float *components);
static inline void			resolveHSV(float *color1, float *color2);


#pragma mark -
@interface DKColorStop (Private)

- (void)				setOwner:(DKGradient*) owner;
- (DKGradient*)			owner;

@end

#pragma mark -
@implementation DKGradient
#pragma mark As a DKGradient

#pragma mark - simple gradient convenience methods
///*********************************************************************************************************************
///
/// method:			defaultGradient
/// scope:			public class method
/// overrides:		
/// description:	returns an instance of the default gradient (simple linear black to white)
/// 
/// parameters:		none.
/// result:			autoreleased default gradient object
///
/// notes:			
///
///********************************************************************************************************************

+ (DKGradient*)			defaultGradient
{
	DKGradient* grad = [[DKGradient alloc] init];
	
	[grad addColor:[NSColor rgbBlack] at:0.0];	
	[grad addColor:[NSColor rgbWhite] at:1.0];
	
	return [grad autorelease];
}


///*********************************************************************************************************************
///
/// method:			gradientWithStartingColor:endingColor:
/// scope:			public class method
/// overrides:		
/// description:	returns a linear gradient from Color c1 to c2
/// 
/// parameters:		<c1> the starting Color
///					<c2> the ending Color
/// result:			gradient object
///
/// notes:			gradient is linear and draws left to right c1 --> c2
///
///********************************************************************************************************************

+ (DKGradient*)			gradientWithStartingColor:(NSColor*) c1 endingColor:(NSColor*) c2
{
	return [self gradientWithStartingColor:c1 endingColor:c2 type:kGCGradientTypeLinear angle:0.0];
}


///*********************************************************************************************************************
///
/// method:			gradientWithStartingColor:endingColor:type:angle:
/// scope:			public class method
/// overrides:		
/// description:	returns a gradient from Color c1 to c2 with given type and angle
/// 
/// parameters:		<c1> the starting Color
///					<c2> the ending Color
///					<type> the gradient's type (linear or radial, etc)
///					<degrees> angle in degrees
/// result:			gradient object
///
/// notes:			
///
///********************************************************************************************************************

+ (DKGradient*)			gradientWithStartingColor:(NSColor*) c1 endingColor:(NSColor*) c2 type:(int) gt angle:(float) degrees
{
	DKGradient* grad = [[DKGradient alloc] init];

	[grad addColor:c1 at:0.0];
	[grad addColor:c2 at:1.0];
	[grad setGradientType:gt];
	[grad setAngleInDegrees:degrees];
	
	return [grad autorelease];
}


#pragma mark -
#pragma mark - modified copies
///*********************************************************************************************************************
///
/// method:			gradientByColorizingWithColor:
/// scope:			public instance method
/// overrides:		
/// description:	creates a copy of the gradient but colorizies it by substituting the hue from <color>
/// 
/// parameters:		<color> donates its hue
/// result:			a new gradient, a copy of the receiver in every way except colourized by <color> 
///
/// notes:			
///
///********************************************************************************************************************

- (DKGradient*)			gradientByColorizingWithColor:(NSColor*) color
{
	DKGradient* copy = [self copy];
	
	NSColor*		rgb = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	NSEnumerator*	iter = [[copy colorStops] objectEnumerator];
	DKColorStop*	stop;
	
	while(( stop = [iter nextObject]))
		[stop setColor:[[stop color] colorWithHueAndSaturationFrom:rgb]];

	return [copy autorelease];
}


///*********************************************************************************************************************
///
/// method:			gradientWithAlpha:
/// scope:			public instance method
/// overrides:		
/// description:	creates a copy of the gradient but sets the alpha vealue of all stop colours to <alpha>
/// 
/// parameters:		<alpha> the desired alpha
/// result:			a new gradient, a copy of the receiver with requested alpha 
///
/// notes:			
///
///********************************************************************************************************************

- (DKGradient*)			gradientWithAlpha:(float) alpha
{
	DKGradient* copy = [self copy];
	
	NSEnumerator*	iter = [[copy colorStops] objectEnumerator];
	DKColorStop*	stop;
	
	while(( stop = [iter nextObject]))
		[stop setAlpha:alpha];

	return [copy autorelease];
}


#pragma mark -
#pragma mark - setting up the Color stops
///*********************************************************************************************************************
///
/// method:			addColor:at:
/// scope:			public method
/// overrides:		
/// description:	add a Color to the list of gradient Colors
/// 
/// parameters:		<Color> the Color to add
///					<pos> the position of the Color relative to the 0..1 interval representing the entire span
/// result:			the Colorstop object that was added
///
/// notes:			
///
///********************************************************************************************************************

- (DKColorStop*)			addColor:(NSColor*) Color at: (float) pos
{
	DKColorStop *stop = [[DKColorStop alloc] initWithColor:Color at:pos];
	[self addColorStop:stop];
	[stop release];
	return stop;
}


///*********************************************************************************************************************
///
/// method:			addColorStop:
/// scope:			public method
/// overrides:		
/// description:	add a Color stop to the list of gradient Colors
/// 
/// parameters:		<stop> the Colorstop to add
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)					addColorStop:(DKColorStop*) stop
{
	if (! [[self colorStops] containsObject:stop])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientWillAddColorStop object:self];
		[self insertObject:stop inColorStopsAtIndex:[m_colorStops count]];
		//[_colorStops addObject:stop];
		[stop setOwner:self];
		[self sortColorStops];
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientDidAddColorStop object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			removeLastColor
/// scope:			public method
/// overrides:		
/// description:	removes the last Color from he list of Colors
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeLastColor
{
	[self removeColorStop:[m_colorStops lastObject]];
}

///*********************************************************************************************************************
///
/// method:			removeColorStop:
/// scope:			public method
/// overrides:		
/// description:	removes a Color stop from the list of Colors
/// 
/// parameters:		<stop> the stop to remove
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeColorStop:(DKColorStop*) stop;
{
	if ([[self colorStops] containsObject:stop])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientWillRemoveColorStop object:self];
		unsigned int indx = [m_colorStops indexOfObject:stop];
		[self removeObjectFromColorStopsAtIndex:indx];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientDidRemoveColorStop object:self];
	}
}

///*********************************************************************************************************************
///
/// method:			removeAllColors
/// scope:			public method
/// overrides:		
/// description:	removes all Colors from the list of Colors
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeAllColors
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientWillRemoveColorStop object:self];
	[m_colorStops removeAllObjects];
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientDidRemoveColorStop object:self];
}


///*********************************************************************************************************************
///
/// method:			setColorStops
/// scope:			public method
/// overrides:		
/// description:	sets the list of Color stops in the gradient
/// 
/// parameters:		<stops> an array of DKColorStop objects
/// result:			none
///
/// notes:			a gradient needs a minimum of two Colors to be a gradient, but will function with one.
///
///********************************************************************************************************************

- (void)				setColorStops:(NSArray*) stops
{
//	LogEvent_(kStateEvent, @"setting colour stops, new = %@", stops );
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientWillAddColorStop object:self];
	[m_colorStops release];
	m_colorStops = [stops mutableCopy];
	
	// set the owner ref - no longer needed for unarchiving gradients - compat with older files
	
	[m_colorStops makeObjectsPerformSelector:@selector(setOwner:) withObject:self];

	[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientDidAddColorStop object:self];
}


///*********************************************************************************************************************
///
/// method:			colorStops
/// scope:			public method
/// overrides:		
/// description:	returns the list of Color stops in the gradient
/// 
/// parameters:		none
/// result:			the array of DKColorStop (color + position) objects in the gradient
///
/// notes:			a gradient needs a minimum of two Colors to be a gradient, but will function with one.
///
///********************************************************************************************************************

- (NSArray*)			colorStops
{
	return m_colorStops;
}


static int cmpColorStops (id lh, id rh, void *ctx)
{
	#pragma unused(ctx)
	
	float lp = [lh position];
	float rp = [rh position];
	if (lp < rp)
		return NSOrderedAscending;
	else if (lp > rp)
		return NSOrderedDescending;
	else
		return NSOrderedSame;
}

///*********************************************************************************************************************
///
/// method:			sortColorStops
/// scope:			public instance method
/// overrides:		
/// description:	sorts the Color stops into position order
/// 
/// parameters:		none
/// result:			none
///
/// notes:			stops are sorted in place
///
///********************************************************************************************************************

- (void)				sortColorStops
{	
	[m_colorStops sortUsingFunction:cmpColorStops context:NULL];
}


///*********************************************************************************************************************
///
/// method:			reverseColorStops
/// scope:			public instance method
/// overrides:		
/// description:	reverses the order of all the Color stops so "inverting" the gradient
/// 
/// parameters:		none
/// result:			none
///
/// notes:			stop positions are changed, but Colors are not touched
///
///********************************************************************************************************************

- (void)				reverseColorStops
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientWillChange object:self];
	NSEnumerator*	iter = [[self colorStops] objectEnumerator];
	DKColorStop*	stop;
	
	while(( stop = [iter nextObject]))
		[stop setPosition:1.0 - [stop position]];
		
	[self sortColorStops];
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientDidChange object:self];
}

#pragma mark -
#pragma mark - KVO compliant accessors
///*********************************************************************************************************************
///
/// method:			countOfColorStops
/// scope:			public method
/// overrides:		
/// description:	returns the number of Color stops in the gradient
/// 
/// parameters:		none
/// result:			an integer, the number of Colors used to compute the gradient
///
/// notes:			this also makes the stops array KVC compliant
///
///********************************************************************************************************************

- (unsigned int)		countOfColorStops
{
	return [m_colorStops count];
}


///*********************************************************************************************************************
///
/// method:			objectInColorStopsAtIndex:
/// scope:			public method
/// overrides:		
/// description:	returns the the indexed Color stop
/// 
/// parameters:		<ix> index number of the stop
/// result:			a Color stop
///
/// notes:			this also makes the stops array KVC compliant
///
///********************************************************************************************************************

- (DKColorStop*)		objectInColorStopsAtIndex:(unsigned int) ix
{
	return [m_colorStops objectAtIndex:ix];
}


- (void)				insertObject:(DKColorStop*) stop inColorStopsAtIndex:(unsigned int) ix
{
	if ( ix >= [m_colorStops count])
		[m_colorStops addObject:stop];
	else
		[m_colorStops insertObject:stop atIndex:ix];
}


- (void)				removeObjectFromColorStopsAtIndex:(unsigned int) ix
{
	[m_colorStops removeObjectAtIndex:ix];
}


#pragma mark -
#pragma mark - a variety of ways to fill a path
///*********************************************************************************************************************
///
/// method:			fillRect:
/// scope:			public method
/// overrides:		
/// description:	fills the rect using the gradient
/// 
/// parameters:		<rect> the rect to fill. 
/// result:			none
///
/// notes:			The fill will proceed as for a standard fill. A gradient that needs a starting point will assume
///					the centre of the rect as that point when using this method.
///
///********************************************************************************************************************

- (void)				fillRect:(NSRect) rect
{
	[self fillPath:[NSBezierPath bezierPathWithRect:rect]];
}


///*********************************************************************************************************************
///
/// method:			fillPath:
/// scope:			public method
/// overrides:		
/// description:	fills the path using the gradient
/// 
/// parameters:		<path> the bezier path to fill. 
/// result:			none
///
/// notes:			The fill will proceed as for a standard fill. A gradient that needs a starting point will assume
///					the centre of the path's bounds as that point when using this method.
///
///********************************************************************************************************************

- (void)				fillPath:(NSBezierPath*) path
{
	NSPoint cp;
	
	cp.x = NSMidX([path bounds]);
	cp.y = NSMidY([path bounds]);
	
	[self fillPath:path centreOffset:NSZeroPoint];
}


///*********************************************************************************************************************
///
/// method:			fillPath:centreOffset:
/// scope:			public method
/// overrides:		
/// description:	fills the path using the gradient
/// 
/// parameters:		<path> the bezier path to fill
///					<co> displacement from the centre for the start of a radial fill
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				fillPath:(NSBezierPath*) path centreOffset:(NSPoint) co
{
	NSRect pb = [path bounds];
	
	// calculate endpoints to take into account the set angle
	
	NSPoint		sp, ep;
	float		sr = 0.0;
	float		er = 0.0;
	float		r1, r2;
	
	ep.x = NSMidX( pb );
	ep.y = NSMidY( pb );
	
	//radius = hypotf( pb.size.width, pb.size.height ) / 3.0;
	r1 = pb.size.width / 2.0;
	r2 = pb.size.height / 2.0;
	
	if ( [self gradientType] == kGCGradientTypeLinear )
	{
		sp.x = ep.x - r1 * cosf([self angle]);
		sp.y = ep.y - r2 * sinf([self angle]);
		ep.x = ep.x + r1 * cosf([self angle]);
		ep.y = ep.y + r2 * sinf([self angle]);
	}
	else if([self gradientType] == kGCGradientTypeRadial && m_extensionData != nil )
	{
		// can try to get these points from extensions data
		
		sp = [self mapPoint:[self radialStartingPoint] toRect:pb];
		ep = [self mapPoint:[self radialEndingPoint] toRect:pb];
		sr = pb.size.width * [self radialStartingRadius];
		er = pb.size.width * [self radialEndingRadius];
	}
	else
	{
		sp.x = ep.x + co.x;
		sp.y = ep.y + co.y;
		sr = 0.0;
		er = hypotf( pb.size.width, pb.size.height ) / 3.0;
	}	

	[self fillPath:path startingAtPoint:sp startRadius:sr endingAtPoint:ep endRadius:er];
}


- (void)				private_colorAtValue:(float) val components:(float*) components randomAccess:(BOOL) ra
{
	// if <ra> is NO, this is optimised on the basis that it will be called from a loop with <val> going from 0 -> 1. In
	// that case sequential access to the stops can be assumed and so no lookup loop is required. For random access, where
	// <val> can be any value in or out of sequence, the lookup loop is required. If in doubt, pass YES.
	
	int						keys, k2;
	static DKColorStop*		key1 = nil;
	static DKColorStop*		key2 = nil;
	static NSColor*			kk1;
	static NSColor*			kk2;
	static float			k1pos, k2pos;
	static int				indx = 0;

	keys = CFArrayGetCount((CFArrayRef) m_colorStops );
	
	if ( keys < 2 )
		return;
	
	if ( ra )
	{
		// random access - need to find the right stop pair to use
		
		key1 = [[self colorStops] objectAtIndex:0];
		key2 = [[self colorStops] objectAtIndex:1];
		k2 = 1;
		
		while( k2 < ( keys - 1 ) && [key2 position] < val )
		{
			key1 = key2;
			key2 = [[self colorStops] objectAtIndex:++k2];
		}
		
		kk1 = [key1 color];
		kk2 = [key2 color];
		k1pos = [key1 position];
		k2pos = [key2 position];
	}
	else
	{
		// sequential access - can assume that the previous value of <val> already set up the right pair, so we just need
		// to see if it's crossed to the next stop position
		
		// first check we have intialised the starting stops:
		
		if ( key1 == nil || val <= 0.0 )
		{
			key1 = (DKColorStop*) CFArrayGetValueAtIndex((CFArrayRef) m_colorStops, 0 );// [_colorStops objectAtIndex:0];
			key2 = (DKColorStop*) CFArrayGetValueAtIndex((CFArrayRef) m_colorStops, 1 );// [_colorStops objectAtIndex:1];
			kk1 = [key1 color];
			kk2 = [key2 color];
			k1pos = [key1 position];
			k2pos = [key2 position];
			indx = 2;
		}
		
		// need to get next pair?
		
		if ( val > k2pos && indx < keys )
		{
			key1 = key2;
			kk1 = kk2;
			k1pos = k2pos;
			key2 = (DKColorStop*) CFArrayGetValueAtIndex((CFArrayRef) m_colorStops, indx++ );//[[self colorStops] objectAtIndex:index++];
			kk2 = [key2 color];
			k2pos = [key2 position];
		}
	}
	
	if ( val <= k1pos )	
	{
		[kk1 getRed:&components[0] green:&components[1] blue:&components[2] alpha:&components[3]];
	}		
	else if ( val >= k2pos )
	{	
		[kk2 getRed:&components[0] green:&components[1] blue:&components[2] alpha:&components[3]];
		
		if ( !ra && val >= 1.0 )
		{
			// reached the end - reset for next sequential run
			
			key1 = key2 = nil;
		}
	}
	else								
	{
		float p = ( val - k1pos )/( k2pos - k1pos );

		switch( m_interp )
		{
			default:
			case kGCGradientInterpLinear:
				break;
				
			case kGCGradientInterpQuadratic:
				p = powerMap( p, 2 );
				break;
				
			case kGCGradientInterpCubic:
				p = powerMap( p, 3 );
				break;
				
			case kGCGradientInterpSinus:
				p = sineMap( p, 1 );
				break;
				
			case kGCGradientInterpSinus2:
				p = sineMap( p, 2 );
				break;
		}
		
		if ( m_blending == kGCGradientRGBBlending )
		{
			// access the stop's precached components directly for best speed:
			
			float* ca;
			float* cb;
		
			ca = key1->components;
			cb = key2->components;
			
			components[0] = (cb[0] - ca[0]) * p + ca[0]; 
			components[1] = (cb[1] - ca[1]) * p + ca[1];
			components[2] = (cb[2] - ca[2]) * p + ca[2];
			components[3] = (cb[3] - ca[3]) * p + ca[3];
		}
		else if ( m_blending == kGCGradientHSBBlending )
		{
			// blend in HSV space - this method almost entirely lifted from Chad Weider (thanks!)

			float ca[4];
			float cb[4];
			[kk1 getRed:&ca[0] green:&ca[1] blue:&ca[2] alpha:&ca[3]];
			[kk2 getRed:&cb[0] green:&cb[1] blue:&cb[2] alpha:&cb[3]];
			
			transformRGB_HSV( ca );
			transformRGB_HSV( cb );
			resolveHSV( ca, cb );

			if(ca[0] > cb[0])   //if color1's hue is higher than color2's hue then 
				cb[0] += 360;	//	we need to move c2 one revolution around the wheel

			components[0] = (cb[0] - ca[0]) * p + ca[0]; 
			components[1] = (cb[1] - ca[1]) * p + ca[1];
			components[2] = (cb[2] - ca[2]) * p + ca[2];
			components[3] = (cb[3] - ca[3]) * p + ca[3];
			
			transformHSV_RGB( components );
		}
		else if ( m_blending == kGCGradientAlphaBlending )
		{
			float* ca;
			float* cb;
		
			ca = key1->components;
			cb = key2->components;
			
			components[3] = (cb[3] - ca[3]) * p + ca[3];
		}
	}
}

#define		qLogPerformanceMetrics		0

///*********************************************************************************************************************
///
/// method:			fillPath:startingAtPoint:startRadius:endingAtPoint:endRadius:
/// scope:			public method
/// overrides:		
/// description:	fills the path using the gradient between two given points
/// 
/// parameters:		<path> the bezier path to fill
///					<startingAtPoint> the point where the gradient begins
///					<startRadius> for radial fills, the radius of the start of the gradient
///					<endingAtPoint> the point where the gradient ends
///					<endRadius> for radial fills, the radius of the end of the gradient
/// result:			none
///
/// notes:			radii are ignored for linear gradients. Angle is ignored by this method, if you call it directly
///					(angle is used to calculate start and endpoints in other methods that call this)
///
///********************************************************************************************************************

- (void)				fillPath:(NSBezierPath*) path startingAtPoint:(NSPoint) sp startRadius:(float) sr endingAtPoint:(NSPoint) ep endRadius:(float) er
{
	if([path isEmpty] || [path bounds].size.width <= 0.0 || [path bounds].size.height <= 0.0)
		return;

#if qLogPerformanceMetrics
	static NSTimeInterval   total		= 0;
	static int				count		= 0;
	
	NSTimeInterval			average;
	NSTimeInterval			startTime;
	
	startTime = [NSDate timeIntervalSinceReferenceDate];
	++count;
#endif

	[NSGraphicsContext saveGraphicsState];
	[path addClip];
	
	CGContextRef	context = [[NSGraphicsContext currentContext] graphicsPort];
	[self fillContext:context startingAtPoint:sp startRadius:sr endingAtPoint:ep endRadius:er];
	[NSGraphicsContext restoreGraphicsState];

#if qLogPerformanceMetrics
	NSTimeInterval  elapsed = [NSDate timeIntervalSinceReferenceDate] - startTime;
	total += elapsed;
	average = total / count;
	
	LogEvent_(kInfoEvent, @"metrics: elapsed = %f, average = %f, count = %d", elapsed, average, count );
#endif
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			sharedGradientColorSpace
/// scope:			public class method
/// overrides:		
/// description:	returns the Color space used when rendering gradients
/// 
/// parameters:		none
/// result:			Colorspace used for gradients
///
/// notes:			normally this isn't of much interest to application programmers, but if you wanted to customise
///					the Colorspace used for rendering gradients, you could override this.
///
///********************************************************************************************************************

+ (CGColorSpaceRef)		sharedGradientColorSpace
{
	static CGColorSpaceRef sGradientColorSpace = nil;
	
	if ( sGradientColorSpace == nil )
	  #if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_4
		sGradientColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	  #else
		sGradientColorSpace = CGColorSpaceCreateDeviceRGB();
	  #endif
		
	return sGradientColorSpace;
}


///*********************************************************************************************************************
///
/// method:			makeLinearShaderForStartingPoint:endPoint:
/// scope:			protected internal method
/// overrides:		
/// description:	sets up the CGShader for doing a linear gradient fill
/// 
/// parameters:		<sp> the starting point of the fill
///					<ep> the ending point of the fill
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				makeLinearShaderForStartingPoint:(NSPoint) sp endPoint:(NSPoint) ep
{
	if ( m_shader != nil )
		CGShadingRelease( m_shader );
		
	m_shader = CGShadingCreateAxial([DKGradient sharedGradientColorSpace], *(CGPoint*) &sp, *(CGPoint*) &ep, m_cbfunc, YES, YES );
}


///*********************************************************************************************************************
///
/// method:			makeRadialShaderForStartingPoint:startRadius:endPoint:endRadius:
/// scope:			protected internal method
/// overrides:		
/// description:	sets up the CGShader for doing a radial gradient fill
/// 
/// parameters:		<sp> the starting point of the fill
///					<sr> the starting radius
///					<ep> the end point of the fill
///					<er> the ending radius
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				makeRadialShaderForStartingPoint:(NSPoint) sp startRadius:(float) sr endPoint:(NSPoint) ep endRadius:(float) er;
{
	if ( m_shader != nil )
		CGShadingRelease( m_shader );
		
	m_shader = CGShadingCreateRadial([DKGradient sharedGradientColorSpace], *(CGPoint*) &sp, sr, *(CGPoint*) &ep, er, m_cbfunc, YES, YES );
}


#pragma mark -
- (void)				fillContext:(CGContextRef) context startingAtPoint:(NSPoint) sp
								startRadius:(float) sr endingAtPoint:(NSPoint) ep endRadius:(float) er
{
	switch([self gradientType])
	{
		case kGCGradientTypeLinear:
			[self makeLinearShaderForStartingPoint:sp endPoint:ep];
			CGContextDrawShading( context, m_shader );
			break;
			
		case kGCGradientTypeRadial:
			[self makeRadialShaderForStartingPoint:sp startRadius:sr endPoint:ep endRadius:er];
			CGContextDrawShading( context, m_shader );
			break;
			
		default:
			break;
	}
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			colorAtValue:
/// scope:			public method
/// overrides:		
/// description:	returns the computed Color for the gradient ramp expressed as a value from 0 to 1.0
/// 
/// parameters:		<val> the proportion of the gradient ramp from start (0) to finish (1.0) 
/// result:			the Color corresponding to that position
///
/// notes:			while intended for internal use, this function can be called at any time if you wish
///					the private version here is called internally. It does fewer checks and returns raw component
///					values for performance. do not use from external code.
///
///********************************************************************************************************************

- (NSColor*)			colorAtValue:(float) val
{
	// public method to get colour at any point from 0->1 across the gradient. Note that this methiod allows arbitrary
	// (unordered) values of <val> and so is slower than the shader callback. It also creates a calibrated NSColor object
	// that also substantially reduces performance
	
	int keys = [self countOfColorStops];
	
	if ( keys < 2 )
	{
		// deal with case where gradient hasn't really been set up properly (0 or 1 Color stops)
		
		if ( keys == 0 )
			return [NSColor rgbGrey:0.5];
		else
			return [[[self colorStops] objectAtIndex:0] color];
	}
	else
	{
		if ( val < 1.0 )
		{
			float	components[4];
			
			[self private_colorAtValue:val components:components randomAccess:YES];
			return [NSColor colorWithCalibratedRed:components[0] green:components[1] blue:components[2] alpha:components[3]];
		}
		else
			return [[[self colorStops] lastObject] color];
	}
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setAngle
/// scope:			public method
/// overrides:		
/// description:	sets the gradient's current angle in radians
/// 
/// parameters:		<ang> the desired angle in radians
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setAngle:(float) ang
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientWillChange object:self];
	m_gradAngle = ang;
	[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientDidChange object:self];
}


///*********************************************************************************************************************
///
/// method:			angle
/// scope:			public method
/// overrides:		
/// description:	returns the gradient's current angle in radians
/// 
/// parameters:		none
/// result:			angle expressed in radians
///
/// notes:			
///
///********************************************************************************************************************

- (float)				angle
{
	return m_gradAngle;
}

///*********************************************************************************************************************
///
/// method:			setAngleInDegrees:
/// scope:			public method
/// overrides:		
/// description:	sets the angle of the gradient to the given angle
/// 
/// parameters:		<degrees> the desired angle expressed in degrees
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setAngleInDegrees:(float) degrees
{
	[self setAngle:(degrees * pi)/180.0f];
}


///*********************************************************************************************************************
///
/// method:			angleInDegrees
/// scope:			public method
/// overrides:		
/// description:	returns the gradient's current angle in degrees
/// 
/// parameters:		none
/// result:			angle expressed in degrees
///
/// notes:			
///
///********************************************************************************************************************

- (float)				angleInDegrees
{
	return fmodf(([self angle] * 180.0f )/ pi, 360.0 );
}


- (void)				setAngleWithoutNotifying:(float) ang
{
	m_gradAngle = ang;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setGradientType
/// scope:			public method
/// overrides:		
/// description:	sets the gradient's basic type
/// 
/// parameters:		<gt> the type
/// result:			none
///
/// notes:			valid types are: kGCGradientTypeLinear and kGCGradientTypeRadial
///
///********************************************************************************************************************

- (void)				setGradientType:(DKGradientType) gt
{
	if ( gt != m_gradType )
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientWillChange object:self];
		m_gradType = gt;
		
		// if setting to radial style, should set initial values of radius and starting points in the extended data
		
		if ( gt == kGCGradientTypeRadial && ![self hasRadialSettings])
		{
			[self setRadialStartingPoint:NSMakePoint( 0.5, 0.5 )];
			[self setRadialEndingPoint:NSMakePoint( 0.5, 0.5 )];
			[self setRadialStartingRadius:0.0];
			[self setRadialEndingRadius:0.5];
		}
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientDidChange object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			gradientType
/// scope:			public method
/// overrides:		
/// description:	returns the gradient's basic type
/// 
/// parameters:		none
/// result:			the gradient's current basic type
///
/// notes:			
///
///********************************************************************************************************************

- (DKGradientType)			gradientType
{
	return m_gradType;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setGradientBlending:
/// scope:			public method
/// overrides:		
/// description:	sets the blending mode for the gradient
/// 
/// parameters:		<bt> the blending mode
/// result:			none
///
/// notes:			valid types are: kGCGradientRGBBlending and kGCGradientHSBBlending
///
///********************************************************************************************************************

- (void)					setGradientBlending:(DKGradientBlending) bt
{
	if ( bt != m_blending )
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientWillChange object:self];
		m_blending = bt;
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientDidChange object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			gradientBlending
/// scope:			public method
/// overrides:		
/// description:	gets the blending mode for the gradient
/// 
/// parameters:		none
/// result:			the current blending mode
///
/// notes:			
///
///********************************************************************************************************************

- (DKGradientBlending)		gradientBlending
{
	return m_blending;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setGradientInterpolation:
/// scope:			public method
/// overrides:		
/// description:	sets the interpolation algorithm for the gradient
/// 
/// parameters:		<intrp> one of the standard interpolation constants
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)					setGradientInterpolation:(DKGradientInterpolation) intrp
{
	if ( intrp != m_interp )
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientWillChange object:self];
		m_interp = intrp;
		[[NSNotificationCenter defaultCenter] postNotificationName:kGCNotificationGradientDidChange object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			gradientInterpolation
/// scope:			public method
/// overrides:		
/// description:	returns the interpolation algorithm for the gradient
/// 
/// parameters:		none
/// result:			the current interpolation
///
/// notes:			
///
///********************************************************************************************************************

- (DKGradientInterpolation)	gradientInterpolation
{
	return m_interp;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			swatchImageWithSize:withBorder:
/// scope:			public method
/// overrides:		
/// description:	returns an image of the current gradient for use in a UI, etc.
/// 
/// parameters:		<size> the desired image size
///					<showBorder> YES to draw a border around the image, NO for no border
/// result:			an NSIMage containing the current gradient
///
/// notes:			
///
///********************************************************************************************************************

- (NSImage*)			swatchImageWithSize:(NSSize) size withBorder:(BOOL) showBorder
{
	NSImage *swatchImage = [[NSImage alloc] initWithSize:size];
	[swatchImage setFlipped:YES];
	NSRect box = NSMakeRect(0.0, 0.0, size.width, size.height);

	[swatchImage lockFocus];
	[self fillRect:box];
	
	if (showBorder)
	{
		[[NSColor grayColor] set];
		NSFrameRectWithWidth( box, 1.0 );
	}
	[swatchImage unlockFocus];
	
	return [swatchImage autorelease];
}


///*********************************************************************************************************************
///
/// method:			standardSwatchImage
/// scope:			public method
/// overrides:		
/// description:	returns an image of the current gradient for use in a UI, etc.
/// 
/// parameters:		none
/// result:			an NSImage containing the current gradient
///
/// notes:			swatch has standard size and a border
///
///********************************************************************************************************************

- (NSImage*) standardSwatchImage;
{
	return [self swatchImageWithSize:DKGradientSwatchSize withBorder:YES];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			styleScript
/// scope:			public method
/// overrides:		DKRasterizer
/// description:	returns a valid stylescript corresponding to this object's current state
/// 
/// parameters:		none
/// result:			a string, the style script that would reconstruct this object
///
/// notes:			
///
///********************************************************************************************************************

- (NSString*)			styleScript
{
	NSMutableString* s = [[NSMutableString alloc] init];
	
	[s setString:@"(gradient "];

	if ([self gradientType] == kGCGradientTypeRadial)
		[s appendString:@"gradientType:1 "];
		
	if ([self angleInDegrees] != 0.0 )
		[s appendString:[NSString stringWithFormat:@"angle: %1.2f ", [self angle]]];
		
	NSEnumerator* iter = [[self colorStops] objectEnumerator];
	DKColorStop*  stop;
	
	while(( stop = [iter nextObject]))
		[s appendString:[stop styleScript]];

	[s appendString:@")"];

	return [s autorelease];
}


#pragma mark -
- (void)				colorStopWillChangeColor:(DKColorStop*) stop
{
	#pragma unused(stop)
}


- (void)				colorStopDidChangeColor:(DKColorStop*) stop
{
	#pragma unused(stop)
	
//	LogEvent_(kStateEvent, @"stop changed color (%@)", stop);
}


- (void)				colorStopWillChangePosition:(DKColorStop*) stop
{
	#pragma unused(stop)
}


- (void)				colorStopDidChangePosition:(DKColorStop*) stop
{
	#pragma unused(stop)
	
//	LogEvent_(kStateEvent, @"stop changed position (%@)", stop);
}


#pragma mark -
#pragma mark As a GCObservableObject
///*********************************************************************************************************************
///
/// method:			setUpKVOForObserver:
/// scope:			public method
/// overrides:		GCObservableObject
/// description:	sets up KVO for handling undo when this object is used as part of a renderer tree
/// 
/// parameters:		<object> the nominated observer
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				setUpKVOForObserver:(id) object
{
	if([super setUpKVOForObserver:object])
	{
		[self addObserver:object forKeyPath:@"gradientType" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:nil];
		[self addObserver:object forKeyPath:@"angle" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:nil];
		[self addObserver:object forKeyPath:@"colorStops" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:nil];

		[self setActionName:@"Change Gradient Type" forKeyPath:@"gradientType"];
		[self setActionName:@"Change Gradient Angle" forKeyPath:@"angle"];
		[self setActionName:@"#kind# Gradient Stop" forKeyPath:@"colorStops"];
		
		// add the observer to any existing stops at this time.
		
		NSIndexSet* ix = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange( 0, [self countOfColorStops])];
		
		[[self colorStops] addObserver:object toObjectsAtIndexes:ix forKeyPath:@"color" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:nil];
		[[self colorStops] addObserver:object toObjectsAtIndexes:ix forKeyPath:@"position" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:nil];
		
		[GCObservableObject registerActionName:@"Change Gradient Stop Colour" forKeyPath:@"color" objClass:[DKColorStop class]];
		[GCObservableObject registerActionName:@"Move Gradient Stop Position" forKeyPath:@"position" objClass:[DKColorStop class]];
		return YES;
	}
	else
		return NO;
}


///*********************************************************************************************************************
///
/// method:			tearDownKVOForObserver:
/// scope:			public method
/// overrides:		GCObservableObject
/// description:	tears down KVO for handling undo when this object is used as part of a renderer tree
/// 
/// parameters:		<object> the nominated observer
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				tearDownKVOForObserver:(id) object
{
	if([super tearDownKVOForObserver:object])
	{
		[self removeObserver:object forKeyPath:@"gradientType"];
		[self removeObserver:object forKeyPath:@"angle"];
		[self removeObserver:object forKeyPath:@"colorStops"];
		
		NSIndexSet* ix = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange( 0, [self countOfColorStops])];

		[[self colorStops] removeObserver:object fromObjectsAtIndexes:ix forKeyPath:@"color"];
		[[self colorStops] removeObserver:object fromObjectsAtIndexes:ix forKeyPath:@"position"];
		
		return YES;
	}
	else
		return NO;
}


#pragma mark -
#pragma mark As an NSObject

- (void)				dealloc
{
	[self removeAllColors];
	[m_colorStops release];
	CGShadingRelease( m_shader );
	CGFunctionRelease( m_cbfunc );
	[m_extensionData release];
	[super dealloc];
}


- (id)					init
{
	self = [super init];
	if (self != nil)
	{
		m_colorStops = [[NSMutableArray alloc] init];
		NSAssert(m_extensionData == nil, @"Expected init to zero");
		
		// create the default shader stuff - the shader itself is made when
		// the fill function is called
		NSAssert(m_shader == nil, @"Expected init to zero");
		m_cbfunc = makeShaderFunction( self );
		
		NSAssert(m_gradAngle == 0.0, @"Expected init to zero");
		NSAssert(m_gradType == kGCGradientTypeLinear, @"Expected init to zero");
		NSAssert(m_blending == kGCGradientRGBBlending, @"Expected init to zero");
		NSAssert(m_interp == kGCGradientInterpLinear, @"Expected init to zero");

		if (m_colorStops == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


#pragma mark -
#pragma mark As part of GraphicsAttributes Protocol
///*********************************************************************************************************************
///
/// method:			setValue:forNumericParameter:
/// scope:			public method
/// overrides:		NSObject (GraphicsAttributes)
/// description:	adds Color stops from anonymous script parameters
/// 
/// parameters:		<val> a value object
///					<pnum> the index of the parameter
/// result:			none
///
/// notes:			supports style scripting for the gradient object
///
///********************************************************************************************************************

- (void)				setValue:(id) val forNumericParameter:(int) pnum
{
	#pragma unused(pnum)
	
	// supports the parser by assigning each anonymous Color stop. <val> will be a DKColorStop
	
	if([val isKindOfClass:[DKColorStop class]])
		[self addColorStop:val];
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)				encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[coder encodeObject:[self colorStops] forKey:@"gradientStops"];
	[coder encodeObject:m_extensionData forKey:@"extension_data"];
	
	[coder encodeFloat:m_gradAngle forKey:@"gradientAngle"];
	[coder encodeInt:m_gradType forKey:@"gradientType"];
	[coder encodeInt:[self gradientBlending] forKey:@"blending"];
	[coder encodeInt:[self gradientInterpolation] forKey:@"interpolation"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super init];
	if (self != nil)
	{
		[self setColorStops:[coder decodeObjectForKey:@"gradientStops"]];
		m_extensionData = [[coder decodeObjectForKey:@"extension_data"] mutableCopy];
		
		NSAssert(m_shader == nil, @"Expected init to zero");
		m_cbfunc = makeShaderFunction( self );

		m_gradAngle = [coder decodeFloatForKey:@"gradientAngle"];
		m_gradType = [coder decodeIntForKey:@"gradientType"];
		[self setGradientBlending:[coder decodeIntForKey:@"blending"]];
		[self setGradientInterpolation:[coder decodeIntForKey:@"interpolation"]];
		
		if (m_colorStops == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	if (self != nil)
	{
		[self convertOldKeys];
	}

	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)					copyWithZone:(NSZone*) zone
{
	#pragma unused(zone)
	
	DKGradient*	grad = [[[self class] alloc] init];
	grad->m_gradType = m_gradType;
	grad->m_gradAngle = m_gradAngle;
	grad->m_blending = m_blending;
	grad->m_interp = m_interp;
	
	[grad removeAllColors];
	NSEnumerator *curs = [[self colorStops] objectEnumerator];
	id  stop;
	id  stopCopy;
	
	while (( stop = [curs nextObject]))
	{
		stopCopy = [stop copy];
		[grad addColorStop:stopCopy];
		[stopCopy release];
	}
	
	grad->m_extensionData = [m_extensionData mutableCopy];

	return grad;
}


@end


#pragma mark -
@implementation DKColorStop : NSObject
#pragma mark As a DKColorStop
///*********************************************************************************************************************
///
/// method:			initWithColor:at:
/// scope:			public method
/// overrides:		
/// description:	initialise the stop with a Color and position
/// 
/// parameters:		<Color> the initial Color value
///					<pos> the relative position within the gradient, valid range = 0.0..1.0
/// result:			the stop
///
/// notes:			
///
///********************************************************************************************************************

- (id)					initWithColor:(NSColor*) Color at:(float) pos;
{
	self = [super init];
	if (self != nil)
	{
		[self setColor:Color];
		[self setPosition:pos];
		NSAssert(m_ownerRef == nil, @"Expected init to zero");
		
		if (mColor == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			color
/// scope:			public method
/// overrides:		
/// description:	returns the Color associated with this stop
/// 
/// parameters:		none
/// result:			a Color value
///
/// notes:			
///
///********************************************************************************************************************

- (NSColor*)			color
{
	return mColor;
}


///*********************************************************************************************************************
///
/// method:			setColor:
/// scope:			public method
/// overrides:		
/// description:	set the Color associated with this stop
/// 
/// parameters:		<Color> the Color to set
/// result:			none
///
/// notes:			Colors are converted to calibrated RGB to permit shading calculations
///
///********************************************************************************************************************

- (void)				setColor:(NSColor*) Color
{
	[[self owner] colorStopWillChangeColor:self];
	
	NSColor* rgb = [Color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	[rgb retain];
	[mColor release];
	mColor = rgb;
	
	// cache the components so that they can be rapidly accessed when plotting the shading
	
	[rgb getRed:&components[0] green:&components[1] blue:&components[2] alpha:&components[3]];
	[[self owner] colorStopDidChangeColor:self];
}


///*********************************************************************************************************************
///
/// method:			setAlpha:
/// scope:			public method
/// overrides:		
/// description:	set the alpha of the colour associated with this stop
/// 
/// parameters:		<alpha> the alpha to set
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setAlpha:(float) alpha
{
	[self setColor:[[self color] colorWithAlphaComponent:alpha]];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			position
/// scope:			public method
/// overrides:		
/// description:	get the stop's relative position
/// 
/// parameters:		none
/// result:			a value between 0 and 1
///
/// notes:			
///
///********************************************************************************************************************

- (float)				position
{
	return position;
}


///*********************************************************************************************************************
///
/// method:			setPosition:
/// scope:			public method
/// overrides:		
/// description:	set the stop's relative position
/// 
/// parameters:		<pos> a vlue between 0 and 1
/// result:			none
///
/// notes:			value is constrained between 0.0 and 1.0
///
///********************************************************************************************************************

- (void)		setPosition:(float) pos;
{
	[[self owner] colorStopWillChangePosition:self];
	position = LIMIT( pos, 0.0, 1.0 );
	[[self owner] colorStopDidChangePosition:self];
}


#pragma mark -
- (DKGradient*)			owner
{
	return m_ownerRef;
}


- (void)				setOwner:(DKGradient*) owner
{
	m_ownerRef = owner;
}


///*********************************************************************************************************************
///
/// method:			styleScript
/// scope:			public method
/// overrides:		
/// description:	return a script fragment for this object
/// 
/// parameters:		none
/// result:			a string
///
/// notes:			
///
///********************************************************************************************************************

- (NSString*)			styleScript
{
	return [NSString stringWithFormat:@"(stop %1.1f %@)", [self position], [[self color] styleScript]];
}


#pragma mark -
#pragma mark As an NSObject
- (void)				dealloc
{
	[mColor release];
	[super dealloc];
}
	

#pragma mark -
#pragma mark As part of GraphicsAttributes Protocol
///*********************************************************************************************************************
///
/// method:			setValue:forNumericParameter:
/// scope:			public method
/// overrides:		NSObject (GraphicsAtrributes)
/// description:	set up from anonymous parameters in script
/// 
/// parameters:		<val> the value
///					<pnum> parameter index
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setValue:(id) val forNumericParameter:(int) pnum
{
	// supports the parser by assigning param 0 -> position, param 1 -> Color
	
	if ( pnum == 0 )
		[self setPosition:[val floatValue]];
	else if ( pnum == 1 )
		[self setColor:val];
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)				encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[coder encodeObject:[self color] forKey:@"color"];
	[coder encodeFloat:[self position] forKey:@"position"];
	[coder encodeConditionalObject:[self owner] forKey:@"DKColorStop_owner"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super init];
	if (self != nil)
	{
		[self setColor:[coder decodeObjectForKey:@"color"]];
		[self setPosition:[coder decodeFloatForKey:@"position"]];
		[self setOwner:[coder decodeObjectForKey:@"DKColorStop_owner"]];
		
		if (mColor == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)					copyWithZone:(NSZone*) zone
{
	return [[DKColorStop allocWithZone:zone] initWithColor:[self color] at:[self position]];
}


@end






#pragma mark -

#define		qUseDirectComponents	1		// this makes a big difference - almost 5x faster
#define		qUseImpCaching			1		// this makes a tiny difference - just 4% faster

static inline void  shaderCallback (void *info, const float *in, float *out)
{
	// callback function simply vectors the callback to the object, which handles the actual work.
	
#if qUseDirectComponents

	// here we use a number of optimisation tricks to extract maximum performance - caching the function pointer
	// and using raw rgb components and not NSColors
#if qUseImpCaching	
	static void(*sfunc)( id, SEL, float, float*, BOOL ) = nil;
	static SEL ssel = nil;
	
	if ( sfunc == nil )
	{
		ssel = @selector( private_colorAtValue:components:randomAccess: );
		sfunc = (void(*)( id, SEL, float, float*, BOOL ))[DKGradient instanceMethodForSelector:ssel];
	}
	
	sfunc( info, ssel, *in, out, NO );
#else
	[(DKGradient*)info private_colorAtValue:*in components:out randomAccess:NO];
#endif
#else
	// ol' faithful - very slow but sure.
	
	DKGradient*	gradient = (DKGradient*) info;
	NSColor* Color = [gradient colorAtValue:*in];
	
	out[0] = [Color redComponent];
	out[1] = [Color greenComponent];
	out[2] = [Color blueComponent];
	out[3] = [Color alphaComponent];
#endif
}


static CGFunctionRef makeShaderFunction( DKGradient* object ) 
{
    static const float input_value_range [2] = { 0, 1 };
    static const float output_value_ranges [8] = { 0, 1, 0, 1, 0, 1, 0, 1 };
    static const CGFunctionCallbacks callbacks = { 0,  &shaderCallback, NULL };

    return CGFunctionCreate ((void *) object, 1, input_value_range, 4, output_value_ranges, &callbacks); 
}


static inline double		powerMap( double x, double y )
{
	if ( y == 0.0 )
		y = 1.0;
		
	if ( y < 0 )
		return 1.0 - pow( 1.0 - x, -y );
	else
		return pow( x, y );
}


static inline double		sineMap( double x, double y )
{
	if ( y < 0 )
		return sin( x * pi / 2.0 + 3.0 * pi / 2.0 ) + 1.0;
	else
		return sin( x * pi / 2.0 );
}


static inline void			transformHSV_RGB(float *components) //H,S,B -> R,G,B
{
	float R, G, B;
	float H = fmodf(components[0],359),	//map to [0,360)
		  S = components[1],
		  V = components[2];
	
	int   Hi = (int)floorf(H/60.) % 6;
	float f  = H/60-Hi,
		  p  = V*(1-S),
		  q  = V*(1-f*S),
		  t  = V*(1-(1-f)*S);
	
	switch (Hi)
	{
		default:
		case 0:	R=V;G=t;B=p;	break;
		case 1:	R=q;G=V;B=p;	break;
		case 2:	R=p;G=V;B=t;	break;
		case 3:	R=p;G=q;B=V;	break;
		case 4:	R=t;G=p;B=V;	break;
		case 5:	R=V;G=p;B=q;	break;
	}
	
	components[0] = R;
	components[1] = G;
	components[2] = B;
}


static inline void transformRGB_HSV(float *components) //H,S,B -> R,G,B
{
	float H = 0.0;
	float S, V;
	float R = components[0],
		  G = components[1],
		  B = components[2];
	
	float MAX = R > G ? (R > B ? R : B) : (G > B ? G : B),
	      MIN = R < G ? (R < B ? R : B) : (G < B ? G : B);
	
	if(MAX == MIN)
		H = NAN;
	else if(MAX == R)
		if(G >= B)
			H = 60*(G-B)/(MAX-MIN)+0;
		else
			H = 60*(G-B)/(MAX-MIN)+360;
	else if(MAX == G)
		H = 60*(B-R)/(MAX-MIN)+120;
	else if(MAX == B)
		H = 60*(R-G)/(MAX-MIN)+240;
	
	S = MAX == 0 ? 0 : 1 - MIN/MAX;
	V = MAX;
	
	components[0] = H;
	components[1] = S;
	components[2] = V;
}


static inline void resolveHSV(float *color1, float *color2)
{
	if(isnan(color1[0]) && isnan(color2[0]))
		color1[0] = color2[0] = 0;
	else if(isnan(color1[0]))
		color1[0] = color2[0];
	else if(isnan(color2[0]))
		color2[0] = color1[0];
}


