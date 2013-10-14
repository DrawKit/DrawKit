/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

@interface NSColor (DKAdditions)

/** @brief Returns the colour white as an RGB Color
 * @note
 * Uses the RGB Color space, not the greyscale Colorspace you get with NSColor's whiteColor
 * method.
 * @return the colour white
 * @public
 */
+ (NSColor*)			rgbWhite;

/** @brief Returns the colour black as an RGB Color
 * @note
 * Uses the RGB Color space, not the greyscale Colorspace you get with NSColor's blackColor
 * method.
 * @return the colour black
 * @public
 */
+ (NSColor*)			rgbBlack;

/** @brief Returns a grey RGB colour
 * @note
 * Uses the RGB Color space, not the greyscale Colorspace you get with NSColor's grey
 * method. 
 * @param grayscale 0 to 1.0
 * @return a grey colour
 * @public
 */
+ (NSColor*)			rgbGrey:(CGFloat) grayscale;

/** @brief Returns a grey RGB colour
 * @note
 * Uses the RGB Color space, not the greyscale Colorspace you get with NSColor's grey
 * method.
 * @param grayscale 0 to 1.0
 * @param alpha 0 to 1.0
 * @return a grey colour with variable opacity
 * @public
 */
+ (NSColor*)			rgbGrey:(CGFloat) grayscale withAlpha:(CGFloat) alpha;

/** @brief Returns a grey RGB colour with the same perceived brightness as the source colour
 * @param colour any colour
 * @param alpha 0 to 1.0
 * @return a grey colour in rgb space of equivalent luminosity
 * @public
 */
+ (NSColor*)			rgbGreyWithLuminosityFrom:(NSColor*) colour withAlpha:(CGFloat) alpha;

/** @brief A very light grey colour
 * @return a very light grey colour in rgb space
 * @public
 */
+ (NSColor*)			veryLightGrey;

+ (NSColor*)			contrastingColor:(NSColor*) color;

/** @brief Returns an RGB colour approximating the wavelength.
 * @note
 * Lambda range outside 380 to 780 (nm) returns black
 * @param lambda the wavelength in nanometres
 * @return approximate rgb equivalent colour
 * @public
 */
+ (NSColor*)			colorWithWavelength:(CGFloat) lambda;

/** @brief Returns an RGB colour corresponding to the standard-formatted HTML hexadecimal colour string.
 * @param hex a string formatted '#RRGGBB'
 * @return rgb equivalent colour
 * @public
 */
+ (NSColor*)			colorWithHexString:(NSString*) hex;

/** @brief Returns a colour by interpolating between two colours
 * @param startColor a colour
 * @param endColor a second colour
 * @param interpValue a value between 0 and 1
 * @return a colour that is intermediate between startColor and endColor, in RGB space
 * @public
 */
+ (NSColor*)			colorByInterpolatingFrom:(NSColor*) startColor to:(NSColor*) endColor atValue:(CGFloat) interpValue;

/** @brief Returns a copy ofthe receiver but substituting the hue from the given colour.
 * @note
 * If the receiver is black or white or otherwise fully unsaturated, colourization may not produce visible
 * results. Input colours must be in RGB colour space
 * @param color donates hue
 * @return a colour with the hue of <color> but the receiver's saturation and brightness
 * @public
 */
- (NSColor*)			colorWithHueFrom:(NSColor*) color;

/** @brief Returns a copy ofthe receiver but substituting the hue and saturation from the given colour.
 * @note
 * Input colours must be in RGB colour space
 * @param color donates hue and saturation
 * @return a colour with the hue, sat of <color> but the receiver's brightness
 * @public
 */
- (NSColor*)			colorWithHueAndSaturationFrom:(NSColor*) color;

/** @brief Returns a colour by averaging the receiver with <color> in rgb space
 * @note
 * Input colours must be in RGB colour space
 * @param color average with this colour
 * @return average of the two colours
 * @public
 */
- (NSColor*)			colorWithRGBAverageFrom:(NSColor*) color;

/** @brief Returns a colour by averaging the receiver with <color> in hsb space
 * @note
 * Input colours must be in RGB colour space
 * @param color average with this colour
 * @return average of the two colours
 * @public
 */
- (NSColor*)			colorWithHSBAverageFrom:(NSColor*) color;

/** @brief Returns a colour by blending the receiver with <color> in rgb space
 * @param color blend with this colour
 * @param blendingAmounts an array of four values, each 0..1, specifies how components from each colour are
 * @return blend of the two colours
 * @public
 */
- (NSColor*)			colorWithRGBBlendFrom:(NSColor*) color blendingAmounts:(CGFloat[]) blends;

/** @brief Returns a colour by blending the receiver with <color> in hsb space
 * @param color blend with this colour
 * @param blendingAmounts an array of four values, each 0..1, specifies how components from each colour are
 * @return blend of the two colours
 * @public
 */
- (NSColor*)			colorWithHSBBlendFrom:(NSColor*) color blendingAmounts:(CGFloat[]) blends;

/** @brief Returns the luminosity value of the receiver
 * @note
 * Luminosity of a colour is both subjective and dependent on the display characteristics of particular
 * monitors, etc. A frequently used formula can be traced to experiments done by the NTSC television
 * standards committee in 1953, which was based on tube phosphors in common use at that time. A more
 * modern formula is applicable for LCD monitors. This method uses the NTSC formula if
 * NTSC_1953_STANDARD is defined, otherwise the modern one.
 * @return a value 0..1 that is the colour's luminosity
 * @public
 */
- (CGFloat)				luminosity;

/** @brief Returns a grey rgb colour having the same luminosity as the receiver
 * @return a grey colour having the same luminosity
 * @public
 */
- (NSColor*)			colorWithLuminosity;

/** @brief Returns black or white to give best contrast with the receiver's colour
 * @return black or white
 * @public
 */
- (NSColor*)			contrastingColor;

/** @brief Returns the colour with each colour component subtracted from 1
 * @note
 * The alpha value is not inverted
 * @return the "inverse" of the receiver
 * @public
 */
- (NSColor*)			invertedColor;

/** @brief Returns a lighter colour based on a blend between the receiver and white
 * @note
 * The alpha value is unchanged
 * @param amount a value 0.0..1.0, 0 returns the original colour, 1 returns white.
 * @return a lightened version of the receiver
 * @public
 */
- (NSColor*)			lighterColorWithLevel:(CGFloat) amount;

/** @brief Returns a darker colour based on a blend between the receiver and black
 * @note
 * The alpha value is unchanged
 * @param amount a value 0.0..1.0, 0 returns the original colour, 1 returns black.
 * @return a darkened version of the receiver
 * @public
 */
- (NSColor*)			darkerColorWithLevel:(CGFloat) amount;

/** @brief Returns a colour by interpolating between the receiver and a second colour
 * @param secondColour another colour
 * @param interpValue a value between 0 and 1
 * @return a colour that is intermediate between the receiver and secondColor, in RGB space
 * @public
 */
- (NSColor*)			interpolatedColorToColor:(NSColor*) secondColor atValue:(CGFloat) interpValue;

/** @brief Returns a standard web-formatted hexadecimal representation of the receiver's colour
 * @note
 * Format is '#000000' (black) to '#FFFFFF' (white)
 * @return hexadecimal string
 * @public
 */
- (NSString*)			hexString;

/** @brief Returns a quartz CGColorRef corresponding to the receiver's colours
 * @note
 * Returned colour uses the generic RGB colour space, regardless of the receivers colourspace. Caller
 * is responsible for releasing the colour ref when done.
 * @return CGColorRef
 * @public
 */
- (CGColorRef)			newQuartzColor;

@end
