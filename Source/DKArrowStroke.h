/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKStroke.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DKArrowSrokeDimensioning;

/** @brief arrow head kinds - each end can be specified independently:
 */
typedef NS_ENUM(NSInteger, DKArrowHeadKind) {
	kDKArrowHeadNone = 0,
	kDKArrowHeadStandard = 1,
	kDKArrowHeadInflected = 2,
	kDKArrowHeadRound = 3,
	kDKArrowHeadSingleFeather = 4,
	kDKArrowHeadDoubleFeather = 5,
	kDKArrowHeadTripleFeather = 6,
	kDKArrowHeadDimensionLine = 7,
	kDKArrowHeadDimensionLineAndBar = 8,
	kDKArrowHeadSquare = 9,
	kDKArrowHeadDiamond = 10
};

/** @brief positioning of dimension label, or none:
 */
typedef NS_ENUM(NSInteger, DKDimensioningLineOptions) {
	kDKDimensionNone = 0,
	kDKDimensionPlaceAboveLine = 1,
	kDKDimensionPlaceInLine = 2,
	kDKDimensionPlaceBelowLine = 3
};

/** @brief dimension kind - sets additional embellishments on the dimension text:
 */
typedef NS_ENUM(NSInteger, DKDimensionTextKind) {
	kDKDimensionLinear = 0,
	kDKDimensionDiameter = 1,
	kDKDimensionRadius = 2,
	kDKDimensionAngle = 3
};

/** @brief tolerance options:
 */
typedef NS_ENUM(NSInteger, DKDimensionToleranceOption) {
	kDKDimensionToleranceNotShown = 0,
	kDKDimensionToleranceShown = 1
};

// the class:

/** @brief DKArrowStroke is a rasterizer that implements arrowheads on the ends of paths.

 DKArrowStroke is a rasterizer that implements arrowheads on the ends of paths. The heads are drawn by filling the
 arrowhead using the same colour as the stroke, thus seamlessly blending the head into the path. Where multiple
 strokes are used, the resulting effect should be correct when angles are kept the same and lengths are calculated
 from the stroke width.
*/
@interface DKArrowStroke : DKStroke <NSCoding, NSCopying> {
@private
	DKArrowHeadKind mArrowHeadAtStart;
	DKArrowHeadKind mArrowHeadAtEnd;
	CGFloat m_arrowLength;
	CGFloat m_arrowWidth;
	DKDimensioningLineOptions mDimensionOptions;
	NSNumberFormatter* m_dims_formatter;
	NSColor* m_outlineColour;
	CGFloat m_outlineWidth;
	DKDimensionTextKind mDimTextKind;
	DKDimensionToleranceOption mDimToleranceOptions;
}

@property (class, retain /*, null_resettable*/) NSDictionary<NSAttributedStringKey,id> *dimensioningLineTextAttributes;
@property (class, readonly, retain) DKArrowStroke *standardDimensioningLine;
+ (NSNumberFormatter*)defaultDimensionLineFormatter;

// head kind at each end

@property DKArrowHeadKind arrowHeadAtStart;
@property DKArrowHeadKind arrowHeadAtEnd;

// head widths and lengths (some head kinds may set these also)

@property CGFloat arrowHeadWidth;
@property CGFloat arrowHeadLength;

- (void)standardArrowForStrokeWidth:(CGFloat)sw;

#ifdef DRAWKIT_DEPRECATED
- (void)setOutlineColour:(NSColor*)colour width:(CGFloat)width;
#endif

@property (copy) NSColor *outlineColour;
@property CGFloat outlineWidth;

- (NSImage*)arrowSwatchImageWithSize:(NSSize)size strokeWidth:(CGFloat)width;
- (NSImage*)standardArrowSwatchImage;

- (nullable NSBezierPath*)arrowPathFromOriginalPath:(NSBezierPath*)inPath fromObject:(id)obj;

// dimensioning lines:

@property (strong) NSNumberFormatter *formatter;
- (void)setFormat:(NSString*)format;

@property (nonatomic) DKDimensioningLineOptions dimensioningLineOptions;

- (nullable NSAttributedString*)dimensionTextForObject:(nullable id<DKArrowSrokeDimensioning>)obj;
- (CGFloat)widthOfDimensionTextForObject:(id)obj;
- (NSString*)toleranceTextForObject:(id)object;

@property (nonatomic) DKDimensionTextKind dimensionTextKind;

@property DKDimensionToleranceOption dimensionToleranceOption;

@property (copy) NSDictionary<NSAttributedStringKey,id> *textAttributes;
@property (strong) NSFont *font;

@end

/** @brief informal protocol for requesting dimension information from an object.

 If it does not respond, the rasterizer infers the values from the path length and its internal values.
 */
@protocol DKArrowSrokeDimensioning <NSObject>

- (NSDictionary*)dimensionValuesForArrowStroke:(DKArrowStroke*)arrowStroke;

@end

#define kDKStandardArrowSwatchImageSize (NSMakeSize(80.0, 9.0))
#define kDKStandardArrowSwatchStrokeWidth 3.0

extern NSString* const kDKPositiveToleranceKey;
extern NSString* const kDKNegativeToleranceKey;
extern NSString* const kDKDimensionValueKey;
extern NSString* const kDKDimensionUnitsKey;

NS_ASSUME_NONNULL_END
