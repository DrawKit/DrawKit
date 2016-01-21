/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKCommonTypes.h"

/** @brief These category methods perform high-level text layout.

These category methods perform high-level text layout.

In the first case, the text is laid out in the layoutRect which dictates the line wrapping and number lines by its width or height (this rect
is the text container in other words). The resulting text is then rotated to the given angle and mapped into <destRect>, which applies any visual scaling
and translation, and drawn into the current context.

The second method is similar except that text is flowed into the layoutPath.
*/
@interface NSAttributedString (DKAdditions)

/** @brief Lays out the receiver then draws it to the destination

 This method is intended to be utilised by high-level text objects such as DKTextShape and
 DKTextAdornment. It both lays out and renders text in many different ways according to its
 parameters (and the string's attributes themselves). 
 @param destRect the final destination of the text. The text is scaled and translated to draw in this rect
 @param layoutSize a size describing the text layout container. Text is laid out to fit into this size.
 @param radians an angle to which the text is rotated before being drawn to <destRect>
 */

/** @brief Lays out the receiver then draws it to the destination

 This method is intended to be utilised by high-level text objects such as DKTextShape and
 DKTextAdornment. It both lays out and renders text in many different ways according to its
 parameters (and the string's attributes themselves). 
 @param destRect the final destination of the text. The text is scaled and translated to draw in this rect
 @param layoutPath a path describing the text layout container. Text is laid out to fit into this path.
 @param radians an angle to which the text is rotated before being drawn to <destRect>
 @param vAlign whether the text is positioned at top, centre, bottom or at some value
 @param vPos proportion of srcRect given by interval 0..1 when vAlign is proportional
 */
- (void)drawInRect:(NSRect)destRect withLayoutSize:(NSSize)layoutSize atAngle:(CGFloat)radians;

/** @brief Lays out the receiver then draws it to the destination

 This method is intended to be utilised by high-level text objects such as DKTextShape and
 DKTextAdornment. It both lays out and renders text in many different ways according to its
 parameters (and the string's attributes themselves). 
 @param destRect the final destination of the text. The text is scaled and translated to draw in this rect
 @param layoutPath a path describing the text layout container. Text is laid out to fit into this path.
 @param radians an angle to which the text is rotated before being drawn to <destRect>
 */
- (void)drawInRect:(NSRect)destRect withLayoutPath:(NSBezierPath*)layoutPath atAngle:(CGFloat)radians;
- (void)drawInRect:(NSRect)destRect withLayoutPath:(NSBezierPath*)layoutPath atAngle:(CGFloat)radians verticalPositioning:(DKVerticalTextAlignment)vAlign verticalOffset:(CGFloat)vPos;
- (NSSize)accurateSize;
- (BOOL)isHomogeneous;
- (BOOL)attributeIsHomogeneous:(NSString*)attrName;
- (BOOL)attributesAreHomogeneous:(NSDictionary*)attrs;

@end

@interface NSMutableAttributedString (DKAdditions)

- (void)makeUppercase;
- (void)makeLowercase;
- (void)capitalize;

- (void)convertFontsToFace:(NSString*)face;
- (void)convertFontsToFamily:(NSString*)family;
- (void)convertFontsToSize:(CGFloat)aSize;
- (void)convertFontsByAddingSize:(CGFloat)aSize;
- (void)convertFontsToHaveTrait:(NSFontTraitMask)traitMask;
- (void)convertFontsToNotHaveTrait:(NSFontTraitMask)traitMask;

- (void)changeFont:(id)sender;
- (void)changeAttributes:(id)sender;

@end

// can be used by text drawers everywhere

/** @brief Supply a layout manager common to all DKTextShape instances
 @return the shared layout manager instance */
NSLayoutManager* sharedDrawingLayoutManager(void);

/** @brief Supply a layout manager that can be used to capture text layout into a bezier path
 @return the shared layout manager instance */
NSLayoutManager* sharedCaptureLayoutManager(void);
