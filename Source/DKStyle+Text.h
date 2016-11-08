/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKStyle.h"

/** @brief This adds text attributes to the DKStyle object.

This adds text attributes to the DKStyle object. A DKTextShape makes use of styles with attached text attributes to style
the text it displays. Other objects that use text can make use of this as they wish.
*/
@interface DKStyle (TextAdditions)

+ (DKStyle*)defaultTextStyle;
+ (DKStyle*)textStyleWithFont:(NSFont*)font;

/** @brief Returns the name and size of the font in a form that can be used as a style name
 @param font a font
 @return a string, such as "Helvetica Bold 18pt"
 */
+ (NSString*)styleNameForFont:(NSFont*)font;

- (void)setParagraphStyle:(NSParagraphStyle*)style;
- (NSParagraphStyle*)paragraphStyle;

- (void)setAlignment:(NSTextAlignment)align;
- (NSTextAlignment)alignment;

- (void)changeTextAttribute:(NSString*)attribute toValue:(id)val;
- (NSString*)actionNameForTextAttribute:(NSString*)attribute;

- (void)setFont:(NSFont*)font;
- (NSFont*)font;
- (void)setFontSize:(CGFloat)size;
- (CGFloat)fontSize;

- (void)setTextColour:(NSColor*)aColour;
- (NSColor*)textColour;

- (void)setUnderlined:(NSInteger)uval;
- (NSInteger)underlined;
- (void)toggleUnderlined;

- (void)applyToText:(NSMutableAttributedString*)text;
- (void)adoptFromText:(NSAttributedString*)text;

- (DKStyle*)drawingStyleFromTextAttributes;

@end
