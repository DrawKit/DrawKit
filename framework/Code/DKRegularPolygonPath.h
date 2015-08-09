/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawablePath.h"

/**
Implements a regular polygon and variations of it (stars and other similar shapes)

The innerRadius, tip and valley spread values are all relative to the main (outer) radius, so the shape's path is stable with respect to scale. A -ve
value for the inner radius turns off the secondary radius altogether, allowing ordinary regular polygons.

the tip spread is the roundness of the tips or outer vertices of a star or polygon shape, the valley spread is the roundness of the inner vertices of
a star shape (not used if the inner radius is -ve).
*/
@interface DKRegularPolygonPath : DKDrawablePath <NSCopying, NSCoding> {
@private
	NSInteger mVertices; // # of vertices
	NSPoint mCentre; // centre (location)
	CGFloat mOuterRadius; // radius
	CGFloat mInnerRadius; // inner radius of star-type shapes
	CGFloat mTipSpread; // spread of tips
	CGFloat mValleySpread; // spread of star "valleys"
	CGFloat mAngle; // overall rotation angle
	BOOL mShowSpreadControls; // YES to display spread controls as knobs
}

- (void)setNumberOfSides:(NSInteger)sides;
- (CGFloat)numberOfSides;

- (void)setRadius:(CGFloat)rad;
- (CGFloat)radius;

- (void)setInnerRadius:(CGFloat)innerRad;
- (CGFloat)innerRadius;

- (void)setTipSpread:(CGFloat)spread;
- (CGFloat)tipSpread;

- (void)setValleySpread:(CGFloat)spread;
- (CGFloat)valleySpread;

- (void)setShowsSpreadControls:(BOOL)showControls;
- (BOOL)showsSpreadControls;

- (IBAction)convertToPath:(id)sender;
- (IBAction)setNumberOfSidesWithTag:(id)sender;

- (BOOL)isStar;

@end

// partcodes - partcodes for each vertex are sequentially numbered from 3 upwards

enum {
	kDKRegularPolyCentrePart = 1,
	kDKRegularPolyTipSpreadPart = 2,
	kDKRegularPolyValleySpreadPart = 3,
	kDKRegularPolyRotationPart = 4,
	kDKRegularPolyFirstVertexPart = 5 // must be odd
};

enum {
	kDKRegularPolyCreationMode = 7
};
