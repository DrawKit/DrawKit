/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// options:
typedef NS_OPTIONS(NSUInteger, DKShapeOptions) {
	kThreadedBarLeftEndCapped = 1 << 0,
	kThreadedBarRightEndCapped = 1 << 1,
	kThreadedBarThreadLinesDrawn = 1 << 2,
	kFastenerCentreLine = 1 << 3,
	kFastenerHasCapHead = 1 << 4,
	kHexFastenerFaceCurvesDrawn = 1 << 5
};

/**
A category on NSBezierPath for creating various unusual shape paths, particularly for engineering use
*/
@interface NSBezierPath (Shapes)

// chains and sprockets

/**
 Returns the path of a standard roller chain link on a horizontal alignment with link centres of 1.0. Other variants are derived from this
 using transformations of this path.
*/
+ (NSBezierPath*)bezierPathWithStandardChainLink;
/** returns the path of a standard roller chain link linking \c a to <code>b</code>. The distance \c a-b also sets the dimensions of the link and of course
 its angle. The pin centres are aligned on \c a and <code>b</code>.
 */
+ (NSBezierPath*)bezierPathWithStandardChainLinkFromPoint:(NSPoint)a toPoint:(NSPoint)b;
/** returns a path representing a roller chain sprocket having the pitch and number of teeeth specified. The sprocket is centred at the
 origin and is sized as needed to accommodate the number of teeth required.
 */
+ (NSBezierPath*)bezierPathWithSprocketPitch:(CGFloat)pitch numberOfTeeth:(NSInteger)teeth;

// nuts and bolts

/** path consists of zig-zags along the top and bottom edges with a 60° angle, optionally capped and with joining lines.
 */
+ (NSBezierPath*)bezierPathWithThreadedBarOfLength:(CGFloat)length diameter:(CGFloat)dia threadPitch:(CGFloat)pitch options:(DKShapeOptions)options;
+ (NSBezierPath*)bezierPathWithThreadLinesOfLength:(CGFloat)length diameter:(CGFloat)dia threadPitch:(CGFloat)pitch;

/** produces the side-on view of a hex head or nut. The diameter is the across-flats dimension: the diameter of the circle inscribed
 within the hexagon. The resulting path shows the head oriented with its peaks set north-south so the height returned is larger than
 the diameter by <code>2 * 1/sin 60</code>.
 */
+ (NSBezierPath*)bezierPathWithHexagonHeadSideViewOfHeight:(CGFloat)height diameter:(CGFloat)dia options:(DKShapeOptions)options;
+ (NSBezierPath*)bezierPathWithBoltOfLength:(CGFloat)length
							 threadDiameter:(CGFloat)tdia
								threadPitch:(CGFloat)tpitch
							   headDiameter:(CGFloat)hdia
								 headHeight:(CGFloat)hheight
								shankLength:(CGFloat)shank
									options:(DKShapeOptions)options;

// crop marks, etc

/** The path follows the edges of <code>aRect</code>, consisting of four pairs of lines that intersect at the corners. \c length sets the
 length of the mark along the rect edge and \c ext sets the overhang outside of the rect.
 */
+ (NSBezierPath*)bezierPathWithCropMarksForRect:(NSRect)aRect length:(CGFloat)length extension:(CGFloat)ext;
+ (NSBezierPath*)bezierPathWithCropMarksForRect:(NSRect)aRect extension:(CGFloat)ext;

@end

NS_ASSUME_NONNULL_END
