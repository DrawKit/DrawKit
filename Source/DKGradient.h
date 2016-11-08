/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "GCObservableObject.h"

@class DKColorStop;

// gradient type:

typedef enum {
	kDKGradientTypeLinear = 0,
	kDKGradientTypeRadial = 1,
	kDKGradientSweptAngle = 3
} DKGradientType;

// gradient blending mode:

typedef enum {
	kDKGradientRGBBlending = 0,
	kDKGradientHSBBlending = 1,
	kDKGradientAlphaBlending = 64
} DKGradientBlending;

typedef enum {
	kDKGradientInterpLinear = 0,
	kDKGradientInterpQuadratic = 2,
	kDKGradientInterpCubic = 3,
	kDKGradientInterpSinus = 4,
	kDKGradientInterpSinus2 = 5
} DKGradientInterpolation;

/** @brief A DKGradient encapsulates gradient/shading drawing.
*/
@interface DKGradient : GCObservableObject <NSCoding, NSCopying> {
	NSMutableArray* m_colorStops; // color stops
	id m_extensionData; // additional supplementary data
	CGFloat m_gradAngle; // linear angle in radians
	DKGradientType m_gradType; // type
	DKGradientBlending m_blending; // method to blend colours
	DKGradientInterpolation m_interp; // interpolation function
	CGFunctionRef m_cbfunc; // callback function
}

// simple gradient convenience methods

/** @brief Returns an instance of the default gradient (simple linear black to white)
 @return autoreleased default gradient object
 */
+ (DKGradient*)defaultGradient;

/** @brief Returns a linear gradient from Color c1 to c2

 Gradient is linear and draws left to right c1 --> c2
 @param c1 the starting Color
 @param c2 the ending Color
 @return gradient object
 */
+ (DKGradient*)gradientWithStartingColor:(NSColor*)c1 endingColor:(NSColor*)c2;

/** @brief Returns a gradient from Color c1 to c2 with given type and angle
 @param c1 the starting Color
 @param c2 the ending Color
 @param type the gradient's type (linear or radial, etc)
 @param degrees angle in degrees
 @return gradient object
 */
+ (DKGradient*)gradientWithStartingColor:(NSColor*)c1 endingColor:(NSColor*)c2 type:(NSInteger)gt angle:(CGFloat)degrees;

// modified copies:

/** @brief Creates a copy of the gradient but colorizies it by substituting the hue from <color>
 @param color donates its hue
 @return a new gradient, a copy of the receiver in every way except colourized by <color> 
 */
- (DKGradient*)gradientByColorizingWithColor:(NSColor*)color;

/** @brief Creates a copy of the gradient but sets the alpha vealue of all stop colours to <alpha>
 @param alpha the desired alpha
 @return a new gradient, a copy of the receiver with requested alpha 
 */
- (DKGradient*)gradientWithAlpha:(CGFloat)alpha;

// setting up the Color stops

- (DKColorStop*)addColor:(NSColor*)Color at:(CGFloat)pos;
- (void)addColorStop:(DKColorStop*)stop;

/** @brief Removes the last Color from he list of Colors
 */
- (void)removeLastColor;

/** @brief Removes a Color stop from the list of Colors
 @param stop the stop to remove
 */
- (void)removeColorStop:(DKColorStop*)stop;

/** @brief Removes all Colors from the list of Colors
 */
- (void)removeAllColors;

/** @brief Sets the list of Color stops in the gradient

 A gradient needs a minimum of two Colors to be a gradient, but will function with one.
 @param stops an array of DKColorStop objects
 */
- (void)setColorStops:(NSArray*)stops;

/** @brief Returns the list of Color stops in the gradient

 A gradient needs a minimum of two Colors to be a gradient, but will function with one.
 @return the array of DKColorStop (color + position) objects in the gradient
 */
- (NSArray*)colorStops;

/** @brief Sorts the Color stops into position order

 Stops are sorted in place
 */
- (void)sortColorStops;

/** @brief Reverses the order of all the Color stops so "inverting" the gradient

 Stop positions are changed, but Colors are not touched
 */
- (void)reverseColorStops;

// KVO compliant accessors:

/** @brief Returns the number of Color stops in the gradient

 This also makes the stops array KVC compliant
 @return an integer, the number of Colors used to compute the gradient
 */
- (NSUInteger)countOfColorStops;

/** @brief Returns the the indexed Color stop

 This also makes the stops array KVC compliant
 @param ix index number of the stop
 @return a Color stop
 */
- (DKColorStop*)objectInColorStopsAtIndex:(NSUInteger)ix;
- (void)insertObject:(DKColorStop*)stop inColorStopsAtIndex:(NSUInteger)ix;
- (void)removeObjectFromColorStopsAtIndex:(NSUInteger)ix;

// a variety of ways to fill a path

- (void)fillRect:(NSRect)rect;

/** @brief Fills the path using the gradient

 The fill will proceed as for a standard fill. A gradient that needs a starting point will assume
 the centre of the path's bounds as that point when using this method.
 @param path the bezier path to fill. 
 */
- (void)fillPath:(NSBezierPath*)path;

/** @brief Fills the path using the gradient
 @param path the bezier path to fill
 @param co displacement from the centre for the start of a radial fill
 */
- (void)fillPath:(NSBezierPath*)path centreOffset:(NSPoint)co;
- (void)fillPath:(NSBezierPath*)path startingAtPoint:(NSPoint)sp
		startRadius:(CGFloat)sr
	  endingAtPoint:(NSPoint)ep
		  endRadius:(CGFloat)er;

- (void)fillContext:(CGContextRef)context startingAtPoint:(NSPoint)sp
		startRadius:(CGFloat)sr
	  endingAtPoint:(NSPoint)ep
		  endRadius:(CGFloat)er;

/** @brief Returns the computed Color for the gradient ramp expressed as a value from 0 to 1.0

 While intended for internal use, this function can be called at any time if you wish
 the private version here is called internally. It does fewer checks and returns raw component
 values for performance. do not use from external code.
 @param val the proportion of the gradient ramp from start (0) to finish (1.0) 
 @return the Color corresponding to that position
 */

/** @brief Returns the Color associated with this stop
 @return a Color value
 */
- (NSColor*)colorAtValue:(CGFloat)val;

// setting the angle

/** @brief Sets the gradient's current angle in radians
 @param ang the desired angle in radians
 */
- (void)setAngle:(CGFloat)ang;

/** @brief Returns the gradient's current angle in radians
 @return angle expressed in radians
 */
- (CGFloat)angle;

/** @brief Sets the angle of the gradient to the given angle
 @param degrees the desired angle expressed in degrees
 */
- (void)setAngleInDegrees:(CGFloat)degrees;

/** @brief Returns the gradient's current angle in degrees
 @return angle expressed in degrees
 */
- (CGFloat)angleInDegrees;
- (void)setAngleWithoutNotifying:(CGFloat)ang;

// setting gradient type, blending and interpolation settings

/** @brief Sets the gradient's basic type

 Valid types are: kDKGradientTypeLinear and kDKGradientTypeRadial
 @param gt the type
 */
- (void)setGradientType:(DKGradientType)gt;
- (DKGradientType)gradientType;

- (void)setGradientBlending:(DKGradientBlending)bt;
- (DKGradientBlending)gradientBlending;

- (void)setGradientInterpolation:(DKGradientInterpolation)intrp;

/** @brief Returns the interpolation algorithm for the gradient
 @return the current interpolation
 */
- (DKGradientInterpolation)gradientInterpolation;

// swatch images

/** @brief Returns an image of the current gradient for use in a UI, etc.
 @param size the desired image size
 @param showBorder YES to draw a border around the image, NO for no border
 @return an NSIMage containing the current gradient
 */
- (NSImage*)swatchImageWithSize:(NSSize)size withBorder:(BOOL)showBorder;
- (NSImage*)standardSwatchImage;

@end

#define DKGradientSwatchSize (NSMakeSize(20, 20))

#pragma mark -

/** @brief small object that links a Color with its relative position
*/
@interface DKColorStop : NSObject <NSCoding, NSCopying> {
	NSColor* mColor;
	CGFloat position;
	DKGradient* m_ownerRef;
@public
	CGFloat components[4]; // cached rgba values
}

- (id)initWithColor:(NSColor*)aColor at:(CGFloat)pos;

- (NSColor*)color;
- (void)setColor:(NSColor*)aColor;

/** @brief Set the alpha of the colour associated with this stop
 @param alpha the alpha to set
 */
- (void)setAlpha:(CGFloat)alpha;

/** @brief Get the stop's relative position
 @return a value between 0 and 1
 */
- (CGFloat)position;
- (void)setPosition:(CGFloat)pos;

@end

// notifications sent by DKGradient:

extern NSString* kDKNotificationGradientWillAddColorStop;
extern NSString* kDKNotificationGradientDidAddColorStop;
extern NSString* kDKNotificationGradientWillRemoveColorStop;
extern NSString* kDKNotificationGradientDidRemoveColorStop;
extern NSString* kDKNotificationGradientWillChange;
extern NSString* kDKNotificationGradientDidChange;
