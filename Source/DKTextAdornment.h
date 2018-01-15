/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKRasterizer.h"
#import "DKCommonTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class DKStyle, DKTextSubstitutor;

/** @brief This renderer allows text to be an attribute of any object.

 @discussion This renderer allows text to be an attribute of any object.
 
 This renderer also implements text-on-a-path. To do this, set the layoutMode to kDKTextLayoutAlongPath. Some attributes are ignored in
 this mode such as angle and vertical alignment. However all textual attributes are honoured.
 
 Text adornments extensively cache information internally to speed drawing by avoiding recalculation of various things. The cache is a
 dictionary which can store many different cached items. The cache is invalidated by changes arising in the client object and in the
 state of internal data, and in addition the same cache is passed to text-on-path and other lower level methods which they use to avoid
 similar lengthy recalculations. The caching is transparent to client objects but may need to be taken into account if subclassing or
 using alternative helper objects, etc.

 The text content is stored and suplied by \c DKTextSubstitutor which is able to build strings by reading an object's metadata and combining it with
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

@property (class, readonly, strong) NSDictionary<NSAttributedStringKey,id> *defaultTextAttributes;
@property (class, readonly, copy) NSString *defaultLabel;
@property (class) CGFloat defaultMaximumVerticalOffset;

// the text:

@property (readonly, copy) NSString *string;
- (void)setLabel:(id)anySortOfText;
- (NSAttributedString*)label;
- (NSTextStorage*)textToDraw:(id)object;
- (NSTextStorage*)textForEditing;

/** @brief placeholder text - shown if the adornment would otherwise draw nothing
 */
@property (copy) NSString *placeholderString;

// text conversions:

- (nullable NSBezierPath*)textAsPathForObject:(id)object;
- (nullable NSArray<NSBezierPath*>*)textPathsForObject:(id)object usedSize:(nullable NSSize*)aSize;
- (DKStyle*)styleFromTextAttributes;

// text layout:

/** @brief for proportional vertical text placement, this is the proportion 0..1 of the height
 */
@property (nonatomic) CGFloat verticalAlignmentProportion;
@property (readonly) CGFloat baselineOffset;
- (CGFloat)baselineOffsetForTextHeight:(CGFloat)height;
- (CGFloat)verticalTextOffsetForObject:(id<DKRenderable>)object;
- (NSRect)textLayoutRectForObject:(id<DKRenderable>)object;

/** @brief vertical text alignment
 */
@property (nonatomic) DKVerticalTextAlignment verticalAlignment;

/** @brief layout rect
 
 The \c textRect defines a rect relative to the shape's original path bounds that the text is laid out in. If you pass \c NSZeroRect (the default), the text
 is laid out using the shape's bounds. This additional rect gives you the flexibility to modify the text layout to anywhere within the shape. Note the
 coordinate system it uses is transformed by the shape's transform - so if you wanted to lay the text out in half the shape's width, the rect's width
 would be 0.5. Similarly, to offset the text halfway across, its origin would be 0. This means this rect maintains its correct effect no matter how
 the shape is scaled or rotated, and it does the thing you expect. Otherwise it would have to be recalculated for every new shape size.
*/
@property NSRect textRect;

/** @brief layout modes - wrap in box, shape or along path
 */
@property (nonatomic) DKTextLayoutMode layoutMode;

/** @brief inset the layout path by this much before laying out the text
 */
@property (nonatomic) CGFloat flowedTextPathInset;

/** @brief Independent text angle, in radians.
 */
@property (nonatomic) CGFloat angle;
/** @brief Independent text angle, in degrees.
 */
@property CGFloat angleInDegrees;

/** @brief \c YES to add the object's angle to the text angle
 */
@property (nonatomic) BOOL appliesObjectAngle;

/** @brief \c YES to wrap into the text rect, \c NO for single line
 */
@property (nonatomic) BOOL wrapsLines;
/** @brief YES to allow unwrapped text to extend as much as it needs to horizontally
 */
@property BOOL allowsTextToExtendHorizontally;

// text masking or "knockouts":

/** @brief distance to extend path when drawing knockout; 0 = no knockout.
 */
@property (nonatomic) CGFloat textKnockoutDistance;
/** @brief stroke width for text knockout, if any (0 = none)
 */
@property CGFloat textKnockoutStrokeWidth;
/** @brief colour for text knockout, default = white
 */
@property (strong) NSColor *textKnockoutColour;
/** @brief colour for stroking the text knockout, default = black
 */
@property (strong) NSColor *textKnockoutStrokeColour;

// modifying text when drawn:

/** @brief capitalization mode
 */
@property (nonatomic) DKTextCapitalization capitalization;

/** @brief greeking mode
 
 greeking is a text rendition method that substitutes simple rectangles for the actual drawn glyphs. It can be used to render extremely small point text
 more quickly, or to give an impression of text. It is rarely used, but can be handy for hit-testing where the exact glyphs are not required and don't work
 well when rendered using scaling to small bitmap contexts (as when hit-testing).
 
 currently the greeking setting is considered temporary so isn't archived or exported as an observable property
*/
@property DKGreeking greeking;

// text attributes:

- (void)changeFont:(nullable id)sender;
- (void)changeAttributes:(nullable id)sender;

@property (strong) NSFont *font;

@property CGFloat fontSize;
- (void)scaleTextBy:(CGFloat)factor;

@property (strong) NSColor *colour;

@property (copy) NSDictionary<NSAttributedStringKey,id> *textAttributes;
/** @brief returns text attributes to be used when there is no text content at present. These will either be what was previously set or the class
 default.
*/
@property (readonly, strong) NSDictionary<NSAttributedStringKey,id> *defaultTextAttributes;
/** @brief asks whether a given attribute applies over the entire length of the string.
*/
- (BOOL)attributeIsHomogeneous:(NSAttributedStringKey)attributeName;
/** @brief asks whether all attributes apply over the whole length of the string
 */
@property (readonly, getter=isHomogeneous) BOOL homogeneous;

// paragraph styles:

@property (strong) NSParagraphStyle*paragraphStyle;
@property NSTextAlignment alignment;
@property (strong) NSColor *backgroundColour;
@property (strong) NSColor *outlineColour;
@property CGFloat outlineWidth;
@property NSInteger underlines;
@property CGFloat kerning;
@property CGFloat baseline;
@property NSInteger superscriptAttribute;

- (void)loosenKerning;
- (void)tightenKerning;
- (void)turnOffKerning;
- (void)useStandardKerning;
- (void)lowerBaseline;
- (void)raiseBaseline;
- (void)superscript;
- (void)subscript;
- (void)unscript;

/** @brief the substitutor object, which supplies the text content:
 */
@property (nonatomic, strong) DKTextSubstitutor *textSubstitutor;

@property (readonly) BOOL allTextWasFitted;

- (void)invalidateCache;

- (void)drawInRect:(NSRect)aRect;

@end

@interface DKTextAdornment (Deprecated)

- (void)setIdentifier:(null_unspecified NSString*)ident DEPRECATED_ATTRIBUTE;
- (null_unspecified NSString*)identifier DEPRECATED_ATTRIBUTE;

@end

/**
 objects can implement this method if they wish to support the 'centroid' layout mode. While intended for
 positioning text at the centroid, the object is not required to return the true centroid - it can be any point.
 In this mode text is laid out in one line centred on the point with no clipping.
 */
@protocol DKTextLayoutProtocol <DKRenderable>

- (NSPoint)pointForTextLayout;

@end

#define DEFAULT_BASELINE_OFFSET_MAX 16

// these keys are used to access text adornment properties in the -textAttributes dictionary. Using this dictionary allows these settings to
// be more portable especially when cutting and pasting styles between objects. These are placed alongside any Cocoa attributes defined in the
// same dictionary.

extern NSAttributedStringKey const DKTextKnockoutColourAttributeName;
extern NSAttributedStringKey const DKTextKnockoutDistanceAttributeName;
extern NSAttributedStringKey const DKTextKnockoutStrokeColourAttributeName;
extern NSAttributedStringKey const DKTextKnockoutStrokeWidthAttributeName;
extern NSAttributedStringKey const DKTextVerticalAlignmentAttributeName;
extern NSAttributedStringKey const DKTextVerticalAlignmentProportionAttributeName;
extern NSAttributedStringKey const DKTextCapitalizationAttributeName;

NS_ASSUME_NONNULL_END
