/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "GCObservableObject.h"

NS_ASSUME_NONNULL_BEGIN

@class DKColorStop;

//! gradient type:
typedef NS_ENUM(NSInteger, DKGradientType) {
	kDKGradientTypeLinear = 0,
	kDKGradientTypeRadial = 1,
	kDKGradientTypeSweptAngle = 3,
};

//! gradient blending mode:
typedef NS_ENUM(NSInteger, DKGradientBlending) {
	DKGradientBlendingRGB = 0,
	DKGradientBlendingHSB = 1,
	DKGradientBlendingAlpha = 64,
};

typedef NS_ENUM(NSInteger, DKGradientInterpolation) {
	DKGradientInterpolationLinear = 0,
	DKGradientInterpolationQuadratic = 2,
	DKGradientInterpolationCubic = 3,
	DKGradientInterpolationSinus = 4,
	DKGradientInterpolationSinus2 = 5,
};

/** @brief A DKGradient encapsulates gradient/shading drawing.
*/
@interface DKGradient : GCObservableObject <NSCoding, NSCopying> {
	NSMutableArray<DKColorStop*>* m_colorStops; // color stops
	NSMutableDictionary* m_extensionData; // additional supplementary data
	CGFloat m_gradAngle; // linear angle in radians
	DKGradientType m_gradType; // type
	DKGradientBlending m_blending; // method to blend colours
	DKGradientInterpolation m_interp; // interpolation function
}

// simple gradient convenience methods

/** @brief Returns an instance of the default gradient (simple linear black to white).
 @return autoreleased default gradient object.
 */
+ (DKGradient*)defaultGradient;

/** @brief Returns a linear gradient from Color \c c1 to \c c2

 Gradient is linear and draws left to right \c c1 --> \c c2
 @param c1 the starting Color
 @param c2 the ending Color
 @return gradient object
 */
+ (DKGradient*)gradientWithStartingColor:(NSColor*)c1 endingColor:(NSColor*)c2;

/** @brief Returns a gradient from color \c c1 to \c c2 with given type and angle.
 @param c1 The starting Color.
 @param c2 The ending Color.
 @param gt The gradient's type (linear or radial, etc).
 @param degrees Angle in degrees.
 @return Gradient object.
 */
+ (DKGradient*)gradientWithStartingColor:(NSColor*)c1 endingColor:(NSColor*)c2 type:(DKGradientType)gt angle:(CGFloat)degrees;

// modified copies:

/** @brief Creates a copy of the gradient but colorizies it by substituting the hue from \c color
 @param color Donates its hue.
 @return A new gradient, a copy of the receiver in every way except colourized by \c color
 */
- (DKGradient*)gradientByColorizingWithColor:(NSColor*)color;

/** @brief Creates a copy of the gradient but sets the alpha value of all stop colours to \c alpha
 @param alpha The desired alpha.
 @return A new gradient, a copy of the receiver with the requested alpha.
 */
- (DKGradient*)gradientWithAlpha:(CGFloat)alpha;

// setting up the Color stops

- (DKColorStop*)addColor:(NSColor*)color at:(CGFloat)pos;
/** @brief Add a color stop to the list of gradient colors.
 @param stop The Colorstop to add.
 */
- (void)addColorStop:(DKColorStop*)stop;

/** @brief Removes the last color from the list of colors.
 */
- (void)removeLastColor;

/** @brief Removes a color stop from the list of Colors.
 @param stop The stop to remove.
 */
- (void)removeColorStop:(DKColorStop*)stop;

/** @brief Removes all colors from the list of colors.
 */
- (void)removeAllColors;

/** @brief Returns the list of color stops in the gradient.

 A gradient needs a minimum of two colors to be a gradient, but will function with one.
 */
@property (copy) NSArray<DKColorStop*>* colorStops;

/** @brief Sorts the color stops into position order.

 Stops are sorted in place.
 */
- (void)sortColorStops;

/** @brief Reverses the order of all the color stops so "inverting" the gradient.

 Stop positions are changed, but colors are not touched.
 */
- (void)reverseColorStops;

// KVO compliant accessors:

/** @brief Returns the number of color stops in the gradient.

 This also makes the stops array KVC compliant.
 @return An integer, the number of colors used to compute the gradient.
 */
@property (readonly) NSUInteger countOfColorStops;

/** @brief Returns the the indexed Color stop.

 This also makes the stops array KVC compliant.
 @param ix Index number of the stop.
 @return A Color stop.
 */
- (DKColorStop*)objectInColorStopsAtIndex:(NSUInteger)ix;
- (void)insertObject:(DKColorStop*)stop inColorStopsAtIndex:(NSUInteger)ix;
- (void)removeObjectFromColorStopsAtIndex:(NSUInteger)ix;

// a variety of ways to fill a path

/** @brief Fills the rect using the gradient.
 
 The fill will proceed as for a standard fill. A gradient that needs a starting point will assume
 the centre of the rect as that point when using this method.
 @param rect The rect to fill.
 */
- (void)fillRect:(NSRect)rect;

/** @brief Fills the path using the gradient.

 The fill will proceed as for a standard fill. A gradient that needs a starting point will assume
 the centre of the path's bounds as that point when using this method.
 @param path The bezier path to fill.
 */
- (void)fillPath:(NSBezierPath*)path;

/** @brief Fills the path using the gradient.
 @param path The bezier path to fill.
 @param co Displacement from the centre for the start of a radial fill.
 */
- (void)fillPath:(NSBezierPath*)path centreOffset:(NSPoint)co;
/** @brief Fills the path using the gradient between two given points
 
 Radii are ignored for linear gradients. Angle is ignored by this method, if you call it directly
 (angle is used to calculate start and endpoints in other methods that call this)
 @param path The bezier path to fill.
 @param sp The point where the gradient begins.
 @param sr For radial fills, the radius of the start of the gradient.
 @param ep The point where the gradient ends.
 @param er For radial fills, the radius of the end of the gradient.
 */
- (void)fillPath:(NSBezierPath*)path startingAtPoint:(NSPoint)sp
		startRadius:(CGFloat)sr
	  endingAtPoint:(NSPoint)ep
		  endRadius:(CGFloat)er;

- (void)fillContext:(CGContextRef)context startingAtPoint:(NSPoint)sp
		startRadius:(CGFloat)sr
	  endingAtPoint:(NSPoint)ep
		  endRadius:(CGFloat)er API_DEPRECATED_WITH_REPLACEMENT("fillStartingAtPoint:startRadius:endingAtPoint:endRadius:", macosx(10.0, 10.6));

- (void)fillStartingAtPoint:(NSPoint)sp
				startRadius:(CGFloat)sr
			  endingAtPoint:(NSPoint)ep
				  endRadius:(CGFloat)er;

/** @brief Returns the computed color for the gradient ramp expressed as a value from 0 to 1.0
 
 While intended for internal use, this function can be called at any time if you wish
 the private version here is called internally. It does fewer checks and returns raw component
 values for performance. Do not use from external code.
 @param val The proportion of the gradient ramp from start (0) to finish (1.0)
 @return The color corresponding to that position.
 */
- (NSColor*)colorAtValue:(CGFloat)val;

// setting the angle

/** @brief The gradient's angle in radians.
 */
@property (nonatomic) CGFloat angle;

/** @brief The gradient's angle in degrees.
 */
@property CGFloat angleInDegrees;

- (void)setAngleWithoutNotifying:(CGFloat)ang;

// setting gradient type, blending and interpolation settings

/** @brief The gradient's basic type.
 
 Valid types are: \c kDKGradientTypeLinear and \c kDKGradientTypeRadial
 */
@property (nonatomic) DKGradientType gradientType;

/** @brief The blending mode of the gradient.
 */
@property (nonatomic) DKGradientBlending gradientBlending;

/** @brief The interpolation algorithm of the gradient.
 */
@property (nonatomic) DKGradientInterpolation gradientInterpolation;

// swatch images

/** @brief Returns an image of the current gradient for use in a UI, etc.
 @param size The desired image size.
 @param showBorder \c YES to draw a border around the image, \c NO for no border.
 @return An \c NSImage containing the current gradient.
 */
- (NSImage*)swatchImageWithSize:(NSSize)size withBorder:(BOOL)showBorder;
/** @brief Returns an image of the current gradient for use in a UI, etc.
 
 Swatch has standard size and a border
 @return an NSImage containing the current gradient
 */
- (NSImage*)standardSwatchImage;

@end

#define DKGradientSwatchSize (NSMakeSize(20, 20))

#pragma mark -

/** @brief Small object that links a Color with its relative position.
*/
@interface DKColorStop : NSObject <NSCoding, NSCopying> {
	NSColor* mColor;
	CGFloat position;
	DKGradient* __weak m_ownerRef;
@public
	CGFloat components[4]; // cached rgba values
}

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
/** @brief Initialise the stop with a Color and position.
 @param aColor The initial color value.
 @param pos The relative position within the gradient, valid range = 0.0..1.0
 @return The stop.
 */
- (instancetype)initWithColor:(NSColor*)aColor at:(CGFloat)pos NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;

/** @brief The color associated with this stop.
 
 Colors are converted to calibrated RGB to permit shading calculations.
 */
@property (nonatomic, strong) NSColor* color;

/** @brief The alpha of the colour associated with this stop.
 */
@property CGFloat alpha;

/** @brief The stop's relative position.
 
 Value is constrained between 0.0 and 1.0.
 */
@property (nonatomic) CGFloat position;

@end

// notifications sent by DKGradient:

extern NSNotificationName const kDKNotificationGradientWillAddColorStop;
extern NSNotificationName const kDKNotificationGradientDidAddColorStop;
extern NSNotificationName const kDKNotificationGradientWillRemoveColorStop;
extern NSNotificationName const kDKNotificationGradientDidRemoveColorStop;
extern NSNotificationName const kDKNotificationGradientWillChange;
extern NSNotificationName const kDKNotificationGradientDidChange;

// Deprecated enum constants
static const DKGradientInterpolation kDKGradientInterpLinear API_DEPRECATED_WITH_REPLACEMENT("DKGradientInterpolationLinear", macosx(10.0, 10.6)) = DKGradientInterpolationLinear;
static const DKGradientInterpolation kDKGradientInterpQuadratic API_DEPRECATED_WITH_REPLACEMENT("DKGradientInterpolationQuadratic", macosx(10.0, 10.6)) = DKGradientInterpolationQuadratic;
static const DKGradientInterpolation kDKGradientInterpCubic API_DEPRECATED_WITH_REPLACEMENT("DKGradientInterpolationCubic", macosx(10.0, 10.6)) = DKGradientInterpolationCubic;
static const DKGradientInterpolation kDKGradientInterpSinus API_DEPRECATED_WITH_REPLACEMENT("DKGradientInterpolationSinus", macosx(10.0, 10.6)) = DKGradientInterpolationSinus;
static const DKGradientInterpolation kDKGradientInterpSinus2 API_DEPRECATED_WITH_REPLACEMENT("DKGradientInterpolationSinus2", macosx(10.0, 10.6)) = DKGradientInterpolationSinus2;
static const DKGradientType kDKGradientSweptAngle API_DEPRECATED_WITH_REPLACEMENT("kDKGradientTypeSweptAngle", macosx(10.0, 10.6)) = kDKGradientTypeSweptAngle;
static const DKGradientBlending kDKGradientRGBBlending API_DEPRECATED_WITH_REPLACEMENT("DKGradientBlendingRGB", macosx(10.0, 10.6)) = DKGradientBlendingRGB;
static const DKGradientBlending kDKGradientHSBBlending API_DEPRECATED_WITH_REPLACEMENT("DKGradientBlendingHSB", macosx(10.0, 10.6)) = DKGradientBlendingHSB;
static const DKGradientBlending kDKGradientAlphaBlending API_DEPRECATED_WITH_REPLACEMENT("DKGradientBlendingAlpha", macosx(10.0, 10.6)) = DKGradientBlendingAlpha;

NS_ASSUME_NONNULL_END
