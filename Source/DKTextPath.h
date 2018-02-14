/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKDrawablePath.h"
#import "DKCommonTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DKTextAdornment, DKDrawingView;

/** @brief Very similar to a DKTextShape but based on a path and defaulting to text-on-a-path rendering.

Very similar to a DKTextShape but based on a path and defaulting to text-on-a-path rendering. Has virtually identical public API to DKTextShape.
*/
@interface DKTextPath : DKDrawablePath <NSCopying, NSCoding, NSTextViewDelegate> {
@private
	DKTextAdornment* mTextAdornment;
	NSTextView* mEditorRef;
	BOOL mIsSettingStyle;
}

// convenience constructors:

+ (instancetype)textPathWithString:(NSString*)str onPath:(NSBezierPath*)aPath;

// class defaults:

@property (class, copy) NSString *defaultTextString;
@property (class, readonly) Class textAdornmentClass;

/** @brief Return a list of types we can paste in priority order.

 Cocoa's -textPasteboardTypes isn't in an order that is useful to us
 @return a list of types
 */
@property (class, readonly, retain) NSArray<NSPasteboardType> *pastableTextTypes;
+ (DKStyle*)textPathDefaultStyle;

// the text:

- (void)setText:(id)contents;
- (NSTextStorage*)text;
- (NSString*)string;

- (void)pasteTextFromPasteboard:(NSPasteboard*)pb ignoreFormatting:(BOOL)fmt;
- (BOOL)canPasteText:(NSPasteboard*)pb;

// conversion to path/shape with text path:

@property (readonly, copy) NSBezierPath *textPath;
@property (readonly, copy) NSArray<NSBezierPath*> *textPathGlyphs;
- (NSArray<NSBezierPath*>*)textPathGlyphsUsedSize:(nullable NSSize*)textSize;
- (DKDrawablePath*)makePathWithText;
- (DKDrawableShape*)makeShapeWithText;
- (DKShapeGroup*)makeShapeGroupWithText;
@property (readonly, retain) DKStyle *styleWithTextAttributes;

/** @brief Creates a style that is the current style + any text attributes

 A style which is the current style if it has text attributes, otherwise the current style with added text
 attributes. When cutting or copying the object's style, this is what should be used.
 @return a new style object
 */
@property (readonly, retain) DKStyle *syntheticStyle;

// text attributes - accesses the internal adornment object

@property (readonly, copy) NSDictionary<NSAttributedStringKey,id> *textAttributes;
@property (retain) NSFont *font;
@property CGFloat fontSize;
@property (retain) NSColor *textColour;

- (void)scaleTextBy:(CGFloat)factor;

// paragraph style attributes:

@property DKVerticalTextAlignment verticalAlignment;
@property CGFloat verticalAlignmentProportion;
@property (strong) NSParagraphStyle *paragraphStyle;
@property (readonly) NSTextAlignment alignment;

@property DKTextLayoutMode layoutMode;

// editing the text:

- (void)startEditingInView:(DKDrawingView*)view;
- (void)endEditing;
@property (readonly,getter=isEditing) BOOL editing;

// the internal adornment object:

@property (nonatomic, strong, nullable) DKTextAdornment *textAdornment;

// user actions:

- (IBAction)changeFont:(nullable id)sender;
- (IBAction)changeFontSize:(nullable id)sender;
- (IBAction)changeAttributes:(nullable id)sender;
- (IBAction)editText:(nullable id)sender;

- (IBAction)changeLayoutMode:(nullable id)sender;

- (IBAction)alignLeft:(nullable id)sender;
- (IBAction)alignRight:(nullable id)sender;
- (IBAction)alignCenter:(nullable id)sender;
- (IBAction)alignJustified:(nullable id)sender;
- (IBAction)underline:(nullable id)sender;

- (IBAction)loosenKerning:(nullable id)sender;
- (IBAction)tightenKerning:(nullable id)sender;
- (IBAction)turnOffKerning:(nullable id)sender;
- (IBAction)useStandardKerning:(nullable id)sender;

- (IBAction)lowerBaseline:(nullable id)sender;
- (IBAction)raiseBaseline:(nullable id)sender;
- (IBAction)superscript:(nullable id)sender;
- (IBAction)subscript:(nullable id)sender;
- (IBAction)unscript:(nullable id)ssender;

- (IBAction)verticalAlign:(nullable id)sender;
- (IBAction)convertToShape:(nullable id)sender;
- (IBAction)convertToShapeGroup:(nullable id)sender;
- (IBAction)convertToTextShape:(nullable id)sender;
- (IBAction)convertToPath:(nullable id)sender;

- (IBAction)paste:(nullable id)sender;
- (IBAction)capitalize:(nullable id)sender;

- (IBAction)takeTextAlignmentFromSender:(nullable id)sender;
- (IBAction)takeTextVerticalAlignmentFromSender:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
