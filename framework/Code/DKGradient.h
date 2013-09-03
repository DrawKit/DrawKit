///**********************************************************************************************************************************
///  DKGradient.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 2/03/05.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "GCObservableObject.h"


@class DKColorStop;


// gradient type:

typedef enum
{
	kDKGradientTypeLinear		= 0,
	kDKGradientTypeRadial		= 1,
	kDKGradientSweptAngle		= 3
}
DKGradientType;

// gradient blending mode:

typedef enum
{
	kDKGradientRGBBlending			= 0,
	kDKGradientHSBBlending			= 1,
	kDKGradientAlphaBlending		= 64
}
DKGradientBlending;


typedef enum
{
	kDKGradientInterpLinear			= 0,
	kDKGradientInterpQuadratic		= 2,
	kDKGradientInterpCubic			= 3,
	kDKGradientInterpSinus			= 4,
	kDKGradientInterpSinus2			= 5
}
DKGradientInterpolation;

// A DKGradient encapsulates gradient/shading drawing.

@interface DKGradient : GCObservableObject <NSCoding, NSCopying>
{
	NSMutableArray*			m_colorStops;		// color stops
	id						m_extensionData;	// additional supplementary data 
	CGFloat					m_gradAngle;		// linear angle in radians
	DKGradientType			m_gradType;			// type
	DKGradientBlending		m_blending;			// method to blend colours
	DKGradientInterpolation	m_interp;			// interpolation function
	CGFunctionRef			m_cbfunc;			// callback function
}

// simple gradient convenience methods

+ (DKGradient*)			defaultGradient;
+ (DKGradient*)			gradientWithStartingColor:(NSColor*) c1 endingColor:(NSColor*) c2;
+ (DKGradient*)			gradientWithStartingColor:(NSColor*) c1 endingColor:(NSColor*) c2 type:(NSInteger) gt angle:(CGFloat) degrees;

// modified copies:

- (DKGradient*)			gradientByColorizingWithColor:(NSColor*) color;
- (DKGradient*)			gradientWithAlpha:(CGFloat) alpha;

// setting up the Color stops

- (DKColorStop*)		addColor:(NSColor*) Color at:(CGFloat) pos;
- (void)				addColorStop:(DKColorStop*) stop;
- (void)				removeLastColor;
- (void)				removeColorStop:(DKColorStop*) stop;
- (void)				removeAllColors;

- (void)				setColorStops:(NSArray*) stops;
- (NSArray*)			colorStops;
- (void)				sortColorStops;
- (void)				reverseColorStops;

// KVO compliant accessors:

- (NSUInteger)		countOfColorStops;
- (DKColorStop*)		objectInColorStopsAtIndex:(NSUInteger) ix;
- (void)				insertObject:(DKColorStop*) stop inColorStopsAtIndex:(NSUInteger) ix;
- (void)				removeObjectFromColorStopsAtIndex:(NSUInteger) ix;

// a variety of ways to fill a path

- (void)				fillRect:(NSRect)rect;
- (void)				fillPath:(NSBezierPath*) path;
- (void)				fillPath:(NSBezierPath*) path centreOffset:(NSPoint) co;
- (void)				fillPath:(NSBezierPath*) path startingAtPoint:(NSPoint) sp
								startRadius:(CGFloat) sr endingAtPoint:(NSPoint) ep endRadius:(CGFloat) er;

- (void)				fillContext:(CGContextRef) context startingAtPoint:(NSPoint) sp
								startRadius:(CGFloat) sr endingAtPoint:(NSPoint) ep endRadius:(CGFloat) er;

- (NSColor*)			colorAtValue:(CGFloat) val;

// setting the angle

- (void)				setAngle:(CGFloat) ang;
- (CGFloat)				angle;
- (void)				setAngleInDegrees:(CGFloat) degrees;
- (CGFloat)				angleInDegrees;
- (void)				setAngleWithoutNotifying:(CGFloat) ang;

// setting gradient type, blending and interpolation settings

- (void)				setGradientType:(DKGradientType) gt;
- (DKGradientType)		gradientType;

- (void)				setGradientBlending:(DKGradientBlending) bt;
- (DKGradientBlending)  gradientBlending;

- (void)				setGradientInterpolation:(DKGradientInterpolation) intrp;
- (DKGradientInterpolation)	gradientInterpolation;

// swatch images

- (NSImage*)			swatchImageWithSize:(NSSize) size withBorder:(BOOL) showBorder;
- (NSImage*)			standardSwatchImage;

@end

#define DKGradientSwatchSize (NSMakeSize (20, 20))

#pragma mark -
/// DKColorStop class - small object that links a Color with its relative position

@interface DKColorStop : NSObject <NSCoding, NSCopying>
{
	NSColor*			mColor;
	CGFloat				position;
	DKGradient*			m_ownerRef;
@public
	CGFloat				components[4];  // cached rgba values
}

- (id)					initWithColor:(NSColor*) aColor at:(CGFloat) pos;

- (NSColor*)			color;
- (void)				setColor:(NSColor*) aColor;
- (void)				setAlpha:(CGFloat) alpha;

- (CGFloat)				position;
- (void)				setPosition:(CGFloat) pos;

@end

// notifications sent by DKGradient:

extern NSString*	kDKNotificationGradientWillAddColorStop;
extern NSString*	kDKNotificationGradientDidAddColorStop;
extern NSString*	kDKNotificationGradientWillRemoveColorStop;
extern NSString*	kDKNotificationGradientDidRemoveColorStop;
extern NSString*	kDKNotificationGradientWillChange;
extern NSString*	kDKNotificationGradientDidChange;

// DKGradient is a simplified version of GCGradient as used in GradientPanel. Because this responds to exactly the same
// methods, you can cast a GCGradient to a DKGradient and it will work. This allows the GradientPanel to be used in a DK-based
// application without there being a clash between different frameworks.

// DKGradient drops the UI convenience methods and support for wavelength-based gradients
