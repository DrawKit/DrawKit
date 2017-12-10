/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

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

/**  */
+ (NSBezierPath*)bezierPathWithStandardChainLink;
+ (NSBezierPath*)bezierPathWithStandardChainLinkFromPoint:(NSPoint)a toPoint:(NSPoint)b;
+ (NSBezierPath*)bezierPathWithSprocketPitch:(CGFloat)pitch numberOfTeeth:(NSInteger)teeth;

// nuts and bolts

+ (NSBezierPath*)bezierPathWithThreadedBarOfLength:(CGFloat)length diameter:(CGFloat)dia threadPitch:(CGFloat)pitch options:(DKShapeOptions)options;
+ (NSBezierPath*)bezierPathWithThreadLinesOfLength:(CGFloat)length diameter:(CGFloat)dia threadPitch:(CGFloat)pitch;
+ (NSBezierPath*)bezierPathWithHexagonHeadSideViewOfHeight:(CGFloat)height diameter:(CGFloat)dia options:(DKShapeOptions)options;
+ (NSBezierPath*)bezierPathWithBoltOfLength:(CGFloat)length
							 threadDiameter:(CGFloat)tdia
								threadPitch:(CGFloat)tpitch
							   headDiameter:(CGFloat)hdia
								 headHeight:(CGFloat)hheight
								shankLength:(CGFloat)shank
									options:(DKShapeOptions)options;

// crop marks, etc

+ (NSBezierPath*)bezierPathWithCropMarksForRect:(NSRect)aRect length:(CGFloat)length extension:(CGFloat)ext;
+ (NSBezierPath*)bezierPathWithCropMarksForRect:(NSRect)aRect extension:(CGFloat)ext;

@end

