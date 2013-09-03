//
//  DKTextShape.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 16/09/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKDrawableShape.h"
#import "DKCommonTypes.h"


@class DKDrawingView, DKShapeGroup, DKTextAdornment;



@interface DKTextShape : DKDrawableShape <NSCoding, NSCopying>
{
@private
	DKTextAdornment*		mTextAdornment;				// handles the text storage, layout and rendering of the text
	NSTextView*				m_editorRef;				// when editing, a reference to the editor view
	BOOL					mIsSettingStyle;			// flags text being set by style
	
#ifdef DRAWKIT_DEPRECATED
	NSTextStorage*			m_text;						// the text
	NSRect					m_textRect;					// rect of the text relative to the final shape
	DKVerticalTextAlignment	m_vertAlign;				// vertical text alignment
	BOOL					m_ignoreStyleAttributes;	// YES to keep the text attributes distinct from style
	CGFloat					mVerticalAlignmentAmount;	// value between 0..1 to set v align in prop mode
#endif
}

// convenience constructors:

+ (DKTextShape*)			textShapeWithString:(NSString*) str inRect:(NSRect) bounds;
+ (DKTextShape*)			textShapeWithRTFData:(NSData*) rtfData inRect:(NSRect) bounds;
+ (DKTextShape*)			textShapeWithAttributedString:(NSAttributedString*) str;

// setting class defaults:

+ (void)					setDefaultTextString:(NSString*) str;
+ (NSString*)				defaultTextString;
+ (Class)					textAdornmentClass;
+ (NSArray*)				pastableTextTypes;

+ (NSBezierPath*)			textOverflowIndicatorPath;
+ (void)					setShowsTextOverflowIndicator:(BOOL) overflowShown;
+ (BOOL)					showsTextOverflowIndicator;

+ (void)					setAllowsInlineImages:(BOOL) allowed;
+ (BOOL)					allowsInlineImages;

// the text:

- (void)					setText:(id) contents;
- (NSTextStorage*)			text;
- (NSString*)				string;
- (void)					sizeVerticallyToFitText;

// pasteboard ops:

- (void)					pasteTextFromPasteboard:(NSPasteboard*) pb ignoreFormatting:(BOOL) fmt;
- (BOOL)					canPasteText:(NSPasteboard*) pb;

// text layout and drawing:

- (NSSize)					minSize;
- (NSSize)					maxSize;
- (NSSize)					idealTextSize;

// conversion to path/shape with text path:

- (NSBezierPath*)			textPath;
- (NSArray*)				textPathGlyphs;
- (NSArray*)				textPathGlyphsUsedSize:(NSSize*) textSize;
- (DKDrawableShape*)		makeShapeWithText;
- (DKShapeGroup*)			makeShapeGroupWithText;
- (DKStyle*)				styleWithTextAttributes;
- (DKStyle*)				syntheticStyle;

// text attributes - accesses the internal adornment object

- (NSDictionary*)			textAttributes;
- (void)					updateFontPanel;

// setting text attributes for the entire text:

- (void)					setFont:(NSFont*) font;
- (NSFont*)					font;
- (void)					setFontSize:(CGFloat) size;
- (CGFloat)					fontSize;
- (void)					setTextColour:(NSColor*) colour;
- (NSColor*)				textColour;

- (void)					scaleTextBy:(CGFloat) factor;

// paragraph style attributes:

- (void)					setVerticalAlignment:(DKVerticalTextAlignment) align;
- (DKVerticalTextAlignment)	verticalAlignment;
- (void)					setVerticalAlignmentProportion:(CGFloat) prop;
- (CGFloat)					verticalAlignmentProportion;
- (void)					setParagraphStyle:(NSParagraphStyle*) ps;
- (NSParagraphStyle*)		paragraphStyle;
- (void)					setAlignment:(NSTextAlignment) align;
- (NSTextAlignment)			alignment;

// layout within the text object:

- (void)					setLayoutMode:(DKTextLayoutMode) mode;
- (DKTextLayoutMode)		layoutMode;
- (void)					setWrapsLines:(BOOL) wraps;
- (BOOL)					wrapsLines;

// editing the text:

- (void)					startEditingInView:(DKDrawingView*) view;
- (void)					endEditing;
- (BOOL)					isEditing;
- (DKTextAdornment*)		textAdornment;
- (void)					setTextAdornment:(DKTextAdornment*) adornment;

// user actions:

- (IBAction)				changeFont:(id) sender;
- (IBAction)				changeFontSize:(id) sender;
- (IBAction)				changeAttributes:(id) sender;
- (IBAction)				editText:(id) sender;

- (IBAction)				changeLayoutMode:(id) sender;

- (IBAction)				alignLeft:(id) sender;
- (IBAction)				alignRight:(id) sender;
- (IBAction)				alignCenter:(id) sender;
- (IBAction)				alignJustified:(id) sender;
- (IBAction)				underline:(id) sender;

- (IBAction)				loosenKerning:(id) sender;
- (IBAction)				tightenKerning:(id) sender;
- (IBAction)				turnOffKerning:(id)sender;
- (IBAction)				useStandardKerning:(id) sender;

- (IBAction)				lowerBaseline:(id) sender;
- (IBAction)				raiseBaseline:(id) sender;
- (IBAction)				superscript:(id) sender;
- (IBAction)				subscript:(id) sender;
- (IBAction)				unscript:(id) ssender;

- (IBAction)				fitToText:(id) sender;
- (IBAction)				verticalAlign:(id) sender;
- (IBAction)				convertToShape:(id) sender;
- (IBAction)				convertToShapeGroup:(id) sender;
- (IBAction)				convertToTextPath:(id) sender;

- (IBAction)				paste:(id) sender;
- (IBAction)				capitalize:(id) sender;

- (IBAction)				takeTextAlignmentFromSender:(id) sender;
- (IBAction)				takeTextVerticalAlignmentFromSender:(id) sender;

@end


// the following methods are deprecated, many are now no-ops.

#ifdef DRAWKIT_DEPRECATED

@interface DKTextShape (Deprecated)

- (NSPoint)					textOriginForSize:(NSSize) textSize;

@end

#endif

extern NSString*	kDKTextOverflowIndicatorDefaultsKey;
extern NSString*	kDKTextAllowsInlineImagesDefaultsKey;

/*
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
