/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKRasterizer.h"
#import "DKCommonTypes.h"

@class DKStyle, DKTextSubstitutor;

/** @brief This renderer allows text to be an attribute of any object.

This renderer allows text to be an attribute of any object.

This renderer also implements text-on-a-path. To do this, set the layoutMode to kDKTextLayoutAlongPath. Some attributes are ignored in
this mode such as angle and vertical alignment. However all textual attributes are honoured.
 
Text adornments extensively cache information internally to speed drawing by avoiding recalculation of various things. The cache is a
dictionary which can store many different cached items. The cache is invalidated by changes arising in the client object and in the
state of internal data, and in addition the same cache is passed to text-on-path and other lower level methods which they use to avoid
similar lengthy recalculations. The caching is transparent to client objects but may need to be taken into account if subclassing or
using alternative helper objects, etc.

The text content is stored and suplied by DKTextSubstitutor which is able to build strings by reading an object's metadata and combining it with
other fixed content. See that class for details.
*/
@interface DKTextAdornment : DKRasterizer <NSCoding, NSCopying> {
@private
	DKTextSubstitutor* mSubstitutor; // stores master string & performs substitutions on specially formatted strings
	NSString* mPlaceholder; // placeholder string
	NSRect m_textRect; // layout rect
	CGFloat m_angle; // independent text angle
	DKVerticalTextAlignment m_vertAlign; // vertical text alignment
	DKTextLayoutMode m_layoutMode; // layout modes - wrap in box, shape or along path
	DKTextCapitalization mCapitalization; // capitalization mode
	DKGreeking mGreeking; // greeking mode
	BOOL m_wrapLines; // YES to wrap into the text rect, NO for single line
	BOOL m_applyObjectAngle; // YES to add the object's angle to the text angle
	CGFloat mFlowedTextPathInset; // inset the layout path by this much before laying out the text
	BOOL mAllowIndefiniteWidth; // YES to allow unwrapped text to extend as much as it needs to horizontally
	BOOL mLastLayoutFittedAllText; // flags whether most recent rendering drew all the text
	CGFloat mVerticalPosition; // for proportional vertical text placement, this is the proportion 0..1 of the height
	CGFloat mTextKnockoutDistance; // distance to extend path when drawing knockout; 0 = no knockout.
	CGFloat mTextKnockoutStrokeWidth; // stroke width for text knockout, if any (0 = none)
	NSColor* mTextKnockoutColour; // colour for text knockout, default = white
	NSColor* mTextKnockoutStrokeColour; // colour for stroking the text knockout, default = black
	NSMutableDictionary* mTACache; // private cache used for various text layout caching
	NSDictionary* mDefaultAttributes; // saves default attributes for when text is deleted altogether
}

// convenience constructor:

+ (DKTextAdornment*)textAdornmentWithText:(id)anySortOfText;

// class defaults:

+ (NSDictionary*)defaultTextAttributes;
+ (NSString*)defaultLabel;
+ (CGFloat)defaultMaximumVerticalOffset;
+ (void)setDefaultMaximumVerticalOffset:(CGFloat)mvo;

// the text:

- (NSString*)string;
- (void)setLabel:(id)anySortOfText;
- (NSAttributedString*)label;
- (NSTextStorage*)textToDraw:(id)object;
- (NSTextStorage*)textForEditing;

// placeholder text - shown if the adornment would otherwise draw nothing

- (void)setPlaceholderString:(NSString*)str;
- (NSString*)placeholderString;

// text conversions:

- (NSBezierPath*)textAsPathForObject:(id)object;
- (NSArray*)textPathsForObject:(id)object usedSize:(NSSize*)aSize;
- (DKStyle*)styleFromTextAttributes;

// text layout:

- (void)setVerticalAlignment:(DKVerticalTextAlignment)placement;
- (DKVerticalTextAlignment)verticalAlignment;
- (void)setVerticalAlignmentProportion:(CGFloat)prop;
- (CGFloat)verticalAlignmentProportion;
- (CGFloat)baselineOffset;
- (CGFloat)baselineOffsetForTextHeight:(CGFloat)height;
- (CGFloat)verticalTextOffsetForObject:(id<DKRenderable>)object;
- (NSRect)textLayoutRectForObject:(id<DKRenderable>)object;
- (void)setTextRect:(NSRect)rect;
- (NSRect)textRect;

- (void)setLayoutMode:(DKTextLayoutMode)mode;
- (DKTextLayoutMode)layoutMode;

- (void)setFlowedTextPathInset:(CGFloat)inset;
- (CGFloat)flowedTextPathInset;

- (void)setAngle:(CGFloat)angle;
- (CGFloat)angle;
- (void)setAngleInDegrees:(CGFloat)degrees;
- (CGFloat)angleInDegrees;

- (void)setAppliesObjectAngle:(BOOL)aa;
- (BOOL)appliesObjectAngle;

- (void)setWrapsLines:(BOOL)wraps;
- (BOOL)wrapsLines;
- (void)setAllowsTextToExtendHorizontally:(BOOL)extend;
- (BOOL)allowsTextToExtendHorizontally;

// text masking or "knockouts":

- (void)setTextKnockoutDistance:(CGFloat)distance;
- (CGFloat)textKnockoutDistance;
- (void)setTextKnockoutStrokeWidth:(CGFloat)width;
- (CGFloat)textKnockoutStrokeWidth;
- (void)setTextKnockoutColour:(NSColor*)colour;
- (NSColor*)textKnockoutColour;
- (void)setTextKnockoutStrokeColour:(NSColor*)colour;
- (NSColor*)textKnockoutStrokeColour;

// modifying text when drawn:

- (void)setCapitalization:(DKTextCapitalization)cap;
- (DKTextCapitalization)capitalization;

- (void)setGreeking:(DKGreeking)greeking;
- (DKGreeking)greeking;

// text attributes:

- (void)changeFont:(id)sender;
- (void)changeAttributes:(id)sender;

- (void)setFont:(NSFont*)font;
- (NSFont*)font;

- (void)setFontSize:(CGFloat)fontSize;
- (CGFloat)fontSize;
- (void)scaleTextBy:(CGFloat)factor;

- (void)setColour:(NSColor*)colour;
- (NSColor*)colour;

- (void)setTextAttributes:(NSDictionary*)attrs;
- (NSDictionary*)textAttributes;
- (NSDictionary*)defaultTextAttributes;
- (BOOL)attributeIsHomogeneous:(NSString*)attributeName;
- (BOOL)isHomogeneous;

// paragraph styles:

- (void)setParagraphStyle:(NSParagraphStyle*)style;
- (NSParagraphStyle*)paragraphStyle;

- (void)setAlignment:(NSTextAlignment)align;
- (NSTextAlignment)alignment;

- (void)setBackgroundColour:(NSColor*)colour;
- (NSColor*)backgroundColour;

- (void)setOutlineColour:(NSColor*)aColour;
- (NSColor*)outlineColour;

- (void)setOutlineWidth:(CGFloat)aWidth;
- (CGFloat)outlineWidth;

- (void)setUnderlines:(NSInteger)under;
- (NSInteger)underlines;

- (void)setKerning:(CGFloat)kernValue;
- (CGFloat)kerning;

- (void)setBaseline:(CGFloat)baseLine;
- (CGFloat)baseline;

- (void)setSuperscriptAttribute:(NSInteger)amount;
- (NSInteger)superscriptAttribute;

- (void)loosenKerning;
- (void)tightenKerning;
- (void)turnOffKerning;
- (void)useStandardKerning;
- (void)lowerBaseline;
- (void)raiseBaseline;
- (void)superscript;
- (void)subscript;
- (void)unscript;

// the substitutor object, which supplies the text content:

- (void)setTextSubstitutor:(DKTextSubstitutor*)subs;
- (DKTextSubstitutor*)textSubstitutor;

- (BOOL)allTextWasFitted;

- (void)invalidateCache;

- (void)drawInRect:(NSRect)aRect;

@end

@interface DKTextAdornment (Deprecated)

- (void)setIdentifier:(NSString*)ident;
- (NSString*)identifier;

@end

// objects can implement this method if they wish to support the 'centroid' layout mode. While intended for
// positioning text at the centroid, the object is not required to return the true centroid - it can be any point.
// In this mode text is laid out in one line centred on the point with no clipping.

@interface NSObject (TextLayoutProtocol)

- (NSPoint)pointForTextLayout;

@end

#define DEFAULT_BASELINE_OFFSET_MAX 16

// these keys are used to access text adornment properties in the -textAttributes dictionary. Using this dictionary allows these settings to
// be more portable especially when cuttign and pasting styles between objects. These are placed alongside any Cocoa attributes defined in the
// same dictionary.

extern NSString* DKTextKnockoutColourAttributeName;
extern NSString* DKTextKnockoutDistanceAttributeName;
extern NSString* DKTextKnockoutStrokeColourAttributeName;
extern NSString* DKTextKnockoutStrokeWidthAttributeName;
extern NSString* DKTextVerticalAlignmentAttributeName;
extern NSString* DKTextVerticalAlignmentProportionAttributeName;
extern NSString* DKTextCapitalizationAttributeName;
