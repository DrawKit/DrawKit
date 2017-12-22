/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKLayer.h"
#import "DKDrawing.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DKGridMeasurementSystem) {
	kDKMetricDrawingGrid = 0,
	kDKImperialDrawingGrid
};

/** @brief This class is a layer that draws a grid like a piece of graph paper.

This class is a layer that draws a grid like a piece of graph paper. In addition it can modify a point to lie at the intersection of
any of its "squares" (for snap to grid, etc).

The master interval is called the graph's span. It will be set to the actual number of coordinate units representing the main unit
of the grid. For example, a 1cm grid has a span of ~28.35.

The span is divided into an integral number of smaller divisions, for example 10 divisions of 1cm gives 1mm small squares.

A integral number of spans is called the major interval. This is drawn in a darker colour and bolder width. For example you could
highlight every 10cm by setting the spans per major to 10. The same style is also used to draw a border around the whole thing
allowing for the set margins.

Class methods exist to return a number of "standard" grids.

The spans, minor and major intervals are all drawn in different colours, but more typically you'll set a single "theme" colour which
derives the three colours such that they form a coherent set.

Grid Layers work with methods in DKDrawing to manage the rulers in an NSRulerView. Generally the rulers are set to align with the
span interval of the grid and allow for the drawing's margins. Because a ruler's settings require a name, you need to set this up along
with the grid's parameters. To help make this easy for a client application (that will probably want to present a user interface for
setting this all up), the "one stop shop" method -setSpan:unitToPointsConversionFactor:measurementSystem:drawingUnits:divisions:majors:rulerSteps:
will set up the grid AND the rulers provided the layer has already been added to a drawing. Due to limitations in NSRuler regarding its step up
and step down ratios, this method also imposes similar limits on the span divisions.

General-purpose "snap to grid" type methods are implemented by DKDrawing using the grid as a basis - the grid itself doesn't implement snapping.

Note: caching in a CGLayer is not recommended - the code is here but it doesn't draw nicely at high zooms. Turned off by default.
*/
@interface DKGridLayer : DKLayer <NSCoding> {
@private
	NSColor* m_spanColour; // the colour of the spans grid
	NSColor* m_divisionColour; // the colour of the divisions grid
	NSColor* m_majorColour; // the colour of the majors grid
	NSBezierPath* m_divsCache; // the path for the divisions grid
	NSBezierPath* m_spanCache; // the path for the spans grid
	NSBezierPath* m_majorsCache; // the path for the majors grid
	NSPoint m_zeroDatum; // where "zero" is supposed to be
	BOOL mDrawsDivisions; // YES to draw divisions
	BOOL mDrawsSpans; // YES to draw spans
	BOOL mDrawsMajors; // YES to draw majors
	CGFloat m_spanLineWidth; // the line width to draw the spans
	CGFloat m_divisionLineWidth; // the line width to draw the divisions
	CGFloat m_majorLineWidth; // the line width to draw the majors
	NSUInteger m_rulerStepUpCycle; // the ruler step-up cycle to use
	BOOL m_cacheInLayer; // YES if the grid is cache dusing a CGLayer
	CGLayerRef m_cgl; // the CGLayer when the grid is cached there
	NSUInteger mSpanCycle; // span increment cycle (typically 1)
	CGFloat mDivsSupressionScale; // scale below which divs are not drawn at all (default = 0.5)
	CGFloat mSpanSupressionScale; // scale below which span is not drawn at all (default = 0.1)
	CGFloat mSpanCycleChangeThreshold; // scale below which span cycle is incremented
	CGFloat mCachedViewScale; // view scale cache currently set up for
@protected
	CGFloat mSpanMultiplier; // the span is unit distance x this (usually 1.0)
	NSUInteger m_divisionsPerSpan; // the number of divisions per span
	NSUInteger m_spansPerMajor; // the number of spans per major
}

// setting class defaults:

@property (class, retain, null_resettable) NSColor *defaultSpanColour;
@property (class, retain, null_resettable) NSColor *defaultDivisionColour;
@property (class, retain, null_resettable) NSColor *defaultMajorColour;
+ (void)setDefaultGridThemeColour:(NSColor*)colour;

+ (instancetype)standardMetricGridLayer;
+ (instancetype)standardImperialGridLayer;
+ (instancetype)standardImperialPCBGridLayer;

// setting up the grid

- (void)setMetricDefaults;
- (void)setImperialDefaults;

//! using the grid as the master grid for a drawing
- (BOOL)isMasterGrid;
@property (readonly, getter=isMasterGrid) BOOL masterGrid;

// one-stop shop for setting grid, drawing and rulers in one hit:

/** @brief High-level method to set up the grid in its entirety with one method

 This also sets the drawing's setDrawingUnits:unitToPointsConversionFactor: method, so should be
 attached views so that there is a general agreement between all these parts. If the layer is locked
 this does nothing.
 @param conversionFactor the distance in points represented by a single span unit
 @param units a string giving the user-readable full name of the drawing units
 @param span the span distance in grid coordinates (typically 1.0)
 @param divs the number of divisions per span, must be  1
 @param majors the number of spans per major
 @param steps the ruler step-up cycle (see NSRulerView), must be  1
 */
- (void)setDistanceForUnitSpan:(CGFloat)conversionFactor
				  drawingUnits:(DKDrawingUnit)units
						  span:(CGFloat)span
					 divisions:(NSUInteger)divs
						majors:(NSUInteger)majors
					rulerSteps:(NSUInteger)steps;

// other settings:

@property (readonly) CGFloat spanDistance;
@property (readonly) CGFloat divisionDistance;
@property (nonatomic) NSPoint zeroPoint;
@property (readonly) NSUInteger divisions;
@property (readonly) NSUInteger majors;
@property (readonly) CGFloat spanMultiplier;

/** @brief Returns the actual distance of one span in points
 
 The result is the unit distance.
 @return a float value
 */
- (CGFloat)spanDistance;

/** @brief Returns the actual distance, in points, between each division
 @return the distance in quartz points for one division.
 */
- (CGFloat)divisionDistance;

/** @brief Sets the location within the drawing where the grid considers zero to be (i.e. coordinate 0,0)
 
 By default this is set to the upper, left corner of the drawing's interior
 @param zero a point in the drawing where zero is
 */
- (void)setZeroPoint:(NSPoint)zero;

/** @brief Returns the location within the drawing where the grid considers zero to be (i.e. coordinate 0,0)
 
 By default this is set to the upper, left corner of the drawing's interior
 @return a point in the drawing where zero is
 */
- (NSPoint)zeroPoint;

/** @brief Returns the number of divisions per span
 @return an integer value > 1
 */
- (NSUInteger)divisions;

/** @brief Returns the number of spans per major
 @return an integer value
 */
- (NSUInteger)majors;

/** @brief Returns the number of units of basic distance for one span
 @return a float value
 */
- (CGFloat)spanMultiplier;

// hiding elements of the grid

@property BOOL divisionsHidden;
@property BOOL spansHidden;
@property BOOL majorsHidden;

- (void)setDivisionsHidden:(BOOL)hide;
- (BOOL)divisionsHidden;
- (void)setSpansHidden:(BOOL)hide;
- (BOOL)spansHidden;
- (void)setMajorsHidden:(BOOL)hide;
- (BOOL)majorsHidden;

// managing rulers and margins

@property (nonatomic) NSUInteger rulerSteps;

/** @brief Sets the ruler step-up cycle
 
 See NSRulerView for details about the ruler step-up cycle
 @param steps an integer value that must be  1
 */
- (void)setRulerSteps:(NSUInteger)steps;

/** @brief Returns the ruler step-up cycle in use
 
 See NSRulerView for details about the ruler step-up cycle
 @return an integer value > 1
 */
- (NSUInteger)rulerSteps;

/** @brief Set up the rulers of all views that have them so that they agree with the current grid
 
 @discussion This method prepares the rulers to match to the current grid and drawing settings. It should be
 called once after changing the grid's parameters or the drawing units (which are set in the
 drawing object). This registers the current settings using the drawing units name as a key.
 This requires a valid drawing as some parameters come from there and ruler view changes are
 actually implemented by the drawing.
 */
- (void)synchronizeRulers;

/** @brief Adjust the drawing margins to encompass an integral number of grid spans

 This method alters the existing drawing margins such that a whole number of
 spans is spanned by the interior area of the drawing. The margins are only ever moved inwards (enlarged) by this
 method to ensure that the interior of a drawing always remains within the printable area of a
 printer (assuming margins were set by the printing parameters originally - not always the case).
 Note - from B5, this method changed to adjust all margins, not just centre the interior. The result
 is much nicer behaviour - you can set a very wide margin on one side for example and expect it to
 stay more or less where it is.
 */
- (void)tweakDrawingMargins;

// colours for grid display

/**
 @brief Colour used to draw the spans.
 @discussion Typically a grid is set using a theme colour rather than setting individual colours for each
 part of the grid, but it's up to you.
 */

@property (nonatomic, strong) NSColor *spanColour;
/**
 @brief the colour used to draw the divisions.
 @discussion Typically a grid is set using a theme colour rather than setting individual colours for each
 part of the grid, but it's up to you.
 */

@property (nonatomic, strong) NSColor *divisionColour;
/**
 @brief The colour used to draw the majors.
 
 @discussion Typically a grid is set using a theme colour rather than setting individual colours for each
 part of the grid, but it's up to you.
 */
@property (nonatomic, strong) NSColor *majorColour;

/** @brief Sets the colour used to draw the spans

 Typically a grid is set using a theme colour rather than setting individual colours for each
 part of the grid, but it's up to you. see setGridThemeColour:
 @param colour a colour
 */
- (void)setSpanColour:(NSColor*)colour;

/** @brief The colour used to draw the spans
 
 Typically a grid is set using a theme colour rather than setting individual colours for each
 part of the grid, but it's up to you.
 @return a colour
 */
- (NSColor*)spanColour;

/** @brief Sets the colour used to draw the divisions

 Typically a grid is set using a theme colour rather than setting individual colours for each
 part of the grid, but it's up to you. see setGridThemeColour:
 @param colour a colour
 */
- (void)setDivisionColour:(NSColor*)colour;
- (NSColor*)divisionColour;

/** @brief Sets the colour used to draw the majors

 Typically a grid is set using a theme colour rather than setting individual colours for each
 part of the grid, but it's up to you. see setGridThemeColour:
 @param colour a colour
 */
- (void)setMajorColour:(NSColor*)colour;
- (NSColor*)majorColour;

/** @brief Sets the colours used to draw the grid as a whole

 Typically a grid is set using a theme colour rather than setting individual colours for each
 part of the grid, but it's up to you. This sets the three separate colours based on lighter and
 darker variants of the passed colour. Note that it's usual to have some transparency (alpha) set
 for the theme colour.
 @param colour a colour
 */
- (void)setGridThemeColour:(NSColor*)colour;
- (NSColor*)themeColour;

// converting between the base (Quartz) coordinate system and the grid

/** @brief Given a point in drawing coordinates, returns nearest grid intersection to that point

 The intersection of the nearest division is returned, which is smaller than the span. This is
 a fundamental operation when snapping a point to the grid.
 @param p a point in the drawing
 @return a point, the nearest grid intersection to the point
 */
- (NSPoint)nearestGridIntersectionToPoint:(NSPoint)p;

/** @brief Given a width and height in drawing coordinates, returns the same adjusted to the nearest whole
 number of divisions

 The returned size cannot be larger than the drawing's interior in either dimension.
 @param size a size value
 @return a size, the nearest whole number of divisions to the original size
 */
- (NSSize)nearestGridIntegralToSize:(NSSize)size;

/** @brief Given a width and height in drawing coordinates, returns the same adjusted to the nearest whole
 number of spans

 The returned size cannot be larger than the drawing's interior in either dimension. As spans are
 a coarser measure than divisions, the adjusted size might differ substantially from the input.
 @param size a size value
 @return a size, the nearest whole number of spans to the original size
 */
- (NSSize)nearestGridSpanIntegralToSize:(NSSize)size;

/** @brief Given a point in drawing coordinates, returns the "real world" coordinate of the same point

 See also pointForGridLocation: which is the inverse operation
 @param pt a point local to the drawing
 @return a point giving the same position in terms of the grid's drawing units, etc.
 */
- (NSPoint)gridLocationForPoint:(NSPoint)pt;

/** @brief Given a point in "real world" coordinates, returns the drawing coordinates of the same point

 See also gridLocationForPoint: which is the inverse operation
 @param gpt a point in terms of the grid's drawing units
 @return a point giving the same position in the drawing.
 */
- (NSPoint)pointForGridLocation:(NSPoint)gpt;

/** @brief Given a distance value in drawing coordinates, returns the grid's "real world" equivalent

 See also quartzDistanceForGridDistance: which is the inverse operation. Note that the h and v
 scales of a grid are assumed to be the same (in this implementtaion they always are).
 @param qd a distance given in drawing units (points)
 @return the distance in grid units
 */
- (CGFloat)gridDistanceForQuartzDistance:(CGFloat)qd;

/** @brief Given a distance value in the grid's "real world" coordinates, returns the quartz equivalent

 See also gridDistanceForQuartzDistance: which is the inverse operation
 @param gd a distance given in grid units
 @return the distance in quartz units
 */
- (CGFloat)quartzDistanceForGridDistance:(CGFloat)gd;

// private:

/** @brief When the scale crosses the span threshold, the cache is invalidated and the span cycle adjusted

 This permits dynamic display of the span grid based on the zoom factor. Currently only one
 threshold is used
 @param scale the view's current scale
 */
- (void)adjustSpanCycleForViewScale:(CGFloat)scale;
- (void)invalidateCache;
- (void)createGridCacheInRect:(NSRect)r;
- (void)drawBorderOutline:(DKDrawingView*)aView;

// user actions

/** @brief Set the grid to one ofthe default grids

 [sender tag] is interpreted as a measurement system value; restores either the metric or imperial
 defaults. Not super-useful, but handy for quickly exploring alternative grids.
 @param sender the sender of the action
 */
- (IBAction)setMeasurementSystemAction:(nullable id)sender;

@end

// fundamental constants for grid setup - do not change:

#define kDKGridDrawingLayerMetricInterval 28.346456692913 // 1cm, = 72 / 2.54
#define kDKGridDrawingLayerImperialInterval 72.00 // 1 inch

extern NSString* kDKGridDrawingLayerStandardMetric;
extern NSString* kDKGridDrawingLayerStandardImperial;
extern NSString* kDKGridDrawingLayerStandardImperialPCB;

NS_ASSUME_NONNULL_END
