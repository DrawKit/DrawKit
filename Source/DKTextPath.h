/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKDrawablePath.h"
#import "DKCommonTypes.h"

@class DKTextAdornment, DKDrawingView;

/** @brief Very similar to a DKTextShape but based on a path and defaulting to text-on-a-path rendering.

Very similar to a DKTextShape but based on a path and defaulting to text-on-a-path rendering. Has virtually identical public API to DKTextShape.
*/
@interface DKTextPath : DKDrawablePath <NSCopying, NSCoding> {
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
- (NSArray<NSBezierPath*>*)textPathGlyphsUsedSize:(NSSize*)textSize;
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

@property (nonatomic, strong) DKTextAdornment *textAdornment;

// user actions:

- (IBAction)changeFont:(id)sender;
- (IBAction)changeFontSize:(id)sender;
- (IBAction)changeAttributes:(id)sender;
- (IBAction)editText:(id)sender;

- (IBAction)changeLayoutMode:(id)sender;

- (IBAction)alignLeft:(id)sender;
- (IBAction)alignRight:(id)sender;
- (IBAction)alignCenter:(id)sender;
- (IBAction)alignJustified:(id)sender;
- (IBAction)underline:(id)sender;

- (IBAction)loosenKerning:(id)sender;
- (IBAction)tightenKerning:(id)sender;
- (IBAction)turnOffKerning:(id)sender;
- (IBAction)useStandardKerning:(id)sender;

- (IBAction)lowerBaseline:(id)sender;
- (IBAction)raiseBaseline:(id)sender;
- (IBAction)superscript:(id)sender;
- (IBAction)subscript:(id)sender;
- (IBAction)unscript:(id)ssender;

- (IBAction)verticalAlign:(id)sender;
- (IBAction)convertToShape:(id)sender;
- (IBAction)convertToShapeGroup:(id)sender;
- (IBAction)convertToTextShape:(id)sender;
- (IBAction)convertToPath:(id)sender;

- (IBAction)paste:(id)sender;
- (IBAction)capitalize:(id)sender;

- (IBAction)takeTextAlignmentFromSender:(id)sender;
- (IBAction)takeTextVerticalAlignmentFromSender:(id)sender;

@end
