///**********************************************************************************************************************************
///  DKGridLayer.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 12/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKLayer.h"


typedef enum
{
	kDKMetricDrawingGrid			= 0,
	kDKImperialDrawingGrid
}
DKGridMeasurementSystem;


@interface DKGridLayer : DKLayer <NSCoding>
{
@private
	NSColor*				m_spanColour;					// the colour of the spans grid
	NSColor*				m_divisionColour;				// the colour of the divisions grid
	NSColor*				m_majorColour;					// the colour of the majors grid
	NSBezierPath*			m_divsCache;					// the path for the divisions grid
	NSBezierPath*			m_spanCache;					// the path for the spans grid
	NSBezierPath*			m_majorsCache;					// the path for the majors grid
	NSPoint					m_zeroDatum;					// where "zero" is supposed to be
	BOOL					mDrawsDivisions;				// YES to draw divisions
	BOOL					mDrawsSpans;					// YES to draw spans
	BOOL					mDrawsMajors;					// YES to draw majors
	CGFloat					m_spanLineWidth;				// the line width to draw the spans
	CGFloat					m_divisionLineWidth;			// the line width to draw the divisions
	CGFloat					m_majorLineWidth;				// the line width to draw the majors
	NSUInteger				m_rulerStepUpCycle;				// the ruler step-up cycle to use
	BOOL					m_cacheInLayer;					// YES if the grid is cache dusing a CGLayer
	CGLayerRef				m_cgl;							// the CGLayer when the grid is cached there
	NSUInteger				mSpanCycle;						// span increment cycle (typically 1)
	CGFloat					mDivsSupressionScale;			// scale below which divs are not drawn at all (default = 0.5)
	CGFloat					mSpanSupressionScale;			// scale below which span is not drawn at all (default = 0.1)
	CGFloat					mSpanCycleChangeThreshold;		// scale below which span cycle is incremented
	CGFloat					mCachedViewScale;				// view scale cache currently set up for
@protected
	CGFloat					mSpanMultiplier;				// the span is unit distance x this (usually 1.0)
	NSUInteger				m_divisionsPerSpan;				// the number of divisions per span
	NSUInteger				m_spansPerMajor;				// the number of spans per major
}

// setting class defaults:

+ (void)					setDefaultSpanColour:(NSColor*) colour;
+ (NSColor*)				defaultSpanColour;
+ (void)					setDefaultDivisionColour:(NSColor*) colour;
+ (NSColor*)				defaultDivisionColour;
+ (void)					setDefaultMajorColour:(NSColor*) colour;
+ (NSColor*)				defaultMajorColour;
+ (void)					setDefaultGridThemeColour:(NSColor*) colour;

+ (DKGridLayer*)			standardMetricGridLayer;
+ (DKGridLayer*)			standardImperialGridLayer;
+ (DKGridLayer*)			standardImperialPCBGridLayer;

// setting up the grid

- (void)					setMetricDefaults;
- (void)					setImperialDefaults;

// using the grid as the master grid for a drawing

- (BOOL)					isMasterGrid;

// one-stop shop for setting grid, drawing and rulers in one hit:

- (void)					setDistanceForUnitSpan:(CGFloat) conversionFactor
							drawingUnits:(NSString*) units
							span:(CGFloat) span
							divisions:(NSUInteger) divs
							majors:(NSUInteger) majors
							rulerSteps:(NSUInteger) steps;

// other settings:

- (CGFloat)					spanDistance;
- (CGFloat)					divisionDistance;
- (void)					setZeroPoint:(NSPoint) zero;
- (NSPoint)					zeroPoint;
- (NSUInteger)				divisions;
- (NSUInteger)				majors;
- (CGFloat)					spanMultiplier;

// hiding elements of the grid

- (void)					setDivisionsHidden:(BOOL) hide;
- (BOOL)					divisionsHidden;
- (void)					setSpansHidden:(BOOL) hide;
- (BOOL)					spansHidden;
- (void)					setMajorsHidden:(BOOL) hide;
- (BOOL)					majorsHidden;

// managing rulers and margins

- (void)					setRulerSteps:(NSUInteger) steps;
- (NSUInteger)				rulerSteps;
- (void)					synchronizeRulers;
- (void)					tweakDrawingMargins;

// colours for grid display

- (void)					setSpanColour:(NSColor*) colour;
- (NSColor*)				spanColour;
- (void)					setDivisionColour:(NSColor*) colour;
- (NSColor*)				divisionColour;
- (void)					setMajorColour:(NSColor*) colour;
- (NSColor*)				majorColour;
- (void)					setGridThemeColour:(NSColor*) colour;
- (NSColor*)				themeColour;

// converting between the base (Quartz) coordinate system and the grid

- (NSPoint)					nearestGridIntersectionToPoint:(NSPoint) p;
- (NSSize)					nearestGridIntegralToSize:(NSSize) size;
- (NSSize)					nearestGridSpanIntegralToSize:(NSSize) size;
- (NSPoint)					gridLocationForPoint:(NSPoint) pt;
- (NSPoint)					pointForGridLocation:(NSPoint) gpt;
- (CGFloat)					gridDistanceForQuartzDistance:(CGFloat) qd;
- (CGFloat)					quartzDistanceForGridDistance:(CGFloat) gd;

// private:

- (void)					adjustSpanCycleForViewScale:(CGFloat) scale;
- (void)					invalidateCache;
- (void)					createGridCacheInRect:(NSRect) r;
- (void)					drawBorderOutline:(DKDrawingView*) aView;

// user actions

- (IBAction)				setMeasurementSystemAction:(id) sender;


@end


// fundamental constants for grid setup - do not change:

#define				kDKGridDrawingLayerMetricInterval		28.346456692913		// 1cm, = 72 / 2.54
#define				kDKGridDrawingLayerImperialInterval		72.00				// 1 inch


extern NSString*	kDKGridDrawingLayerStandardMetric;
extern NSString*	kDKGridDrawingLayerStandardImperial;
extern NSString*	kDKGridDrawingLayerStandardImperialPCB;



/*

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

