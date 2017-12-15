/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKStyle.h"

/** @brief This adds text attributes to the DKStyle object.

This adds text attributes to the DKStyle object. A DKTextShape makes use of styles with attached text attributes to style
the text it displays. Other objects that use text can make use of this as they wish.
*/
@interface DKStyle (TextAdditions)

+ (DKStyle*)defaultTextStyle NS_SWIFT_NAME(init(defaultTextStyle:));
+ (DKStyle*)textStyleWithFont:(NSFont*)font NS_SWIFT_NAME(init(textStyleWith:));

/** @brief Returns the name and size of the font in a form that can be used as a style name
 @param font a font
 @return a string, such as "Helvetica Bold 18pt"
 */
+ (NSString*)styleNameForFont:(NSFont*)font;

@property (strong) NSParagraphStyle *paragraphStyle;

@property NSTextAlignment alignment;

- (void)changeTextAttribute:(NSAttributedStringKey)attribute toValue:(id)val;
- (NSString*)actionNameForTextAttribute:(NSAttributedStringKey)attribute;

@property (strong) NSFont *font;
@property CGFloat fontSize;

@property (strong) NSColor *textColour;

@property NSUnderlineStyle underlined;
- (void)toggleUnderlined;

- (void)applyToText:(NSMutableAttributedString*)text;
- (void)adoptFromText:(NSAttributedString*)text;

- (DKStyle*)drawingStyleFromTextAttributes;

@end
