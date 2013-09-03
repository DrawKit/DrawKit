///**********************************************************************************************************************************
///  DKDrawing.m
///  DrawKit ¬¨¬®¬¨¬Æ¬¨¬®¬¨¬©2005-2008 Apptree.net
///
///  Created by graham on 14/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

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

#pragma mark Contants (Non-localized)

// notifications:

NSString*		kDKDrawingActiveLayerWillChange			= @"kDKDrawingActiveLayerWillChange";
NSString*		kDKDrawingActiveLayerDidChange			= @"kDKDrawingActiveLayerDidChange";
NSString*		kDKDrawingWillChangeSize				= @"kDKDrawingWillChangeSize";
NSString*		kDKDrawingDidChangeSize					= @"kDKDrawingDidChangeSize";
NSString*		kDKDrawingUnitsWillChange				= @"kDKDrawingUnitsWillChange";
NSString*		kDKDrawingUnitsDidChange				= @"kDKDrawingUnitsDidChange";
NSString*		kDKDrawingWillChangeMargins				= @"kDKDrawingWillChangeMargins";
NSString*		kDKDrawingDidChangeMargins				= @"kDKDrawingDidChangeMargins";
NSString*		kDKDrawingWillBeSavedOrExported			= @"kDKDrawingWillBeSavedOrExported";

// drawng info keys:

NSString*		kDKDrawingInfoUserInfoKey				= @"kDKDrawingInfoUserInfoKey";

NSString*		kDKDrawingInfoDrawingNumber				= @"kDKDrawingInfoDrawingNumber";
NSString*		kDKDrawingInfoDrawingNumberUnformatted	= @"kDKDrawingInfoDrawingNumberUnformatted";
NSString*		kDKDrawingInfoDrawingRevision			= @"kDKDrawingInfoDrawingRevision";
NSString*		kDKDrawingInfoDrawingPrefix				= @"kDKDrawingInfoDrawingPrefix";

NSString*		kDKDrawingInfoDraughter					= @"kDKDrawingInfoDraughter";
NSString*		kDKDrawingInfoCreationDate				= @"kDKDrawingInfoCreationDate";
NSString*		kDKDrawingInfoLastModificationDate		= @"kDKDrawingInfoLastModificationDate";
NSString*		kDKDrawingInfoModificationHistory		= @"kDKDrawingInfoModificationHistory";
NSString*		kDKDrawingInfoOriginalFilename			= @"kDKDrawingInfoOriginalFilename";
NSString*		kDKDrawingInfoTitle						= @"kDKDrawingInfoTitle";
NSString*		kDKDrawingInfoDrawingDimensions			= @"kDKDrawingInfoDrawingDimensions";
NSString*		kDKDrawingInfoDimensionsUnits			= @"kDKDrawingInfoDimensionsUnits";
NSString*		kDKDrawingInfoDimensionsShortUnits		= @"kDKDrawingInfoDimensionsShortUnits";

// user default keys:

NSString*		kDKDrawingSnapToGridUserDefault			= @"kDKDrawingSnapToGridUserDefault";
NSString*		kDKDrawingSnapToGuidesUserDefault		= @"kDKDrawingSnapToGuidesUserDefault";
NSString*		kDKDrawingUnitAbbreviationsUserDefault	= @"kDKDrawingUnitAbbreviations";

#pragma mark Static vars

static id	sDearchivingHelper = nil;

#pragma mark -
@implementation DKDrawing
#pragma mark As a DKDrawing
//! Return the current version number of the framework.

//!	A number formatted in 8-4-4 bit format representing the current version number

///*********************************************************************************************************************
///
/// method:			drawkitVersion
/// scope:			public class method
/// description:	return the current version number of the framework
/// 
/// parameters:		none
/// result:			a number formatted in 8-4-4 bit format representing the current version number
///
/// notes:			
///
///********************************************************************************************************************

+ (NSUInteger)				drawkitVersion
{
	return 0x0107;
}


//! Return the current release status of the framework.

//! A string, either "alpha", "beta", "release candidate" or nil (final)

///*********************************************************************************************************************
///
/// method:			drawkitReleaseStatus
/// scope:			public class method
/// description:	return the current release status of the framework
/// 
/// parameters:		none
/// result:			a string, either "alpha", "beta", "release candidate" or nil (final)
///
/// notes:			
///
///********************************************************************************************************************

+ (NSString*)				drawkitReleaseStatus
{
	return @"beta";
}



///*********************************************************************************************************************
///
/// method:			drawkitVersionString
/// scope:			public class method
/// description:	return the current version number and release status as a preformatted string
/// 
/// parameters:		none
/// result:			a string, e.g. "1.0.b6"
///
/// notes:			This is intended for occasional display, rather than testing for the framework version.
///
///********************************************************************************************************************

+ (NSString*)				drawkitVersionString
{
	NSUInteger		v = [self drawkitVersion];
	unsigned char	s = 0;
	
	NSString* status = [self drawkitReleaseStatus];
	
	if([status isEqualToString:@"beta"])
		s = 'b';
	else if([status isEqualToString:@"alpha"])
		s = 'a';
	
	return [NSString stringWithFormat:@"%ld.%ld.%c%ld", (long)(v & 0xFF00) >> 8, (long)(v & 0xF0) >> 4, s, (long)( v & 0x0F )];
}




#pragma mark -
//! Constructs the default drawing system for a view when the system isn't prebuilt "by hand".

//! As a convenience for users of this system, if you set up a DKDrawingView in IB, and do nothing else,
//!	you'll get a fully working, prebuilt drawing system behind that view. This can be very handy for all
//!	sorts of uses. However, it is more usual to build the system the other way around - start with a
//!	drawing object within a document (say) and attach views to it.

///*********************************************************************************************************************
///
/// method:			defaultDrawingWithSize:
/// scope:			public class method
/// description:	constructs the default drawing system when the system isn't prebuilt "by hand"
/// 
/// parameters:		<aSize> - the size of the drawing to create
/// result:			a fully constructed default drawing system
///
/// notes:			as a convenience for users of DrawKit, if you set up a DKDrawingView in IB, and do nothing else,
///					you'll get a fully working, prebuilt drawing system behind that view. This can be very handy for all
///					sorts of uses. However, it is more usual to build the system the other way around - start with a
///					drawing object within a document (say) and attach views to it. This gives you the flexibility to
///					do it either way. For automatic construction, this method is called to supply the drawing.
///
///********************************************************************************************************************

+ (DKDrawing*)				defaultDrawingWithSize:(NSSize) aSize
{
	// for when a view builds the back-end automatically, this supplies a default drawing complete with a grid layer, an object drawing
	// layer, and the view attached. The drawing size is set to the current view bounds size.
	
	NSAssert( aSize.width > 0.0, @"width of drawing size was zero or negative");
	NSAssert( aSize.height > 0.0, @"height of drawing size was zero or negative");
	
	// the defaults chosen here may need to be simplified - in general, would we want a grid, for example?
	
	DKDrawing*	dr = [[self alloc] initWithSize:aSize];		
	[dr setMarginsLeft:5.0 top:5.0 right:5.0 bottom:5.0];	
	
	// attach a grid layer
	[DKGridLayer setDefaultGridThemeColour:[[NSColor brownColor] colorWithAlphaComponent:0.5]];
	DKGridLayer* grid = [DKGridLayer standardMetricGridLayer];
	[dr addLayer:grid];
	[grid tweakDrawingMargins];
	
	// attach a drawing layer and make it the active layer
	
	DKObjectDrawingLayer*	layer = [[DKObjectDrawingLayer alloc] init];
	[dr addLayer:layer];
	[dr setActiveLayer:layer];
	[layer release];
	
	// attach a guide layer
	
	DKGuideLayer*	guides = [[DKGuideLayer alloc] init];
	[dr addLayer:guides];
	[guides release];
		
	return [dr autorelease];
}


//! Creates a drawing from a data object.

//! Unarchives the data, and returns the unarchived drawing object
//! \param drawingData a NSData object containing a complete archive of a drawing

///*********************************************************************************************************************
///
/// method:			drawingWithData:
/// scope:			public class method
/// description:	creates a drawing from a lump of data
/// 
/// parameters:		<drawingData> data representing an archived drawing
/// result:			the unarchived drawing
///
/// notes:			
///
///********************************************************************************************************************

+ (DKDrawing*)				drawingWithData:(NSData*) drawingData
{
	NSAssert( drawingData != nil, @"drawing data was nil - unable to proceed");
	NSAssert([drawingData length] > 0, @"drawing data was empty - unable to proceed");
	
	// using DKKeyedUnarchiver allows passing of image data manager to dearchiving methods for certain objects
	
	DKKeyedUnarchiver*		unarch = [[DKKeyedUnarchiver alloc] initForReadingWithData:drawingData];
	
	// in order to translate older files with classes named 'GC' instead of 'DK', need a delegate that can handle the
	// translation. DKUnarchivingHelper can also be used to report loading progress.
	
	id dearchivingHelper = [self dearchivingHelper];
	if([dearchivingHelper respondsToSelector:@selector(reset)])
		[dearchivingHelper reset];
	
	[unarch setDelegate:dearchivingHelper];
	
	LogEvent_(kReactiveEvent, @"decoding drawing root object......");
	
	DKDrawing* dwg = [unarch decodeObjectForKey:@"root"];
	
	[unarch finishDecoding];
	[unarch release];
	
	return dwg;
}


///*********************************************************************************************************************
///
/// method:			dearchivingHelper
/// scope:			public class method
/// description:	return the default derachiving helper for deaerchiving a drawing
/// 
/// parameters:		none
/// result:			the dearchiving helper
///
/// notes:			this helper is a delegate of the dearchiver during dearchiving and translates older or obsolete
///					classes into modern ones, etc. The default helper deals with older DrawKit classes, but can be
///					replaced to provide the same functionality for application-specific classes.
///
///********************************************************************************************************************

+ (id)						dearchivingHelper
{
	if( sDearchivingHelper == nil )
		sDearchivingHelper = [[DKUnarchivingHelper alloc] init];
	
	return sDearchivingHelper;
}


///*********************************************************************************************************************
///
/// method:			setDearchivingHelper
/// scope:			public class method
/// description:	replace the default dearchiving helper for deaerchiving a drawing
/// 
/// parameters:		<helper> a suitable helper object
/// result:			none
///
/// notes:			this helper is a delegate of the dearchiver during dearchiving and translates older or obsolete
///					classes into modern ones, etc. The default helper deals with older DrawKit classes, but can be
///					replaced to provide the same functionality for application-specific classes.
///
///********************************************************************************************************************

+ (void)					setDearchivingHelper:(id) helper
{
	[helper retain];
	[sDearchivingHelper release];
	sDearchivingHelper = helper;
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			newDrawingNumber
/// scope:			public class method
/// description:	returns a new drawing number by incrementing the current default seed value
/// 
/// parameters:		none
/// result:			a new drawing number
///
/// notes:			
///
///********************************************************************************************************************

+ (NSUInteger)				newDrawingNumber
{
	NSUInteger dNum = [[NSUserDefaults standardUserDefaults] integerForKey:@"DKDrawing_drawingNumberSeedValue"] + 1;
	[[NSUserDefaults standardUserDefaults] setInteger:dNum forKey:@"DKDrawing_drawingNumberSeedValue"];
	
	return dNum;
}


//! Returns the default metadata that is attached to new drawings.

//! This is called by the drawing object itself when built new. Often you'll want to replace
///	its contents with your own info. A DKDrawingInfoLayer can interpret some of the standard values and
///	display them in its info box.

///*********************************************************************************************************************
///
/// method:			defaultDrawingInfo
/// scope:			public class method
/// description:	returns a dictionary containing some standard drawing info attributes
/// 
/// parameters:		none
/// result:			a mutable dictionary of standard drawing info
///
/// notes:			this is usually called by the drawing object itself when built new. Usually you'll want to replace
///					its contents with your own info. A DKDrawingInfoLayer can interpret some of the standard values and
///					display them in its info box.
///
///********************************************************************************************************************

+ (NSMutableDictionary*)	defaultDrawingInfo
{
	NSMutableDictionary*	di = [[NSMutableDictionary alloc] init];
	
	NSUInteger	revision = 1;
	NSUInteger	drawingNumber = [self newDrawingNumber];
	NSString*	prefix = @"A2";
	
	[di setObject:[NSNumber numberWithInteger:revision] forKey:[kDKDrawingInfoDrawingRevision lowercaseString]];
	[di setObject:prefix forKey:[kDKDrawingInfoDrawingPrefix lowercaseString]];
	[di setObject:[NSNumber numberWithInteger:drawingNumber] forKey:[kDKDrawingInfoDrawingNumberUnformatted lowercaseString]];
	[di setObject:[NSString stringWithFormat:@"%@-%06ld-%04ld", prefix, (long)drawingNumber, (long)revision] forKey:[kDKDrawingInfoDrawingNumber lowercaseString]];
	
	[di setObject:[NSFullUserName() capitalizedString] forKey:[kDKDrawingInfoDraughter lowercaseString]];
	[di setObject:[NSDate date] forKey:[kDKDrawingInfoCreationDate lowercaseString]];
	[di setObject:[NSDate date] forKey:[kDKDrawingInfoLastModificationDate lowercaseString]];

	return [di autorelease];
}


///*********************************************************************************************************************
///
/// method:			setAbbreviation:forDrawingUnits:
/// scope:			public class method
/// description:	sets the abbreviation for the given drawing units string
/// 
/// parameters:		<abbrev> the abbreviation for the unit
///					<fullString> the full name of the drawing units
/// result:			none
///
/// notes:			this allows special abbreviations to be set for units if desired. The setting writes to the user
///					defaults so is persistent.
///
///********************************************************************************************************************

+ (void)					setAbbreviation:(NSString*) abbrev forDrawingUnits:(NSString*) fullString
{
	// ensure the defaults exist
	
	[self abbreviationForDrawingUnits:fullString];
	
	// change or set the setting
	
	NSMutableDictionary* dict = [[[NSUserDefaults standardUserDefaults] objectForKey:kDKDrawingUnitAbbreviationsUserDefault] mutableCopy];
	[dict setObject:abbrev forKey:[fullString lowercaseString]];
	[[NSUserDefaults standardUserDefaults] setObject:dict forKey:kDKDrawingUnitAbbreviationsUserDefault];
	[dict release];
}


///*********************************************************************************************************************
///
/// method:			abbreviationForDrawingUnits:
/// scope:			public class method
/// description:	returns the abbreviation for the given drawing units string
/// 
/// parameters:		<fullString> the full name of the drawing units
/// result:			a string - the abbreviated form
///
/// notes:			
///
///********************************************************************************************************************

+ (NSString*)				abbreviationForDrawingUnits:(NSString*) fullString
{
	NSDictionary*	abbrevs = [[NSUserDefaults standardUserDefaults] objectForKey:kDKDrawingUnitAbbreviationsUserDefault];
	
	if ( abbrevs == nil )
	{
		abbrevs = [NSDictionary dictionaryWithObjectsAndKeys:  @"in.", @"inches",
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
		
		[[NSUserDefaults standardUserDefaults] setObject:abbrevs forKey:kDKDrawingUnitAbbreviationsUserDefault];
	}
	
	NSString* abbr = [abbrevs objectForKey:[fullString lowercaseString]];
	
	if ( abbr == nil )
	{
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

///*********************************************************************************************************************
///
/// method:			drawingWithContentsOfFile:
/// scope:			public class method
/// description:	creates a drawing from the named file
/// 
/// parameters:		<filename> full path to the file in question
/// result:			the unarchived drawing
///
/// notes:			deprecated
///
///********************************************************************************************************************

+ (DKDrawing*)				drawingWithContentsOfFile:(NSString*) filename
{
	return [self drawingWithData:[NSData dataWithContentsOfMappedFile:filename] fromFileAtPath:filename];
}


///*********************************************************************************************************************
///
/// method:			drawingWithData:fromFileAtPath:
/// scope:			public class method
/// description:	creates a drawing from a lump of data, and also sets the drawing metadata to contain the original filename
/// 
/// parameters:		<drawingData> data representing an archived drawing
///					<filepath> the full path of the original file
/// result:			the unarchived drawing
///
/// notes:			deprecated - rarely of practical use
///
///********************************************************************************************************************

+ (DKDrawing*)				drawingWithData:(NSData*) drawingData fromFileAtPath:(NSString*) filepath
{
	DKDrawing*	dwg = [self drawingWithData:drawingData];
	
	// insert the filename into the drawing metadata
	
	[[dwg drawingInfo] setObject:[filepath lastPathComponent] forKey:kDKDrawingInfoOriginalFilename];
	
	return dwg;
}


///*********************************************************************************************************************
///
/// method:			saveDefaults
/// scope:			public class method
/// description:	saves the static class defaults for ALL classes in the drawing system
/// 
/// parameters:		none
/// result:			none
///
/// notes:			Deprecated - no longer does anything
///
///********************************************************************************************************************

+ (void)				saveDefaults
{
}


///*********************************************************************************************************************
///
/// method:			loadDefaults
/// scope:			public class method
/// description:	loads the static user defaults for all classes in the drawing system
/// 
/// parameters:		none
/// result:			none
///
/// notes:			Deprecated - no longer does anything
///
///********************************************************************************************************************

+ (void)				loadDefaults
{
}


#pragma mark -
#pragma mark - designated initializer
///*********************************************************************************************************************
///
/// method:			initWithSize:
/// scope:			public method, designated initializer
/// overrides:
/// description:	initialises a newly allocated drawing model object
/// 
/// parameters:		<size> the paper size for the drawing
/// result:			the initialised drawing object
///
/// notes:			sets up the drawing in its default state. No layers are added initially.
///
///********************************************************************************************************************

- (id)					initWithSize:(NSSize) size
{
	self = [super init];
	if (self != nil)
	{
		[self setFlipped:YES];
		[self setDrawingSize:size];
		CGFloat m = 25.0;
		[self setMarginsLeft:m top:m right:m bottom:m];
		[self setDrawingUnits:@"Centimetres" unitToPointsConversionFactor:kDKGridDrawingLayerMetricInterval];
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
				|| mControllers == nil )
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


///*********************************************************************************************************************
///
/// method:			owner
/// scope:			public method
/// overrides:		
/// description:	returns the "owner" of this drawing.
/// 
/// parameters:		none
/// result:			the owner
///
/// notes:			the owner is usually either a document, a window controller or a drawing view.
///
///********************************************************************************************************************
- (id)						owner
{
	return mOwnerRef;
}


///*********************************************************************************************************************
///
/// method:			setOwner:
/// scope:			public method
/// overrides:		
/// description:	sets the "owner" of this drawing.
/// 
/// parameters:		<owner> the owner for this object
/// result:			none
///
/// notes:			the owner is usually either a document, a window controller or a drawing view. It is not required to
///					be set at all, though some higher-level conveniences may depend on it.
///
///********************************************************************************************************************
- (void)					setOwner:(id) owner
{
	mOwnerRef = owner;
}


#pragma mark -
#pragma mark - basic drawing parameters
///*********************************************************************************************************************
///
/// method:			setDrawingSize:
/// scope:			public method
/// overrides:		
/// description:	sets the paper dimensions of the drawing.
/// 
/// parameters:		<aSize> the paper size in Quartz units
/// result:			none
///
/// notes:			the paper size is the absolute limits of ths drawing dimensions. Usually margins are set within this.
///
///********************************************************************************************************************

- (void)				setDrawingSize:(NSSize) aSize
{
	NSAssert( aSize.width > 0.0, @"width cant be zero or negative");
	NSAssert( aSize.height > 0.0, @"height can't be zero or negative");
	
	if (! NSEqualSizes( aSize, m_size ))
	{
		LogEvent_(kReactiveEvent, @"setting drawing size = {%f, %f}", aSize.width, aSize.height);

		[[[self undoManager] prepareWithInvocationTarget:self] setDrawingSize:[self drawingSize]];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingWillChangeSize object:self];
		m_size = aSize;
		
		// adjust bounds of every view to match
		
		[self drawingDidChangeToSize:[NSValue valueWithSize:aSize]];
		[[self controllers] makeObjectsPerformSelector:@selector( drawingDidChangeToSize:) withObject:[NSValue valueWithSize:aSize]];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingDidChangeSize object:self];
		
		if(! ([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
			[[self undoManager] setActionName:NSLocalizedString(@"Change Drawing Size", @"undo action for set drawing size")];
	}
}


///*********************************************************************************************************************
///
/// method:			drawingSize
/// scope:			public method
/// overrides:
/// description:	returns the current paper size of the drawing
/// 
/// parameters:		none
/// result:			the drawing size
///
/// notes:			
///
///********************************************************************************************************************

- (NSSize)				drawingSize
{
	return m_size;
}


///*********************************************************************************************************************
///
/// method:			setDrawingSizeFromPrintInfo:
/// scope:			public method
/// overrides:
/// description:	sets the drawing's paper size and margins to be equal to the sizes stored in a NSPrintInfo object.
/// 
/// parameters:		<printInfo> a NSPrintInfo object, obtained from the printing system
/// result:			none
///
/// notes:			can be used to synchronise a drawing size to the settings for a printer
///
///********************************************************************************************************************

- (void)				setDrawingSizeWithPrintInfo:(NSPrintInfo*) printInfo
{
	NSAssert( printInfo != nil, @"unable to set drawing size - print info was nil");
	
	[self setDrawingSize:[printInfo paperSize]];
	[self setMarginsWithPrintInfo:printInfo];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setMarginsLeft:top:right:bottom:
/// scope:			public method
/// overrides:
/// description:	sets the margins for the drawing
/// 
/// parameters:		<left,top, right,bottom> the margin sizes in Quartz units
/// result:			none
///
/// notes:			the margins inset the drawing area within the papersize set
///
///********************************************************************************************************************

- (void)				setMarginsLeft:(CGFloat) l top:(CGFloat) t right:(CGFloat) r bottom:(CGFloat) b
{
	if( l != m_leftMargin || r != m_rightMargin || t != m_topMargin || b != m_bottomMargin )
	{
		LogEvent_(kReactiveEvent, @"setting margins = {%f, %f, %f, %f}", l, t, r, b);
		
		[[[self undoManager] prepareWithInvocationTarget:self] setMarginsLeft:m_leftMargin top:m_topMargin right:m_rightMargin bottom:m_bottomMargin];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingWillChangeMargins object:self];
		
		NSRect oldInterior = [self interior];
		
		m_leftMargin = l;
		m_rightMargin = r;
		m_topMargin = t;
		m_bottomMargin = b;
		
		[self drawingDidChangeMargins:[NSValue valueWithRect:oldInterior]];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingDidChangeMargins object:self];
		[self setNeedsDisplay:YES];

		if(! ([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
			[[self undoManager] setActionName:NSLocalizedString(@"Change Margins", @"undo action for set margins")];
	}
}


///*********************************************************************************************************************
///
/// method:			setMarginsFromPrintInfo:
/// scope:			public method
/// overrides:
/// description:	sets the margins from the margin values stored in a NSPrintInfo object
/// 
/// parameters:		<printInfo> a NSPrintInfo object, obtained from the printing system
/// result:			none
///
/// notes:			setDrawingSizeFromPrintInfo: will also call this for you
///
///********************************************************************************************************************

- (void)				setMarginsWithPrintInfo:(NSPrintInfo*) printInfo
{
	[self setMarginsLeft:	[printInfo leftMargin]
					top:	[printInfo topMargin]
					right:	[printInfo rightMargin]
					bottom:	[printInfo bottomMargin]];
}


///*********************************************************************************************************************
///
/// method:			leftMargin
/// scope:			public method
/// overrides:
/// description:	
/// 
/// parameters:		none
/// result:			the width of the left margin
///
/// notes:			
///
///********************************************************************************************************************

- (CGFloat)				leftMargin
{
	return m_leftMargin;
}


///*********************************************************************************************************************
///
/// method:			rightMargin
/// scope:			public method
/// overrides:
/// description:	
/// 
/// parameters:		none
/// result:			the width of the right margin
///
/// notes:			
///
///********************************************************************************************************************

- (CGFloat)				rightMargin
{
	return m_rightMargin;
}


///*********************************************************************************************************************
///
/// method:			topMargin
/// scope:			public method
/// overrides:
/// description:	
/// 
/// parameters:		none
/// result:			the width of the top margin
///
/// notes:			
///
///********************************************************************************************************************

- (CGFloat)				topMargin
{
	return m_topMargin;
}


///*********************************************************************************************************************
///
/// method:			bottomMargin
/// scope:			public method
/// overrides:
/// description:	
/// 
/// parameters:		none
/// result:			the width of the bottom margin
///
/// notes:			
///
///********************************************************************************************************************

- (CGFloat)				bottomMargin
{
	return m_bottomMargin;
}


///*********************************************************************************************************************
///
/// method:			interior
/// scope:			public method
/// overrides:
/// description:	returns the interior region of the drawing, within the margins
/// 
/// parameters:		none
/// result:			a rectangle, the interior area of the drawing (paper size less margins)
///
/// notes:			
///
///********************************************************************************************************************

- (NSRect)				interior
{
	NSRect r = NSZeroRect;
	
	r.size = [self drawingSize];
	r.origin.x += [self leftMargin];
	r.origin.y += [self topMargin];
	r.size.width -= ([self leftMargin] + [self rightMargin]);
	r.size.height -= ([self topMargin] + [self bottomMargin]);
	
	return r;
}


///*********************************************************************************************************************
///
/// method:			pinPointToInterior
/// scope:			public method
/// overrides:
/// description:	constrains the point within the interior area of the drawing
/// 
/// parameters:		<p> a point structure
/// result:			a point, equal to p if p is within the interior, otherwise pinned to the nearest point within
///
/// notes:			
///
///********************************************************************************************************************

- (NSPoint)				pinPointToInterior:(NSPoint) p
{
	NSRect	r = [self interior];
	NSPoint	pin;
	
	pin.x = LIMIT( p.x, NSMinX( r ), NSMaxX( r ));
	pin.y = LIMIT( p.y, NSMinY( r ), NSMaxY( r ));
	
	return pin;
}


///*********************************************************************************************************************
///
/// method:			setFlipped:
/// scope:			public method
/// overrides:
/// description:	sets whether the Y axis of the drawing is flipped
/// 
/// parameters:		<flipped> YES to have increase Y going down, NO for increasing Y going up
/// result:			none
///
/// notes:			drawings are typically flipped, YES is the default. This affects the -isFlipped return from a
///					DKDrawingView. WARNING: drawings with flip set to NO may have issues at present as some lower level
///					code is currently assuming a flipped view.
///
///********************************************************************************************************************

- (void)				setFlipped:(BOOL) flipped
{
	if( flipped != mFlipped )
	{
		mFlipped = flipped;
		[self setNeedsDisplay:YES];
	}
}


///*********************************************************************************************************************
///
/// method:			isFlipped:
/// scope:			public method
/// overrides:
/// description:	whether the Y axis of the drawing is flipped
/// 
/// parameters:		none 
/// result:			YES to have increase Y going down, NO for increasing Y going up
///
/// notes:			drawings are typically flipped, YES is the default. This affects the -isFlipped return from a
///					DKDrawingView
///
///********************************************************************************************************************

- (BOOL)				isFlipped
{
	return mFlipped;
}


///*********************************************************************************************************************
///
/// method:			setColourSpace:
/// scope:			public method
/// overrides:
/// description:	sets the destination colour space for the whole drawing
/// 
/// parameters:		<cSpace> the colour space 
/// result:			none
///
/// notes:			colours set by styles and so forth are converted to this colourspace when rendering. A value of
///					nil will use whatever is set in the colours used by the styles.
///
///********************************************************************************************************************

- (void)					setColourSpace:(NSColorSpace*) cSpace
{
	[cSpace retain];
	[mColourSpace release];
	mColourSpace = cSpace;
}


///*********************************************************************************************************************
///
/// method:			colourSpace:
/// scope:			public method
/// overrides:
/// description:	returns the colour space for the whole drawing
/// 
/// parameters:		none
/// result:			the colour space
///
/// notes:			colours set by styles and so forth are converted to this colourspace when rendering. A value of
///					nil will use whatever is set in the colours used by the styles.
///
///********************************************************************************************************************

- (NSColorSpace*)			colourSpace
{
	return mColourSpace;
}



#pragma mark -
#pragma mark - setting the rulers to the grid

///*********************************************************************************************************************
///
/// method:			setDrawingUnits:unitToPointsConversionFactor:
/// scope:			public method
/// overrides:
/// description:	sets the units and basic coordinate mapping factor
/// 
/// parameters:		<units> a string which is the drawing units of the drawing, e.g. "millimetres"
///					<conversionFactor> how many Quartz points per basic unit?
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setDrawingUnits:(NSString*) units unitToPointsConversionFactor:(CGFloat) conversionFactor
{
	NSAssert( units != nil, @"cannot set drawing units to nil");
	NSAssert([units length] > 0, @"units string is empty"); 
	
	if ( conversionFactor != m_unitConversionFactor || ![units isEqualToString:m_units])
	{
		LogEvent_( kReactiveEvent, @"setting drawing units:'%@'", units);
		
		[[[self undoManager] prepareWithInvocationTarget:self] setDrawingUnits:m_units unitToPointsConversionFactor:m_unitConversionFactor];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingUnitsWillChange object:self];
		[units retain];
		[m_units release];
		m_units = units;
		m_unitConversionFactor = conversionFactor;
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingUnitsDidChange object:self];
	}
}


///*********************************************************************************************************************
///
/// method:			drawingUnits
/// scope:			public method
/// overrides:
/// description:	returns the full name of the drawing's units
/// 
/// parameters:		none
/// result:			a string
///
/// notes:			
///
///********************************************************************************************************************

- (NSString*)			drawingUnits
{
	return m_units;
}


///*********************************************************************************************************************
///
/// method:			abbreviatedDrawingUnits
/// scope:			public method
/// overrides:
/// description:	returns the abbreviation of the drawing's units
/// 
/// parameters:		none
/// result:			a string
///
/// notes:			For those it knows about, it does a lookup. For unknown units, it uses the first two characters
///					and makes them lower case. The delegate can also elect to supply this string if it prefers.
///
///********************************************************************************************************************

- (NSString*)			abbreviatedDrawingUnits
{
	NSString* abbrev = nil;
	
	if([[self delegate] respondsToSelector:@selector(drawing:willReturnAbbreviationForUnit:)])
		abbrev = [[self delegate] drawing:self willReturnAbbreviationForUnit:[self drawingUnits]];
	
	if( abbrev )
		return abbrev;
	else
		return [[self class] abbreviationForDrawingUnits:[self drawingUnits]];
}


///*********************************************************************************************************************
///
/// method:			unitToPointsConversionFactor
/// scope:			public method
/// overrides:
/// description:	returns the number of Quartz units per basic drawing unit
/// 
/// parameters:		none
/// result:			the conversion value
///
/// notes:			
///
///********************************************************************************************************************

- (CGFloat)				unitToPointsConversionFactor
{
	return m_unitConversionFactor;
}


///*********************************************************************************************************************
///
/// method:			effectiveUnitToPointsConversionFactor
/// scope:			public method
/// overrides:
/// description:	returns the number of Quartz units per basic drawing unit, as optionally determined by the delegate
/// 
/// parameters:		none
/// result:			the conversion value
///
/// notes:			This allows the delegate to return a different value for special requirements. If the delegate does
///					not respond, the normal conversion factor is returned. Note that DK currently doesn't use this
///					internally but app-level code may do if it further overlays a coordinate mapping on top of the
///					drawing's own.
///
///********************************************************************************************************************

- (CGFloat)				effectiveUnitToPointsConversionFactor
{
	if([[self delegate] respondsToSelector:@selector(drawingWillReturnUnitToPointsConversonFactor:)])
		return [[self delegate] drawingWillReturnUnitToPointsConversonFactor:self];
	else
		return [self unitToPointsConversionFactor];
}


///*********************************************************************************************************************
///
/// method:			synchronizeRulersWithUnits
/// scope:			public method
/// overrides:
/// description:	sets up the rulers for all attached views to a previously registered ruler state
/// 
/// parameters:		<unitString> the name of a previously registered ruler state
/// result:			none
///
/// notes:			DKGridLayer registers rulers to match its grid using the drawingUnits string returned by
///					this class as the registration key. If your drawing doesn't have a grid but does use the rulers,
///					you need to register the ruler setup yourself somewhere.
///
///********************************************************************************************************************

- (void)				synchronizeRulersWithUnits:(NSString*) unitString
{
	[[self controllers] makeObjectsPerformSelector:@selector(synchronizeViewRulersWithUnits:) withObject:unitString];
}


///*********************************************************************************************************************
///
/// method:			setDelegate:
/// scope:			public method
/// overrides:
/// description:	sets the delegate
/// 
/// parameters:		<aDelegate> some delegate object
/// result:			none
///
/// notes:			see header for possible delegate methods
///
///********************************************************************************************************************

- (void)				setDelegate:(id) aDelegate
{
	mDelegateRef = aDelegate;
}


///*********************************************************************************************************************
///
/// method:			delegate
/// scope:			public method
/// overrides:
/// description:	return the delegate
/// 
/// parameters:		none 
/// result:			some delegate object
///
/// notes:			see header for possible delegate methods
///
///********************************************************************************************************************

- (id)					delegate
{
	return mDelegateRef;
}

#pragma mark -
#pragma mark - controllers attachment

///*********************************************************************************************************************
///
/// method:			controllers
/// scope:			public method
/// overrides:
/// description:	return the current controllers the drawing owns
/// 
/// parameters:		none
/// result:			a set of the current controllers
///
/// notes:			controllers are in no particular order. The drawing object owns its controllers.
///
///********************************************************************************************************************

- (NSSet*)				controllers
{
	return mControllers;
}


///*********************************************************************************************************************
///
/// method:			addController:
/// scope:			public method
/// overrides:
/// description:	add a controller to the drawing
/// 
/// parameters:		<aController> the controller to add
/// result:			none
///
/// notes:			a controller is associated with a view, but must be added to the drawing to forge the connection
///					between the drawing and its views. The drawing owns the controller. DKDrawingDocument and the
///					automatic back-end set-up handle all of this for you - you only need this if you are building
///					the DK system entirely by hand.
///
///********************************************************************************************************************

- (void)				addController:(DKViewController*) aController
{
	NSAssert( aController != nil, @"cannot add a nil controller to drawing");
	
	if(![aController isKindOfClass:[DKViewController class]])
		[NSException raise:NSInternalInconsistencyException format:@"attempt to add an invalid object as a controller"];
	
	// synch the rulers here in case we got this far without any sort of view infrastructure in place - this can
	// occur when launching the app with a file to open in the Finder. Without synching the ruler class with throw
	// an exception which breaks the setup.
	
	[[self gridLayer] synchronizeRulers];
	[mControllers addObject:aController];
	[aController setDrawing:self];
}


///*********************************************************************************************************************
///
/// method:			removeController:
/// scope:			public method
/// overrides:
/// description:	removes a controller from the drawing
/// 
/// parameters:		<aController> the controller to remove
/// result:			none
///
/// notes:			typically controllers are removed when necessary - there is little reason to call this yourself
///
///********************************************************************************************************************

- (void)				removeController:(DKViewController*) aController
{
	NSAssert( aController != nil, @"attempt to remove a nil controller from drawing");
	
	if([[self controllers] containsObject:aController])
	{
		[aController setDrawing:nil];
		[mControllers removeObject:aController];
	}
}


///*********************************************************************************************************************
///
/// method:			removeAllControllers
/// scope:			public method
/// overrides:
/// description:	removes all controller from the drawing
/// 
/// parameters:		none
/// result:			none
///
/// notes:			typically controllers are removed when necessary - there is little reason to call this yourself
///
///********************************************************************************************************************

- (void)					removeAllControllers
{
	[mControllers makeObjectsPerformSelector:@selector(setDrawing:) withObject:nil];
	[mControllers removeAllObjects];
}



#pragma mark -
///*********************************************************************************************************************
///
/// method:			invalidateCursors
/// scope:			public method
/// overrides:
/// description:	causes all cursor rectangles for all attached views to be recalculated. This forces any cursors
///					that may be in use to be updated.
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				invalidateCursors
{
	[[self controllers] makeObjectsPerformSelector:_cmd];
}


///*********************************************************************************************************************
///
/// method:			scrollToRect:
/// scope:			public method
/// overrides:
/// description:	causes all attached views to scroll to show the rect, if necessary
/// 
/// parameters:		<rect> the rect to reveal
/// result:			none
///
/// notes:			Called for things like scroll to selection - all attached views may scroll if necessary. Note that
///					it is OK to directly call the view's methods if scrolling a single view is required - the drawing
///					isn't aware of any view's scroll position.
///
///********************************************************************************************************************

- (void)				scrollToRect:(NSRect) rect
{
	[[self controllers] makeObjectsPerformSelector:@selector(scrollViewToRect:) withObject:[NSValue valueWithRect:rect]];
}


///*********************************************************************************************************************
///
/// method:			objectDidNotifyStatusChange
/// scope:			public method
/// overrides:
/// description:	notifies all the controllers that an object within the drawing notified a status change
/// 
/// parameters:		<object> the original object that sent the notification
/// result:			none
///
/// notes:			status changes are non-visual changes that a view controller might want to know about
///
///********************************************************************************************************************

- (void)				objectDidNotifyStatusChange:(id) object
{
	[[self controllers] makeObjectsPerformSelector:_cmd withObject:object];
}


#pragma mark -
#pragma mark - dynamically adjusting the rendering quality

///*********************************************************************************************************************
///
/// method:			setDynamicQualityModulationEnabled
/// scope:			public method
/// overrides:
/// description:	set whether drawing quality modulation is enabled or not
/// 
/// parameters:		qmEnabled
/// result:			none
///
/// notes:			rasterizers are able to use a low quality drawing mode for rapid updates when DKDrawing detects
///					the need for it. This flag allows that behaviour to be turned on or off.
///
///********************************************************************************************************************

- (void)					setDynamicQualityModulationEnabled:(BOOL) qmEnabled
{
	m_qualityModEnabled = qmEnabled;
}


- (BOOL)					dynamicQualityModulationEnabled
{
	return m_qualityModEnabled;
}

///*********************************************************************************************************************
///
/// method:			setLowRenderingQuality:
/// scope:			public method
/// overrides:
/// description:	advise whether drawing should be done in best quality or not
/// 
/// parameters:		<quickAndDirty> YES to offer low quality faster rendering
/// result:			none
///
/// notes:			rasterizers in DK can query this flag to check if they can use a fast quick rendering method.
///					this is set while zooming, scrolling or other operations that require many rapid updates. Speed
///					under these conditions can be improved by using bitmap caches, etc rather than drawing at best
///					quality.
///
///********************************************************************************************************************

- (void)				setLowRenderingQuality:(BOOL) quickAndDirty
{
	if ( quickAndDirty != m_useQandDRendering )
	{
		m_useQandDRendering = quickAndDirty;
	
	//	LogEvent_(kStateEvent, @"setting rendering quality: %@", m_useQandDRendering? @"LOW": @"HIGH" );
	}
}


///*********************************************************************************************************************
///
/// method:			lowRenderingQuality
/// scope:			public method
/// overrides:
/// description:	advise whether drawing should be done in best quality or not
/// 
/// parameters:		none
/// result:			YES if low quality is an option
///
/// notes:			renderers in drawkit can query this flag to check if they can use a fast quick rendering method.
///					this is set while zooming, scrolling or other operations that require many rapid updates. Speed
///					under these conditions can be inmproved by using bitmap caches, etc rather than drawing at best
///					quality.
///
///********************************************************************************************************************

- (BOOL)				lowRenderingQuality
{
	return m_useQandDRendering;
}


///*********************************************************************************************************************
///
/// method:			checkIfLowQualityRequired
/// scope:			private method
/// overrides:
/// description:	dynamically check if low or high quality should be used
/// 
/// parameters:		none
/// result:			none
///
/// notes:			called from the drawing method, this starts or extends a timer which will set high quality after
///					a delay. Thus if rapid updates are happening, it will switch to low quality, and switch to high
///					quality after a delay.
///
///********************************************************************************************************************

- (void)				checkIfLowQualityRequired
{
	// if this is being called frequently, set low quality and start a timer to restore high quality after a delay. If the timer is
	// already running, retrigger it.
	
	// if not drawing to screen, don't do this - always use HQ
	
	if (![[NSGraphicsContext currentContext] isDrawingToScreen])
	{
		[self setLowRenderingQuality:NO];
		return;
	}

	if([self dynamicQualityModulationEnabled])
	{
		
		[self setLowRenderingQuality:YES];
		
		if ( m_renderQualityTimer == nil )
		{
			// start the timer:
			
			m_renderQualityTimer = [[NSTimer scheduledTimerWithTimeInterval:mTriggerPeriod target:self selector:@selector(qualityTimerCallback:) userInfo:nil repeats:YES] retain];
			[[NSRunLoop currentRunLoop] addTimer:m_renderQualityTimer forMode:NSEventTrackingRunLoopMode];
		}
		else
		{
			// already running - retrigger it:
			
			[m_renderQualityTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:mTriggerPeriod]];
		}
	}
	else
		[self setLowRenderingQuality:NO];
}


- (void)				qualityTimerCallback:(NSTimer*) timer
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


- (void)				setLowQualityTriggerInterval:(NSTimeInterval) t
{
	mTriggerPeriod = t;
}


- (NSTimeInterval)		lowQualityTriggerInterval;
{
	return mTriggerPeriod;
}


#pragma mark -
#pragma mark - setting the undo manager
///*********************************************************************************************************************
///
/// method:			setUndoManager:
/// scope:			public method
/// overrides:
/// description:	sets the undoManager that will be used for all undo actions that occur in this drawing.
/// 
/// parameters:		<um> the undo manager to use
/// result:			none
///
/// notes:			the undoManager is retained. It is passed down to all levels that need undoable actions. The
///					default is nil, so nothing will be undoable unless you set it. In a document-based app, the
///					document's undoManager should be used. Otherwise, the view's or window's undoManager can be used.
///
///********************************************************************************************************************

- (void)				setUndoManager:(id) um
{
	if ( um != m_undoManager )
	{
		[m_undoManager removeAllActions];
		
		[um retain];
		[m_undoManager release];
		m_undoManager = um;
		
		// the undo manager needs to be known objects (particularly styles) that the drawing contains. For a drawing created from an
		// archive, this needs to be pushed out to all those objects
		
		[self drawingHasNewUndoManager:um];
	}
}


///*********************************************************************************************************************
///
/// method:			undoManager
/// scope:			public method
/// overrides:
/// description:	returns the undo manager for the drawing
/// 
/// parameters:		none
/// result:			the currently used undo manager
///
/// notes:			
///
///********************************************************************************************************************

- (id)		undoManager
{
	return m_undoManager;
}


#pragma mark -
#pragma mark - drawing meta-data
///*********************************************************************************************************************
///
/// method:			setDrawingInfo:
/// scope:			public method
/// overrides:
/// description:	sets the drawing info metadata for the drawing
/// 
/// parameters:		<info> the drawing info dictionary
/// result:			none
///
/// notes:			the drawing info contains whatever you want, but a number of standard fields are defined and can be
///					interpreted by a DKDrawingInfoLayer, if there is one. Note this inherits the storage from
///					DKLayer.
///
///********************************************************************************************************************

- (void)				setDrawingInfo:(NSMutableDictionary*) info
{
	[self setUserInfoObject:info forKey:kDKDrawingInfoUserInfoKey];
}


///*********************************************************************************************************************
///
/// method:			drawingInfo
/// scope:			public method
/// overrides:
/// description:	returns the current drawing info metadata
/// 
/// parameters:		none
/// result:			a dictionary, the drawing info
///
/// notes:			
///
///********************************************************************************************************************

- (NSMutableDictionary*) drawingInfo
{
	return [self userInfoObjectForKey:kDKDrawingInfoUserInfoKey];
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			setPaperColour:
/// scope:			public method
/// overrides:
/// description:	sets the background colour of the entire drawing
/// 
/// parameters:		<colour> the colour to set for the drawing's background (paper) colour
/// result:			none
///
/// notes:			default is white
///
///********************************************************************************************************************

- (void)				setPaperColour:(NSColor*) colour
{
	if( colour != [self paperColour])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setPaperColour:[self paperColour]];
		
		[colour retain];
		[m_paperColour release];
		m_paperColour = colour;
		[self setNeedsDisplay:YES];
		
		if(! ([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
			[[self undoManager] setActionName:NSLocalizedString(@"Background Colour", @"undo action for setPaperColour")];
	}
}


///*********************************************************************************************************************
///
/// method:			paperColour
/// scope:			public method
/// overrides:
/// description:	the curremt paper colour of the drawing
/// 
/// parameters:		none
/// result:			the current colour of the background (paper)
///
/// notes:			default is white
///
///********************************************************************************************************************

- (NSColor*)			paperColour
{
	return m_paperColour;
}


///*********************************************************************************************************************
///
/// method:			setPaperColourIsPrinted:
/// scope:			public method
/// overrides:
/// description:	set whether the paper colour is printed or not
/// 
/// parameters:		<printIt> YES to include the paper colour when printing
/// result:			none
///
/// notes:			default is NO
///
///********************************************************************************************************************

- (void)				setPaperColourIsPrinted:(BOOL) printIt
{
	mPaperColourIsPrinted = printIt;
}


///*********************************************************************************************************************
///
/// method:			paperColourIsPrinted
/// scope:			public method
/// overrides:
/// description:	whether the paper colour is printed or not
/// 
/// parameters:		none
/// result:			YES if the paper colour is included when printing
///
/// notes:			default is NO
///
///********************************************************************************************************************

- (BOOL)				paperColourIsPrinted
{
	return mPaperColourIsPrinted;
}



#pragma mark -
///*********************************************************************************************************************
///
/// method:			exitTemporaryTextEditingMode
/// scope:			private method
/// overrides:
/// description:	for the utility of contained objects, this ends any open text editing session without the object
///					needing to know which view is handling it.
/// 
/// parameters:		none
/// result:			none
///
/// notes:			if any attached view has started a temporary text editing mode, this method can be called to end
///					that mode and perform all necessary cleanup. This is useful if the object that requested the mode
///					no longer knows which view it asked to do the editing (and thus saves it the need to record the
///					view in question). Note that normally only one such view could have entered this mode, but this
///					will also recover from a situation (bug!) where more than one has a text editing operation mode open.
///
///********************************************************************************************************************

- (void)				exitTemporaryTextEditingMode
{
	[[self controllers] makeObjectsPerformSelector:_cmd];
}


#pragma mark -
#pragma mark - active layer
///*********************************************************************************************************************
///
/// method:			setActiveLayer:
/// scope:			public method
/// overrides:
/// description:	sets which layer is currently active
/// 
/// parameters:		<aLayer> the layer to make the active layer, or nil to make no layer active
/// result:			YES if the active layer changed, NO if not
///
/// notes:			the active layer is automatically linked from the first responder so it can receive commands
///					only one layer can be active at a time. Layers also receive activate/deactivate messages when their
///					active state changes.
///
///********************************************************************************************************************

- (BOOL)			setActiveLayer:(DKLayer*) aLayer
{
	return [self setActiveLayer:aLayer withUndo:NO];
}


///*********************************************************************************************************************
///
/// method:			setActiveLayer:withUndo:
/// scope:			public method
/// overrides:
/// description:	sets which layer is currently active, optionally making this change undoable
/// 
/// parameters:		<aLayer> the layer to make the active layer, or nil to make no layer active
/// result:			YES if the active layer changed, NO if not
///
/// notes:			normally active layer changes are not undoable as the active layer is not considered part of the
///					state of the data model. However some actions such as adding and removing layers should include
///					the active layer state as part of the undo, so that the user experience is pleasant.
///
///********************************************************************************************************************

- (BOOL)			setActiveLayer:(DKLayer*) aLayer withUndo:(BOOL) undo
{
	// we already own this, so don't retain it
	
	if ( aLayer != m_activeLayerRef && (aLayer == nil || [aLayer layerMayBecomeActive]) && ![self locked])
	{
		if( undo )
			[[[self undoManager] prepareWithInvocationTarget:self] setActiveLayer:m_activeLayerRef withUndo:YES];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingActiveLayerWillChange object:self];
		[[self controllers] makeObjectsPerformSelector:@selector(activeLayerWillChangeToLayer:) withObject:aLayer];
		
		[m_activeLayerRef layerDidResignActiveLayer];
		m_activeLayerRef = aLayer;
		[m_activeLayerRef layerDidBecomeActiveLayer];
		[self invalidateCursors];

		[[self controllers] makeObjectsPerformSelector:@selector(activeLayerDidChangeToLayer:) withObject:aLayer];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingActiveLayerDidChange object:self];
		
		LogEvent_(kReactiveEvent, @"Active Layer changed to: %@", aLayer);
		
		return YES;
	}
	
	return NO;
}


///*********************************************************************************************************************
///
/// method:			activeLayer
/// scope:			public method
/// overrides:
/// description:	returns the current active layer
/// 
/// parameters:		none
/// result:			a DKLayer object, or subclass, which is the current active layer
///
/// notes:			
///
///********************************************************************************************************************

- (DKLayer*)		activeLayer
{
	return m_activeLayerRef;
}


///*********************************************************************************************************************
///
/// method:			activeLayerOfClass:
/// scope:			public method
/// overrides:
/// description:	returns the active layer if it matches the requested class
/// 
/// parameters:		<aClass> the class of layer sought
/// result:			the active layer if it matches the requested class, otherwise nil
///
/// notes:			
///
///********************************************************************************************************************

- (id)					activeLayerOfClass:(Class) aClass
{
	if ([[self activeLayer] isKindOfClass:aClass])
		return [self activeLayer];
	else
		return nil;
}


///*********************************************************************************************************************
///
/// method:			addLayer:andActivateIt:
/// scope:			public method
/// overrides:
/// description:	adds a layer to the drawing and optionally activates it
/// 
/// parameters:		<aLayer> a layer object to be added
///					<activateIt> if YES, the added layer will be made the active layer, NO will not change it
/// result:			none
///
/// notes:			this method has the advantage over separate add + activate calls that the active layer change is
///					recorded by the undo stack, so it's the better one to use when adding layers via a UI since an
///					undo of the action will restore the UI to its previous state with respect to the active layer.
///					Normally changes to the active layer are not undoable.
///
///********************************************************************************************************************

- (void)				addLayer:(DKLayer*) aLayer andActivateIt:(BOOL) activateIt
{
	NSAssert( aLayer != nil, @"cannot add a nil layer to the drawing");
	
	NSString* layerName = [self uniqueLayerNameForName:[aLayer layerName]];
	[aLayer setLayerName:layerName];

	[super addLayer:aLayer];

	// tell the layer it was added to the root (drawing)
	
	[aLayer drawingHasNewUndoManager:[self undoManager]];
	[aLayer wasAddedToDrawing:self];

	if( activateIt )
		[self setActiveLayer:aLayer withUndo:YES];
}


///*********************************************************************************************************************
///
/// method:			removeLayer:andActivateLayer:
/// scope:			public method
/// overrides:
/// description:	removes a layer from the drawing and optionally activates another one
/// 
/// parameters:		<aLayer> a layer object to be removed
///					<anotherLayer> if not nil, this layer will be activated after removing the first one.
/// result:			none
///
/// notes:			this method is the inverse of the one above, used to help make UIs more usable by also including
///					undo for the active layer change. It is an error for <anotherLayer> to be equal to <aLayer>. As a
///					further UI convenience, if <aLayer> is the current active layer, and <anotherLayer> is nil, this
///					finds the topmost layer of the same class as <aLayer> and makes that active.
///
///********************************************************************************************************************

- (void)				removeLayer:(DKLayer*) aLayer andActivateLayer:(DKLayer*) anotherLayer
{
	NSAssert( aLayer != nil, @"can't remove a nil layer from the drawing ");
	NSAssert( aLayer != anotherLayer, @"cannot activate the layer being removed - layers must be different");
	
	// retain the layer until we are completely done with it
	
	[aLayer retain];
	
	BOOL removingActive = ( aLayer == [self activeLayer]);
	
	// remove it from the drawing
	
	[super removeLayer:aLayer];

	if( removingActive && ( anotherLayer == nil ))
	{
		// for convenience activate the topmost layer of the same class as the one being removed. If that
		// returns nil, activate the top layer.
		
		DKLayer* newActive = [self firstLayerOfClass:[aLayer class]];
	
		if( newActive == nil )
			newActive = [self topLayer];
			
		anotherLayer = newActive;
	}
	
	if( anotherLayer )
		[self setActiveLayer:anotherLayer withUndo:YES];
	
	[aLayer release];
}


///*********************************************************************************************************************
///
/// method:			firstActivateableLayerOfClass:
/// scope:			public method
/// overrides:
/// description:	finds the first layer of the given class that can be activated.
/// 
/// parameters:		<cl> the class of layer to look for
/// result:			the first such layer that returns yes to -layerMayBecomeActive
///
/// notes:			looks through all subgroups
///
///********************************************************************************************************************

- (DKLayer*)			firstActivateableLayerOfClass:(Class) cl
{
	NSArray*		layers = [self layersOfClass:cl performDeepSearch:YES];
	NSEnumerator*	iter = [layers objectEnumerator];
	DKLayer*		layer;
	
	while(( layer = [iter nextObject]))
	{
		if([layer layerMayBecomeActive])
			return layer;
	}
	
	return nil;
}


#pragma mark -
#pragma mark - snapping

///*********************************************************************************************************************
///
/// method:			setSnapsToGrid:
/// scope:			public method
/// overrides:
/// description:	sets whether mouse actions within the drawing should snap to grid or not.
/// 
/// parameters:		<snaps> YES to turn on snap to grid, NO to turn it off
/// result:			
///
/// notes:			actually snapping requires that objects call the snapToGrid: method for points that they are
///					processing while dragging the mouse, etc.
///
///********************************************************************************************************************

- (void)				setSnapsToGrid:(BOOL) snaps
{
	m_snapsToGrid = snaps;
	[[NSUserDefaults standardUserDefaults] setBool:!snaps forKey:kDKDrawingSnapToGridUserDefault];
}


///*********************************************************************************************************************
///
/// method:			snapsToGrid
/// scope:			public method
/// overrides:
/// description:	whether snap to grid os on or off
/// 
/// parameters:		none
/// result:			YES if grid snap is on, NO if off
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				snapsToGrid
{
	return m_snapsToGrid;
}


///*********************************************************************************************************************
///
/// method:			setSnapsToGuides:
/// scope:			public method
/// overrides:
/// description:	sets whether mouse actions within the drawing should snap to guides or not.
/// 
/// parameters:		<snaps> YES to turn on snap to guides, NO to turn it off
/// result:			
///
/// notes:			actually snapping requires that objects call the snapToGuides: method for points and rects that they are
///					processing while dragging the mouse, etc.
///
///********************************************************************************************************************

- (void)				setSnapsToGuides:(BOOL) snaps
{
	m_snapsToGuides = snaps;
	[[NSUserDefaults standardUserDefaults] setBool:!snaps forKey:kDKDrawingSnapToGuidesUserDefault];
}


///*********************************************************************************************************************
///
/// method:			snapsToGrid
/// scope:			public method
/// overrides:
/// description:	whether snap to grid os on or off
/// 
/// parameters:		none
/// result:			YES if grid snap is on, NO if off
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				snapsToGuides
{
	return m_snapsToGuides;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			snapToGrid:withControlFlag:
/// scope:			public method
/// overrides:
/// description:	moves a point to the nearest grid position if snapControl is different from current user setting,
///					otherwise returns it unchanged
/// 
/// parameters:		<p> a point value within the drawing
///					<snapControl> inverts the applied state of the grid snapping setting
/// result:			a modified point located at the nearest grid intersection
///
/// notes:			the grid layer actually performs the computation, if one exists. The <snapControl> parameter
///					usually comes from a modifer key such as ctrl - if snapping is on it disables it, if off it
///					enables it. This flag is passed up from whatever mouse event is actually being handled.
///
///********************************************************************************************************************

- (NSPoint)				snapToGrid:(NSPoint) p withControlFlag:(BOOL) snapControl
{
	BOOL doSnap = snapControl != [self snapsToGrid];
	
	if( doSnap )
	{
		DKGridLayer* grid = [self gridLayer];
	
		if ( grid != nil )
			p = [grid nearestGridIntersectionToPoint:p];
	}
		
	return p;
}


///*********************************************************************************************************************
///
/// method:			snapToGrid:ignoringUserSetting:
/// scope:			public method
/// overrides:
/// description:	moves a point to the nearest grid position if snap is turned ON, otherwise returns it unchanged
/// 
/// parameters:		<p> a point value within the drawing
///					<ignore> if YES, the current state of [self snapsToGrid] is ignored
/// result:			a modified point located at the nearest grid intersection
///
/// notes:			the grid layer actually performs the computation, if one exists. If the control modifier key is down
///					grid snapping is temporarily disabled, so this modifier universally means don't snap for all drags.
///					Passing YES for <ignore> is intended for use by internal classes such as DKGuideLayer.
///
///********************************************************************************************************************

- (NSPoint)				snapToGrid:(NSPoint) p ignoringUserSetting:(BOOL) ignore
{
	DKGridLayer* grid = [self gridLayer];
	
	if ( grid != nil && ([self snapsToGrid] || ignore ))
		p = [grid nearestGridIntersectionToPoint:p];
		
	return p;
}


///*********************************************************************************************************************
///
/// method:			snapToGuides:
/// scope:			public method
/// overrides:
/// description:	moves a point to a nearby guide position if snap is turned ON, otherwise returns it unchanged
/// 
/// parameters:		<p> a point value within the drawing
/// result:			a modified point located at a nearby guide
///
/// notes:			the guide layer actually performs the computation, if one exists.
///
///********************************************************************************************************************

- (NSPoint)				snapToGuides:(NSPoint) p
{
	DKGuideLayer*	gl = [self guideLayer];
	
	if ( gl != nil && [self snapsToGuides])
		p = [gl snapPointToGuide:p];
		
	return p;
}


///*********************************************************************************************************************
///
/// method:			snapRectToGuides:includingCentres:
/// scope:			public method
/// overrides:
/// description:	snaps any edge (and optionally the centre) of a rect to any nearby guide
/// 
/// parameters:		<r> a proposed rectangle which might bethe bounds of some object for example
///					<cent> if YES, the centre point of the rect is also considered a candidadte for snapping, NO for
///					just the edges.
/// result:			a rectangle, either the input rectangle or a rectangle of identical size offset to align with
///					one of the guides
///
/// notes:			the guide layer itself implements the snapping calculations, if it exists.
///
///********************************************************************************************************************

- (NSRect)				snapRectToGuides:(NSRect) r includingCentres:(BOOL) cent
{
	DKGuideLayer*	gl = [self guideLayer];
	
	if ( gl != nil && [self snapsToGuides])
		r = [gl snapRectToGuide:r includingCentres:cent];
		
	return r;
}


///*********************************************************************************************************************
///
/// method:			snapPointsToGuide:
/// scope:			public method
/// overrides:
/// description:	determines the snap offset for any of a list of points
/// 
/// parameters:		<points> an array containing NSValue objects with NSPoint values
/// result:			an offset amount which is the distance to move one ofthe points to make it snap. This value can
///					usually be simply added to the current mouse point that is dragging the object
///
/// notes:			the guide layer itself implements the snapping calculations, if it exists.
///
///********************************************************************************************************************

- (NSSize)				snapPointsToGuide:(NSArray*) points
{
	DKGuideLayer*	gl = [self guideLayer];
	
	if ( gl != nil && [self snapsToGuides])
		return [gl snapPointsToGuide:points];
		
	return NSZeroSize;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			nudgeOffset
/// scope:			public method
/// overrides:
/// description:	returns the amount meant by a single press of any of the arrow keys
/// 
/// parameters:		none
/// result:			an x and y value representing how far each "nudge" should move an object. If there is a grid layer,
///					and snapping is on, this will be a grid interval. Otherwise it will be 1.
///
/// notes:			
///
///********************************************************************************************************************

- (NSPoint)				nudgeOffset
{
	// returns the x and y distances a nudge operation should move an object. If snapToGrid is on, this returns the grid division
	// size, otherwise it returns 1, 1. Note that an actual nudge may want to take steps to actually align the object to the grid.
	
	DKGridLayer*	grid = [self gridLayer];
	BOOL			ctrl = ([[NSApp currentEvent] modifierFlags] & NSControlKeyMask) != 0;
	
	if ( grid != nil && [self snapsToGrid] && !ctrl )
	{
		NSPoint nudge;
		nudge.x = nudge.y = [grid divisionDistance];
		return nudge;
	}
	else
		return NSMakePoint( 1.0, 1.0 );
}


#pragma mark -
#pragma mark - grids, guides and conversions

///*********************************************************************************************************************
///
/// method:			gridLayer
/// scope:			public method
/// overrides:
/// description:	returns the master grid layer, if there is one
/// 
/// parameters:		none
/// result:			the grid layer, or nil
///
/// notes:			Usually there will only be one grid, but if there is more than one this only finds the uppermost.
///					This only returns a grid that returns YES to -isMasterGrid, so subclasses can return NO to
///					prevent themselves being considered for this role.
///
///********************************************************************************************************************

- (DKGridLayer*)	gridLayer
{
	NSArray* gridLayers = [self layersOfClass:[DKGridLayer class] performDeepSearch:YES];
	
	NSEnumerator*	iter = [gridLayers objectEnumerator];
	DKGridLayer*	grid;
	
	while(( grid = [iter nextObject]))
	{
		if([grid isMasterGrid])
			return grid;
	}
	
	return nil;
}


///*********************************************************************************************************************
///
/// method:			guideLayer
/// scope:			public method
/// overrides:
/// description:	returns the guide layer, if there is one
/// 
/// parameters:		none
/// result:			the guide layer, or nil
///
/// notes:			Usually there will only be one guide layer, but if there is more than one this only finds the uppermost.
///
///********************************************************************************************************************

- (DKGuideLayer*)		guideLayer
{
	return (DKGuideLayer*)[self firstLayerOfClass:[DKGuideLayer class] performDeepSearch:YES];
}


///*********************************************************************************************************************
///
/// method:			convertLength:
/// scope:			public instance method
/// overrides:
/// description:	convert a distance in quartz coordinates to the units established by the drawing grid
/// 
/// parameters:		<len> a distance in base points (pixels)
/// result:			the distance in drawing units
///
/// notes:			this is a convenience API to query the drawing's grid layer. If there is a delegate and it implements
///					the optional conversionmethod, it is given the opportunity to further modify the result. This
///					permits a delegate to impose an additional coordinate system on the drawing for display purposes,
///					for example by converting to latitude/longitude or other scale.
///
///********************************************************************************************************************

- (CGFloat)			convertLength:(CGFloat) len
{
	CGFloat length = [[self gridLayer] gridDistanceForQuartzDistance:len];
	
	if([[self delegate] respondsToSelector:@selector(drawing:convertDistanceToExternalCoordinates:)])
		length = [[self delegate] drawing:self convertDistanceToExternalCoordinates:length];
	
	return length;
}


///*********************************************************************************************************************
///
/// method:			convertPoint:
/// scope:			public instance method
/// overrides:
/// description:	convert a point in quartz coordinates to the units established by the drawing grid
/// 
/// parameters:		<pt> a point in base points (pixels)
/// result:			the position ofthe point in drawing units
///
/// notes:			this is a convenience API to query the drawing's grid layer. The delegate is also given a shot
///					at further modifying the returned values.
///
///********************************************************************************************************************

- (NSPoint)			convertPoint:(NSPoint) pt
{
	NSPoint cpt = [[self gridLayer] gridLocationForPoint:pt];
	
	if([[self delegate] respondsToSelector:@selector(drawing:convertLocationToExternalCoordinates:)])
		cpt = [[self delegate] drawing:self convertLocationToExternalCoordinates:cpt];
	
	return cpt;
}


///*********************************************************************************************************************
///
/// method:			formattedConvertedLength:
/// scope:			public instance method
/// overrides:
/// description:	convert a distance in quartz coordinates to the units established by the drawing grid
/// 
/// parameters:		<len> a distance in base points (pixels)
/// result:			a string containing a fully formatted distance plus the units abbreviation
///
/// notes:			this wraps up length conversion and formatting for display into one method, which also calls the
///					delegate if it implements the relevant method.
///
///********************************************************************************************************************

- (NSString*)				formattedConvertedLength:(CGFloat) len
{
	CGFloat length = [[self gridLayer] gridDistanceForQuartzDistance:len];
	
	if([[self delegate] respondsToSelector:@selector(drawing:willReturnFormattedCoordinateForDistance:)])
		return [[self delegate] drawing:self willReturnFormattedCoordinateForDistance:length];
	else
		return [NSString stringWithFormat:@"%.2f %@", length, [self abbreviatedDrawingUnits]];
}


///*********************************************************************************************************************
///
/// method:			formattedConvertedPoint:
/// scope:			public instance method
/// overrides:
/// description:	convert a point in quartz coordinates to the units established by the drawing grid
/// 
/// parameters:		<pt> a point in base points (pixels)
/// result:			a pair of strings containing a fully formatted distance plus the units abbreviation
///
/// notes:			this wraps up length conversion and formatting for display into one method, which also calls the
///					delegate if it implements the relevant method. The result is an array with two strings - the first
///					is the x coordinate, the second is the y co-ordinate
///
///********************************************************************************************************************

- (NSArray*)				formattedConvertedPoint:(NSPoint) pt
{
	NSMutableArray* array = [NSMutableArray array];
	NSPoint			cpt = [[self gridLayer] gridLocationForPoint:pt];
	NSString*		fmt;
	
	if([[self delegate] respondsToSelector:@selector(drawing:willReturnFormattedCoordinateForDistance:)])
	{
		fmt = [[self delegate] drawing:self willReturnFormattedCoordinateForDistance:cpt.x];
		[array addObject:fmt];
		fmt = [[self delegate] drawing:self willReturnFormattedCoordinateForDistance:cpt.y];
		[array addObject:fmt];
	}
	else
	{
		fmt = [NSString stringWithFormat:@"%.2f %@", cpt.x, [self abbreviatedDrawingUnits]];
		[array addObject:fmt];
		fmt = [NSString stringWithFormat:@"%.2f %@", cpt.y, [self abbreviatedDrawingUnits]];
		[array addObject:fmt];
	}
	
	return array;
}


///*********************************************************************************************************************
///
/// method:			convertPointFromDrawingToBase:
/// scope:			public instance method
/// overrides:
/// description:	convert a point in drawing coordinates to the underlying Quartz coordinates
/// 
/// parameters:		<pt> a point in drawing units
/// result:			the position of the point in Quartz units
///
/// notes:			this is a convenience API to query the drawing's grid layer
///
///********************************************************************************************************************

- (NSPoint)			convertPointFromDrawingToBase:(NSPoint) pt
{
	return [[self gridLayer] pointForGridLocation:pt];
}


///*********************************************************************************************************************
///
/// method:			convertLengthFromDrawingToBase:
/// scope:			public instance method
/// overrides:
/// description:	convert a length in drawing coordinates to the underlying Quartz coordinates
/// 
/// parameters:		<len> a distance in drawing units
/// result:			the distance in Quartz units
///
/// notes:			this is a convenience API to query the drawing's grid layer
///
///********************************************************************************************************************

- (CGFloat)			convertLengthFromDrawingToBase:(CGFloat) len
{
	return [[self gridLayer] quartzDistanceForGridDistance:len];
}



#pragma mark -
#pragma mark - export


///*********************************************************************************************************************
///
/// method:			finalizePriorToSaving
/// scope:			public method
/// overrides:
/// description:	called just prior to an operation that saves the drawing to a file, pasteboard or data.
/// 
/// parameters:		none
/// result:			none
///
/// notes:			can be overridden or you can make use of the notification
///
///********************************************************************************************************************

- (void)			finalizePriorToSaving
{
	[[self undoManager] disableUndoRegistration];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingWillBeSavedOrExported object:self];
	
	// the drawing size is updated/added to the metadata by default here.
	
	NSSize ds = [self drawingSize];
	CGFloat upc = [self unitToPointsConversionFactor];
	
	ds.width /= upc;
	ds.height /= upc;
	
	[self setSize:ds forKey:kDKDrawingInfoDrawingDimensions];
	[self setString:[self drawingUnits] forKey:kDKDrawingInfoDimensionsUnits];
	[self setString:[self abbreviatedDrawingUnits] forKey:kDKDrawingInfoDimensionsShortUnits];
	
	// for compatibility with info file, copy the same information directly to the drawing info as well
	
	[[self drawingInfo] setObject:[self abbreviatedDrawingUnits] forKey:[kDKDrawingInfoDimensionsShortUnits lowercaseString]];
	[[self drawingInfo] setObject:[self drawingUnits] forKey:[kDKDrawingInfoDimensionsUnits lowercaseString]];
	[[self drawingInfo] setObject:[NSString stringWithFormat:@"%f", ds.width] forKey:[[NSString stringWithFormat:@"%@.size_width", kDKDrawingInfoDrawingDimensions] lowercaseString]];
	[[self drawingInfo] setObject:[NSString stringWithFormat:@"%f", ds.height] forKey:[[NSString stringWithFormat:@"%@.size_height", kDKDrawingInfoDrawingDimensions] lowercaseString]];
	
	[[self undoManager] enableUndoRegistration];
}


///*********************************************************************************************************************
///
/// method:			writeToFile:atomically:
/// scope:			public method
/// overrides:
/// description:	saves the entire drawing to a file
/// 
/// parameters:		<filename> the full path of the file 
///					<atom> YES to save to a temporary file and swap (safest), NO to overwrite file
/// result:			YES if succesfully written, NO otherwise
///
/// notes:			implies the binary format
///
///********************************************************************************************************************

- (BOOL)				writeToFile:(NSString*) filename atomically:(BOOL) atom
{
	NSAssert( filename != nil, @"filename was nil");
	NSAssert([filename length] > 0, @"filename was empty");
	
	[[self drawingInfo] setObject:filename forKey:kDKDrawingInfoOriginalFilename];
	return [[self drawingData] writeToFile:filename atomically:atom];
}


///*********************************************************************************************************************
///
/// method:			drawingAsXMLDataAtRoot
/// scope:			public method
/// overrides:
/// description:	returns the entire drawing's data in XML format, having the key "root"
/// 
/// parameters:		none
/// result:			an NSData object which is the entire drawing and all its contents
///
/// notes:			specifies NSPropertyListXMLFormat_v1_0
///
///********************************************************************************************************************

- (NSData*)				drawingAsXMLDataAtRoot
{
	return [self drawingAsXMLDataForKey:@"root"];
}

///*********************************************************************************************************************
///
/// method:			drawingAsXMLDataForKey:
/// scope:			public method
/// overrides:
/// description:	returns the entire drawing's data in XML format, having the key passed
/// 
/// parameters:		<key> a key under which the data is archived
/// result:			an NSData object which is the entire drawing and all its contents
///
/// notes:			specifies NSPropertyListXMLFormat_v1_0
///
///********************************************************************************************************************

- (NSData*)				drawingAsXMLDataForKey:(NSString*) key
{
	NSAssert( key != nil, @"key cannot be nil");
	NSAssert( [key length] > 0, @"key cannot be empty");
	
	NSMutableData*		data = [[NSMutableData alloc] init];
	
	NSAssert( data != nil, @"couldn't create data for archiving");
	
	NSKeyedArchiver*	karch = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
	
	NSAssert( karch != nil, @"couldn't create archiver for archiving with data");

	[karch setOutputFormat:NSPropertyListXMLFormat_v1_0];
	[self finalizePriorToSaving];
	[karch encodeObject:self forKey:key];
	[karch finishEncoding];
	[karch release];
	
	return [data autorelease];
}


///*********************************************************************************************************************
///
/// method:			drawingData
/// scope:			public method
/// overrides:
/// description:	returns the entire drawing's data in binary format
/// 
/// parameters:		none
/// result:			an NSData object which is the entire drawing and all its contents
///
/// notes:			specifies NSPropertyListBinaryFormat_v1_0
///
///********************************************************************************************************************

- (NSData*)				drawingData
{
	[self finalizePriorToSaving];
	return [NSKeyedArchiver archivedDataWithRootObject:self];
}


///*********************************************************************************************************************
///
/// method:			pdf
/// scope:			public method
/// overrides:
/// description:	the entire drawing in PDF format
/// 
/// parameters:		none
/// result:			an NSData object, containing the PDF representation of the entire drawing
///
/// notes:			when rendering a drawing for PDF, the drawing acts as if it were printing, therefore layers that
///					return NO to shouldDrawToPrinter: are not drawn. Selections are also not shown.
///
///********************************************************************************************************************

- (NSData*)				pdf
{
	[self finalizePriorToSaving];
	return [super pdf];
}


///*********************************************************************************************************************
///
/// method:			imageManager
/// scope:			public method
/// overrides:
/// description:	returns the image manager
/// 
/// parameters:		none
/// result:			the drawing's image manager
///
/// notes:			the image manager is an object that is used to improve archiving efficiency of images. Classes
///					that have images, such as DKImageShape, use this to cache image data.
///
///********************************************************************************************************************

- (DKImageDataManager*)		imageManager
{
	return mImageManager;
}


#pragma mark -
#pragma mark As a DKLayerGroup
///*********************************************************************************************************************
///
/// method:			addLayer:
/// scope:			public method
/// overrides:		DKLayerGroup
/// description:	adds a layer to the drawing
/// 
/// parameters:		<aLayer> a DKLayer object, or subclass thereof
/// result:			none
///
/// notes:			the added layer is placed above all other layers. If it is the first layer to be added to the
///					drawing, or the current active layer isn't set, it is also made the active layer (if permitted).
///					For a UI-driven call, it is probably better to use addLayer:andActivateIt: which is smarter.
///
///********************************************************************************************************************

- (void)				addLayer:(DKLayer*) aLayer
{
	NSAssert( aLayer != nil, @"cannot add nil layer");
	
	[super addLayer:aLayer];
	
	if ([self countOfLayers] == 1 || [self activeLayer] == nil)
		[self setActiveLayer:aLayer];
	
	// tell the layer it was added to the root (drawing)
	
	[aLayer drawingHasNewUndoManager:[self undoManager]];
	[aLayer wasAddedToDrawing:self];
}

///*********************************************************************************************************************
///
/// method:			removeLayer:
/// scope:			public method
/// overrides:		DKLayerGroup
/// description:	removes the layer from the drawing
/// 
/// parameters:		<aLayer> a DKLayer object, or subclass thereof, that already exists in the drawing
/// result:			none
///
/// notes:			disposes of the layer if there are no other references to it.
///					For a UI-driven call, it is probably better to use removeLayer:andActivateLayer: which is smarter.
///
///********************************************************************************************************************

- (void)				removeLayer:(DKLayer*) aLayer
{
	NSAssert( aLayer != nil, @"cannot remove nil layer");

	[super removeLayer:aLayer];
	if ( aLayer == [self activeLayer])
		[self setActiveLayer:nil];
}


///*********************************************************************************************************************
///
/// method:			removeAllLayers
/// scope:			public method
/// overrides:		DKLayerGroup
/// description:	removes all of the drawing's layers
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeAllLayers
{
	[super removeAllLayers];
	[self setActiveLayer:nil];
}


///*********************************************************************************************************************
///
/// method:			uniqueLayerNameForName:
/// scope:			public method
/// overrides:		DKLayerGroup
/// description:	disambiguates a layer's name by appending digits until there is no conflict
/// 
/// parameters:		<aName> a string containing the proposed name
/// result:			a string, either the original string or a modified version of it
///
/// notes:			DKLayerGroup's implementation of this only considers layers in the local group. This considers
///					all layers in the drawing as a flattened set, so will disambiguate the layer name for the entire
///					hierarchy.
///
///********************************************************************************************************************

- (NSString*)				uniqueLayerNameForName:(NSString*) aName
{
	NSArray*	existingNames = [[self flattenedLayersIncludingGroups:YES] valueForKey:@"layerName"];
	NSInteger	numeral = 0;
	BOOL		found = YES;
	NSString*	temp = aName;
	
	while( found )
	{
		NSInteger	k = [existingNames indexOfObject:temp];
		
		if ( k == NSNotFound )
			found = NO;
		else
			temp = [NSString stringWithFormat:@"%@ %ld", aName, (long)++numeral];
	}
	
	return temp;
}


#pragma mark -
#pragma mark As a DKLayer
///*********************************************************************************************************************
///
/// method:			drawing
/// scope:			public method
/// overrides:		DKLayer
/// description:	returns the drawing
/// 
/// parameters:		none
/// result:			the drawing, which is self of course
///
/// notes:			because layers locate the drawing by recursing back up through the layer tree, the root (this)
///					must return self.
///
///********************************************************************************************************************

- (DKDrawing*)		drawing
{
	return self;
}


///*********************************************************************************************************************
///
/// method:			drawRect:inView:
/// scope:			public method
/// overrides:		DKLayer
/// description:	renders the drawing in the view
/// 
/// parameters:		<rect> the update rect being drawn - graphics outside this rect can be skipped.
///					<aView> the view that is curremtly rendering the drawing.
/// result:			none
///
/// notes:			called by a DKDrawingView's drawRect: method to update itself.
///
///********************************************************************************************************************

- (void)				drawRect:(NSRect) rect inView:(DKDrawingView*) aView
{
	// save the graphics context on entry so that we can restore it when we return. This allows recovery from an exception
	// that could leave the context stack unbalanced.
	
	NSGraphicsContext* topContext = [[NSGraphicsContext currentContext] retain];
	
	@try
	{
		// paint the paper colour over the view area. Not printed unless explictly set to do so.
		
		if([NSGraphicsContext currentContextDrawingToScreen] || [self paperColourIsPrinted])
		{
			[[self paperColour] set];
			NSRectFillUsingOperation( rect, NSCompositeSourceOver );
		}
		
		// if no layers, nothing to draw
		
		if ([self visible] && [self countOfLayers] > 0 )
		{
			// if not forcing a high quality render, set low quality and start the timer
			
			if ( !m_isForcedHQUpdate )
			{
				[self checkIfLowQualityRequired];
				m_lastRectUpdated = NSUnionRect( m_lastRectUpdated, rect );
			}
			
			if ([self knobsShouldAdjustToViewScale] && aView != nil )
				[[self knobs] setControlKnobSizeForViewScale:[aView scale]];

			// draw all the layer content
			
			if([[self delegate] respondsToSelector:@selector(drawing:willDrawRect:inView:)])
				[[self delegate] drawing:self willDrawRect:rect inView:aView];
			
			[self beginDrawing];
			[super drawRect:rect inView:aView];
			[self endDrawing];

			if([[self delegate] respondsToSelector:@selector(drawing:didDrawRect:inView:)])
				[[self delegate] drawing:self didDrawRect:rect inView:aView];
		}
	}
	@catch(id exc)
	{
		NSLog(@"### DK: An exception occurred while drawing - (%@) - will be ignored ###", exc );
	}
	@finally
	{
		m_isForcedHQUpdate = NO;
	}
	
	[NSGraphicsContext setCurrentContext:topContext];
	[topContext release];
}


///*********************************************************************************************************************
///
/// method:			setNeedsDisplay:
/// scope:			public method
/// overrides:		DKLayer
/// description:	marks the entire drawing as needing updating (or not) for all attached views
/// 
/// parameters:		<refresh> YES to update the entire drawing, NO to stop any updates.
/// result:			none
///
/// notes:			YES causes all attached views to re-render the drawing parts visible in each view
///
///********************************************************************************************************************

- (void)				setNeedsDisplay:(BOOL) refresh
{
	[[self controllers] makeObjectsPerformSelector:@selector(setViewNeedsDisplay:) withObject:[NSNumber numberWithBool:refresh]];
}


///*********************************************************************************************************************
///
/// method:			setNeedsDisplayInRect:
/// scope:			public method
/// overrides:		DKLayer
/// description:	marks the rect as needing update in all attached views
/// 
/// parameters:		<rect> the rectangle within the drawing to update
/// result:			none
///
/// notes:			if <rect> is visible in any attached view, it will be re-rendered by each affected view. Normally
///					objects know when to refresh themselves and do so by indirectly calling this method.
///
///********************************************************************************************************************

- (void)				setNeedsDisplayInRect:(NSRect) rect
{
	[[self controllers] makeObjectsPerformSelector:@selector(setViewNeedsDisplayInRect:) withObject:[NSValue valueWithRect:rect]];
}

///*********************************************************************************************************************
///
/// method:			setNeedsDisplayInRects:
/// scope:			public instance method
///	overrides:		DKLayer
/// description:	marks several areas for update at once
/// 
/// parameters:		<setOfRects> a set containing NSValues with rect values
/// result:			none
///
/// notes:			directly passes the value to the view controller, saving the unpacking and repacking
///
///********************************************************************************************************************

- (void)			setNeedsDisplayInRects:(NSSet*) setOfRects
{
	NSAssert( setOfRects != nil, @"update set was nil");
	
	NSEnumerator*	iter = [setOfRects objectEnumerator];
	NSValue*		val;
	
	while(( val = [iter nextObject]))
		[[self controllers] makeObjectsPerformSelector:@selector(setViewNeedsDisplayInRect:) withObject:val];
}

///*********************************************************************************************************************
///
/// method:			setNeedsDisplayInRects:
/// scope:			public instance method
/// description:	marks several areas for update at once
/// 
/// parameters:		<setOfRects> a set containing NSValues with rect values
///					<padding> the width and height will be added to EACH rect before invalidating
/// result:			none
///
/// notes:			several update optimising methods return sets of rect values, this allows them to be processed
///					directly.
///
///********************************************************************************************************************

- (void)			setNeedsDisplayInRects:(NSSet*) setOfRects withExtraPadding:(NSSize) padding
{
	NSAssert( setOfRects != nil, @"update set was nil");
	
	NSEnumerator*	iter = [setOfRects objectEnumerator];
	NSValue*		val;
	NSRect			ur;
	
	while(( val = [iter nextObject]))
	{
		ur = NSInsetRect([val rectValue], -padding.width, -padding.height);
		[self setNeedsDisplayInRect:ur];
	}
}


///*********************************************************************************************************************
///
/// method:			layerMayBeDeleted
/// scope:			public instance method
/// description:	return whether the layer can be deleted
/// 
/// parameters:		none
/// result:			NO - the root drawing can't be deleted
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			layerMayBeDeleted
{
	return NO;
}


///*********************************************************************************************************************
///
/// method:			updateMetadataKeys
/// scope:			public instance method
/// description:	migrate user info to current schema
/// 
/// parameters:		none
/// result:			none
///
/// notes:			see DKLayer+Metadata for more details. This migrates drawing info to the current schema.
///
///********************************************************************************************************************

- (void)			updateMetadataKeys
{
	if([self drawingInfo] == nil )
	{
		// assumes that all items in userInfo belong to drawing info. This is certainly true for DK implementations prior
		// to 107, since all info values got dumped into the user info as a flat list.
		
		NSMutableDictionary* oldDrawingInfo = [[self userInfo] mutableCopy];
		[[self userInfo] removeAllObjects];
		
		if( oldDrawingInfo )
			[self setDrawingInfo:oldDrawingInfo];
		[oldDrawingInfo release];
	}
}


///*********************************************************************************************************************
///
/// method:			updateRulerMarkersForRect:
/// scope:			public method
/// overrides:
/// description:	updates the ruler markers for all attached views to indicate the rectangle
/// 
/// parameters:		<rect> a rectangle within the drawing (usually the bounds of the selected object(s))
/// result:			none
///
/// notes:			updates all ruler markers in all attached views, if those views have visible rulers
///
///********************************************************************************************************************

- (void)				updateRulerMarkersForRect:(NSRect) rect
{
	[[self controllers] makeObjectsPerformSelector:@selector(updateViewRulerMarkersForRect:) withObject:[NSValue valueWithRect:rect]];
}


///*********************************************************************************************************************
///
/// method:			hideRulerMarkers
/// scope:			public method
/// overrides:
/// description:	hides the ruler markers in all attached views
/// 
/// parameters:		none
/// result:			none
///
/// notes:			ruler markers are generally hidden when there is no selection
///
///********************************************************************************************************************

- (void)				hideRulerMarkers
{
	[[self controllers] makeObjectsPerformSelector:@selector(hideViewRulerMarkers)];
}



#pragma mark -
#pragma mark As an NSObject

- (void)				dealloc
{
	LogEvent_( kLifeEvent, @"deallocating DKDrawing %@", self );
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self setUndoManager:nil];
	[self exitTemporaryTextEditingMode];
	[self removeAllControllers];
	[mControllers release];
	
	m_activeLayerRef = nil;
	mDelegateRef = nil;
	
	if (m_renderQualityTimer != nil)
	{
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


- (id)					init
{
	return [self initWithSize:[DKDrawing isoA2PaperSize:NO]];
}


- (id)					copyWithZone:(NSZone*) zone
{
	// drawings are not copyable but are sometimes used a dict key, so they need to respond to the copying protocol
	#pragma unused(zone)
	
	return self;
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)				encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	// this flag used to detect gross change of architecture in older files
	
	[coder encodeBool:YES forKey:@"hasHierarchicalLayers"];
	
	[super encodeWithCoder:coder];
	
	// note: due to the way image manager clients work, the image manager itself does not need to be archived
	
	[coder encodeSize:[self drawingSize] forKey:@"drawingSize"];
	[coder encodeBool:[self isFlipped] forKey:@"DKDrawing_isFlipped"];
	[coder encodeDouble:[self leftMargin] forKey:@"leftMargin"];
	[coder encodeDouble:[self rightMargin] forKey:@"rightMargin"];
	[coder encodeDouble:[self topMargin] forKey:@"topMargin"];
	[coder encodeDouble:[self bottomMargin] forKey:@"bottomMargin"];
	[coder encodeObject:[self drawingUnits] forKey:@"drawing_units"];
	[coder encodeDouble:[self unitToPointsConversionFactor] forKey:@"utp_conv"];
	[coder encodeObject:[self colourSpace] forKey:@"DKDrawing_colourspace"];
	[coder encodeObject:[self paperColour] forKey:@"papercolour"];
	[coder encodeBool:[self paperColourIsPrinted] forKey:@"DKDrawing_printPaperColour"];
	
	[coder encodeBool:[self snapsToGrid] forKey:@"gridsnap"];
	[coder encodeBool:[self snapsToGuides] forKey:@"guidesnap"];
	[coder encodeBool:[self clipsDrawingToInterior] forKey:@"clips"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	
	LogEvent_(kFileEvent, @"decoding drawing %@", self);
	
	// set drawing units before layers are added so grid layer can use the values
	
	[self setDrawingUnits:[coder decodeObjectForKey:@"drawing_units"] unitToPointsConversionFactor:[coder decodeDoubleForKey:@"utp_conv"]];
	
	// create an image manager - it is not necessary for this object to be archived
	
	mImageManager = [[DKImageDataManager alloc] init];
	
	// if the coder can respond to the -setImageManager: method, set it. This allows certain objects to dearchive images that
	// are held by the image manager even though the object doesn't have a valid reference to the drawing to get it. It can get it from the
	// dearchiver instead.
	
	if([coder respondsToSelector:@selector(setImageManager:)])
		[(DKKeyedUnarchiver*)coder setImageManager:mImageManager];
	
	// older files had a flat layer structure and the drawing didn't inherit from the layer group - this
	// flag detects that and decodes the archive accordingly
	
	BOOL newFileFormat = [coder decodeBoolForKey:@"hasHierarchicalLayers"];
	
	if ( newFileFormat )
		self = [super initWithCoder:coder];
	else
		self = [self init];
		
	if (self != nil)
	{
		if([coder containsValueForKey:@"DKDrawing_isFlipped"])
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
		
		if([self drawingInfo] == nil && [coder containsValueForKey:@"info"])
			[self setDrawingInfo:[coder decodeObjectForKey:@"info"]];
		
		[self setSnapsToGrid:[coder decodeBoolForKey:@"gridsnap"]];
		[self setSnapsToGuides:[coder decodeBoolForKey:@"guidesnap"]];
		[self setClipsDrawingToInterior:[coder decodeBoolForKey:@"clips"]];

		m_lastRenderTime = [NSDate timeIntervalSinceReferenceDate];
		
		// older files handled the knobs differently, so if at this point there are no knobs, Supply a default set
		
		if([self knobs] == nil )
			[self setKnobs:[DKKnob standardKnobs]];
		
		if (m_units == nil 
				|| m_paperColour == nil )
		{
			NSLog(@"drawing failed initialization (%@)", self );
			
			[self autorelease];
			self = nil;
		}
		
		// notify all the contained layers that they were added to the root drawing, allowing them to perform any special
		// set up.
		
		[self wasAddedToDrawing:self];
	}
	if (self != nil)
	{
		if ( ! newFileFormat)
		{
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

- (NSWindow*)			windowForSheet
{
	// attempts to return a window useful for hosting a sheet by referring to its owner. If that doesn't work, it asks each of its controllers.
	
	id owner = [self owner];
	
	if([owner respondsToSelector:_cmd])
		return [owner windowForSheet];
	else if([owner respondsToSelector:@selector(window)])
		return [owner window];
	else
	{
		// roll up sleeves and go through the controllers
		
		NSEnumerator*		iter = [[self controllers] objectEnumerator];
		DKViewController*	cllr;
		
		while(( cllr = [iter nextObject]))
		{
			if([cllr respondsToSelector:_cmd])
				return [(id)cllr windowForSheet];
			else if([[cllr view] respondsToSelector:@selector(window)])
				return [[cllr view] window];
		}
	}
	
	return nil;	// give up
}



@end

