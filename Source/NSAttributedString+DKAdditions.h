/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKBezierLayoutManager.h"
#import "DKCommonTypes.h"

NS_ASSUME_NONNULL_BEGIN

/** @brief These category methods perform high-level text layout.

 These category methods perform high-level text layout.

 In the first case, the text is laid out in the layoutRect which dictates the line wrapping and number lines by its width or height (this rect
 is the text container in other words). The resulting text is then rotated to the given angle and mapped into <code>destRect</code>, which applies any visual scaling
 and translation, and drawn into the current context.

 The second method is similar except that text is flowed into the layoutPath.
*/
@interface NSAttributedString (DKAdditions)

/** @brief Lays out the receiver then draws it to the destination.

 This method is intended to be utilised by high-level text objects such as \c DKTextShape and
 <code>DKTextAdornment</code>. It both lays out and renders text in many different ways according to its
 parameters (and the string's attributes themselves). 
 @param destRect The final destination of the text. The text is scaled and translated to draw in this rect
 @param layoutSize A size describing the text layout container. Text is laid out to fit into this size.
 @param radians An angle to which the text is rotated before being drawn to <code>destRect</code>.
 */
- (void)drawInRect:(NSRect)destRect withLayoutSize:(NSSize)layoutSize atAngle:(CGFloat)radians;

/** @brief Lays out the receiver then draws it to the destination

 This method is intended to be utilised by high-level text objects such as \c DKTextShape and
 DKTextAdornment. It both lays out and renders text in many different ways according to its
 parameters (and the string's attributes themselves). 
 @param destRect The final destination of the text. The text is scaled and translated to draw in this rect.
 @param layoutPath A path describing the text layout container. Text is laid out to fit into this path.
 @param radians An angle to which the text is rotated before being drawn to <code>destRect</code>.
 */
- (void)drawInRect:(NSRect)destRect withLayoutPath:(NSBezierPath*)layoutPath atAngle:(CGFloat)radians;

/** @brief Lays out the receiver then draws it to the destination
 
 This method is intended to be utilised by high-level text objects such as \c DKTextShape and
 DKTextAdornment. It both lays out and renders text in many different ways according to its
 parameters (and the string's attributes themselves).
 @param destRect The final destination of the text. The text is scaled and translated to draw in this rect.
 @param layoutPath A path describing the text layout container. Text is laid out to fit into this path.
 @param radians An angle to which the text is rotated before being drawn to <code>destRect</code>.
 @param vAlign Whether the text is positioned at top, centre, bottom or at some value.
 @param vPos Proportion of \c srcRect given by interval 0..1 when \c vAlign is proportional.
 */
- (void)drawInRect:(NSRect)destRect withLayoutPath:(NSBezierPath*)layoutPath atAngle:(CGFloat)radians verticalPositioning:(DKVerticalTextAlignment)vAlign verticalOffset:(CGFloat)vPos;

/** @brief Returns the accurate size needed to draw the string on a single line. This works by forcing the text layout, so is considerably more
 expensive than <code>-size</code>. However, it is a lot more accurate!
 */
- (NSSize)accurateSize;

/** @brief Is \c YES if all the attributes at index \c 0 apply to the entire string, or if string is empty.
 */
@property (readonly, getter=isHomogeneous) BOOL homogeneous;

/** @brief Returns \c YES if the attribute named applies over the entire length of the string or the string is
 empty, \c NO otherwise (including if the attribute doesn't exist).
 */
- (BOOL)attributeIsHomogeneous:(NSAttributedStringKey)attrName;

/** @brief returns \c YES if the attributes listed in \c attrs are homogeneous, \c NO otherwise.
 */
- (BOOL)attributesAreHomogeneous:(NSDictionary<NSAttributedStringKey, id>*)attrs;

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

/** @brief This allows any mutable attributed string to make use of the font panel directly.
 
 This allows any mutable attributed string to make use of the font panel directly. It applies the font change to the entire string but in chunks such that
 each range is modified separately and minimally. \c sender is assumed to be the font manager, as per normal rules for \c changeFont:
 */
- (void)changeFont:(nullable id)sender;
- (void)changeAttributes:(nullable id)sender;

@end

// can be used by text drawers everywhere

/** @brief Supply a layout manager common to all \c DKTextShape instances
 @return the shared layout manager instance */
NSLayoutManager* sharedDrawingLayoutManager(void);

/** @brief Supply a layout manager that can be used to capture text layout into a bezier path
 @return the shared layout manager instance */
DKBezierLayoutManager* sharedCaptureLayoutManager(void);

NS_ASSUME_NONNULL_END
