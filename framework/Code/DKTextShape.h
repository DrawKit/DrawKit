/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawableShape.h"
#import "DKCommonTypes.h"

@class DKDrawingView, DKShapeGroup, DKTextAdornment;

/** @brief Text shapes are shapes that draw text.

Text shapes are shapes that draw text. 
 
 For b5 and later this object has been redesigned to harmonise text handling to common classes within the framework. This has numerous advantages such as fewer bugs and
 more flexibility. Now, a text shape has a DKTextAdornment property that is independent of its style. This T/A handles the text storage, layout and rendering of the text
 just as it does when contained by a style. This T/A is drawn after (on top of) all other style renderings.
 
 Because the T/A is independent of the style, it may be directly changed by text attibute operations such as font changes without concern for whether the style is locked
 or not. Unless th eobject itself is locked therefore, text attributs are always changeable. When a style is set and it has text attributes, those attributes are initially
 applied to the T/A but from then on take no further part. Thus the need to synchronise styles and local attributes disappears.
 
 The use of a T/A opens up more options for text layout such as flowed into the path, along the path as well as block text.
 
 Some methods no longer have meaning in the redesigned class and have been deprecated. Calling them is now a no-op. Reading in an old-style version of the class will be
 translated to the new approach. Some functionality has been moved to the DKTextAdornment class.
*/
@interface DKTextShape : DKDrawableShape <NSCoding, NSCopying> {
@private
	DKTextAdornment* mTextAdornment; // handles the text storage, layout and rendering of the text
	NSTextView* m_editorRef; // when editing, a reference to the editor view
	BOOL mIsSettingStyle; // flags text being set by style

#ifdef DRAWKIT_DEPRECATED
	NSTextStorage* m_text; // the text
	NSRect m_textRect; // rect of the text relative to the final shape
	DKVerticalTextAlignment m_vertAlign; // vertical text alignment
	BOOL m_ignoreStyleAttributes; // YES to keep the text attributes distinct from style
	CGFloat mVerticalAlignmentAmount; // value between 0..1 to set v align in prop mode
#endif
}

// convenience constructors:

/** @brief Create an instance of a DKTextShape with the initial string and rect.
 @param str the initial string to set
 @param bounds the bounding rectangle of the shape
 @return an autoreleased DKTextShape instance
 */
+ (DKTextShape*)textShapeWithString:(NSString*)str inRect:(NSRect)bounds;

/** @brief Create an instance of a DKTextShape with the RTF data and rect.
 @param rtfData NSData representing some RTF text
 @param bounds the bounding rectangle of the shape
 @return an autoreleased DKTextShape instance
 */
+ (DKTextShape*)textShapeWithRTFData:(NSData*)rtfData inRect:(NSRect)bounds;

/** @brief Create an instance of a DKTextShape with the given string, laid out on one line.

 The object is sized to fit the text string passed on a single line (up to a certain sensible
 maximum width). The returned object needs to be positioned where it is needed.
 @param str the string
 @return an autoreleased DKTextShape instance
 */
+ (DKTextShape*)textShapeWithAttributedString:(NSAttributedString*)str;

// setting class defaults:

/** @brief Set the initial text string for new text shape objects.

 The default is usually "Double-click to edit this text"
 @param str a string
 */
+ (void)setDefaultTextString:(NSString*)str;

/** @brief Get the initial text string for new text shape objects.

 The default is usually "Double-click to edit this text"
 @return a string
 */
+ (NSString*)defaultTextString;

/** @brief Return the class of object to create as the shape's text adornment.

 This provides an opportunity for subclasses to supply a different type of object, which must be
 a DKTextAdornment, a subclass of it, or one that implements its API.
 @return the object class
 */
+ (Class)textAdornmentClass;

/** @brief Return a list of types we can paste in priority order.

 Cocoa's -textPasteboardTypes isn't in an order that is useful to us
 @return a list of types
 */
+ (NSArray*)pastableTextTypes;

/** @brief Return a path used for indicating unlaid text in object

 The path consists of a plus sign within a square with origin at 0,0 and sides 1,1
 @return a path
 */
+ (NSBezierPath*)textOverflowIndicatorPath;

/** @brief Set whether objects of this class should display an overflow symbol when text can't be fully laid

 Setting is persistent
 @param overflowShown YES to dislay, NO otherwise
 */
+ (void)setShowsTextOverflowIndicator:(BOOL)overflowShown;

/** @brief Return whether objects of this class should display an overflow symbol when text can't be fully laid

 See also: -drawSelectedState
 @return YES to dislay, NO otherwise
 */
+ (BOOL)showsTextOverflowIndicator;

/** @brief Set whether text editing permits inline images to be pasted

 This state is persistent and ends up as the parameter to [NSTextView setImportsGraphics:]
 @param allowed YES to allow images, NO to disallow 
 */
+ (void)setAllowsInlineImages:(BOOL)allowed;

/** @brief Whether text editing permits inline images to be pasted

 This state is persistent and ends up as the parameter to [NSTextView setImportsGraphics:]
 @return YES to allow images, NO to disallow
 */
+ (BOOL)allowsInlineImages;

// the text:

- (void)setText:(id)contents;

/** @brief Get the text of the text shape

 The returned text has attributes applied wherever they come from - the style or local.
 @return the object's text
 */
- (NSTextStorage*)text;

/** @brief Get the string of the text shape

 This returns just the characters - no attributes
 @return the object's text string
 */
- (NSString*)string;

/** @brief Adjust the object's height to match the height of the current text

 Honours the minimum and maximum sizes set
 */
- (void)sizeVerticallyToFitText;

// pasteboard ops:

/** @brief Set the object's text from the pasteboard, optionally ignoring its formatting

 If the style is locked, even if fmt is NO it won't be updated.
 @param pb a pasteboard
 @param fmt YES to just paste the string and use the existing attributes, NO to update with the pasted
 */
- (void)pasteTextFromPasteboard:(NSPasteboard*)pb ignoreFormatting:(BOOL)fmt;

/** @brief Test whether the pasteboard contains any text we can paste
 @param pb a pasteboard
 @return YES if there is text of any kind that we can paste, NO otherwise
 */
- (BOOL)canPasteText:(NSPasteboard*)pb;

// text layout and drawing:

/** @brief Return the minimum size of the text layout area

 Subclasses can specify something else
 @return a size, the smallest width and height text can be laid out in
 */
- (NSSize)minSize;

/** @brief Return the maximum size of the text layout area

 Subclasses can specify something else
 @return a size, the largest width and height of the text
 */
- (NSSize)maxSize;

/** @brief Return the ideal size of the text layout area

 Returns the size needed to accommodate the text, honouring min and max and whether the shape has
 already had its size set
 @return a size, the ideal text size
 */
- (NSSize)idealTextSize;

// conversion to path/shape with text path:

/** @brief Return the current text as a path
 @return the path contains the glyphs laid out exactly as the object displays them, with the same line
 breaks, etc. The path is transformed to the object's current location and angle.
 */
- (NSBezierPath*)textPath;

/** @brief Return the individual glyph paths in an array
 @return an array containing all of the individual glyph paths (i.e. each item in the array is one letter). */
- (NSArray*)textPathGlyphs;

/** @brief Return the individual glyph paths in an array and the size used
 @param textSize receives the resulting sixe occupied by the text
 @return an array containing all of the individual glyph paths (i.e. each item in the array is one letter). */
- (NSArray*)textPathGlyphsUsedSize:(NSSize*)textSize;

/** @brief High level method turns the text into a drawable shape having the text as its path

 This tries to maintain as much fidelity as it can in terms of the text's appearance - attributes
 such as the colour and shadow are used to construct a style for the new object.
 @return a new shape object.
 */
- (DKDrawableShape*)makeShapeWithText;

/** @brief High level method turns the text into a drawable shape group having each glyph as a subobject

 Creates a group object containing individual path objects each with one letter of the text, but
 overall retaining the same spatial relationships as the original text in the shape. This allows you
 to convert text to a graphic in a way that allows you to get at each individual letter, as opposed
 to converting to a path and then breaking it apart, which goes too far in that subcurves
 within letters become separated. May fail (returning nil) if there are fewer than 2 valid paths
 submitted to make a group.
 @return a new shape group object.
 */
- (DKShapeGroup*)makeShapeGroupWithText;

/** @brief Creates a style that attempts to maintain fidelity of appearance based on the text's attributes
 @return a new style object. */
- (DKStyle*)styleWithTextAttributes;

/** @brief Creates a style that is the current style + any text attributes

 A style which is the current style if it has text attributes, otherwise the current style with added text
 attributes. When cutting or copying the object's style, this is what should be used.
 @return a new style object
 */
- (DKStyle*)syntheticStyle;

// text attributes - accesses the internal adornment object

- (NSDictionary*)textAttributes;
- (void)updateFontPanel;

// setting text attributes for the entire text:

/** @brief Sets the text's font, if permitted

 Updates the style if using it and it's not locked
 @param font a new font
 */
- (void)setFont:(NSFont*)font;

/** @brief Gets the text's font
 @return the current font
 */
- (NSFont*)font;

/** @brief Sets the text's font size, if permitted

 Updates the style if using it and it's not locked. Currently does nothing if using local attributes -
 use setFont: instead.
 @param size the point size of the font
 */
- (void)setFontSize:(CGFloat)size;

/** @brief Gets the text's font size
 @return the size of the text's current font
 */
- (CGFloat)fontSize;
- (void)setTextColour:(NSColor*)colour;
- (NSColor*)textColour;

- (void)scaleTextBy:(CGFloat)factor;

// paragraph style attributes:

- (void)setVerticalAlignment:(DKVerticalTextAlignment)align;
- (DKVerticalTextAlignment)verticalAlignment;
- (void)setVerticalAlignmentProportion:(CGFloat)prop;
- (CGFloat)verticalAlignmentProportion;
- (void)setParagraphStyle:(NSParagraphStyle*)ps;
- (NSParagraphStyle*)paragraphStyle;
- (void)setAlignment:(NSTextAlignment)align;
- (NSTextAlignment)alignment;

// layout within the text object:

- (void)setLayoutMode:(DKTextLayoutMode)mode;
- (DKTextLayoutMode)layoutMode;
- (void)setWrapsLines:(BOOL)wraps;
- (BOOL)wrapsLines;

// editing the text:

- (void)startEditingInView:(DKDrawingView*)view;
- (void)endEditing;
- (BOOL)isEditing;
- (DKTextAdornment*)textAdornment;
- (void)setTextAdornment:(DKTextAdornment*)adornment;

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

- (IBAction)fitToText:(id)sender;
- (IBAction)verticalAlign:(id)sender;
- (IBAction)convertToShape:(id)sender;
- (IBAction)convertToShapeGroup:(id)sender;
- (IBAction)convertToTextPath:(id)sender;

- (IBAction)paste:(id)sender;
- (IBAction)capitalize:(id)sender;

- (IBAction)takeTextAlignmentFromSender:(id)sender;
- (IBAction)takeTextVerticalAlignmentFromSender:(id)sender;

@end

// the following methods are deprecated, many are now no-ops.

#ifdef DRAWKIT_DEPRECATED

@interface DKTextShape (Deprecated)

- (NSPoint)textOriginForSize:(NSSize)textSize;

@end

#endif

extern NSString* kDKTextOverflowIndicatorDefaultsKey;
extern NSString* kDKTextAllowsInlineImagesDefaultsKey;
