/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawing.h"
#import "DKDrawing+Paper.h"
#import "DKCategoryManager.h"
#import "DKStyle.h"
#import "DKStyleRegistry.h"
#import "DKDrawingTool.h"
#import "DKDrawingView.h"
#import "DKDrawKitMacros.h"
#import "DKGridLayer.h"
#import "DKGuideLayer.h"
#import "DKKnob.h"
#import "DKObjectDrawingLayer.h"
#import "DKViewController.h"
#import "DKUniqueID.h"
#import "LogEvent.h"
#import "DKLayer+Metadata.h"
#import "DKImageDataManager.h"
#import "DKKeyedUnarchiver.h"
#import "DKUnarchivingHelper.h"
#import "DKUndoManager.h"

#pragma mark Contants(Non - localized)

// notifications:

NSString* kDKDrawingActiveLayerWillChange = @"kDKDrawingActiveLayerWillChange";
NSString* kDKDrawingActiveLayerDidChange = @"kDKDrawingActiveLayerDidChange";
NSString* kDKDrawingWillChangeSize = @"kDKDrawingWillChangeSize";
NSString* kDKDrawingDidChangeSize = @"kDKDrawingDidChangeSize";
NSString* kDKDrawingUnitsWillChange = @"kDKDrawingUnitsWillChange";
NSString* kDKDrawingUnitsDidChange = @"kDKDrawingUnitsDidChange";
NSString* kDKDrawingWillChangeMargins = @"kDKDrawingWillChangeMargins";
NSString* kDKDrawingDidChangeMargins = @"kDKDrawingDidChangeMargins";
NSString* kDKDrawingWillBeSavedOrExported = @"kDKDrawingWillBeSavedOrExported";

// drawng info keys:

NSString* kDKDrawingInfoUserInfoKey = @"kDKDrawingInfoUserInfoKey";

NSString* kDKDrawingInfoDrawingNumber = @"kDKDrawingInfoDrawingNumber";
NSString* kDKDrawingInfoDrawingNumberUnformatted = @"kDKDrawingInfoDrawingNumberUnformatted";
NSString* kDKDrawingInfoDrawingRevision = @"kDKDrawingInfoDrawingRevision";
NSString* kDKDrawingInfoDrawingPrefix = @"kDKDrawingInfoDrawingPrefix";

NSString* kDKDrawingInfoDraughter = @"kDKDrawingInfoDraughter";
NSString* kDKDrawingInfoCreationDate = @"kDKDrawingInfoCreationDate";
NSString* kDKDrawingInfoLastModificationDate = @"kDKDrawingInfoLastModificationDate";
NSString* kDKDrawingInfoModificationHistory = @"kDKDrawingInfoModificationHistory";
NSString* kDKDrawingInfoOriginalFilename = @"kDKDrawingInfoOriginalFilename";
NSString* kDKDrawingInfoTitle = @"kDKDrawingInfoTitle";
NSString* kDKDrawingInfoDrawingDimensions = @"kDKDrawingInfoDrawingDimensions";
NSString* kDKDrawingInfoDimensionsUnits = @"kDKDrawingInfoDimensionsUnits";
NSString* kDKDrawingInfoDimensionsShortUnits = @"kDKDrawingInfoDimensionsShortUnits";

// user default keys:

NSString* kDKDrawingSnapToGridUserDefault = @"kDKDrawingSnapToGridUserDefault";
NSString* kDKDrawingSnapToGuidesUserDefault = @"kDKDrawingSnapToGuidesUserDefault";
NSString* kDKDrawingUnitAbbreviationsUserDefault = @"kDKDrawingUnitAbbreviations";

// drawing units:

NSString *const DKDrawingUnitInches = @"inches";
NSString *const DKDrawingUnitMillimetres = @"millimetres";
NSString *const DKDrawingUnitCentimetres = @"centimetres";
NSString *const DKDrawingUnitMetres = @"metres";
NSString *const DKDrawingUnitKilometres = @"kilometres";
NSString *const DKDrawingUnitPicas = @"picas";
NSString *const DKDrawingUnitPixels = @"pixels";
NSString *const DKDrawingUnitFeet = @"feet";
NSString *const DKDrawingUnitYards = @"yards";
NSString *const DKDrawingUnitPoints = @"points";
NSString *const DKDrawingUnitMiles = @"miles";

#pragma mark Static vars

static id sDearchivingHelper = nil;

#pragma mark -
@implementation DKDrawing
#pragma mark As a DKDrawing
//! Return the current version number of the framework.

//!	A number formatted in 8-4-4 bit format representing the current version number

/** @brief Return the current version number of the framework
 @return a number formatted in 8-4-4 bit format representing the current version number
 */
+ (NSUInteger)drawkitVersion
{
	return 0x0107;
}

//! Return the current release status of the framework.

//! A string, either "alpha", "beta", "release candidate" or nil (final)

/** @brief Return the current release status of the framework
 @return a string, either "alpha", "beta", "release candidate" or nil (final)
 */
+ (NSString*)drawkitReleaseStatus
{
	return @"beta";
}

/** @brief Return the current version number and release status as a preformatted string

 This is intended for occasional display, rather than testing for the framework version.
 @return a string, e.g. "1.0.b6"
 */
+ (NSString*)drawkitVersionString
{
	NSUInteger v = [self drawkitVersion];
	unsigned char s = 0;

	NSString* status = [self drawkitReleaseStatus];

	if ([status isEqualToString:@"beta"])
		s = 'b';
	else if ([status isEqualToString:@"alpha"])
		s = 'a';

	return [NSString stringWithFormat:@"%ld.%ld.%c%ld", (long)(v & 0xFF00) >> 8, (long)(v & 0xF0) >> 4, s, (long)(v & 0x0F)];
}

#pragma mark -
//! Constructs the default drawing system for a view when the system isn't prebuilt "by hand".

//! As a convenience for users of this system, if you set up a DKDrawingView in IB, and do nothing else,
//!	you'll get a fully working, prebuilt drawing system behind that view. This can be very handy for all
//!	sorts of uses. However, it is more usual to build the system the other way around - start with a
//!	drawing object within a document (say) and attach views to it.

/** @brief Constructs the default drawing system when the system isn't prebuilt "by hand"

 As a convenience for users of DrawKit, if you set up a DKDrawingView in IB, and do nothing else,
 you'll get a fully working, prebuilt drawing system behind that view. This can be very handy for all
 sorts of uses. However, it is more usual to build the system the other way around - start with a
 drawing object within a document (say) and attach views to it. This gives you the flexibility to
 do it either way. For automatic construction, this method is called to supply the drawing.
 @param aSize - the size of the drawing to create
 @return a fully constructed default drawing system
 */
+ (DKDrawing*)defaultDrawingWithSize:(NSSize)aSize
{
	// for when a view builds the back-end automatically, this supplies a default drawing complete with a grid layer, an object drawing
	// layer, and the view attached. The drawing size is set to the current view bounds size.

	NSAssert(aSize.width > 0.0, @"width of drawing size was zero or negative");
	NSAssert(aSize.height > 0.0, @"height of drawing size was zero or negative");

	// the defaults chosen here may need to be simplified - in general, would we want a grid, for example?

	DKDrawing* dr = [[self alloc] initWithSize:aSize];
	[dr setMarginsLeft:5.0
				   top:5.0
				 right:5.0
				bottom:5.0];

	// attach a grid layer
	[DKGridLayer setDefaultGridThemeColour:[[NSColor brownColor] colorWithAlphaComponent:0.5]];
	DKGridLayer* grid = [DKGridLayer standardMetricGridLayer];
	[dr addLayer:grid];
	[grid tweakDrawingMargins];

	// attach a drawing layer and make it the active layer

	DKObjectDrawingLayer* layer = [[DKObjectDrawingLayer alloc] init];
	[dr addLayer:layer];
	[dr setActiveLayer:layer];
	[layer release];

	// attach a guide layer

	DKGuideLayer* guides = [[DKGuideLayer alloc] init];
	[dr addLayer:guides];
	[guides release];

	return [dr autorelease];
}

/** @brief Creates a drawing from a lump of data
 @param drawingData data representing an archived drawing
 @return the unarchived drawing
 */
+ (DKDrawing*)drawingWithData:(NSData*)drawingData
{
	NSAssert(drawingData != nil, @"drawing data was nil - unable to proceed");
	NSAssert([drawingData length] > 0, @"drawing data was empty - unable to proceed");

	// using DKKeyedUnarchiver allows passing of image data manager to dearchiving methods for certain objects

	DKKeyedUnarchiver* unarch = [[DKKeyedUnarchiver alloc] initForReadingWithData:drawingData];

	// in order to translate older files with classes named 'GC' instead of 'DK', need a delegate that can handle the
	// translation. DKUnarchivingHelper can also be used to report loading progress.

	id dearchivingHelper = [self dearchivingHelper];
	if ([dearchivingHelper respondsToSelector:@selector(reset)])
		[dearchivingHelper reset];

	[unarch setDelegate:dearchivingHelper];

	LogEvent_(kReactiveEvent, @"decoding drawing root object......");

	DKDrawing* dwg = [unarch decodeObjectForKey:@"root"];

	[unarch finishDecoding];
	[unarch release];

	return dwg;
}

/** @brief Return the default derachiving helper for deaerchiving a drawing

 This helper is a delegate of the dearchiver during dearchiving and translates older or obsolete
 classes into modern ones, etc. The default helper deals with older DrawKit classes, but can be
 replaced to provide the same functionality for application-specific classes.
 @return the dearchiving helper
 */
+ (id)dearchivingHelper
{
	if (sDearchivingHelper == nil)
		sDearchivingHelper = [[DKUnarchivingHelper alloc] init];

	return sDearchivingHelper;
}

/** @brief Replace the default dearchiving helper for deaerchiving a drawing

 This helper is a delegate of the dearchiver during dearchiving and translates older or obsolete
 classes into modern ones, etc. The default helper deals with older DrawKit classes, but can be
 replaced to provide the same functionality for application-specific classes.
 @param helper a suitable helper object
 */
+ (void)setDearchivingHelper:(id)helper
{
	[helper retain];
	[sDearchivingHelper release];
	sDearchivingHelper = helper;
}

#pragma mark -

/** @brief Returns a new drawing number by incrementing the current default seed value
 @return a new drawing number
 */
+ (NSUInteger)newDrawingNumber
{
	NSUInteger dNum = [[NSUserDefaults standardUserDefaults] integerForKey:@"DKDrawing_drawingNumberSeedValue"] + 1;
	[[NSUserDefaults standardUserDefaults] setInteger:dNum
											   forKey:@"DKDrawing_drawingNumberSeedValue"];

	return dNum;
}

/** @brief Returns a dictionary containing some standard drawing info attributes

 This is usually called by the drawing object itself when built new. Usually you'll want to replace
 its contents with your own info. A DKDrawingInfoLayer can interpret some of the standard values and
 display them in its info box.
 @return a mutable dictionary of standard drawing info
 */
+ (NSMutableDictionary*)defaultDrawingInfo
{
	NSMutableDictionary* di = [[NSMutableDictionary alloc] init];

	NSUInteger revision = 1;
	NSUInteger drawingNumber = [self newDrawingNumber];
	NSString* prefix = @"A2";

	[di setObject:[NSNumber numberWithInteger:revision]
		   forKey:[kDKDrawingInfoDrawingRevision lowercaseString]];
	[di setObject:prefix
		   forKey:[kDKDrawingInfoDrawingPrefix lowercaseString]];
	[di setObject:[NSNumber numberWithInteger:drawingNumber]
		   forKey:[kDKDrawingInfoDrawingNumberUnformatted lowercaseString]];
	[di setObject:[NSString stringWithFormat:@"%@-%06ld-%04ld", prefix, (long)drawingNumber, (long)revision]
		   forKey:[kDKDrawingInfoDrawingNumber lowercaseString]];

	[di setObject:[NSFullUserName() capitalizedString]
		   forKey:[kDKDrawingInfoDraughter lowercaseString]];
	[di setObject:[NSDate date]
		   forKey:[kDKDrawingInfoCreationDate lowercaseString]];
	[di setObject:[NSDate date]
		   forKey:[kDKDrawingInfoLastModificationDate lowercaseString]];

	return [di autorelease];
}

/** @brief Sets the abbreviation for the given drawing units string

 This allows special abbreviations to be set for units if desired. The setting writes to the user
 defaults so is persistent.
 @param abbrev the abbreviation for the unit
 @param fullString the full name of the drawing units
 */
+ (void)setAbbreviation:(NSString*)abbrev forDrawingUnits:(NSString*)fullString
{
	// ensure the defaults exist

	[self abbreviationForDrawingUnits:fullString];

	// change or set the setting

	NSMutableDictionary* dict = [[[NSUserDefaults standardUserDefaults] objectForKey:kDKDrawingUnitAbbreviationsUserDefault] mutableCopy];
	[dict setObject:abbrev
			 forKey:[fullString lowercaseString]];
	[[NSUserDefaults standardUserDefaults] setObject:dict
											  forKey:kDKDrawingUnitAbbreviationsUserDefault];
	[dict release];
}

/** @brief Returns the abbreviation for the given drawing units string
 @param fullString the full name of the drawing units
 @return a string - the abbreviated form
 */
+ (NSString*)abbreviationForDrawingUnits:(NSString*)fullString
{
	NSDictionary* abbrevs = [[NSUserDefaults standardUserDefaults] objectForKey:kDKDrawingUnitAbbreviationsUserDefault];

	if (abbrevs == nil) {
		abbrevs = [NSDictionary dictionaryWithObjectsAndKeys:@"in.", @"inches",
															 @"mm", @"millimetres",
															 @"cm", @"centimetres",
															 @"m", @"metres",
															 @"km", @"kilometres",
															 @"pc", @"picas",
															 @"px", @"pixels",
															 @"ft.", @"feet",
															 @"yd.", @"yards",
															 @"pt", @"points",
															 @"mi", @"miles", nil];

		[[NSUserDefaults standardUserDefaults] setObject:abbrevs
												  forKey:kDKDrawingUnitAbbreviationsUserDefault];
	}

	NSString* abbr = [abbrevs objectForKey:[fullString lowercaseString]];

	if (abbr == nil) {
		// make up an abbreviation using the first two characters and a .
		//abbr = [NSString stringWithFormat:@"%@.", [[fullString lowercaseString] substringWithRange:NSMakeRange(0, MIN([fullString length], 2U))]];

		abbr = fullString;
	}

	return abbr;
}

#pragma mark -
#pragma mark - deprecated

//! Creates a drawing from the named file.

//! Unarchives the file at <filename>, and returns the unarchived drawing object
//! \param filename a full path to the file

/** @brief Creates a drawing from the named file

 Deprecated
 @param filename full path to the file in question
 @return the unarchived drawing
 */
+ (DKDrawing*)drawingWithContentsOfFile:(NSString*)filename
{
	return [self drawingWithData:[NSData dataWithContentsOfMappedFile:filename]
				  fromFileAtPath:filename];
}

/** @brief Creates a drawing from a lump of data, and also sets the drawing metadata to contain the original filename

 Deprecated - rarely of practical use
 @param drawingData data representing an archived drawing
 @param filepath the full path of the original file
 @return the unarchived drawing
 */
+ (DKDrawing*)drawingWithData:(NSData*)drawingData fromFileAtPath:(NSString*)filepath
{
	DKDrawing* dwg = [self drawingWithData:drawingData];

	// insert the filename into the drawing metadata

	[[dwg drawingInfo] setObject:[filepath lastPathComponent]
						  forKey:kDKDrawingInfoOriginalFilename];

	return dwg;
}

/** @brief Saves the static class defaults for ALL classes in the drawing system

 Deprecated - no longer does anything
 */
+ (void)saveDefaults
{
}

/** @brief Loads the static user defaults for all classes in the drawing system

 Deprecated - no longer does anything
 */
+ (void)loadDefaults
{
}

#pragma mark -
#pragma mark - designated initializer

/** @brief Initialises a newly allocated drawing model object

 Sets up the drawing in its default state. No layers are added initially.
 @param size the paper size for the drawing
 @return the initialised drawing object
 */
- (id)initWithSize:(NSSize)size
{
	self = [super init];
	if (self != nil) {
		[self setFlipped:YES];
		[self setDrawingSize:size];
		CGFloat m = 25.0;
		[self setMarginsLeft:m
						 top:m
					   right:m
					  bottom:m];
		[self setDrawingUnits:@"Centimetres"
			unitToPointsConversionFactor:kDKGridDrawingLayerMetricInterval];
		mControllers = [[NSMutableSet alloc] init];

		[self setKnobs:[DKKnob standardKnobs]];
		[self setPaperColour:[NSColor whiteColor]];
		[self setDrawingInfo:[[self class] defaultDrawingInfo]];

		m_snapsToGrid = ![[NSUserDefaults standardUserDefaults] boolForKey:kDKDrawingSnapToGridUserDefault];
		m_snapsToGuides = ![[NSUserDefaults standardUserDefaults] boolForKey:kDKDrawingSnapToGuidesUserDefault];
		[self setKnobsShouldAdustToViewScale:YES];
		m_lastRenderTime = [NSDate timeIntervalSinceReferenceDate];

		[self setDynamicQualityModulationEnabled:NO];
		[self setLowQualityTriggerInterval:0.2];

		mImageManager = [[DKImageDataManager alloc] init];

		if (m_units == nil
			|| [self knobs] == nil
			|| m_paperColour == nil
			|| mControllers == nil) {
			[self autorelease];
			self = nil;
		}
	}
	return self;
}

/** @brief Returns the "owner" of this drawing.

 The owner is usually either a document, a window controller or a drawing view.
 @return the owner
 */
- (id)owner
{
	return mOwnerRef;
}

/** @brief Sets the "owner" of this drawing.

 The owner is usually either a document, a window controller or a drawing view. It is not required to
 be set at all, though some higher-level conveniences may depend on it.
 @param owner the owner for this object
 */
- (void)setOwner:(id)owner
{
	mOwnerRef = owner;
}

#pragma mark -
#pragma mark - basic drawing parameters

/** @brief Sets the paper dimensions of the drawing.

 The paper size is the absolute limits of ths drawing dimensions. Usually margins are set within this.
 @param aSize the paper size in Quartz units
 */
- (void)setDrawingSize:(NSSize)aSize
{
	NSAssert(aSize.width > 0.0, @"width cant be zero or negative");
	NSAssert(aSize.height > 0.0, @"height can't be zero or negative");

	if (!NSEqualSizes(aSize, m_size)) {
		LogEvent_(kReactiveEvent, @"setting drawing size = {%f, %f}", aSize.width, aSize.height);

		[[[self undoManager] prepareWithInvocationTarget:self] setDrawingSize:[self drawingSize]];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingWillChangeSize
															object:self];
		m_size = aSize;

		// adjust bounds of every view to match

		[self drawingDidChangeToSize:[NSValue valueWithSize:aSize]];
		[[self controllers] makeObjectsPerformSelector:@selector(drawingDidChangeToSize:)
											withObject:[NSValue valueWithSize:aSize]];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingDidChangeSize
															object:self];

		if (!([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
			[[self undoManager] setActionName:NSLocalizedString(@"Change Drawing Size", @"undo action for set drawing size")];
	}
}

/** @brief Returns the current paper size of the drawing
 @return the drawing size
 */
- (NSSize)drawingSize
{
	return m_size;
}

/** @brief Sets the drawing's paper size and margins to be equal to the sizes stored in a NSPrintInfo object.

 Can be used to synchronise a drawing size to the settings for a printer
 @param printInfo a NSPrintInfo object, obtained from the printing system
 */
- (void)setDrawingSizeWithPrintInfo:(NSPrintInfo*)printInfo
{
	NSAssert(printInfo != nil, @"unable to set drawing size - print info was nil");

	[self setDrawingSize:[printInfo paperSize]];
	[self setMarginsWithPrintInfo:printInfo];
}

#pragma mark -

/** @brief Sets the margins for the drawing

 The margins inset the drawing area within the \c papersize set
 @param l the left margin in Quartz units
 @param t the top margin in Quartz units
 @param r the right margin in Quartz units
 @param b the bottom margin in Quartz units
 */
- (void)setMarginsLeft:(CGFloat)l top:(CGFloat)t right:(CGFloat)r bottom:(CGFloat)b
{
	if (l != m_leftMargin || r != m_rightMargin || t != m_topMargin || b != m_bottomMargin) {
		LogEvent_(kReactiveEvent, @"setting margins = {%f, %f, %f, %f}", l, t, r, b);

		[[[self undoManager] prepareWithInvocationTarget:self] setMarginsLeft:m_leftMargin
																		  top:m_topMargin
																		right:m_rightMargin
																	   bottom:m_bottomMargin];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingWillChangeMargins
															object:self];

		NSRect oldInterior = [self interior];

		m_leftMargin = l;
		m_rightMargin = r;
		m_topMargin = t;
		m_bottomMargin = b;

		[self drawingDidChangeMargins:[NSValue valueWithRect:oldInterior]];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingDidChangeMargins
															object:self];
		[self setNeedsDisplay:YES];

		if (!([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
			[[self undoManager] setActionName:NSLocalizedString(@"Change Margins", @"undo action for set margins")];
	}
}

/** @brief Sets the margins from the margin values stored in a NSPrintInfo object

 SetDrawingSizeFromPrintInfo: will also call this for you
 @param printInfo a NSPrintInfo object, obtained from the printing system
 */
- (void)setMarginsWithPrintInfo:(NSPrintInfo*)printInfo
{
	[self setMarginsLeft:[printInfo leftMargin]
					 top:[printInfo topMargin]
				   right:[printInfo rightMargin]
				  bottom:[printInfo bottomMargin]];
}

/** @return the width of the left margin
 */
- (CGFloat)leftMargin
{
	return m_leftMargin;
}

/** @return the width of the right margin
 */
- (CGFloat)rightMargin
{
	return m_rightMargin;
}

/** @return the width of the top margin
 */
- (CGFloat)topMargin
{
	return m_topMargin;
}

/** @return the width of the bottom margin
 */
- (CGFloat)bottomMargin
{
	return m_bottomMargin;
}

/** @brief Returns the interior region of the drawing, within the margins
 @return a rectangle, the interior area of the drawing (paper size less margins)
 */
- (NSRect)interior
{
	NSRect r = NSZeroRect;

	r.size = [self drawingSize];
	r.origin.x += [self leftMargin];
	r.origin.y += [self topMargin];
	r.size.width -= ([self leftMargin] + [self rightMargin]);
	r.size.height -= ([self topMargin] + [self bottomMargin]);

	return r;
}

/** @brief Constrains the point within the interior area of the drawing
 @param p a point structure
 @return a point, equal to p if p is within the interior, otherwise pinned to the nearest point within
 */
- (NSPoint)pinPointToInterior:(NSPoint)p
{
	NSRect r = [self interior];
	NSPoint pin;

	pin.x = LIMIT(p.x, NSMinX(r), NSMaxX(r));
	pin.y = LIMIT(p.y, NSMinY(r), NSMaxY(r));

	return pin;
}

/** @brief Sets whether the Y axis of the drawing is flipped

 Drawings are typically flipped, YES is the default. This affects the -isFlipped return from a
 DKDrawingView. WARNING: drawings with flip set to NO may have issues at present as some lower level
 code is currently assuming a flipped view.
 @param flipped YES to have increase Y going down, NO for increasing Y going up
 */
- (void)setFlipped:(BOOL)flipped
{
	if (flipped != mFlipped) {
		mFlipped = flipped;
		[self setNeedsDisplay:YES];
	}
}

/** @brief Whether the Y axis of the drawing is flipped

 Drawings are typically flipped, YES is the default. This affects the -isFlipped return from a
 DKDrawingView
 @return YES to have increase Y going down, NO for increasing Y going up
 */
- (BOOL)isFlipped
{
	return mFlipped;
}

/** @brief Sets the destination colour space for the whole drawing

 Colours set by styles and so forth are converted to this colourspace when rendering. A value of
 nil will use whatever is set in the colours used by the styles.
 @param cSpace the colour space 
 */
- (void)setColourSpace:(NSColorSpace*)cSpace
{
	[cSpace retain];
	[mColourSpace release];
	mColourSpace = cSpace;
}

/** @brief Returns the colour space for the whole drawing

 Colours set by styles and so forth are converted to this colourspace when rendering. A value of
 nil will use whatever is set in the colours used by the styles.
 @return the colour space
 */
- (NSColorSpace*)colourSpace
{
	return mColourSpace;
}

#pragma mark -
#pragma mark - setting the rulers to the grid

/** @brief Sets the units and basic coordinate mapping factor
 @param units a string which is the drawing units of the drawing, e.g. "millimetres"
 @param conversionFactor how many Quartz points per basic unit?
 */
- (void)setDrawingUnits:(NSString*)units unitToPointsConversionFactor:(CGFloat)conversionFactor
{
	NSAssert(units != nil, @"cannot set drawing units to nil");
	NSAssert([units length] > 0, @"units string is empty");

	if (conversionFactor != m_unitConversionFactor || ![units isEqualToString:m_units]) {
		LogEvent_(kReactiveEvent, @"setting drawing units:'%@'", units);

		[[[self undoManager] prepareWithInvocationTarget:self] setDrawingUnits:m_units
												  unitToPointsConversionFactor:m_unitConversionFactor];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingUnitsWillChange
															object:self];
		[units retain];
		[m_units release];
		m_units = [units copy];
		[units release];
		m_unitConversionFactor = conversionFactor;
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingUnitsDidChange
															object:self];
	}
}

@synthesize drawingUnits=m_units;

/** @brief Returns the abbreviation of the drawing's units

 For those it knows about, it does a lookup. For unknown units, it uses the first two characters
 and makes them lower case. The delegate can also elect to supply this string if it prefers.
 @return a string
 */
- (NSString*)abbreviatedDrawingUnits
{
	NSString* abbrev = nil;

	if ([[self delegate] respondsToSelector:@selector(drawing:
												willReturnAbbreviationForUnit:)])
		abbrev = [[self delegate] drawing:self
			willReturnAbbreviationForUnit:[self drawingUnits]];

	if (abbrev)
		return abbrev;
	else
		return [[self class] abbreviationForDrawingUnits:[self drawingUnits]];
}

/** @brief Returns the number of Quartz units per basic drawing unit
 @return the conversion value
 */
- (CGFloat)unitToPointsConversionFactor
{
	return m_unitConversionFactor;
}

/** @brief Returns the number of Quartz units per basic drawing unit, as optionally determined by the delegate

 This allows the delegate to return a different value for special requirements. If the delegate does
 not respond, the normal conversion factor is returned. Note that DK currently doesn't use this
 internally but app-level code may do if it further overlays a coordinate mapping on top of the
 drawing's own.
 @return the conversion value
 */
- (CGFloat)effectiveUnitToPointsConversionFactor
{
	if ([[self delegate] respondsToSelector:@selector(drawingWillReturnUnitToPointsConversonFactor:)])
		return [[self delegate] drawingWillReturnUnitToPointsConversonFactor:self];
	else
		return [self unitToPointsConversionFactor];
}

/** @brief Sets up the rulers for all attached views to a previously registered ruler state

 DKGridLayer registers rulers to match its grid using the drawingUnits string returned by
 this class as the registration key. If your drawing doesn't have a grid but does use the rulers,
 you need to register the ruler setup yourself somewhere.
 @param unitString the name of a previously registered ruler state
 */
- (void)synchronizeRulersWithUnits:(NSString*)unitString
{
	[[self controllers] makeObjectsPerformSelector:@selector(synchronizeViewRulersWithUnits:)
										withObject:unitString];
}

@synthesize delegate=mDelegateRef;

#pragma mark -
#pragma mark - controllers attachment

/** @brief Return the current controllers the drawing owns

 Controllers are in no particular order. The drawing object owns its controllers.
 @return a set of the current controllers
 */
- (NSSet*)controllers
{
	return mControllers;
}

/** @brief Add a controller to the drawing

 A controller is associated with a view, but must be added to the drawing to forge the connection
 between the drawing and its views. The drawing owns the controller. DKDrawingDocument and the
 automatic back-end set-up handle all of this for you - you only need this if you are building
 the DK system entirely by hand.
 @param aController the controller to add
 */
- (void)addController:(DKViewController*)aController
{
	NSAssert(aController != nil, @"cannot add a nil controller to drawing");

	if (![aController isKindOfClass:[DKViewController class]])
		[NSException raise:NSInternalInconsistencyException
					format:@"attempt to add an invalid object as a controller"];

	// synch the rulers here in case we got this far without any sort of view infrastructure in place - this can
	// occur when launching the app with a file to open in the Finder. Without synching the ruler class with throw
	// an exception which breaks the setup.

	[[self gridLayer] synchronizeRulers];
	[mControllers addObject:aController];
	[aController setDrawing:self];
}

/** @brief Removes a controller from the drawing

 Typically controllers are removed when necessary - there is little reason to call this yourself
 @param aController the controller to remove
 */
- (void)removeController:(DKViewController*)aController
{
	NSAssert(aController != nil, @"attempt to remove a nil controller from drawing");

	if ([[self controllers] containsObject:aController]) {
		[aController setDrawing:nil];
		[mControllers removeObject:aController];
	}
}

/** @brief Removes all controller from the drawing

 Typically controllers are removed when necessary - there is little reason to call this yourself
 */
- (void)removeAllControllers
{
	[mControllers makeObjectsPerformSelector:@selector(setDrawing:)
								  withObject:nil];
	[mControllers removeAllObjects];
}

#pragma mark -

/** @brief Causes all cursor rectangles for all attached views to be recalculated. This forces any cursors
 that may be in use to be updated.
 */
- (void)invalidateCursors
{
	[[self controllers] makeObjectsPerformSelector:_cmd];
}

/** @brief Causes all attached views to scroll to show the rect, if necessary

 Called for things like scroll to selection - all attached views may scroll if necessary. Note that
 it is OK to directly call the view's methods if scrolling a single view is required - the drawing
 isn't aware of any view's scroll position.
 @param rect the rect to reveal
 */
- (void)scrollToRect:(NSRect)rect
{
	[[self controllers] makeObjectsPerformSelector:@selector(scrollViewToRect:)
										withObject:[NSValue valueWithRect:rect]];
}

/** @brief Notifies all the controllers that an object within the drawing notified a status change

 Status changes are non-visual changes that a view controller might want to know about
 @param object the original object that sent the notification
 */
- (void)objectDidNotifyStatusChange:(id)object
{
	[[self controllers] makeObjectsPerformSelector:_cmd
										withObject:object];
}

#pragma mark -
#pragma mark - dynamically adjusting the rendering quality

@synthesize dynamicQualityModulationEnabled=m_qualityModEnabled;
@synthesize lowRenderingQuality=m_useQandDRendering;

/** @brief Dynamically check if low or high quality should be used

 Called from the drawing method, this starts or extends a timer which will set high quality after
 a delay. Thus if rapid updates are happening, it will switch to low quality, and switch to high
 quality after a delay.
 */
- (void)checkIfLowQualityRequired
{
	// if this is being called frequently, set low quality and start a timer to restore high quality after a delay. If the timer is
	// already running, retrigger it.

	// if not drawing to screen, don't do this - always use HQ

	if (![[NSGraphicsContext currentContext] isDrawingToScreen]) {
		[self setLowRenderingQuality:NO];
		return;
	}

	if ([self dynamicQualityModulationEnabled]) {

		[self setLowRenderingQuality:YES];

		if (m_renderQualityTimer == nil) {
			// start the timer:

			m_renderQualityTimer = [[NSTimer scheduledTimerWithTimeInterval:mTriggerPeriod
																	 target:self
																   selector:@selector(qualityTimerCallback:)
																   userInfo:nil
																	repeats:YES] retain];
			[[NSRunLoop currentRunLoop] addTimer:m_renderQualityTimer
										 forMode:NSEventTrackingRunLoopMode];
		} else {
			// already running - retrigger it:

			[m_renderQualityTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:mTriggerPeriod]];
		}
	} else
		[self setLowRenderingQuality:NO];
}

- (void)qualityTimerCallback:(NSTimer*)timer
{
#pragma unused(timer)

	// if the timer ever fires it calls this, so we simply invalidate it and set high quality

	[m_renderQualityTimer invalidate];
	[m_renderQualityTimer release];
	m_renderQualityTimer = nil;
	[self setLowRenderingQuality:NO];
	m_isForcedHQUpdate = YES;
	[self setNeedsDisplayInRect:m_lastRectUpdated];
	m_lastRectUpdated = NSZeroRect;
}

@synthesize lowQualityTriggerInterval=mTriggerPeriod;

#pragma mark -
#pragma mark - setting the undo manager

- (void)setUndoManager:(id)um
{
	if (um != m_undoManager) {
		[m_undoManager removeAllActions];

		[um retain];
		[m_undoManager release];
		m_undoManager = um;

		// the undo manager needs to be known objects (particularly styles) that the drawing contains. For a drawing created from an
		// archive, this needs to be pushed out to all those objects

		[self drawingHasNewUndoManager:um];
	}
}

@synthesize undoManager=m_undoManager;

#pragma mark -
#pragma mark - drawing meta - data

/** @brief Sets the drawing info metadata for the drawing

 The drawing info contains whatever you want, but a number of standard fields are defined and can be
 interpreted by a DKDrawingInfoLayer, if there is one. Note this inherits the storage from
 DKLayer.
 @param info the drawing info dictionary
 */
- (void)setDrawingInfo:(NSMutableDictionary*)info
{
	[self setUserInfoObject:info
					 forKey:kDKDrawingInfoUserInfoKey];
}

/** @brief Returns the current drawing info metadata
 @return a dictionary, the drawing info
 */
- (NSMutableDictionary*)drawingInfo
{
	return [self userInfoObjectForKey:kDKDrawingInfoUserInfoKey];
}

#pragma mark -

- (void)setPaperColour:(NSColor*)colour
{
	if (colour != [self paperColour]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setPaperColour:[self paperColour]];

		[colour retain];
		[m_paperColour release];
		m_paperColour = colour;
		[self setNeedsDisplay:YES];

		if (!([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
			[[self undoManager] setActionName:NSLocalizedString(@"Background Colour", @"undo action for setPaperColour")];
	}
}

@synthesize paperColour=m_paperColour;

@synthesize paperColourIsPrinted=mPaperColourIsPrinted;
#pragma mark -

/** @brief For the utility of contained objects, this ends any open text editing session without the object
 needing to know which view is handling it.

 If any attached view has started a temporary text editing mode, this method can be called to end
 that mode and perform all necessary cleanup. This is useful if the object that requested the mode
 no longer knows which view it asked to do the editing (and thus saves it the need to record the
 view in question). Note that normally only one such view could have entered this mode, but this
 will also recover from a situation (bug!) where more than one has a text editing operation mode open.
 */
- (void)exitTemporaryTextEditingMode
{
	[[self controllers] makeObjectsPerformSelector:_cmd];
}

#pragma mark -
#pragma mark - active layer

/** @brief Sets which layer is currently active

 The active layer is automatically linked from the first responder so it can receive commands
 active state changes.
 @param aLayer the layer to make the active layer, or nil to make no layer active
 @return YES if the active layer changed, NO if not
 */
- (BOOL)setActiveLayer:(DKLayer*)aLayer
{
	return [self setActiveLayer:aLayer
					   withUndo:NO];
}

/** @brief Sets which layer is currently active, optionally making this change undoable

 Normally active layer changes are not undoable as the active layer is not considered part of the
 state of the data model. However some actions such as adding and removing layers should include
 the active layer state as part of the undo, so that the user experience is pleasant.
 @param aLayer the layer to make the active layer, or nil to make no layer active
 @return YES if the active layer changed, NO if not
 */
- (BOOL)setActiveLayer:(DKLayer*)aLayer withUndo:(BOOL)undo
{
	// we already own this, so don't retain it

	if (aLayer != m_activeLayerRef && (aLayer == nil || [aLayer layerMayBecomeActive]) && ![self locked]) {
		if (undo)
			[[[self undoManager] prepareWithInvocationTarget:self] setActiveLayer:m_activeLayerRef
																		 withUndo:YES];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingActiveLayerWillChange
															object:self];
		[[self controllers] makeObjectsPerformSelector:@selector(activeLayerWillChangeToLayer:)
											withObject:aLayer];

		[m_activeLayerRef layerDidResignActiveLayer];
		m_activeLayerRef = aLayer;
		[m_activeLayerRef layerDidBecomeActiveLayer];
		[self invalidateCursors];

		[[self controllers] makeObjectsPerformSelector:@selector(activeLayerDidChangeToLayer:)
											withObject:aLayer];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingActiveLayerDidChange
															object:self];

		LogEvent_(kReactiveEvent, @"Active Layer changed to: %@", aLayer);

		return YES;
	}

	return NO;
}

@synthesize activeLayer=m_activeLayerRef;

/** @brief Returns the active layer if it matches the requested class
 @param aClass the class of layer sought
 @return the active layer if it matches the requested class, otherwise nil
 */
- (id)activeLayerOfClass:(Class)aClass
{
	if ([[self activeLayer] isKindOfClass:aClass])
		return [self activeLayer];
	else
		return nil;
}

/** @brief Adds a layer to the drawing and optionally activates it

 This method has the advantage over separate add + activate calls that the active layer change is
 recorded by the undo stack, so it's the better one to use when adding layers via a UI since an
 undo of the action will restore the UI to its previous state with respect to the active layer.
 Normally changes to the active layer are not undoable.
 @param aLayer a layer object to be added
 @param activateIt if YES, the added layer will be made the active layer, NO will not change it
 */
- (void)addLayer:(DKLayer*)aLayer andActivateIt:(BOOL)activateIt
{
	NSAssert(aLayer != nil, @"cannot add a nil layer to the drawing");

	NSString* layerName = [self uniqueLayerNameForName:[aLayer layerName]];
	[aLayer setLayerName:layerName];

	[super addLayer:aLayer];

	// tell the layer it was added to the root (drawing)

	[aLayer drawingHasNewUndoManager:[self undoManager]];
	[aLayer wasAddedToDrawing:self];

	if (activateIt)
		[self setActiveLayer:aLayer
					withUndo:YES];
}

/** @brief Removes a layer from the drawing and optionally activates another one

 This method is the inverse of the one above, used to help make UIs more usable by also including
 undo for the active layer change. It is an error for <anotherLayer> to be equal to <aLayer>. As a
 further UI convenience, if <aLayer> is the current active layer, and <anotherLayer> is nil, this
 finds the topmost layer of the same class as <aLayer> and makes that active.
 @param aLayer a layer object to be removed
 @param anotherLayer if not nil, this layer will be activated after removing the first one.
 */
- (void)removeLayer:(DKLayer*)aLayer andActivateLayer:(DKLayer*)anotherLayer
{
	NSAssert(aLayer != nil, @"can't remove a nil layer from the drawing ");
	NSAssert(aLayer != anotherLayer, @"cannot activate the layer being removed - layers must be different");

	// retain the layer until we are completely done with it

	[aLayer retain];

	BOOL removingActive = (aLayer == [self activeLayer]);

	// remove it from the drawing

	[super removeLayer:aLayer];

	if (removingActive && (anotherLayer == nil)) {
		// for convenience activate the topmost layer of the same class as the one being removed. If that
		// returns nil, activate the top layer.

		DKLayer* newActive = [self firstLayerOfClass:[aLayer class]];

		if (newActive == nil)
			newActive = [self topLayer];

		anotherLayer = newActive;
	}

	if (anotherLayer)
		[self setActiveLayer:anotherLayer
					withUndo:YES];

	[aLayer release];
}

/** @brief Finds the first layer of the given class that can be activated.

 Looks through all subgroups
 @param cl the class of layer to look for
 @return the first such layer that returns yes to -layerMayBecomeActive
 */
- (DKLayer*)firstActivateableLayerOfClass:(Class)cl
{
	NSArray* layers = [self layersOfClass:cl
						performDeepSearch:YES];
	NSEnumerator* iter = [layers objectEnumerator];
	DKLayer* layer;

	while ((layer = [iter nextObject])) {
		if ([layer layerMayBecomeActive])
			return layer;
	}

	return nil;
}

#pragma mark -
#pragma mark - snapping

/** @brief Sets whether mouse actions within the drawing should snap to grid or not.

 Actually snapping requires that objects call the snapToGrid: method for points that they are
 processing while dragging the mouse, etc.
 @param snaps YES to turn on snap to grid, NO to turn it off
 */
- (void)setSnapsToGrid:(BOOL)snaps
{
	m_snapsToGrid = snaps;
	[[NSUserDefaults standardUserDefaults] setBool:!snaps
											forKey:kDKDrawingSnapToGridUserDefault];
}

/** @brief Whether snap to grid os on or off
 @return YES if grid snap is on, NO if off
 */
- (BOOL)snapsToGrid
{
	return m_snapsToGrid;
}

/** @brief Sets whether mouse actions within the drawing should snap to guides or not.

 Actually snapping requires that objects call the snapToGuides: method for points and rects that they are
 processing while dragging the mouse, etc.
 @param snaps YES to turn on snap to guides, NO to turn it off
 */
- (void)setSnapsToGuides:(BOOL)snaps
{
	m_snapsToGuides = snaps;
	[[NSUserDefaults standardUserDefaults] setBool:!snaps
											forKey:kDKDrawingSnapToGuidesUserDefault];
}

/** @brief Whether snap to grid os on or off
 @return YES if grid snap is on, NO if off
 */
- (BOOL)snapsToGuides
{
	return m_snapsToGuides;
}

#pragma mark -

/** @brief Moves a point to the nearest grid position if snapControl is different from current user setting,
 otherwise returns it unchanged

 The grid layer actually performs the computation, if one exists. The <snapControl> parameter
 usually comes from a modifer key such as ctrl - if snapping is on it disables it, if off it
 enables it. This flag is passed up from whatever mouse event is actually being handled.
 @param p a point value within the drawing
 @param snapControl inverts the applied state of the grid snapping setting
 @return a modified point located at the nearest grid intersection
 */
- (NSPoint)snapToGrid:(NSPoint)p withControlFlag:(BOOL)snapControl
{
	BOOL doSnap = snapControl != [self snapsToGrid];

	if (doSnap) {
		DKGridLayer* grid = [self gridLayer];

		if (grid != nil)
			p = [grid nearestGridIntersectionToPoint:p];
	}

	return p;
}

/** @brief Moves a point to the nearest grid position if snap is turned ON, otherwise returns it unchanged

 The grid layer actually performs the computation, if one exists. If the control modifier key is down
 grid snapping is temporarily disabled, so this modifier universally means don't snap for all drags.
 Passing YES for <ignore> is intended for use by internal classes such as DKGuideLayer.
 @param p a point value within the drawing
 @param ignore if YES, the current state of [self snapsToGrid] is ignored
 @return a modified point located at the nearest grid intersection
 */
- (NSPoint)snapToGrid:(NSPoint)p ignoringUserSetting:(BOOL)ignore
{
	DKGridLayer* grid = [self gridLayer];

	if (grid != nil && ([self snapsToGrid] || ignore))
		p = [grid nearestGridIntersectionToPoint:p];

	return p;
}

/** @brief Moves a point to a nearby guide position if snap is turned ON, otherwise returns it unchanged

 The guide layer actually performs the computation, if one exists.
 @param p a point value within the drawing
 @return a modified point located at a nearby guide
 */
- (NSPoint)snapToGuides:(NSPoint)p
{
	DKGuideLayer* gl = [self guideLayer];

	if (gl != nil && [self snapsToGuides])
		p = [gl snapPointToGuide:p];

	return p;
}

/** @brief Snaps any edge (and optionally the centre) of a rect to any nearby guide

 The guide layer itself implements the snapping calculations, if it exists.
 @param r a proposed rectangle which might bethe bounds of some object for example
 @param cent if YES, the centre point of the rect is also considered a candidadte for snapping, NO for
 @return a rectangle, either the input rectangle or a rectangle of identical size offset to align with
 one of the guides
 */
- (NSRect)snapRectToGuides:(NSRect)r includingCentres:(BOOL)cent
{
	DKGuideLayer* gl = [self guideLayer];

	if (gl != nil && [self snapsToGuides])
		r = [gl snapRectToGuide:r
			   includingCentres:cent];

	return r;
}

/** @brief Determines the snap offset for any of a list of points

 The guide layer itself implements the snapping calculations, if it exists.
 @param points an array containing NSValue objects with NSPoint values
 @return an offset amount which is the distance to move one ofthe points to make it snap. This value can
 usually be simply added to the current mouse point that is dragging the object
 */
- (NSSize)snapPointsToGuide:(NSArray*)points
{
	DKGuideLayer* gl = [self guideLayer];

	if (gl != nil && [self snapsToGuides])
		return [gl snapPointsToGuide:points];

	return NSZeroSize;
}

#pragma mark -

/** @brief Returns the amount meant by a single press of any of the arrow keys
 @return an x and y value representing how far each "nudge" should move an object. If there is a grid layer,
 and snapping is on, this will be a grid interval. Otherwise it will be 1.
 */
- (NSPoint)nudgeOffset
{
	// returns the x and y distances a nudge operation should move an object. If snapToGrid is on, this returns the grid division
	// size, otherwise it returns 1, 1. Note that an actual nudge may want to take steps to actually align the object to the grid.

	DKGridLayer* grid = [self gridLayer];
	BOOL ctrl = ([[NSApp currentEvent] modifierFlags] & NSControlKeyMask) != 0;

	if (grid != nil && [self snapsToGrid] && !ctrl) {
		NSPoint nudge;
		nudge.x = nudge.y = [grid divisionDistance];
		return nudge;
	} else
		return NSMakePoint(1.0, 1.0);
}

#pragma mark -
#pragma mark - grids, guides and conversions

/** @brief Returns the master grid layer, if there is one

 Usually there will only be one grid, but if there is more than one this only finds the uppermost.
 This only returns a grid that returns YES to -isMasterGrid, so subclasses can return NO to
 prevent themselves being considered for this role.
 @return the grid layer, or nil
 */
- (DKGridLayer*)gridLayer
{
	NSArray* gridLayers = [self layersOfClass:[DKGridLayer class]
							performDeepSearch:YES];

	NSEnumerator* iter = [gridLayers objectEnumerator];
	DKGridLayer* grid;

	while ((grid = [iter nextObject])) {
		if ([grid isMasterGrid])
			return grid;
	}

	return nil;
}

/** @brief Returns the guide layer, if there is one

 Usually there will only be one guide layer, but if there is more than one this only finds the uppermost.
 @return the guide layer, or nil
 */
- (DKGuideLayer*)guideLayer
{
	return (DKGuideLayer*)[self firstLayerOfClass:[DKGuideLayer class]
								performDeepSearch:YES];
}

/** @brief Convert a distance in quartz coordinates to the units established by the drawing grid

 This is a convenience API to query the drawing's grid layer. If there is a delegate and it implements
 the optional conversionmethod, it is given the opportunity to further modify the result. This
 permits a delegate to impose an additional coordinate system on the drawing for display purposes,
 @param len a distance in base points (pixels)
 @return the distance in drawing units
 */
- (CGFloat)convertLength:(CGFloat)len
{
	CGFloat length = [[self gridLayer] gridDistanceForQuartzDistance:len];

	if ([[self delegate] respondsToSelector:@selector(drawing:
												convertDistanceToExternalCoordinates:)])
		length = [[self delegate] drawing:self
			convertDistanceToExternalCoordinates:length];

	return length;
}

/** @brief Convert a point in quartz coordinates to the units established by the drawing grid

 This is a convenience API to query the drawing's grid layer. The delegate is also given a shot
 at further modifying the returned values.
 @param pt a point in base points (pixels)
 @return the position ofthe point in drawing units
 */
- (NSPoint)convertPoint:(NSPoint)pt
{
	NSPoint cpt = [[self gridLayer] gridLocationForPoint:pt];

	if ([[self delegate] respondsToSelector:@selector(drawing:
												convertLocationToExternalCoordinates:)])
		cpt = [[self delegate] drawing:self
			convertLocationToExternalCoordinates:cpt];

	return cpt;
}

/** @brief Convert a distance in quartz coordinates to the units established by the drawing grid

 This wraps up length conversion and formatting for display into one method, which also calls the
 delegate if it implements the relevant method.
 @param len a distance in base points (pixels)
 @return a string containing a fully formatted distance plus the units abbreviation
 */
- (NSString*)formattedConvertedLength:(CGFloat)len
{
	CGFloat length = [[self gridLayer] gridDistanceForQuartzDistance:len];

	if ([[self delegate] respondsToSelector:@selector(drawing:
												willReturnFormattedCoordinateForDistance:)])
		return [[self delegate] drawing:self
			willReturnFormattedCoordinateForDistance:length];
	else
		return [NSString stringWithFormat:@"%.2f %@", length, [self abbreviatedDrawingUnits]];
}

/** @brief Convert a point in quartz coordinates to the units established by the drawing grid

 This wraps up length conversion and formatting for display into one method, which also calls the
 delegate if it implements the relevant method. The result is an array with two strings - the first
 is the x coordinate, the second is the y co-ordinate
 @param pt a point in base points (pixels)
 @return a pair of strings containing a fully formatted distance plus the units abbreviation
 */
- (NSArray*)formattedConvertedPoint:(NSPoint)pt
{
	NSMutableArray* array = [NSMutableArray array];
	NSPoint cpt = [[self gridLayer] gridLocationForPoint:pt];
	NSString* fmt;

	if ([[self delegate] respondsToSelector:@selector(drawing:
												willReturnFormattedCoordinateForDistance:)]) {
		fmt = [[self delegate] drawing:self
			willReturnFormattedCoordinateForDistance:cpt.x];
		[array addObject:fmt];
		fmt = [[self delegate] drawing:self
			willReturnFormattedCoordinateForDistance:cpt.y];
		[array addObject:fmt];
	} else {
		fmt = [NSString stringWithFormat:@"%.2f %@", cpt.x, [self abbreviatedDrawingUnits]];
		[array addObject:fmt];
		fmt = [NSString stringWithFormat:@"%.2f %@", cpt.y, [self abbreviatedDrawingUnits]];
		[array addObject:fmt];
	}

	return array;
}

/** @brief Convert a point in drawing coordinates to the underlying Quartz coordinates

 This is a convenience API to query the drawing's grid layer
 @param pt a point in drawing units
 @return the position of the point in Quartz units
 */
- (NSPoint)convertPointFromDrawingToBase:(NSPoint)pt
{
	return [[self gridLayer] pointForGridLocation:pt];
}

/** @brief Convert a length in drawing coordinates to the underlying Quartz coordinates

 This is a convenience API to query the drawing's grid layer
 @param len a distance in drawing units
 @return the distance in Quartz units
 */
- (CGFloat)convertLengthFromDrawingToBase:(CGFloat)len
{
	return [[self gridLayer] quartzDistanceForGridDistance:len];
}

#pragma mark -
#pragma mark - export

/** @brief Called just prior to an operation that saves the drawing to a file, pasteboard or data.

 Can be overridden or you can make use of the notification
 */
- (void)finalizePriorToSaving
{
	[[self undoManager] disableUndoRegistration];

	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingWillBeSavedOrExported
														object:self];

	// the drawing size is updated/added to the metadata by default here.

	NSSize ds = [self drawingSize];
	CGFloat upc = [self unitToPointsConversionFactor];

	ds.width /= upc;
	ds.height /= upc;

	[self setSize:ds
		   forKey:kDKDrawingInfoDrawingDimensions];
	[self setString:[self drawingUnits]
			 forKey:kDKDrawingInfoDimensionsUnits];
	[self setString:[self abbreviatedDrawingUnits]
			 forKey:kDKDrawingInfoDimensionsShortUnits];

	// for compatibility with info file, copy the same information directly to the drawing info as well

	[[self drawingInfo] setObject:[self abbreviatedDrawingUnits]
						   forKey:[kDKDrawingInfoDimensionsShortUnits lowercaseString]];
	[[self drawingInfo] setObject:[self drawingUnits]
						   forKey:[kDKDrawingInfoDimensionsUnits lowercaseString]];
	[[self drawingInfo] setObject:[NSString stringWithFormat:@"%f", ds.width]
						   forKey:[[NSString stringWithFormat:@"%@.size_width", kDKDrawingInfoDrawingDimensions] lowercaseString]];
	[[self drawingInfo] setObject:[NSString stringWithFormat:@"%f", ds.height]
						   forKey:[[NSString stringWithFormat:@"%@.size_height", kDKDrawingInfoDrawingDimensions] lowercaseString]];

	[[self undoManager] enableUndoRegistration];
}

/** @brief Saves the entire drawing to a file

 Implies the binary format
 @param filename the full path of the file 
 @param atom YES to save to a temporary file and swap (safest), NO to overwrite file
 @return YES if succesfully written, NO otherwise
 */
- (BOOL)writeToFile:(NSString*)filename atomically:(BOOL)atom
{
	NSAssert(filename != nil, @"filename was nil");
	NSAssert([filename length] > 0, @"filename was empty");

	[[self drawingInfo] setObject:filename
						   forKey:kDKDrawingInfoOriginalFilename];
	return [[self drawingData] writeToFile:filename
								atomically:atom];
}

- (BOOL)writeToURL:(NSURL*)filename options:(NSDataWritingOptions)writeOptionsMask error:(NSError * _Nullable * _Nullable)errorPtr
{
	NSAssert(filename != nil, @"filename was nil");
	NSAssert([[filename path] length] > 0, @"filename was empty");
	
	[[self drawingInfo] setObject:filename.path
						   forKey:kDKDrawingInfoOriginalFilename];
	return [[self drawingData] writeToURL:filename options:writeOptionsMask error:errorPtr];
}


/** @brief Returns the entire drawing's data in XML format, having the key "root"

 Specifies NSPropertyListXMLFormat_v1_0
 @return an NSData object which is the entire drawing and all its contents
 */
- (NSData*)drawingAsXMLDataAtRoot
{
	return [self drawingAsXMLDataForKey:@"root"];
}

/** @brief Returns the entire drawing's data in XML format, having the key passed

 Specifies NSPropertyListXMLFormat_v1_0
 @param key a key under which the data is archived
 @return an NSData object which is the entire drawing and all its contents
 */
- (NSData*)drawingAsXMLDataForKey:(NSString*)key
{
	NSAssert(key != nil, @"key cannot be nil");
	NSAssert([key length] > 0, @"key cannot be empty");

	NSMutableData* data = [[NSMutableData alloc] init];

	NSAssert(data != nil, @"couldn't create data for archiving");

	NSKeyedArchiver* karch = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];

	NSAssert(karch != nil, @"couldn't create archiver for archiving with data");

	[karch setOutputFormat:NSPropertyListXMLFormat_v1_0];
	[self finalizePriorToSaving];
	[karch encodeObject:self
				 forKey:key];
	[karch finishEncoding];
	[karch release];

	return [data autorelease];
}

/** @brief Returns the entire drawing's data in binary format

 Specifies NSPropertyListBinaryFormat_v1_0
 @return an NSData object which is the entire drawing and all its contents
 */
- (NSData*)drawingData
{
	[self finalizePriorToSaving];
	return [NSKeyedArchiver archivedDataWithRootObject:self];
}

/** @brief The entire drawing in PDF format

 When rendering a drawing for PDF, the drawing acts as if it were printing, therefore layers that
 return NO to shouldDrawToPrinter: are not drawn. Selections are also not shown.
 @return an NSData object, containing the PDF representation of the entire drawing
 */
- (NSData*)pdf
{
	[self finalizePriorToSaving];
	return [super pdf];
}

/** @brief Returns the image manager

 The image manager is an object that is used to improve archiving efficiency of images. Classes
 that have images, such as DKImageShape, use this to cache image data.
 @return the drawing's image manager
 */
- (DKImageDataManager*)imageManager
{
	return mImageManager;
}

#pragma mark -
#pragma mark As a DKLayerGroup

- (void)addLayer:(DKLayer*)aLayer
{
	NSAssert(aLayer != nil, @"cannot add nil layer");

	[super addLayer:aLayer];

	if ([self countOfLayers] == 1 || [self activeLayer] == nil)
		[self setActiveLayer:aLayer];

	// tell the layer it was added to the root (drawing)

	[aLayer drawingHasNewUndoManager:[self undoManager]];
	[aLayer wasAddedToDrawing:self];
}

- (void)removeLayer:(DKLayer*)aLayer
{
	NSAssert(aLayer != nil, @"cannot remove nil layer");

	[super removeLayer:aLayer];
	if (aLayer == [self activeLayer])
		[self setActiveLayer:nil];
}

/** @brief Removes all of the drawing's layers
 */
- (void)removeAllLayers
{
	[super removeAllLayers];
	[self setActiveLayer:nil];
}

/** @brief Disambiguates a layer's name by appending digits until there is no conflict

 DKLayerGroup's implementation of this only considers layers in the local group. This considers
 all layers in the drawing as a flattened set, so will disambiguate the layer name for the entire
 hierarchy.
 @param aName a string containing the proposed name
 @return a string, either the original string or a modified version of it
 */
- (NSString*)uniqueLayerNameForName:(NSString*)aName
{
	NSArray* existingNames = [[self flattenedLayersIncludingGroups:YES] valueForKey:@"layerName"];
	NSInteger numeral = 0;
	BOOL found = YES;
	NSString* temp = aName;

	while (found) {
		NSInteger k = [existingNames indexOfObject:temp];

		if (k == NSNotFound)
			found = NO;
		else
			temp = [NSString stringWithFormat:@"%@ %ld", aName, (long)++numeral];
	}

	return temp;
}

#pragma mark -
#pragma mark As a DKLayer

/** @brief Returns the drawing

 Because layers locate the drawing by recursing back up through the layer tree, the root (this)
 must return self.
 @return the drawing, which is self of course
 */
- (DKDrawing*)drawing
{
	return self;
}

/** @brief Renders the drawing in the view

 Called by a DKDrawingView's drawRect: method to update itself.
 @param rect the update rect being drawn - graphics outside this rect can be skipped.
 @param aView the view that is curremtly rendering the drawing.
 */
- (void)drawRect:(NSRect)rect inView:(DKDrawingView*)aView
{
	// save the graphics context on entry so that we can restore it when we return. This allows recovery from an exception
	// that could leave the context stack unbalanced.

	NSGraphicsContext* topContext = [[NSGraphicsContext currentContext] retain];

	@try
	{
		// paint the paper colour over the view area. Not printed unless explictly set to do so.

		if ([NSGraphicsContext currentContextDrawingToScreen] || [self paperColourIsPrinted]) {
			[[self paperColour] set];
			NSRectFillUsingOperation(rect, NSCompositeSourceOver);
		}

		// if no layers, nothing to draw

		if ([self visible] && [self countOfLayers] > 0) {
			// if not forcing a high quality render, set low quality and start the timer

			if (!m_isForcedHQUpdate) {
				[self checkIfLowQualityRequired];
				m_lastRectUpdated = NSUnionRect(m_lastRectUpdated, rect);
			}

			if ([self knobsShouldAdjustToViewScale] && aView != nil)
				[[self knobs] setControlKnobSizeForViewScale:[aView scale]];

			// draw all the layer content

			if ([[self delegate] respondsToSelector:@selector(drawing:
														 willDrawRect:
															   inView:)])
				[[self delegate] drawing:self
							willDrawRect:rect
								  inView:aView];

			[self beginDrawing];
			[super drawRect:rect
					 inView:aView];
			[self endDrawing];

			if ([[self delegate] respondsToSelector:@selector(drawing:
														  didDrawRect:
															   inView:)])
				[[self delegate] drawing:self
							 didDrawRect:rect
								  inView:aView];
		}
	}
	@catch (id exc)
	{
		NSLog(@"### DK: An exception occurred while drawing - (%@) - will be ignored ###", exc);
	}
	@finally
	{
		m_isForcedHQUpdate = NO;
	}

	[NSGraphicsContext setCurrentContext:topContext];
	[topContext release];
}

/** @brief Marks the entire drawing as needing updating (or not) for all attached views

 YES causes all attached views to re-render the drawing parts visible in each view
 @param refresh YES to update the entire drawing, NO to stop any updates.
 */
- (void)setNeedsDisplay:(BOOL)refresh
{
	[[self controllers] makeObjectsPerformSelector:@selector(setViewNeedsDisplay:)
										withObject:[NSNumber numberWithBool:refresh]];
}

/** @brief Marks the rect as needing update in all attached views

 If <rect> is visible in any attached view, it will be re-rendered by each affected view. Normally
 objects know when to refresh themselves and do so by indirectly calling this method.
 @param rect the rectangle within the drawing to update
 */
- (void)setNeedsDisplayInRect:(NSRect)rect
{
	[[self controllers] makeObjectsPerformSelector:@selector(setViewNeedsDisplayInRect:)
										withObject:[NSValue valueWithRect:rect]];
}

/** @brief Marks several areas for update at once

 Directly passes the value to the view controller, saving the unpacking and repacking
 @param setOfRects a set containing NSValues with rect values
 */
- (void)setNeedsDisplayInRects:(NSSet*)setOfRects
{
	NSAssert(setOfRects != nil, @"update set was nil");

	NSEnumerator* iter = [setOfRects objectEnumerator];
	NSValue* val;

	while ((val = [iter nextObject]))
		[[self controllers] makeObjectsPerformSelector:@selector(setViewNeedsDisplayInRect:)
											withObject:val];
}

/** @brief Marks several areas for update at once

 Several update optimising methods return sets of rect values, this allows them to be processed
 directly.
 @param setOfRects a set containing NSValues with rect values
 @param padding the width and height will be added to EACH rect before invalidating
 */
- (void)setNeedsDisplayInRects:(NSSet*)setOfRects withExtraPadding:(NSSize)padding
{
	NSAssert(setOfRects != nil, @"update set was nil");

	NSEnumerator* iter = [setOfRects objectEnumerator];
	NSValue* val;
	NSRect ur;

	while ((val = [iter nextObject])) {
		ur = NSInsetRect([val rectValue], -padding.width, -padding.height);
		[self setNeedsDisplayInRect:ur];
	}
}

/** @brief Return whether the layer can be deleted
 @return NO - the root drawing can't be deleted
 */
- (BOOL)layerMayBeDeleted
{
	return NO;
}

/** @brief Migrate user info to current schema

 See DKLayer+Metadata for more details. This migrates drawing info to the current schema.
 */
- (void)updateMetadataKeys
{
	if ([self drawingInfo] == nil) {
		// assumes that all items in userInfo belong to drawing info. This is certainly true for DK implementations prior
		// to 107, since all info values got dumped into the user info as a flat list.

		NSMutableDictionary* oldDrawingInfo = [[self userInfo] mutableCopy];
		[[self userInfo] removeAllObjects];

		if (oldDrawingInfo)
			[self setDrawingInfo:oldDrawingInfo];
		[oldDrawingInfo release];
	}
}

/** @brief Updates the ruler markers for all attached views to indicate the rectangle

 Updates all ruler markers in all attached views, if those views have visible rulers
 @param rect a rectangle within the drawing (usually the bounds of the selected object(s))
 */
- (void)updateRulerMarkersForRect:(NSRect)rect
{
	[[self controllers] makeObjectsPerformSelector:@selector(updateViewRulerMarkersForRect:)
										withObject:[NSValue valueWithRect:rect]];
}

/** @brief Hides the ruler markers in all attached views

 Ruler markers are generally hidden when there is no selection
 */
- (void)hideRulerMarkers
{
	[[self controllers] makeObjectsPerformSelector:@selector(hideViewRulerMarkers)];
}

#pragma mark -
#pragma mark As an NSObject

- (void)dealloc
{
	LogEvent_(kLifeEvent, @"deallocating DKDrawing %@", self);

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[self setUndoManager:nil];
	[self exitTemporaryTextEditingMode];
	[self removeAllControllers];
	[mControllers release];

	m_activeLayerRef = nil;
	mDelegateRef = nil;

	if (m_renderQualityTimer != nil) {
		[m_renderQualityTimer invalidate];
		[m_renderQualityTimer release];
		m_renderQualityTimer = nil;
	}

	[m_paperColour release];
	[mColourSpace release];
	[m_units release];
	[mImageManager release];

	[super dealloc];
}

- (id)init
{
	return [self initWithSize:[DKDrawing isoA2PaperSize:NO]];
}

- (id)copyWithZone:(NSZone*)zone
{
// drawings are not copyable but are sometimes used a dict key, so they need to respond to the copying protocol
#pragma unused(zone)

	return self;
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	// this flag used to detect gross change of architecture in older files

	[coder encodeBool:YES
			   forKey:@"hasHierarchicalLayers"];

	[super encodeWithCoder:coder];

	// note: due to the way image manager clients work, the image manager itself does not need to be archived

	[coder encodeSize:[self drawingSize]
			   forKey:@"drawingSize"];
	[coder encodeBool:[self isFlipped]
			   forKey:@"DKDrawing_isFlipped"];
	[coder encodeDouble:[self leftMargin]
				 forKey:@"leftMargin"];
	[coder encodeDouble:[self rightMargin]
				 forKey:@"rightMargin"];
	[coder encodeDouble:[self topMargin]
				 forKey:@"topMargin"];
	[coder encodeDouble:[self bottomMargin]
				 forKey:@"bottomMargin"];
	[coder encodeObject:[self drawingUnits]
				 forKey:@"drawing_units"];
	[coder encodeDouble:[self unitToPointsConversionFactor]
				 forKey:@"utp_conv"];
	[coder encodeObject:[self colourSpace]
				 forKey:@"DKDrawing_colourspace"];
	[coder encodeObject:[self paperColour]
				 forKey:@"papercolour"];
	[coder encodeBool:[self paperColourIsPrinted]
			   forKey:@"DKDrawing_printPaperColour"];

	[coder encodeBool:[self snapsToGrid]
			   forKey:@"gridsnap"];
	[coder encodeBool:[self snapsToGuides]
			   forKey:@"guidesnap"];
	[coder encodeBool:[self clipsDrawingToInterior]
			   forKey:@"clips"];
}

- (id)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");

	LogEvent_(kFileEvent, @"decoding drawing %@", self);

	// set drawing units before layers are added so grid layer can use the values

	[self setDrawingUnits:[coder decodeObjectForKey:@"drawing_units"]
		unitToPointsConversionFactor:[coder decodeDoubleForKey:@"utp_conv"]];

	// create an image manager - it is not necessary for this object to be archived

	DKImageDataManager* imageManager = [[DKImageDataManager alloc] init];

	// if the coder can respond to the -setImageManager: method, set it. This allows certain objects to dearchive images that
	// are held by the image manager even though the object doesn't have a valid reference to the drawing to get it. It can get it from the
	// dearchiver instead.

	if ([coder respondsToSelector:@selector(setImageManager:)])
		[(DKKeyedUnarchiver*)coder setImageManager:imageManager];

	// older files had a flat layer structure and the drawing didn't inherit from the layer group - this
	// flag detects that and decodes the archive accordingly

	BOOL newFileFormat = [coder decodeBoolForKey:@"hasHierarchicalLayers"];

	if (newFileFormat)
		self = [super initWithCoder:coder];
	else
		self = [self init];

	if (self != nil) {
		mImageManager = imageManager;

		if ([coder containsValueForKey:@"DKDrawing_isFlipped"])
			[self setFlipped:[coder decodeBoolForKey:@"DKDrawing_isFlipped"]];
		else
			[self setFlipped:YES];

		[self setDrawingSize:[coder decodeSizeForKey:@"drawingSize"]];
		m_leftMargin = [coder decodeDoubleForKey:@"leftMargin"];
		m_rightMargin = [coder decodeDoubleForKey:@"rightMargin"];
		m_topMargin = [coder decodeDoubleForKey:@"topMargin"];
		m_bottomMargin = [coder decodeDoubleForKey:@"bottomMargin"];

		mControllers = [[NSMutableSet alloc] init];

		[self setColourSpace:[coder decodeObjectForKey:@"DKDrawing_colourspace"]];
		[self setPaperColour:[coder decodeObjectForKey:@"papercolour"]];
		[self setPaperColourIsPrinted:[coder decodeBoolForKey:@"DKDrawing_printPaperColour"]];

		// metadata handling has changed. Now this is inherited from DKLayer, and is archived by that class. However, older files
		// will have the older archive format, so here we detect that and try loading the old format data if not loaded by DKLayer

		if ([self drawingInfo] == nil && [coder containsValueForKey:@"info"])
			[self setDrawingInfo:[coder decodeObjectForKey:@"info"]];

		[self setSnapsToGrid:[coder decodeBoolForKey:@"gridsnap"]];
		[self setSnapsToGuides:[coder decodeBoolForKey:@"guidesnap"]];
		[self setClipsDrawingToInterior:[coder decodeBoolForKey:@"clips"]];

		m_lastRenderTime = [NSDate timeIntervalSinceReferenceDate];

		// older files handled the knobs differently, so if at this point there are no knobs, Supply a default set

		if ([self knobs] == nil)
			[self setKnobs:[DKKnob standardKnobs]];

		if (m_units == nil
			|| m_paperColour == nil) {
			NSLog(@"drawing failed initialization (%@)", self);

			[self autorelease];
			self = nil;
		}

		// notify all the contained layers that they were added to the root drawing, allowing them to perform any special
		// set up.

		[self wasAddedToDrawing:self];
	}
	if (self != nil) {
		if (!newFileFormat) {
			LogEvent_(kReactiveEvent, @"old file format - dearchiving layers directly");

			[self setLayers:[coder decodeObjectForKey:@"layers"]];
		}
		// make the first drawing layer active. It would be possible to save the active layer and restore it when reading the
		// file - would that be better? I'm unsure whether the active layer is legitimately part of a saved file's state.

		[self setActiveLayer:[self firstLayerOfClass:[DKObjectDrawingLayer class]]];
	}

	return self;
}

@end

#pragma mark -

@implementation DKDrawing (UISupport)

- (NSWindow*)windowForSheet
{
	// attempts to return a window useful for hosting a sheet by referring to its owner. If that doesn't work, it asks each of its controllers.

	id owner = [self owner];

	if ([owner respondsToSelector:_cmd])
		return [owner windowForSheet];
	else if ([owner respondsToSelector:@selector(window)])
		return [owner window];
	else {
		// roll up sleeves and go through the controllers

		NSEnumerator* iter = [[self controllers] objectEnumerator];
		DKViewController* cllr;

		while ((cllr = [iter nextObject])) {
			if ([cllr respondsToSelector:_cmd])
				return [(id)cllr windowForSheet];
			else if ([[cllr view] respondsToSelector:@selector(window)])
				return [[cllr view] window];
		}
	}

	return nil; // give up
}

@end
