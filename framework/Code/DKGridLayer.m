/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKGridLayer.h"
#import "DKDrawing.h"
#import "NSBezierPath+Geometry.h"
#import "NSColor+DKAdditions.h"
#import "DKDrawKitMacros.h"
#import "DKDrawingView.h"
#import "NSColor+DKAdditions.h"
#import "LogEvent.h"
#include <tgmath.h>

#pragma mark Contants (Non-localized)
NSString* kDKGridDrawingLayerStandardMetric = @"DK_std_metric";
NSString* kDKGridDrawingLayerStandardImperial = @"DK_std_imperial";
NSString* kDKGridDrawingLayerStandardImperialPCB = @"DK_std_imperial_pcb";

#pragma mark Static Vars
static NSColor* sSpanColour = nil;
static NSColor* sDivisionColour = nil;
static NSColor* sMajorColour = nil;

#pragma mark -
@implementation DKGridLayer
#pragma mark As a DKGridLayer

/** @brief Set the class default span colour
 @param colour a colour
 */
+ (void)setDefaultSpanColour:(NSColor*)colour
{
    [colour retain];
    [sSpanColour release];
    sSpanColour = colour;
}

/** @brief Return the class default span colour
 @return a colour
 */
+ (NSColor*)defaultSpanColour
{
    if (sSpanColour == nil)
        [self setDefaultSpanColour:[NSColor colorWithCalibratedRed:0.5
                                                             green:0.4
                                                              blue:1.0
                                                             alpha:0.7]];

    return sSpanColour;
}

/** @brief Set the class default division colour
 @param colour a colour
 */
+ (void)setDefaultDivisionColour:(NSColor*)colour
{
    [colour retain];
    [sDivisionColour release];
    sDivisionColour = colour;
}

/** @brief Return the class default division colour
 @return a colour
 */
+ (NSColor*)defaultDivisionColour
{
    if (sDivisionColour == nil)
        [self setDefaultDivisionColour:[NSColor colorWithCalibratedRed:0.5
                                                                 green:0.5
                                                                  blue:1.0
                                                                 alpha:0.7]];

    return sDivisionColour;
}

/** @brief Set the class default major colour
 @param colour a colour
 */
+ (void)setDefaultMajorColour:(NSColor*)colour
{
    [colour retain];
    [sMajorColour release];
    sMajorColour = colour;
}

/** @brief Return the class default major colour
 @return a colour
 */
+ (NSColor*)defaultMajorColour
{
    if (sMajorColour == nil)
        [self setDefaultMajorColour:[NSColor colorWithCalibratedRed:0.5
                                                              green:0.2
                                                               blue:1.0
                                                              alpha:0.7]];

    return sMajorColour;
}

/** @brief Set the three class default colours based on a single theme colour
 @note
 The theme colour directly sets the span colour, the division colour is a lighter version and the
 major colour a darker version.
 @param colour a colour
 */
+ (void)setDefaultGridThemeColour:(NSColor*)colour
{
    // sets up the three seperate grid colours based on the one theme colour passed. The colour itself is used for the span, a darker
    // version for majors and a lighter version for divs.

    [self setDefaultSpanColour:colour];
    [self setDefaultDivisionColour:[colour lighterColorWithLevel:0.5]];
    [self setDefaultMajorColour:[colour darkerColorWithLevel:0.33]];
}

#pragma mark -

/** @brief Return a grid layer with default metric settings
 @note
 The default metric grid has a 10mm span, 5 divisions per span (2mm) and 10 spans per major (100mm)
 and the drawing units are "Centimetres"
 @return a grid layer, autoreleased
 */
+ (DKGridLayer*)standardMetricGridLayer
{
    DKGridLayer* gl = [[self alloc] init];
    return [gl autorelease];
}

/** @brief Return a grid layer with default imperial settings
 @return a grid layer, autoreleased
 and the drawing units are "Inches"
 */
+ (DKGridLayer*)standardImperialGridLayer
{
    DKGridLayer* gl = [[self alloc] init];
    [gl setImperialDefaults];
    return [gl autorelease];
}

/** @brief Return a grid layer with default imperial PCB (printed circuit board) settings
 @note
 The default PCB grid has a 1 inch span, 10 divisions per span (0.1") and 2 spans per major (2")
 and the drawing units are "Inches". This grid is suitable for classic printed circuit layout
 based on a 0.1" grid pitch.
 @return a grid layer, autoreleased
 */
+ (DKGridLayer*)standardImperialPCBGridLayer
{
    DKGridLayer* gl = [[self alloc] init];
    [gl setDistanceForUnitSpan:kDKGridDrawingLayerImperialInterval
                  drawingUnits:@"Inches"
                          span:1.0
                     divisions:10
                        majors:2
                    rulerSteps:2];

    return [gl autorelease];
}

#pragma mark -
#pragma mark - one-stop shop for setting grid, drawing and rulers in one hit

/** @brief Sets the grid to the standard metric default settings
 @note
 The default metric grid has a 10mm span, 5 divisions per span (2mm) and 10 spans per major (100mm)
 and the drawing units are "Centimetres"
 */
- (void)setMetricDefaults
{
    [self setDistanceForUnitSpan:kDKGridDrawingLayerMetricInterval
                    drawingUnits:@"Centimetres"
                            span:1.0
                       divisions:5
                          majors:10
                      rulerSteps:2];
}

/** @brief Sets the grid to the standard imperial default settings
 @return none
 and the drawing units are "Inches"
 */
- (void)setImperialDefaults
{
    [self setDistanceForUnitSpan:kDKGridDrawingLayerImperialInterval
                    drawingUnits:@"Inches"
                            span:1.0
                       divisions:8
                          majors:4
                      rulerSteps:2];
}

/** @brief Is this grid a master for the drawing?
 @note
 By default the grid is a master. Typically a drawing will only use one grid, but some specialised
 applications may wish to have other grids as well. To avoid confusion, those grids should arrange
 to return NO here so that they are not used by mistake for general purpose drawing.
 @return YES
 */
- (BOOL)isMasterGrid
{
    return YES;
}

/** @brief High-level method to set up the grid in its entirety with one method
 @note
 This also sets the drawing's setDrawingUnits:unitToPointsConversionFactor: method, so should be
 attached views so that there is a general agreement between all these parts. If the layer is locked
 this does nothing.
 @param conversionFactor the distance in points represented by a single span unit
 @param units a string giving the user-readable full name of the drawing units
 @param span the span distance in grid coordinates (typically 1.0)
 @param divs> the number of divisions per span, must be  1
 @param majors the number of spans per major
 @param steps> the ruler step-up cycle (see NSRulerView), must be  1
 */
- (void)setDistanceForUnitSpan:(CGFloat)conversionFactor
                  drawingUnits:(NSString*)units
                          span:(CGFloat)span
                     divisions:(NSUInteger)divs
                        majors:(NSUInteger)majors
                    rulerSteps:(NSUInteger)steps
{
    // one-stop shop to set up everything

    if (![self locked]) {
        [[[self undoManager] prepareWithInvocationTarget:self] setDistanceForUnitSpan:[[self drawing] unitToPointsConversionFactor]
                                                                         drawingUnits:[[self drawing] drawingUnits]
                                                                                 span:mSpanMultiplier
                                                                            divisions:m_divisionsPerSpan
                                                                               majors:m_spansPerMajor
                                                                           rulerSteps:m_rulerStepUpCycle];

        [[self drawing] setDrawingUnits:units
            unitToPointsConversionFactor:conversionFactor];

        mSpanMultiplier = MAX(span, 0.1);
        m_divisionsPerSpan = MAX(divs, 2u);
        m_spansPerMajor = MAX(majors, 2u);

        // calculate the span cycle threshold - this is the zoom factor where the span lines become too close together
        // to be shown clearly. We set this arbitrarily to 12 pixels - if the span is closer than this only every other one is drawn

        mSpanCycleChangeThreshold = 12.0 / conversionFactor;

        [self setRulerSteps:steps];

        [self invalidateCache];
        [self setNeedsDisplay:YES];
    }
}

#pragma mark -

/** @brief Returns the actual distance, in points, between each division
 @return the distance in quartz points for one division.
 */
- (CGFloat)divisionDistance
{
    return ([self spanDistance] * mSpanMultiplier) / m_divisionsPerSpan;
}

#pragma mark -

/** @brief Sets the location within the drawing where the grid considers zero to be (i.e. coordinate 0,0)
 @note
 By default this is set to the upper, left corner of the drawing's interior
 @param zero a point in the drawing where zero is
 */
- (void)setZeroPoint:(NSPoint)zero
{
    if (![self locked]) {
        if (!NSEqualPoints(zero, m_zeroDatum)) {
            m_zeroDatum = zero;
            [self invalidateCache];
            [self setNeedsDisplay:YES];
        }
    }
}

/** @brief Returns the location within the drawing where the grid considers zero to be (i.e. coordinate 0,0)
 @note
 By default this is set to the upper, left corner of the drawing's interior
 @return a point in the drawing where zero is
 */
- (NSPoint)zeroPoint
{
    return m_zeroDatum;
}

#pragma mark -
#pragma mark - getting grid info

/** @brief Returns the actual distance of one span in points
 @note
 The result is the unit distance.
 @return a float value
 */
- (CGFloat)spanDistance
{
    return [[self drawing] unitToPointsConversionFactor];
}

/** @brief Returns the number of divisions per span
 @return an integer value > 1
 */
- (NSUInteger)divisions
{
    return m_divisionsPerSpan;
}

/** @brief Returns the number of spans per major
 @return an integer value
 */
- (NSUInteger)majors
{
    return m_spansPerMajor;
}

/** @brief Returns the number of units of basic distance for one span
 @return a float value
 */
- (CGFloat)spanMultiplier
{
    return mSpanMultiplier;
}

- (void)setDivisionsHidden:(BOOL)hide
{
    mDrawsDivisions = !hide;
}

- (void)setSpansHidden:(BOOL)hide
{
    mDrawsSpans = !hide;
}

- (void)setMajorsHidden:(BOOL)hide
{
    mDrawsMajors = !hide;
}

- (BOOL)divisionsHidden
{
    return !mDrawsDivisions;
}

- (BOOL)spansHidden
{
    return !mDrawsSpans;
}

- (BOOL)majorsHidden
{
    return !mDrawsMajors;
}

#pragma mark -

/** @brief Sets the ruler step-up cycle
 @note
 See NSRulerView for details about the ruler step-up cycle
 @param steps> an integer value that must be  1 
 */
- (void)setRulerSteps:(NSUInteger)steps
{
    if (![self locked]) {
        m_rulerStepUpCycle = MAX(2u, steps);
        [self synchronizeRulers];
    }
}

/** @brief Returns the ruler step-up cycle in use
 @note
 See NSRulerView for details about the ruler step-up cycle
 @return an integer value > 1
 */
- (NSUInteger)rulerSteps
{
    return m_rulerStepUpCycle;
}

/** @brief Set up the rulers of all views that have them so that they agree with the current grid
 @note
 This method prepares the rulers to match to the current grid and drawing settings. It should be
 called once after changing the grid's parameters or the drawing units (which are set in the
 drawing object). This registers the current settings using the drawing units name as a key.
 This requires a valid drawing as some parameters come from there and ruler view changes are
 actually implemented by the drawing.
 */
- (void)synchronizeRulers
{
    NSString* units = [[self drawing] drawingUnits];
    CGFloat conversionFactor = [[self drawing] unitToPointsConversionFactor];

    // sanity check: if the limits of ruler cycles can't be met - take an early bath

    if (units == nil || conversionFactor == 0.0 || m_rulerStepUpCycle <= 1 || [self divisions] <= 1)
        return;

    NSString* abbr = [[self drawing] abbreviatedDrawingUnits];
    NSArray* upCycle; // > 1.0
    NSArray* downCycle; // < 1.0

    upCycle = [NSArray arrayWithObject:[NSNumber numberWithDouble:m_rulerStepUpCycle]];
    downCycle = [NSArray arrayWithObject:[NSNumber numberWithDouble:1.0 / [self divisions]]];

    LogEvent_(kReactiveEvent, @"registering ruler units '%@', abbr: '%@'", units, abbr);

    [NSRulerView registerUnitWithName:units
                         abbreviation:abbr
         unitToPointsConversionFactor:conversionFactor
                          stepUpCycle:upCycle
                        stepDownCycle:downCycle];

    [[self drawing] synchronizeRulersWithUnits:units];
}

/** @brief Adjust the drawing margins to encompass an integral number of grid spans
 @note
 This method alters the existing drawing margins such that a whole number of
 spans is spanned by the interior area of the drawing. The margins are only ever moved inwards (enlarged) by this
 method to ensure that the interior of a drawing always remains within the printable area of a
 printer (assuming margins were set by the printing parameters originally - not always the case).
 Note - from B5, this method changed to adjust all margins, not just centre the interior. The result
 is much nicer behaviour - you can set a very wide margin on one side for example and expect it to
 stay more or less where it is.
 */
- (void)tweakDrawingMargins
{
    NSAssert([self drawing] != nil, @"must add grid layer to a drawing or group within one before tweaking margins");

    NSSize paper = [[self drawing] drawingSize];
    CGFloat marg = [[self drawing] leftMargin] + [[self drawing] rightMargin];
    CGFloat q = [[self drawing] unitToPointsConversionFactor];
    CGFloat newLeft, newTop, newRight, newBottom;

    CGFloat dim = paper.width - marg;
    CGFloat rem = fmod(dim, q);

    if (rem < 0.001)
        rem = 0;

    newLeft = [[self drawing] leftMargin] + (rem * 0.5f);
    newRight = [[self drawing] rightMargin] + (rem * 0.5f);

    marg = [[self drawing] topMargin] + [[self drawing] bottomMargin];
    dim = paper.height - marg;
    rem = fmod(dim, q);

    if (rem < 0.001)
        rem = 0;

    newTop = [[self drawing] topMargin] + (rem * 0.5f);
    newBottom = [[self drawing] bottomMargin] + (rem * 0.5f);

    [[self drawing] setMarginsLeft:newLeft
                               top:newTop
                             right:newRight
                            bottom:newBottom];
    [self invalidateCache];
    [self synchronizeRulers];
}

#pragma mark -
#pragma mark - colours for grid display

/** @brief Sets the colour used to draw the spans
 @note
 Typically a grid is set using a theme colour rather than setting individual colours for each
 part of the grid, but it's up to you. see setGridThemeColour:
 @param colour a colour
 */
- (void)setSpanColour:(NSColor*)colour
{
    if (![self locked]) {
        [colour retain];
        [m_spanColour release];
        m_spanColour = colour;
        [self setNeedsDisplay:YES];
    }
}

/** @brief The colour used to draw the spans
 @note
 Typically a grid is set using a theme colour rather than setting individual colours for each
 part of the grid, but it's up to you.
 @return a colour
 */
- (NSColor*)spanColour
{
    return m_spanColour;
}

/** @brief Sets the colour used to draw the divisions
 @note
 Typically a grid is set using a theme colour rather than setting individual colours for each
 part of the grid, but it's up to you. see setGridThemeColour:
 @param colour a colour
 */
- (void)setDivisionColour:(NSColor*)colour
{
    if (![self locked]) {
        [colour retain];
        [m_divisionColour release];
        m_divisionColour = colour;
        [self setNeedsDisplay:YES];
    }
}

- (NSColor*)divisionColour
{
    return m_divisionColour;
}

/** @brief Sets the colour used to draw the majors
 @note
 Typically a grid is set using a theme colour rather than setting individual colours for each
 part of the grid, but it's up to you. see setGridThemeColour:
 @param colour a colour
 */
- (void)setMajorColour:(NSColor*)colour
{
    if (![self locked]) {
        [colour retain];
        [m_majorColour release];
        m_majorColour = colour;
        [self setNeedsDisplay:YES];
    }
}

- (NSColor*)majorColour
{
    return m_majorColour;
}

/** @brief Sets the colours used to draw the grid as a whole
 @note
 Typically a grid is set using a theme colour rather than setting individual colours for each
 part of the grid, but it's up to you. This sets the three separate colours based on lighter and
 darker variants of the passed colour. Note that it's usual to have some transparency (alpha) set
 for the theme colour.
 @param colour a colour
 */
- (void)setGridThemeColour:(NSColor*)colour
{
    if (![self locked]) {
        [self setSpanColour:colour];
        [self setDivisionColour:[colour lighterColorWithLevel:0.5]];
        [self setMajorColour:[colour darkerColorWithLevel:0.33]];
    }
}

- (NSColor*)themeColour
{
    return m_spanColour;
}

#pragma mark -
#pragma mark - converting between base (Quartz) and the grid

/** @brief Given a point in drawing coordinates, returns nearest grid intersection to that point
 @note
 The intersection of the nearest division is returned, which is smaller than the span. This is
 a fundamental operation when snapping a point to the grid.
 @param p a point in the drawing
 @return a point, the nearest grid intersection to the point
 */
- (NSPoint)nearestGridIntersectionToPoint:(NSPoint)p
{
    CGFloat dd = [self divisionDistance];
    CGFloat rem = fmod(p.x - [[self drawing] leftMargin], dd);

    if (rem > dd * 0.5f)
        p.x += (dd - rem);
    else
        p.x -= rem;

    rem = fmod(p.y - [[self drawing] topMargin], dd);

    if (rem > dd * 0.5f)
        p.y += (dd - rem);
    else
        p.y -= rem;

    return p;
}

/** @brief Given a width and height in drawing coordinates, returns the same adjusted to the nearest whole
 number of divisions
 @note
 The returned size cannot be larger than the drawing's interior in either dimension.
 @param size a size value
 @return a size, the nearest whole number of divisions to the original size
 */
- (NSSize)nearestGridIntegralToSize:(NSSize)size
{
    NSRect interior = [[self drawing] interior];
    CGFloat divs = 0.0;
    CGFloat rem;

    if (size.width > interior.size.width)
        size.width = interior.size.width;
    else {
        divs = [self divisionDistance];
        rem = fmod(size.width, divs);
        if (rem > divs / 2.0)
            size.width += (divs - rem);
        else
            size.width -= rem;
    }

    if (size.height > interior.size.height)
        size.height = interior.size.height;
    else {
        rem = fmod(size.height, divs);
        if (rem > divs / 2.0)
            size.height += (divs - rem);
        else
            size.height -= rem;
    }

    return size;
}

/** @brief Given a width and height in drawing coordinates, returns the same adjusted to the nearest whole
 number of spans
 @note
 The returned size cannot be larger than the drawing's interior in either dimension. As spans are
 a coarser measure than divisions, the adjusted size might differ substantially from the input.
 @param size a size value
 @return a size, the nearest whole number of spans to the original size
 */
- (NSSize)nearestGridSpanIntegralToSize:(NSSize)size
{
    NSRect interior = [[self drawing] interior];
    CGFloat divs, rem;

    if (size.width > interior.size.width)
        size.width = interior.size.width;
    else {
        divs = [self spanDistance];
        rem = fmod(size.width, divs);
        if (rem > divs / 2.0)
            size.width += (divs - rem);
        else
            size.width -= rem;
    }

    if (size.height > interior.size.height)
        size.height = interior.size.height;
    else {
        divs = [self spanDistance];
        rem = fmod(size.height, divs);
        if (rem > divs / 2.0)
            size.height += (divs - rem);
        else
            size.height -= rem;
    }

    return size;
}

/** @brief Given a point in drawing coordinates, returns the "real world" coordinate of the same point
 @note
 See also pointForGridLocation: which is the inverse operation
 @param pt a point local to the drawing
 @return a point giving the same position in terms of the grid's drawing units, etc.
 */
- (NSPoint)gridLocationForPoint:(NSPoint)pt
{
    NSPoint rp;
    CGFloat qs = [self spanDistance];
    NSRect margins = [[self drawing] interior];

    rp.x = (pt.x - margins.origin.x) / qs;
    rp.y = (pt.y - margins.origin.y) / qs;

    return rp;
}

/** @brief Given a point in "real world" coordinates, returns the drawing coordinates of the same point
 @note
 See also gridLocationForPoint: which is the inverse operation
 @param pt a point in terms of the grid's drawing units
 @return a point giving the same position in the drawing.
 */
- (NSPoint)pointForGridLocation:(NSPoint)gpt
{
    NSPoint rp;
    CGFloat qs = [self spanDistance];
    NSRect margins = [[self drawing] interior];

    rp.x = (gpt.x * qs) + margins.origin.x;
    rp.y = (gpt.y * qs) + margins.origin.y;

    return rp;
}

/** @brief Given a distance value in drawing coordinates, returns the grid's "real world" equivalent
 @note
 See also quartzDistanceForGridDistance: which is the inverse operation. Note that the h and v
 scales of a grid are assumed to be the same (in this implementtaion they always are).
 @param qd a distance given in drawing units (points)
 @return the distance in grid units
 */
- (CGFloat)gridDistanceForQuartzDistance:(CGFloat)qd
{
    // return the distance in grid terms of the quartz distance passed. Note - assumes h and v scaling is the same, which is usual.

    return qd / [self spanDistance];
}

/** @brief Given a distance value in the grid's "real world" coordinates, returns the quartz equivalent
 @note
 See also gridDistanceForQuartzDistance: which is the inverse operation
 @param gd a distance given in grid units
 @return the distance in quartz units
 */
- (CGFloat)quartzDistanceForGridDistance:(CGFloat)gd
{
    return gd * [self spanDistance];
}

#pragma mark -

/** @brief When the scale crosses the span threshold, the cache is invalidated and the span cycle adjusted
 @note
 This permits dynamic display of the span grid based on the zoom factor. Currently only one
 threshold is used
 @param scale the view's current scale
 */
- (void)adjustSpanCycleForViewScale:(CGFloat)scale
{
    if (scale <= mSpanCycleChangeThreshold && mCachedViewScale > mSpanCycleChangeThreshold) {
        // crossed the threshold going down in scale - increase the span cycle

        ++mSpanCycle;
        [self invalidateCache];
    } else if (scale > mSpanCycleChangeThreshold && mCachedViewScale <= mSpanCycleChangeThreshold) {
        --mSpanCycle;
        if (mSpanCycle < 1)
            mSpanCycle = 1;
        [self invalidateCache];
    }
    mCachedViewScale = scale;
}

/** @brief Removes the cached paths used to draw the grid when a grid parameter is changed
 @note
 The grid is cached to help speed up drawing, and is only recalculated when necessary.
 */
- (void)invalidateCache
{
    [m_divsCache release];
    [m_spanCache release];
    [m_majorsCache release];
    m_divsCache = nil;
    m_spanCache = nil;
    m_majorsCache = nil;

    if (m_cgl)
        CGLayerRelease(m_cgl);
    m_cgl = nil;
}

/** @brief Recreates the cached paths used to draw the grid when required
 @note
 The grid is cached to help speed up drawing, and is only recalculated when necessary.
 @param r the rect in which the grid is defined (typically the drawing interior)
 */
- (void)createGridCacheInRect:(NSRect)r
{
    CGFloat sp = NSMinX(r);
    CGFloat lp = 0.0;
    CGFloat divs;
    NSUInteger i, m;
    NSPoint a, b;

    m = 0;
    divs = [self divisionDistance];
    a.y = NSMinY(r);
    b.y = NSMaxY(r);

    if (mSpanCycle <= 0)
        mSpanCycle = 1;

    if (m_divsCache == nil) {
        //float divsDash[2] = { divs * 0.5f, divs * 0.5f };

        m_divsCache = [[NSBezierPath bezierPath] retain];
        //[m_divsCache setLineDash:divsDash count:2 phase:divs * 0.25f];
    }

    if (m_spanCache == nil) {
        //float spanDash[2] = { divs * 2, m_spanDistance - ( divs * 2 )};

        m_spanCache = [[NSBezierPath bezierPath] retain];
        //[m_spanCache setLineDash:spanDash count:2 phase:divs];
    }

    if (m_majorsCache == nil) {
        //float majDash[2] = { divs * 4, m_spansPerMajor * m_spanDistance - (divs * 4)};

        m_majorsCache = [[NSBezierPath bezierPath] retain];
        //[m_majorsCache setLineDash:majDash count:2 phase:divs * 2];
    }
    // first all the vertical lines

    CGFloat span = [self spanDistance] * mSpanMultiplier;

    while (lp < NSMaxX(r)) {
        lp = sp + (m * span);

        if ((m % m_spansPerMajor) == 0) {
            // drawing a major line
            a.x = b.x = lp;
            [m_majorsCache moveToPoint:a];
            [m_majorsCache lineToPoint:b];
        } else {
            a.x = b.x = lp;
            [m_spanCache moveToPoint:a];
            [m_spanCache lineToPoint:b];
        }

        // subdivide each span into the number of divisions

        for (i = 0; i < (m_divisionsPerSpan * mSpanCycle); ++i) {
            if (lp <= NSMaxX(r)) {
                a.x = b.x = lp;
                [m_divsCache moveToPoint:a];
                [m_divsCache lineToPoint:b];
            } else
                break;
            lp += divs;
        }
        m += mSpanCycle;
    }

    // horizontal lines:

    sp = lp = NSMinY(r);
    m = 0;
    a.x = NSMinX(r);
    b.x = NSMaxX(r);

    while (lp <= NSMaxY(r)) {
        lp = sp + (m * span);

        if ((m % m_spansPerMajor) == 0) {
            // drawing a major line
            a.y = b.y = lp;
            [m_majorsCache moveToPoint:a];
            [m_majorsCache lineToPoint:b];
        } else {
            a.y = b.y = lp;
            [m_spanCache moveToPoint:a];
            [m_spanCache lineToPoint:b];
        }
        for (i = 0; i < (m_divisionsPerSpan * mSpanCycle); ++i) {
            if (lp <= NSMaxY(r)) {
                a.y = b.y = lp;
                [m_divsCache moveToPoint:a];
                [m_divsCache lineToPoint:b];
            } else
                break;
            lp += divs;
        }
        m += mSpanCycle;
    }
}

- (void)drawBorderOutline:(DKDrawingView*)aView
{
    CGFloat zoom = [aView scale];
    CGFloat mlw;

    mlw = MIN(m_majorLineWidth / zoom, 1.0);

    if (zoom * mlw > 1.0)
        mlw = 0;

    [m_majorColour set];
    [NSBezierPath setDefaultLineWidth:mlw];

    NSRect mr = [[self drawing] interior];
    [NSBezierPath strokeRect:mr];
}

#pragma mark -
#pragma mark - user actions

/** @brief Set the grid to one ofthe default grids
 @note
 [sender tag] is interpreted as a measurement system value; restores either the metric or imperial
 defaults. Not super-useful, but handy for quickly exploring alternative grids.
 @param sender the sender of the action
 */
- (IBAction)setMeasurementSystemAction:(id)sender
{
    if (![self locked]) {
        DKGridMeasurementSystem ms = (DKGridMeasurementSystem)[sender tag];
        if (ms == kDKMetricDrawingGrid)
            [self setMetricDefaults];
        else
            [self setImperialDefaults];
        [self setNeedsDisplay:YES];
    }
}

#pragma mark -
#pragma mark As a DKLayer

/** @brief Draw the grid
 @note
 Draws the cached grid to the view
 @param rect the area of the view needing to be redrawn
 @param aView where it came from
 */
- (void)drawRect:(NSRect)rect inView:(DKDrawingView*)aView
{
#pragma unused(rect)

    // if the view scale has crossed the threshold for span cycle change, invalidate the cache

    [self adjustSpanCycleForViewScale:[aView scale]];

    NSRect mr = [[self drawing] interior];

    if (m_divsCache == nil)
        [self createGridCacheInRect:mr];

    // be smart about colour: if the drawing has a dark background, switch the divs and majors colours to give better contrast
    // this is very rarely required but for some unusual situations gives a more usable/visible grid.

    NSColor* dc = m_divisionColour;
    NSColor* mc = m_majorColour;

    CGFloat lum = [[[self drawing] paperColour] luminosity];

    if (lum < 0.67) {
        mc = m_divisionColour;
        dc = m_majorColour;
    }

    // draw directly from the cache. Apply the linewidth accounting for the view's scale factor

    CGFloat zoom = [aView scale];
    CGFloat dlw, slw, mlw;

    dlw = LIMIT(m_divisionLineWidth / zoom, 0.05, 1.0);
    slw = MIN(m_spanLineWidth / zoom, 1.0);
    mlw = MIN(m_majorLineWidth / zoom, 1.0);

    if (mDrawsDivisions && zoom >= mDivsSupressionScale) {
        if (zoom * dlw > 1.0)
            dlw = 0;

        [m_divsCache setLineWidth:dlw];
        [dc setStroke];
        [m_divsCache stroke];
    }

    if (mDrawsSpans && zoom >= mSpanSupressionScale) {
        if (zoom * slw > 1.0)
            slw = 0;

        [m_spanCache setLineWidth:slw];
        [m_spanColour setStroke];
        [m_spanCache stroke];
    }

    if (mDrawsMajors) {
        if (zoom * mlw > 1.0)
            mlw = 0;

        [m_majorsCache setLineWidth:mlw];
        [mc setStroke];
        [m_majorsCache stroke];
    }

    [self drawBorderOutline:aView];
}

/** @brief Return the selection colour
 @note
 This layer type doesn't make use of this inherited colour, so always returns nil. A UI may use that
 as a cue to supress a widget for setting the layer's colour.
 @return nil
 */
- (NSColor*)selectionColour
{
    return nil;
}

- (void)setLayerGroup:(DKLayerGroup*)group
{
    [super setLayerGroup:group];
    [self synchronizeRulers];
}

- (void)drawingDidChangeToSize:(NSValue*)sizeVal
{
#pragma unused(sizeVal)

    [self invalidateCache];
}

- (void)drawingDidChangeMargins:(NSValue*)newInterior
{
#pragma unused(newInterior)

    [self invalidateCache];
}

/** @brief Return whether the layer can be deleted
 @note
 This setting is intended to be checked by UI-level code to prevent deletion of layers within the UI.
 It does not prevent code from directly removing the layer.
 @return NO - typically grid layers shouldn't be deleted
 */
- (BOOL)layerMayBeDeleted
{
    return NO;
}

/** @brief Allows a contextual menu to be built for the layer or its contents
 @param theEvent the original event (a right-click mouse event)
 @param view the view that received the original event
 @return a menu that will be displayed as a contextual menu
 */
- (NSMenu*)menuForEvent:(NSEvent*)theEvent inView:(NSView*)view
{
    NSMenu* menu = [super menuForEvent:theEvent
                                inView:view];

    if (menu == nil)
        menu = [[[NSMenu alloc] initWithTitle:@"DK_GridLayerContextualMenu"] autorelease]; // title never seen

    NSMenuItem* item = [menu addItemWithTitle:NSLocalizedString(@"Copy Grid", nil)
                                       action:@selector(copy:)
                                keyEquivalent:@""];
    [item setTarget:self];

    return menu;
}

- (BOOL)supportsMetadata
{
    return NO;
}

#pragma mark -
#pragma mark As an NSObject
- (void)dealloc
{
    [self invalidateCache]; // Releases cache
    [m_majorColour release];
    [m_divisionColour release];
    [m_spanColour release];

    [super dealloc];
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        [self setSpanColour:[[self class] defaultSpanColour]];
        [self setDivisionColour:[[self class] defaultDivisionColour]];
        [self setMajorColour:[[self class] defaultMajorColour]];

        m_spanLineWidth = 0.3;
        m_divisionLineWidth = 0.1;
        m_majorLineWidth = 0.6;
        mSpanMultiplier = 1.0;
        mSpanCycle = 1;
        mDivsSupressionScale = 0.5;
        mSpanSupressionScale = 0.1;
        mSpanCycleChangeThreshold = 0.5;
        mCachedViewScale = 1.0;
        mDrawsDivisions = YES;
        mDrawsSpans = YES;
        mDrawsMajors = YES;

        if (m_spanColour == nil
            || m_divisionColour == nil
            || m_majorColour == nil) {
            [self autorelease];
            self = nil;
        }
    }
    if (self != nil) {
        [self setShouldDrawToPrinter:NO];
        [self setMetricDefaults];
        [self setLayerName:NSLocalizedString(@"Grid", @"default name for grid layer")];
    }
    return self;
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
    NSAssert(coder != nil, @"Expected valid coder");
    [super encodeWithCoder:coder];

    [coder encodeObject:m_spanColour
                 forKey:@"span_colour"];
    [coder encodeObject:m_divisionColour
                 forKey:@"div_colour"];
    [coder encodeObject:m_majorColour
                 forKey:@"major_colour"];

    [coder encodeDouble:[self spanDistance]
                 forKey:@"span_dist_d"];
    [coder encodeDouble:mSpanMultiplier
                 forKey:@"DKGridLayer_span_multiplier"];

    [coder encodeDouble:m_spanLineWidth
                 forKey:@"span_width"];
    [coder encodeDouble:m_divisionLineWidth
                 forKey:@"div_width"];
    [coder encodeDouble:m_majorLineWidth
                 forKey:@"major_width"];

    [coder encodeInteger:m_divisionsPerSpan
                  forKey:@"divs_span_h"];
    [coder encodeInteger:m_spansPerMajor
                  forKey:@"spans_maj_h"];
    [coder encodeInteger:m_rulerStepUpCycle
                  forKey:@"ruler_steps"];

    // these flags are stored inverted so that older files that lack them preset them to YES

    [coder encodeBool:!mDrawsDivisions
               forKey:@"DKGridLayer_inv_drawsDivisions"];
    [coder encodeBool:!mDrawsSpans
               forKey:@"DKGridLayer_inv_drawsSpans"];
    [coder encodeBool:!mDrawsMajors
               forKey:@"DKGridLayer_inv_drawsMajors"];
}

- (id)initWithCoder:(NSCoder*)coder
{
    NSAssert(coder != nil, @"Expected valid coder");
    self = [super initWithCoder:coder];
    if (self != nil) {
        // set colours directly in case the locked flag was saved in the locked state

        m_spanColour = [[coder decodeObjectForKey:@"span_colour"] retain];
        m_divisionColour = [[coder decodeObjectForKey:@"div_colour"] retain];
        m_majorColour = [[coder decodeObjectForKey:@"major_colour"] retain];

        double span = [coder decodeDoubleForKey:@"span_dist_d"];
        // if this value is 0, try reading it as a size value (older code will have written it as such)
        // this allows old drawings to still be read - will be saved in new form subsequently
        if (span == 0.0) {
            NSSize sd = [coder decodeSizeForKey:@"span_dist"];
            span = sd.width;
        }

        CGFloat spMult = [coder decodeDoubleForKey:@"DKGridLayer_span_multiplier"];
        if (spMult == 0.0)
            spMult = 1.0;

        mSpanMultiplier = spMult;

        m_spanLineWidth = [coder decodeDoubleForKey:@"span_width"];
        m_divisionLineWidth = [coder decodeDoubleForKey:@"div_width"];
        m_majorLineWidth = [coder decodeDoubleForKey:@"major_width"];

        mSpanCycle = 1;
        mDivsSupressionScale = 0.5;
        mSpanSupressionScale = 0.1;
        mCachedViewScale = 1.0;
        mSpanCycleChangeThreshold = 0.5;

        NSString* units = [[self drawing] drawingUnits];
        [[self drawing] setDrawingUnits:units
            unitToPointsConversionFactor:span];

        m_divisionsPerSpan = [coder decodeIntegerForKey:@"divs_span_h"];
        m_spansPerMajor = [coder decodeIntegerForKey:@"spans_maj_h"];

        [self setRulerSteps:[coder decodeIntegerForKey:@"ruler_steps"]];

        // these flags are archived inverted

        mDrawsDivisions = ![coder decodeBoolForKey:@"DKGridLayer_inv_drawsDivisions"];
        mDrawsSpans = ![coder decodeBoolForKey:@"DKGridLayer_inv_drawsSpans"];
        mDrawsMajors = ![coder decodeBoolForKey:@"DKGridLayer_inv_drawsMajors"];
    }

    return self;
}

#pragma mark -
#pragma mark As part of NSMenuValidation protocol

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
    SEL action = [item action];

    if (action == @selector(copy:)) {
        NSString* title = NSLocalizedString(@"Copy %@", nil);
#warning 64BIT: Check formatting arguments
        [item setTitle:[NSString stringWithFormat:title, [self layerName]]];
        return YES;
    }

    if (action == @selector(setMeasurementSystemAction:))
        return ![self locked];

    return [super validateMenuItem:item];
}

@end
