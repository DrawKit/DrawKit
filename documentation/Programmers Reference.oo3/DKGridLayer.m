///**********************************************************************************************************************************
///  DKGridLayer.m
///  DrawKit
///
///  Created by graham on 12/08/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKGridLayer.h"

#import "DKDrawing.h"
#import "DKSelectionPDFView.h"
#import "NSBezierPath+Geometry.h"
#import "NSColor+DKAdditions.h"


#pragma mark Contants (Non-localized)
NSString*	kGCGridDrawingLayerStandardMetric = @"DK_std_metric";
NSString*	kGCGridDrawingLayerStandardImperial = @"DK_std_imperial";
NSString*	kGCGridDrawingLayerStandardImperialPCB = @"DK_std_imperial_pcb";


#pragma mark Static Vars
static NSColor*		sSpanColour = nil;
static NSColor*		sDivisionColour = nil;
static NSColor*		sMajorColour = nil;


#pragma mark -
@implementation DKGridLayer
#pragma mark As a DKGridLayer

///*********************************************************************************************************************
///
/// method:			setDefaultSpanColour:
/// scope:			public class method
/// overrides:
/// description:	set the class default span colour
/// 
/// parameters:		<colour> a colour
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

+ (void)			setDefaultSpanColour:(NSColor*) colour
{
	[colour retain];
	[sSpanColour release];
	sSpanColour = colour;
}


///*********************************************************************************************************************
///
/// method:			defaultSpanColour
/// scope:			public class method
/// overrides:
/// description:	return the class default span colour
/// 
/// parameters:		none
/// result:			a colour
///
/// notes:			
///
///********************************************************************************************************************

+ (NSColor*)		defaultSpanColour
{
	if ( sSpanColour == nil )
		[self setDefaultSpanColour:[NSColor colorWithCalibratedRed:0.5 green:0.4 blue:1.0 alpha:0.7]];
	
	return sSpanColour;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setDefaultDivisionColour:
/// scope:			public class method
/// overrides:
/// description:	set the class default division colour
/// 
/// parameters:		<colour> a colour
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

+ (void)			setDefaultDivisionColour:(NSColor*) colour
{
	[colour retain];
	[sDivisionColour release];
	sDivisionColour = colour;
}


///*********************************************************************************************************************
///
/// method:			defaultDivisionColour
/// scope:			public class method
/// overrides:
/// description:	return the class default division colour
/// 
/// parameters:		none
/// result:			a colour
///
/// notes:			
///
///********************************************************************************************************************

+ (NSColor*)		defaultDivisionColour
{
	if ( sDivisionColour == nil )
		[self setDefaultDivisionColour:[NSColor colorWithCalibratedRed:0.5 green:0.5 blue:1.0 alpha:0.7]];
	
	return sDivisionColour;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setDefaultMajorColour:
/// scope:			public class method
/// overrides:
/// description:	set the class default major colour
/// 
/// parameters:		<colour> a colour
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

+ (void)			setDefaultMajorColour:(NSColor*) colour
{
	[colour retain];
	[sMajorColour release];
	sMajorColour = colour;
}


///*********************************************************************************************************************
///
/// method:			defaultMajorColour
/// scope:			public class method
/// overrides:
/// description:	return the class default major colour
/// 
/// parameters:		none
/// result:			a colour
///
/// notes:			
///
///********************************************************************************************************************

+ (NSColor*)		defaultMajorColour
{
	if ( sMajorColour == nil )
		[self setDefaultMajorColour:[NSColor colorWithCalibratedRed:0.5 green:0.2 blue:1.0 alpha:0.7]];
	
	return sMajorColour;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setGridThemeColour:
/// scope:			public class method
/// overrides:
/// description:	set the three class default colours based on a single theme colour
/// 
/// parameters:		<colour> a colour
/// result:			none
///
/// notes:			the theme colour directly sets the span colour, the division colour is a lighter version and the
///					major colour a darker version.
///
///********************************************************************************************************************

+ (void)			setGridThemeColour:(NSColor*) colour
{
	// sets up the three seperate grid colours based on the one theme colour passed. The colour itself is used for the span, a darker
	// version for majors and a lighter version for divs.
	
	[self setDefaultSpanColour:colour];
	[self setDefaultDivisionColour:[colour highlightWithLevel:0.6]];
	[self setDefaultMajorColour:[colour shadowWithLevel:0.4]];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			standardMetricGridLayer
/// scope:			public class method
/// overrides:
/// description:	return a grid layer with default metric settings
/// 
/// parameters:		none
/// result:			a grid layer, autoreleased
///
/// notes:			the default metric grid has a 10mm span, 5 divisions per span (2mm) and 10 spans per major (100mm)
///					and the drawing units are "Centimetres"
///
///********************************************************************************************************************

+ (DKGridLayer*)		standardMetricGridLayer
{
	DKGridLayer* gl = [[self alloc] init];
	return [gl autorelease];
}


///*********************************************************************************************************************
///
/// method:			standardImperialGridLayer
/// scope:			public class method
/// overrides:
/// description:	return a grid layer with default imperial settings
/// 
/// parameters:		none
/// result:			a grid layer, autoreleased
///
/// notes:			the default imperial grid has a 1 inch span, 8 divisions per span (1/8") and 4 spans per major (4")
///					and the drawing units are "Inches"
///
///********************************************************************************************************************

+ (DKGridLayer*)		standardImperialGridLayer
{
	DKGridLayer* gl = [[self alloc] init];
	[gl setImperialDefaults];
	return [gl autorelease];
}


///*********************************************************************************************************************
///
/// method:			standardImperialPCBGridLayer
/// scope:			public class method
/// overrides:
/// description:	return a grid layer with default imperial PCB (printed circuit board) settings
/// 
/// parameters:		none
/// result:			a grid layer, autoreleased
///
/// notes:			the default PCB grid has a 1 inch span, 10 divisions per span (0.1") and 2 spans per major (2")
///					and the drawing units are "Inches". This grid is suitable for classic printed circuit layout
///					based on a 0.1" grid pitch.
///
///********************************************************************************************************************

+ (DKGridLayer*)		standardImperialPCBGridLayer
{
	DKGridLayer* gl = [[self alloc] init];
	[gl setMeasurementSystem:kGCImperialDrawingGridPCB];
	[gl setSpan:kGCGridDrawingLayerImperialInterval divisions:10 majors:2];
	
	return [gl autorelease];
}


#pragma mark -
#pragma mark - one-stop shop for setting grid, drawing and rulers in one hit
///*********************************************************************************************************************
///
/// method:			setMetricDefaults
/// scope:			public instance method
/// overrides:
/// description:	sets the grid to the standard metric default settings
/// 
/// parameters:		none
/// result:			none
///
/// notes:			the default metric grid has a 10mm span, 5 divisions per span (2mm) and 10 spans per major (100mm)
///					and the drawing units are "Centimetres"
///
///********************************************************************************************************************

- (void)			setMetricDefaults
{
	[self	setSpan:kGCGridDrawingLayerMetricInterval
			unitToPointsConversionFactor:kGCGridDrawingLayerMetricInterval
			measurementSystem:kGCMetricDrawingGrid
			drawingUnits:@"Centimetres"
			divisions:5
			majors:10
			rulerSteps:2];
}


///*********************************************************************************************************************
///
/// method:			setImperialDefaults
/// scope:			public instance method
/// overrides:
/// description:	sets the grid to the standard imperial default settings
/// 
/// parameters:		none
/// result:			none
///
/// notes:			the default imperial grid has a 1 inch span, 8 divisions per span (1/8") and 4 spans per major (4")
///					and the drawing units are "Inches"
///
///********************************************************************************************************************

- (void)			setImperialDefaults
{
	[self	setSpan:kGCGridDrawingLayerImperialInterval
			unitToPointsConversionFactor:kGCGridDrawingLayerImperialInterval
			measurementSystem:kGCImperialDrawingGrid
			drawingUnits:@"Inches"
			divisions:8
			majors:4
			rulerSteps:2];
}


///*********************************************************************************************************************
///
/// method:			setSpan:unitToPointsConversionFactor:measurementSystem:drawingUnits:divisions:majors:rulerSteps:
/// scope:			public instance method
/// overrides:
/// description:	high-level method to set up the grid in its entirety with one method
/// 
/// parameters:		<span> the distance in points represented by a single span
///					<conversionFactor> the distance in points represented by a single unit - typically the same as <span>
///					<sys> the measurement system, currently accepts metric or imperial
///					<units> a string giving the user-readable full name of the drawing units
///					<divs> the number of divisions per span, must be > 1
///					<majors> the number of spans per major
///					<steps> the ruler step-up cycle (see NSRulerView), must be > 1
/// result:			none
///
/// notes:			this also sets the drawing's setDrawingUnits:unitToPointsConversionFactor: method, so should be
///					called when there is a valid drawing. It sets up the grid, the drawing and the rulers of any/all
///					attached views so that there is a general agreement between all these parts. If the layer is locked
///					this does nothing.
///
///********************************************************************************************************************

- (void)					setSpan:(float) span
							unitToPointsConversionFactor:(float) conversionFactor
							measurementSystem:(DKGridMeasurementSystem) sys
							drawingUnits:(NSString*) units
							divisions:(int) divs
							majors:(int) majors
							rulerSteps:(int) steps
{
	// one-stop shop to set up everything
	
	if( ![self locked] )
	{
		[[self drawing] setDrawingUnits:units unitToPointsConversionFactor:conversionFactor];
		[self setMeasurementSystem:sys];
		m_rulerStepUpCycle = steps;
		[self setSpan:span divisions:divs majors:majors];
	}
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setSpan:divisions:majors:
/// scope:			public instance method
/// overrides:
/// description:	sets the span, divisions and majors
/// 
/// parameters:		<span> the distance in points represented by a single span
///					<divs> the number of divisions per span, must be > 1
///					<majors> the number of spans per major
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)					setSpan:(float) span divisions:(int) divs majors:(int) maj
{
	if( ![self locked] )
	{
		m_spanDistance = span;
		m_divisionsPerSpan = MAX( divs, 2 );
		m_spansPerMajor = MAX( maj, 2 );
		[self invalidateCache];
		[self synchronizeRulers];
		[self setNeedsDisplay:YES];
	}
}


///*********************************************************************************************************************
///
/// method:			divisionDistance
/// scope:			public instance method
/// overrides:
/// description:	returns the actual distance, in points, between each division
/// 
/// parameters:		none
/// result:			a point whose x and y values list the actual distances.
///
/// notes:			note that in the current implementation, x and y are always the same
///
///********************************************************************************************************************

- (NSPoint)					divisionDistance
{
	// returns the distances of the grid divisions
	NSPoint d;
	
	d.x = d.y = m_spanDistance / m_divisionsPerSpan;

	return d;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setZeroPoint:
/// scope:			public instance method
/// overrides:
/// description:	sets the location within the drawing where the grid considers zero to be (i.e. coordinate 0,0)
/// 
/// parameters:		<zero> a point in the drawing where zero is
/// result:			none
///
/// notes:			By default this is set to the upper, left corner of the drawing's interior
///
///********************************************************************************************************************

- (void)			setZeroPoint:(NSPoint) zero
{
	if( ![self locked] )
	{
		if ( ! NSEqualPoints( zero, m_zeroDatum ))
		{
			m_zeroDatum = zero;
			[self invalidateCache];
			[self setNeedsDisplay:YES];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			zeroPoint
/// scope:			public instance method
/// overrides:
/// description:	returns the location within the drawing where the grid considers zero to be (i.e. coordinate 0,0)
/// 
/// parameters:		none
/// result:			a point in the drawing where zero is
///
/// notes:			By default this is set to the upper, left corner of the drawing's interior
///
///********************************************************************************************************************

- (NSPoint)			zeroPoint
{
	return m_zeroDatum;
}


#pragma mark -
#pragma mark - getting grid info
///*********************************************************************************************************************
///
/// method:			span
/// scope:			public instance method
/// overrides:
/// description:	returns the actual distance of one span
/// 
/// parameters:		none
/// result:			a double value
///
/// notes:			
///
///********************************************************************************************************************

- (double)			span
{
	return m_spanDistance;
}


///*********************************************************************************************************************
///
/// method:			divisions
/// scope:			public instance method
/// overrides:
/// description:	returns the number of divisions per span
/// 
/// parameters:		none
/// result:			an integer value > 1
///
/// notes:			
///
///********************************************************************************************************************

- (int)				divisions
{
	return m_divisionsPerSpan;
}


///*********************************************************************************************************************
///
/// method:			majors
/// scope:			public instance method
/// overrides:
/// description:	returns the number of spans per major
/// 
/// parameters:		none
/// result:			an integer value
///
/// notes:			
///
///********************************************************************************************************************

- (int)				majors
{
	return m_spansPerMajor;
}


#pragma mark -
#pragma mark - setting the measurement system (imperial/metric)
///*********************************************************************************************************************
///
/// method:			setMeasurementSystem:
/// scope:			public instance method
/// overrides:
/// description:	sets the basic measurement system
/// 
/// parameters:		<sys> a measurement system constant
/// result:			none
///
/// notes:			acceptable values are imperial and metric. Note that the measurement system value doesn't
///					critically affect anything - it's here more as a hint to your code as to what sorts of values
///					might be preferred when setting the grid - for example metric grids may prefer everything in lots
///					of 10, and imperial grids in 12's, etc.
///
///********************************************************************************************************************

- (void)					setMeasurementSystem:(DKGridMeasurementSystem) sys
{
	m_msys = sys;
}


///*********************************************************************************************************************
///
/// method:			measurementSystem
/// scope:			public instance method
/// overrides:
/// description:	returns the basic measurement system
/// 
/// parameters:		none 
/// result:			a measurement system constant
///
/// notes:			Note that the measurement system value doesn't
///					critically affect anything - it's here more as a hint to your code as to what sorts of values
///					might be preferred when setting the grid - for example metric grids may prefer everything in lots
///					of 10, and imperial grids in 12's, etc.
///
///********************************************************************************************************************

- (DKGridMeasurementSystem)	measurementSystem
{
	return m_msys;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setRulerSteps:
/// scope:			public instance method
/// overrides:
/// description:	sets the ruler step-up cycle
/// 
/// parameters:		<steps> an integer value that must be > 1 
/// result:			none
///
/// notes:			see NSRulerView for details about the ruler step-up cycle
///
///********************************************************************************************************************

- (void)			setRulerSteps:(int) steps
{
	if( ![self locked] )
	{
		m_rulerStepUpCycle = MAX( 2, steps );
		[self synchronizeRulers];
	}
}


///*********************************************************************************************************************
///
/// method:			rulerSteps
/// scope:			public instance method
/// overrides:
/// description:	returns the ruler step-up cycle in use
/// 
/// parameters:		none
/// result:			an integer value > 1
///
/// notes:			see NSRulerView for details about the ruler step-up cycle
///
///********************************************************************************************************************

- (int)				rulerSteps
{
	return m_rulerStepUpCycle;
}


///*********************************************************************************************************************
///
/// method:			synchronizeRulers
/// scope:			public instance method
/// overrides:
/// description:	set up the rulers of all views that have them so that they agree with the current grid
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this method prepares the rulers to match to the current grid and drawing settings. It should be
///					called once after changing the grid's parameters or the drawing units (which are set in the
///					drawing object). This registers the current settings using the drawing units name as a key.
///					This requires a valid drawing as some parameters come from there and ruler view changes are
///					actually implemented by the drawing.
///
///********************************************************************************************************************

- (void)			synchronizeRulers
{
	NSString*	units = [[self drawing] drawingUnits];
	float		conversionFactor = [[self drawing] unitToPointsConversionFactor];
	
	// sanity check: if the limits of ruler cycles can't be met - take an early bath
	
	if ( units == nil || conversionFactor == 0.0 ||  m_rulerStepUpCycle <= 1 || [self divisions] <= 1 )
		return;
	
	NSArray*	upCycle;		// > 1.0
	NSArray*	downCycle;		// < 1.0
	
	upCycle = [NSArray arrayWithObject:[NSNumber numberWithFloat:m_rulerStepUpCycle]];
	downCycle = [NSArray arrayWithObject:[NSNumber numberWithFloat:1.0 / [self divisions]]];
	
	[NSRulerView registerUnitWithName:units abbreviation:[[self drawing] abbreviatedDrawingUnits]
					unitToPointsConversionFactor:conversionFactor
					stepUpCycle:upCycle stepDownCycle:downCycle];
					
	[[self drawing] synchronizeRulersWithUnits:units];
}


///*********************************************************************************************************************
///
/// method:			tweakDrawingMargins
/// scope:			public instance method
/// overrides:
/// description:	adjust the drawing margins to encompass an integral number of divisions
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this method very slightly alters the existing drawing margins such that a whole number of
///					divisions is spanned by the interior area of the drawing. The interior is centred between the
///					margins. Only call this if you accept a small adjustment in your margins, and that left/right and
///					top/bottom margins are made equal. The margins are only ever moved inwads (enlarged) by this
///					method to ensure that the interior of a drawing always remains within the printable area of a
///					printer (assuming margins were set by the printing parameters originally - not always the case).
///
///********************************************************************************************************************

- (void)					tweakDrawingMargins
{
	NSAssert([self drawing] != nil, @"must add grid layer to a drawing or group within one before tweaking margins" );
	
	NSSize		paper = [[self drawing] drawingSize];
	float		marg = [[self drawing] leftMargin];
	float		q = [[self drawing] unitToPointsConversionFactor];
	
	float dim = paper.width - ( marg * 2.0 );
	float rem = fmodf( dim, q );
	float hMarg = marg + ( rem / 2.0 );
	
	marg = [[self drawing] topMargin];
	dim = paper.height - ( marg * 2.0 );
	rem = fmodf( dim, q );
	float vMarg = marg + ( rem / 2.0 );
	
	[[self drawing] setMarginsLeft:hMarg top:vMarg right:hMarg bottom:vMarg];
	[self invalidateCache];
	[self synchronizeRulers];
}


#pragma mark -
#pragma mark - colours for grid display
///*********************************************************************************************************************
///
/// method:			setSpanColour:
/// scope:			public instance method
/// overrides:
/// description:	sets the colour used to draw the spans
/// 
/// parameters:		<colour> a colour
/// result:			none
///
/// notes:			typically a grid is set using a theme colour rather than setting individual colours for each
///					part of the grid, but it's up to you. see setGridThemeColour:
///
///********************************************************************************************************************

- (void)					setSpanColour:(NSColor*) colour
{
	if( ![self locked] )
	{
		[colour retain];
		[m_spanColour release];
		m_spanColour = colour;
		[self setNeedsDisplay:YES];
	}
}


///*********************************************************************************************************************
///
/// method:			spanColour
/// scope:			public instance method
/// overrides:
/// description:	the colour used to draw the spans
/// 
/// parameters:		none
/// result:			a colour
///
/// notes:			typically a grid is set using a theme colour rather than setting individual colours for each
///					part of the grid, but it's up to you.
///
///********************************************************************************************************************

- (NSColor*)		spanColour
{
	return m_spanColour;
}


///*********************************************************************************************************************
///
/// method:			setDivisionColour:
/// scope:			public instance method
/// overrides:
/// description:	sets the colour used to draw the divisions
/// 
/// parameters:		<colour> a colour
/// result:			none
///
/// notes:			typically a grid is set using a theme colour rather than setting individual colours for each
///					part of the grid, but it's up to you. see setGridThemeColour:
///
///********************************************************************************************************************

- (void)					setDivisionColour:(NSColor*) colour
{
	if( ![self locked] )
	{
		[colour retain];
		[m_divisionColour release];
		m_divisionColour = colour;
		[self setNeedsDisplay:YES];
	}
}


///*********************************************************************************************************************
///
/// method:			setMajorColour:
/// scope:			public instance method
/// overrides:
/// description:	sets the colour used to draw the majors
/// 
/// parameters:		<colour> a colour
/// result:			none
///
/// notes:			typically a grid is set using a theme colour rather than setting individual colours for each
///					part of the grid, but it's up to you. see setGridThemeColour:
///
///********************************************************************************************************************

- (void)					setMajorColour:(NSColor*) colour
{
	if( ![self locked] )
	{
		[colour retain];
		[m_majorColour release];
		m_majorColour = colour;
		[self setNeedsDisplay:YES];
	}
}


///*********************************************************************************************************************
///
/// method:			setGridThemeColour:
/// scope:			public instance method
/// overrides:
/// description:	sets the colours used to draw the grid as a whole
/// 
/// parameters:		<colour> a colour
/// result:			none
///
/// notes:			typically a grid is set using a theme colour rather than setting individual colours for each
///					part of the grid, but it's up to you. This sets the three separate colours based on lighter and
///					darker variants of the passed colour. Note that it's usual to have some transparency (alpha) set
///					for the theme colour.
///
///********************************************************************************************************************

- (void)					setGridThemeColour:(NSColor*) colour
{
	if( ![self locked] )
	{
		[self setSpanColour:colour];
		[self setDivisionColour:[colour highlightWithLevel:0.6]];
		[self setMajorColour:[colour shadowWithLevel:0.4]];
	}
}


#pragma mark -
#pragma mark - converting between the base (Quartz) coordinate system and the grid

///*********************************************************************************************************************
///
/// method:			nearestGridIntersectionToPoint:
/// scope:			public instance method
/// overrides:
/// description:	given a point in drawing coordinates, returns nearest grid intersection to that point
/// 
/// parameters:		<p> a point in the drawing
/// result:			a point, the nearest grid intersection to the point
///
/// notes:			the intersection of the nearest division is returned, which is smaller than the span. This is
///					a fundamental operation when snapping a point to the grid.
///
///********************************************************************************************************************

- (NSPoint)					nearestGridIntersectionToPoint:(NSPoint) p
{
	float	divs = m_spanDistance / m_divisionsPerSpan;
	float	rem = fmodf( p.x - [[self drawing] leftMargin], divs );
	
	if ( rem > divs / 2.0 )
		p.x += ( divs - rem );
	else
		p.x -= rem;
	
	rem = fmodf( p.y - [[self drawing] topMargin], divs );
	
	if ( rem > divs / 2.0 )
		p.y += ( divs - rem );
	else
		p.y -= rem;
	
	return p;
}


///*********************************************************************************************************************
///
/// method:			nearestGridIntegralToSize:
/// scope:			public instance method
/// overrides:
/// description:	given a width and height in drawing coordinates, returns the same adjusted to the nearest whole
///					number of divisions
/// 
/// parameters:		<size> a size value
/// result:			a size, the nearest whole number of divisions to the original size
///
/// notes:			the returned size cannot be larger than the drawing's interior in either dimension.
///
///********************************************************************************************************************

- (NSSize)					nearestGridIntegralToSize:(NSSize) size
{
	NSRect	interior = [[self drawing] interior];
	float	divs = 0.0;
	float	rem;
	
	if ( size.width > interior.size.width )
		size.width = interior.size.width;
	else
	{
		divs = m_spanDistance / m_divisionsPerSpan;
		rem = fmodf( size.width, divs );
		if ( rem > divs / 2.0 )
			size.width += ( divs - rem );
		else
			size.width -= rem;
	}
		
	if ( size.height > interior.size.height )
		size.height = interior.size.height;
	else
	{
		rem = fmodf( size.height, divs );
		if ( rem > divs / 2.0 )
			size.height += ( divs - rem );
		else
			size.height -= rem;
	}
	
	return size;
}


///*********************************************************************************************************************
///
/// method:			nearestGridSpanIntegralToSize:
/// scope:			public instance method
/// overrides:
/// description:	given a width and height in drawing coordinates, returns the same adjusted to the nearest whole
///					number of spans
/// 
/// parameters:		<size> a size value
/// result:			a size, the nearest whole number of spans to the original size
///
/// notes:			the returned size cannot be larger than the drawing's interior in either dimension. As spans are
///					a coarser measure than divisions, the adjusted size might differ substantially from the input.
///
///********************************************************************************************************************

- (NSSize)					nearestGridSpanIntegralToSize:(NSSize) size
{
	NSRect	interior = [[self drawing] interior];
	float	divs, rem;
	
	if ( size.width > interior.size.width )
		size.width = interior.size.width;
	else
	{
		divs = m_spanDistance;
		rem = fmodf( size.width, divs );
		if ( rem > divs / 2.0 )
			size.width += ( divs - rem );
		else
			size.width -= rem;
	}
		
	if ( size.height > interior.size.height )
		size.height = interior.size.height;
	else
	{
		divs = m_spanDistance;
		rem = fmodf( size.height, divs );
		if ( rem > divs / 2.0 )
			size.height += ( divs - rem );
		else
			size.height -= rem;
	}
	
	return size;
}


///*********************************************************************************************************************
///
/// method:			gridLocationForPoint:
/// scope:			public instance method
/// overrides:
/// description:	given a point in drawing coordinates, returns the "real world" coordinate of the same point
/// 
/// parameters:		<pt> a point local to the drawing
/// result:			a point giving the same position in terms of the grid's drawing units, etc.
///
/// notes:			see also pointForGridLocation: which is the inverse operation
///
///********************************************************************************************************************

- (NSPoint)					gridLocationForPoint:(NSPoint) pt
{
	NSPoint rp;
	float	qs = [[self drawing] unitToPointsConversionFactor];
	NSRect	margins = [[self drawing] interior];
	
	rp.x = ( pt.x - margins.origin.x ) / qs;
	rp.y = ( pt.y - margins.origin.y ) / qs;
	
	return rp;
}


///*********************************************************************************************************************
///
/// method:			pointForGridLocation:
/// scope:			public instance method
/// overrides:
/// description:	given a point in "real world" coordinates, returns the drawing coordinates of the same point
/// 
/// parameters:		<pt> a point in terms of the grid's drawing units
/// result:			a point giving the same position in the drawing.
///
/// notes:			see also gridLocationForPoint: which is the inverse operation
///
///********************************************************************************************************************

- (NSPoint)					pointForGridLocation:(NSPoint) gpt
{
	NSPoint rp;
	float	qs = [[self drawing] unitToPointsConversionFactor];
	NSRect	margins = [[self drawing] interior];
	
	rp.x = ( gpt.x * qs ) + margins.origin.x;
	rp.y = ( gpt.y * qs ) + margins.origin.y;
	
	return rp;
}


///*********************************************************************************************************************
///
/// method:			gridDistanceForQuartzDistance:
/// scope:			public instance method
/// overrides:
/// description:	given a distance value in drawing coordinates, returns the grid's "real world" equivalent
/// 
/// parameters:		<qd> a distance given in drawing units (points)
/// result:			the distance in grid units
///
/// notes:			see also quartzDistanceForGridDistance: which is the inverse operation. Note that the h and v
///					scales of a grid are assumed to be the same (in this implementtaion they always are).
///
///********************************************************************************************************************

- (float)					gridDistanceForQuartzDistance:(float) qd
{
	// return the distance in grid terms of the quartz distance passed. Note - assumes h and v scaling is the same, which is usual.
	
	float		q = [[self drawing] unitToPointsConversionFactor];
	return qd / q;
}


///*********************************************************************************************************************
///
/// method:			quartzDistanceForGridDistance:
/// scope:			public instance method
/// overrides:
/// description:	given a distance value in the grid's "real world" coordinates, returns the quartz equivalent
/// 
/// parameters:		<gd> a distance given in grid units
/// result:			the distance in quartz units
///
/// notes:			see also gridDistanceForQuartzDistance: which is the inverse operation
///
///********************************************************************************************************************

- (float)					quartzDistanceForGridDistance:(float) gd
{
	float	q = [[self drawing] unitToPointsConversionFactor];
	return	gd * q;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			invalidateCache
/// scope:			private instance method
/// overrides:
/// description:	removes the cached paths used to draw the grid when a grid parameter is changed
/// 
/// parameters:		none
/// result:			none
///
/// notes:			the grid is cached to help speed up drawing, and is only recalculated when necessary.
///
///********************************************************************************************************************

- (void)			invalidateCache
{
	[m_divsCache release];
	[m_spanCache release];
	[m_majorsCache release];
	m_divsCache = nil;
	m_spanCache = nil;
	m_majorsCache = nil;
	
	if ( m_cgl )
		CGLayerRelease(m_cgl);
	m_cgl = nil;
}


///*********************************************************************************************************************
///
/// method:			createGridCacheInRect:
/// scope:			private instance method
/// overrides:
/// description:	recreates the cached paths used to draw the grid when required
/// 
/// parameters:		<r> the rect in which the grid is defined (typically the drawing interior)
/// result:			none
///
/// notes:			the grid is cached to help speed up drawing, and is only recalculated when necessary.
///
///********************************************************************************************************************

- (void)			createGridCacheInRect:(NSRect) r
{
	float	sp = NSMinX( r );
	float	lp = 0.0;
	float	divs;
	int		i, m;
	NSPoint	a, b;
	
	m = 0;
	divs = m_spanDistance / m_divisionsPerSpan;
	a.y = NSMinY( r );
	b.y = NSMaxY( r );
	
	if ( m_divsCache == nil )
	{
		//float divsDash[2] = { divs * 0.5f, divs * 0.5f };
		
		m_divsCache = [[NSBezierPath bezierPathWithRect:r] retain];
		[m_divsCache setLineWidth:m_divisionLineWidth];
		//[m_divsCache setLineDash:divsDash count:2 phase:divs * 0.25f];
	}
	
	if ( m_spanCache == nil )
	{
		//float spanDash[2] = { divs * 2, m_spanDistance - ( divs * 2 )};
		
		m_spanCache = [[NSBezierPath bezierPath] retain];
		[m_spanCache setLineWidth:m_spanLineWidth];
		//[m_spanCache setLineDash:spanDash count:2 phase:divs];
	}
	
	if ( m_majorsCache == nil )
	{
		//float majDash[2] = { divs * 4, m_spansPerMajor * m_spanDistance - (divs * 4)};
		
		m_majorsCache = [[NSBezierPath bezierPathWithRect:r] retain];
		[m_majorsCache setLineWidth:m_majorLineWidth];
		//[m_majorsCache setLineDash:majDash count:2 phase:divs * 2];
	}	
	// first all the vertical lines
	
	
	while( lp < NSMaxX( r ))
	{
		lp = sp + ( m * m_spanDistance );
		
		if (( m % m_spansPerMajor) == 0 )
		{
			// drawing a major line
			a.x = b.x = lp;
			[m_majorsCache moveToPoint:a];
			[m_majorsCache lineToPoint:b];
		}
		else
		{
			a.x = b.x = lp;
			[m_spanCache moveToPoint:a];
			[m_spanCache lineToPoint:b];
		}
		for( i = 0; i < m_divisionsPerSpan; i++ )
		{
			if ( lp <= NSMaxX( r ))
			{
				a.x = b.x = lp;
				[m_divsCache moveToPoint:a];
				[m_divsCache lineToPoint:b];
			}
			else
				break;
			lp += divs;
		}
		++m;
	}
	
	// horizontal lines:
	
	sp = lp = NSMinY( r );
	m = 0;
	a.x = NSMinX( r );
	b.x = NSMaxX( r );
	
	while( lp <= NSMaxY( r ))
	{
		lp = sp + ( m * m_spanDistance );

		if (( m % m_spansPerMajor ) == 0 )
		{
			// drawing a major line
			a.y = b.y = lp;
			[m_majorsCache moveToPoint:a];
			[m_majorsCache lineToPoint:b];
		}
		else
		{
			a.y = b.y = lp;
			[m_spanCache moveToPoint:a];
			[m_spanCache lineToPoint:b];
		}	
		for( i = 0; i < m_divisionsPerSpan; i++ )
		{
			if ( lp <= NSMaxY( r ))
			{
				a.y = b.y = lp;
				[m_divsCache moveToPoint:a];
				[m_divsCache lineToPoint:b];
			}
			else
				break;
			lp += divs;
		}
		++m;
	}
}


#pragma mark -
#pragma mark - user actions
///*********************************************************************************************************************
///
/// method:			copy:
/// scope:			public action method
/// overrides:
/// description:	places the grid on the clipboard as a PDF
/// 
/// parameters:		<sender> the sender of the action
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)				copy:(id) sender
{
	#pragma unused(sender)
	
	// export the grid as a PDF
	
	NSRect					fr = NSZeroRect;
	
	fr.size = [[self drawing] drawingSize];
	DKGridLayerPDFView*		pdfView = [[DKGridLayerPDFView alloc] initWithFrame:fr];
	DKViewController*		vc = [pdfView makeViewController];
	
	[[self drawing] addController:vc];
	
	[[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObject:NSPDFPboardType] owner:self];
	[pdfView writePDFInsideRect:fr toPasteboard:[NSPasteboard generalPasteboard]];
	[pdfView release];
}


///*********************************************************************************************************************
///
/// method:			setMeasurementSystemAction:
/// scope:			public action method
/// overrides:
/// description:	set the grid to one ofthe default grids
/// 
/// parameters:		<sender> the sender of the action
/// result:			none
///
/// notes:			[sender tag] is interpreted as a measurement system value; restores either the metric or imperial
///					defaults. Not super-useful, but handy for quickly exploring alternative grids.
///
///********************************************************************************************************************

- (IBAction)				setMeasurementSystemAction:(id) sender
{
	if( ![self locked] )
	{
		DKGridMeasurementSystem ms = (DKGridMeasurementSystem)[sender tag];
		if ( ms == kGCMetricDrawingGrid )
			[self setMetricDefaults];
		else
			[self setImperialDefaults];
		[self setNeedsDisplay:YES];
	}
}


#pragma mark -
#pragma mark As a DKLayer
///*********************************************************************************************************************
///
/// method:			drawRect:inView:
/// scope:			public instance method
/// overrides:		DKLayer
/// description:	draw the grid
/// 
/// parameters:		<rect> the area of the view needing to be redrawn
///					<aView> where it came from
/// result:			none
///
/// notes:			draws the cached grid to the view
///
///********************************************************************************************************************

- (void)			drawRect:(NSRect) rect inView:(DKDrawingView*) aView
{
	#pragma unused(rect)
	#pragma unused(aView)
	
	NSRect mr = [[self drawing] interior];
	CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	
	if( m_cgl && m_cacheInLayer && [[NSGraphicsContext currentContext] isDrawingToScreen ])
	{
		CGContextDrawLayerInRect( context, *(CGRect*) &mr, m_cgl );
	}
	else
	{
		if ( m_divsCache == nil )
			[self createGridCacheInRect:mr];
		
		if ( m_cacheInLayer )
		{
			CGSize ls;
		
			ls.width = mr.size.width;
			ls.height = mr.size.height;
		
			m_cgl = CGLayerCreateWithContext( context, ls, nil );
			context = CGLayerGetContext( m_cgl );
			
			// offset the context's CTM to allow for the grid alignment to the interior rect
			
			CGAffineTransform tfm = CGAffineTransformMakeTranslation( -mr.origin.x, -mr.origin.y );
			CGContextConcatCTM( context, tfm );
			
			// do it using CG
			CGColorRef	colour = [m_divisionColour quartzColor];
			CGContextSetStrokeColorWithColor( context, colour );
			[m_divsCache setQuartzPathInContext:context isNewPath:YES];
			CGContextStrokePath( context );
			CGColorRelease( colour );

			colour = [m_spanColour quartzColor];
			CGContextSetStrokeColorWithColor( context, colour );
			[m_spanCache setQuartzPathInContext:context isNewPath:YES];
			CGContextStrokePath( context );
			CGColorRelease( colour );
		
			colour = [m_majorColour quartzColor];
			CGContextSetStrokeColorWithColor( context, colour );
			[m_majorsCache setQuartzPathInContext:context isNewPath:YES];
			CGContextStrokePath( context );
			CGColorRelease( colour );
		}
		else
		{
			[m_divisionColour setStroke];
			[m_divsCache stroke];
			[m_spanColour setStroke];
			[m_spanCache stroke];
			[m_majorColour setStroke];
			[m_majorsCache stroke];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			selectionColour
/// scope:			public instance method
/// overrides:		DKLayer
/// description:	return the selection colour
/// 
/// parameters:		none
/// result:			nil
///
/// notes:			this layer type doesn't make use of this inherited colour, so always returns nil. A UI may use that
///					as a cue to supress a widget for setting the layer's colour.
///
///********************************************************************************************************************

- (NSColor*)		selectionColour
{
	return nil;
}


- (void)			setLayerGroup:(DKLayerGroup*) group
{
	[super setLayerGroup:group];
	[self synchronizeRulers];
}


#pragma mark -
#pragma mark As an NSObject
- (void)			dealloc
{
	[self invalidateCache]; // Releases cache
	[m_majorColour release];
	[m_divisionColour release];
	[m_spanColour release];
	
	[super dealloc];
}


- (id)				init
{
	self = [super init];
	if (self != nil)
	{
		[self setSpanColour:[[self class] defaultSpanColour]];
		[self setDivisionColour:[[self class] defaultDivisionColour]];
		[self setMajorColour:[[self class] defaultMajorColour]];
		NSAssert(m_divsCache == nil, @"Expected init to zero");
		NSAssert(m_spanCache == nil, @"Expected init to zero");
		NSAssert(m_majorsCache == nil, @"Expected init to zero");
		
		NSAssert(NSEqualPoints(m_zeroDatum, NSZeroPoint), @"Expected init to zero");
		NSAssert(m_spanDistance == 0.0, @"Expected init to zero");
		m_spanLineWidth = 0.3;
		m_divisionLineWidth = 0.1;
		m_majorLineWidth = 0.6;
		
		NSAssert(m_divisionsPerSpan == 0, @"Expected init to zero");
		NSAssert(m_spansPerMajor == 0, @"Expected init to zero");
		NSAssert(m_rulerStepUpCycle == 0, @"Expected init to zero");
		NSAssert(m_msys == kGCMetricDrawingGrid, @"Expected init to zero");
		NSAssert(!m_cacheInLayer, @"Expected init to NO");
		NSAssert(m_cgl == nil, @"Expected init to zero");
		
		if (m_spanColour == nil 
				|| m_divisionColour == nil 
				|| m_majorColour == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	if (self != nil)
	{
		[self setShouldDrawToPrinter:NO];
		[self setMetricDefaults];
		[self setName:NSLocalizedString(@"Grid", @"default name for grid layer")];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)			encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:m_spanColour forKey:@"span_colour"];
	[coder encodeObject:m_divisionColour forKey:@"div_colour"];
	[coder encodeObject:m_majorColour forKey:@"major_colour"];
	
	[coder encodeDouble:m_spanDistance forKey:@"span_dist_d"];
	[coder encodeFloat:m_spanLineWidth forKey:@"span_width"];
	[coder encodeFloat:m_divisionLineWidth forKey:@"div_width"];
	[coder encodeFloat:m_majorLineWidth forKey:@"major_width"];
	
	[coder encodeInt:m_divisionsPerSpan forKey:@"divs_span_h"];
	[coder encodeInt:m_spansPerMajor forKey:@"spans_maj_h"];
	[coder encodeInt:m_rulerStepUpCycle forKey:@"ruler_steps"];
}


- (id)				initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setSpanColour:[coder decodeObjectForKey:@"span_colour"]];
		[self setDivisionColour:[coder decodeObjectForKey:@"div_colour"]];
		[self setMajorColour:[coder decodeObjectForKey:@"major_colour"]];
		NSAssert(m_divsCache == nil, @"Expected init to zero");
		NSAssert(m_spanCache == nil, @"Expected init to zero");
		NSAssert(m_majorsCache == nil, @"Expected init to zero");
		
		NSAssert(NSEqualPoints(m_zeroDatum, NSZeroPoint), @"Expected init to zero");
		m_spanDistance = [coder decodeDoubleForKey:@"span_dist_d"];
		// if this value is 0, try reading it as a size value (older code will have written it as such)
		// this allows old drawings to still be read - will be saved in new form subsequently
		if ( m_spanDistance == 0.0 )
		{
			NSSize sd = [coder decodeSizeForKey:@"span_dist"];
			m_spanDistance = sd.width;
		}
		m_spanLineWidth = [coder decodeFloatForKey:@"span_width"];
		m_divisionLineWidth = [coder decodeFloatForKey:@"div_width"];
		m_majorLineWidth = [coder decodeFloatForKey:@"major_width"];
		
		m_divisionsPerSpan = [coder decodeIntForKey:@"divs_span_h"];
		m_spansPerMajor = [coder decodeIntForKey:@"spans_maj_h"];
		[self setRulerSteps:[coder decodeIntForKey:@"ruler_steps"]];
		NSAssert(m_msys == kGCMetricDrawingGrid, @"Expected init to zero");
		NSAssert(!m_cacheInLayer, @"Expected init to NO");
		NSAssert(m_cgl == nil, @"Expected init to zero");
		
		if (m_spanColour == nil 
				|| m_divisionColour == nil 
				|| m_majorColour == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	if (self != nil)
	{
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol
- (BOOL)					validateMenuItem:(NSMenuItem*) item
{
	BOOL	enable = NO;
	SEL		action = [item action];
	
	if ( action == @selector( copy: ))
		enable = YES;
	else if ( action == @selector( setMeasurementSystemAction: ))
	{
		enable = ![self locked];
	
		DKGridMeasurementSystem ms = (DKGridMeasurementSystem)[item tag];
		[item setState:(ms == [self measurementSystem])? NSOnState : NSOffState];
	}
	
	enable |= [super validateMenuItem:item];
	
	return enable;
}


@end
