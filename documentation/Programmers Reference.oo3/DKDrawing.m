///**********************************************************************************************************************************
///  DKDrawing.m
///  DrawKit
///
///  Created by graham on 14/08/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
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
#import "DKLineDash.h"
#import "DKObjectDrawingLayer.h"
#import "DKViewController.h"
#import "DKUniqueID.h"
#import "LogEvent.h"

#pragma mark Contants (Non-localized)

NSString*		kDKDrawingActiveLayerWillChange		= @"kGCDrawingActiveLayerWillChange";
NSString*		kDKDrawingActiveLayerDidChange		= @"kGCDrawingActiveLayerDidChange";
NSString*		kDKDrawingWillChangeSize			= @"kGCDrawingWillChangeSize";
NSString*		kDKDrawingDidChangeSize				= @"kGCDrawingDidChangeSize";
NSString*		kDKDrawingUnitsWillChange			= @"kGCDrawingUnitsWillChange";
NSString*		kDKDrawingUnitsDidChange			= @"kGCDrawingUnitsDidChange";
NSString*		kDKDrawingWillChangeMargins			= @"kGCDrawingWillChangeMargins";
NSString*		kDKDrawingDidChangeMargins			= @"kGCDrawingDidChangeMargins";


NSString*		kDKDrawingInfoDrawingNumber			= @"kGCDrawingInfoDrawingNumber";
NSString*		kDKDrawingInfoDrawingRevision		= @"kGCDrawingInfoDrawingRevision";
NSString*		kDKDrawingInfoDraughter				= @"kGCDrawingInfoDraughter";
NSString*		kDKDrawingInfoCreationDate			= @"kGCDrawingInfoCreationDate";
NSString*		kDKDrawingInfoLastModificationDate	= @"kGCDrawingInfoLastModificationDate";
NSString*		kDKDrawingInfoModificationHistory	= @"kGCDrawingInfoModificationHistory";
NSString*		kDKDrawingInfoOriginalFilename		= @"kGCDrawingInfoOriginalFilename";

#pragma mark Static vars

static int sDrawingNumber = 0;


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

+ (int)						drawkitVersion
{
	return 0x0103;
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
	// layer, an info layer, and the view attached. The drawing size is set to the current view bounds size.
	
	NSAssert( aSize.width > 0.0, @"width of drawing size was zero or negative");
	NSAssert( aSize.height > 0.0, @"height of drawing size was zero or negative");
	
	// the defaults chosen here may need to be simplified - in general, would we want a grid, for example?
	
	DKDrawing*	dr = [[self alloc] initWithSize:aSize];		
	[dr setMarginsLeft:5.0 top:5.0 right:5.0 bottom:5.0];	
	
	// attach a grid layer
	[DKGridLayer setGridThemeColour:[[NSColor brownColor] colorWithAlphaComponent:0.5]];
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
/// notes:			
///
///********************************************************************************************************************

+ (DKDrawing*)				drawingWithContentsOfFile:(NSString*) filename
{
	return [self drawingWithData:[NSData dataWithContentsOfMappedFile:filename] fromFileAtPath:filename];
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
	NSKeyedUnarchiver*		unarch = [[NSKeyedUnarchiver alloc] initForReadingWithData:drawingData];
	
	// in order to translate older files with classes named 'GC' instead of 'DK', need a delegate that can handle the
	// translation. 
	
	DKUnarchivingHelper* uaDelegate = [[DKUnarchivingHelper alloc] init];
	[unarch setDelegate:uaDelegate];
	
	LogEvent_(kReactiveEvent, @"decoding drawing root object......");
	
	DKDrawing* dwg = [unarch decodeObjectForKey:@"root"];
	
	[unarch finishDecoding];
	[unarch release];
	[uaDelegate release];
	
	return dwg;
}


//! Creates a drawing from a data object and inserts the original filename as metadata.

//! Unarchives the data, and returns the unarchived drawing object
//! \param drawingData a NSData object containing a complete archive of a drawing
//! \param filepath the original filepath, which is added to the drawing's metadata

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
/// notes:			
///
///********************************************************************************************************************

+ (DKDrawing*)				drawingWithData:(NSData*) drawingData fromFileAtPath:(NSString*) filepath
{
	DKDrawing*	dwg = [self drawingWithData:drawingData];
	
	// insert the filename into the drawing metadata
	
	[[dwg drawingInfo] setObject:[filepath lastPathComponent] forKey:kDKDrawingInfoOriginalFilename];

	return dwg;
}


#pragma mark -
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
	if( sDrawingNumber == 0 )
		sDrawingNumber = [[NSUserDefaults standardUserDefaults] integerForKey:@"DKDrawing_drawingNumberSeedValue"];
	
	NSMutableDictionary*	di = [[NSMutableDictionary alloc] init];
	
	[di setObject:[NSString stringWithFormat:@"A2-%06d-0001", ++sDrawingNumber] forKey:kDKDrawingInfoDrawingNumber];
	[di setObject:@"A" forKey:kDKDrawingInfoDrawingRevision];
	[di setObject:[NSFullUserName() capitalizedString] forKey:kDKDrawingInfoDraughter];
	[di setObject:[NSDate date] forKey:kDKDrawingInfoCreationDate];
	[di setObject:[NSDate date] forKey:kDKDrawingInfoLastModificationDate];

	return [di autorelease];
}




#pragma mark -
///*********************************************************************************************************************
///
/// method:			saveDefaults
/// scope:			public class method
/// description:	saves the static class defaults for ALL classes in the drawing system
/// 
/// parameters:		none
/// result:			none
///
/// notes:			you need to arrange your application delegate to call this at application terminate time. It will
///					save the defaults for all classes in the system.
///
///********************************************************************************************************************

+ (void)				saveDefaults
{
	// saves the class defaults in the user defaults.
	
	[[NSUserDefaults standardUserDefaults] setInteger:sDrawingNumber forKey:@"DKDrawing_drawingNumberSeedValue"];
	[DKStyleRegistry saveDefaults];
	[DKLineDash saveDefaults];
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
/// notes:			you need to arrange your application delegate to call this at application startup time
///
///********************************************************************************************************************

+ (void)				loadDefaults
{
	// loads the class defaults from the user defaults.
	
	[DKDrawingTool registerStandardTools];
	[DKLineDash loadDefaults];
	[DKStyleRegistry loadDefaults];
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
		mUniqueKey = [[DKUniqueID uniqueKey] retain];
		[self setFlipped:YES];
		[self setDrawingSize:size];
		float m = 25.0;
		[self setMarginsLeft:m top:m right:m bottom:m];
		[self setDrawingUnits:@"Centimetres" unitToPointsConversionFactor:kGCGridDrawingLayerMetricInterval];
		
		NSAssert(m_activeRef == nil, @"Expected init to zero");
		mControllers = [[NSMutableSet alloc] init];

		[self setKnobs:[DKKnob standardKnobs]];
		[self setPaperColour:[NSColor whiteColor]];
		NSAssert(m_undoManager == nil, @"Expected init to zero");
		[self setDrawingInfo:[[self class] defaultDrawingInfo]];
		
		m_snapsToGrid = YES;
		m_snapsToGuides = YES;
		NSAssert(!m_clipToInterior, @"Expected init to NO");
		[self setKnobsShouldAdustToViewScale:YES];
		NSAssert(!m_useQandDRendering, @"Expected init to NO");
		NSAssert(!m_isForcedHQUpdate, @"Expected init to NO");
		
		NSAssert(m_renderQualityTimer == nil, @"Expected init to zero");
		m_lastRenderTime = [NSDate timeIntervalSinceReferenceDate];
		NSAssert(NSEqualRects(m_lastRectUpdated, NSZeroRect), @"Expected init to zero");
		
		[self setDynamicQualityModulationEnabled:NO];
		[self setLowQualityTriggerInterval:0.2];
		
		if (m_units == nil 
				|| m_knobs == nil 
				|| m_paperColour == nil 
				|| m_meta == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
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
	if (! NSEqualSizes( aSize, m_size ))
	{
		LogEvent_(kReactiveEvent, @"setting drawing size = {%f, %f}", aSize.width, aSize.height);
		
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingWillChangeSize object:self];
		m_size = aSize;
		
		// adjust bounds of every view to match

		[[self controllers] makeObjectsPerformSelector:@selector( drawingDidChangeToSize:) withObject:[NSValue valueWithSize:aSize]];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingDidChangeSize object:self];
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
//	LogEvent_(kReactiveEvent, @"print info = %@", printInfo);
	
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

- (void)				setMarginsLeft:(float) l top:(float) t right:(float) r bottom:(float) b
{
//	LogEvent_(kReactiveEvent, @"setting margins = {%f, %f, %f, %f}", l, t, r, b);
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingWillChangeMargins object:self];
	
	m_leftMargin = l;
	m_rightMargin = r;
	m_topMargin = t;
	m_bottomMargin = b;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingDidChangeMargins object:self];
	[self setNeedsDisplay:YES];
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

- (float)				leftMargin
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

- (float)				rightMargin
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

- (float)				topMargin
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

- (float)				bottomMargin
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

- (void)				setDrawingUnits:(NSString*) units unitToPointsConversionFactor:(float) conversionFactor
{
	NSAssert( units != nil, @"cannot set drawing units to nil");
	NSAssert([units length] > 0, @"units string is empty"); 
	
	if ( conversionFactor != 0.0 )
	{
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
///					and makes them lower case.
///
///********************************************************************************************************************

- (NSString*)			abbreviatedDrawingUnits
{
	static NSDictionary*	abbrevs = nil;
	
	if ( abbrevs == nil )
	{
		abbrevs = [[NSDictionary dictionaryWithObjectsAndKeys:  @"\"", @"inches",
																@"mm", @"millimetres",
																@"cm", @"centimetres",
																@"m", @"metres",
																@"km", @"kilometres",
																@"pc", @"picas",
																@"px", @"pixels",
																@"\'", @"feet",
																@"pt", @"points",
																@"mi", @"miles", nil] retain];
	}

	NSString* abbr = [abbrevs objectForKey:[[self drawingUnits] lowercaseString]];
	
	if ( abbr == nil )
	{
		// make up an abbreviation using the first two characters
		
		abbr = [[[self drawingUnits] lowercaseString] substringWithRange:NSMakeRange(0, 2)];
	}
	
	return abbr;
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

- (float)				unitToPointsConversionFactor
{
	return m_unitConversionFactor;
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

- (NSSet*)					controllers
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

- (void)					addController:(DKViewController*) aController
{
	NSAssert( aController != nil, @"cannot add a nil controller to drawing");
	
	if(![aController isKindOfClass:[DKViewController class]])
		[NSException raise:NSInternalInconsistencyException format:@"attempt to add an invalid object as a controller"];
	
	// synch. the rulers here in case we got this far without any sort of view infrastructure in place - this can
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

- (void)					removeController:(DKViewController*) aController
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
	[[self controllers] makeObjectsPerformSelector:@selector(invalidateCursors)];
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
/// notes:			called for things like scroll to selection - all attached views may scroll if necessary
///
///********************************************************************************************************************

- (void)				scrollToRect:(NSRect) rect
{
	// scrolls all attached views to show the rect.
	
	[[self controllers] makeObjectsPerformSelector:@selector(scrollViewToRect:) withObject:[NSValue valueWithRect:rect]];
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
	// updates all attached views to set their ruler markers to the rect.
	
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
	[[self controllers] makeObjectsPerformSelector:@selector(objectDidNotifyStatusChange:) withObject:object];
}


///*********************************************************************************************************************
///
/// method:			uniqueKey
/// scope:			public method
/// overrides:
/// description:	returna string that can be used as a unique key for this drawing
/// 
/// parameters:		none
/// result:			a string
///
/// notes:			this is used by DKToolController to associate a tool with the drawing without the drawing itself
///					needing to know about tools. Do not interpret this value.
///
///********************************************************************************************************************

- (NSString*)			uniqueKey
{
	return mUniqueKey;
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

- (void)				setUndoManager:(NSUndoManager*) um
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

- (NSUndoManager*)		undoManager
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
///					interpreted by a DKDrawingInfoLayer, if there is one.
///
///********************************************************************************************************************

- (void)				setDrawingInfo:(NSMutableDictionary*) info
{
	[info retain];
	[m_meta release];
	m_meta = info;
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
	return m_meta;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setClipsDrawingToInterior:
/// scope:			public method
/// overrides:
/// description:	sets whether drawing is limited to the interior area or not
/// 
/// parameters:		<clip> YES to limit drawing to the interior, NO to allow drawing to be visible in the margins.
/// result:			none
///
/// notes:			default is NO, so drawings show in the margins. This allows individual layers to add content within
///					the margin area if necessary, but means that they'll have to perform clipping themselves if they
///					require it.
///
///********************************************************************************************************************

- (void)				setClipsDrawingToInterior:(BOOL) clip
{
	if ( clip != m_clipToInterior )
	{
		m_clipToInterior = clip;
		[self setNeedsDisplay:YES];
	}
}


///*********************************************************************************************************************
///
/// method:			clipsDrawingToInterior
/// scope:			public method
/// overrides:
/// description:	whether the drawing will be clipped to the interior or not
/// 
/// parameters:		none
/// result:			YES if clipping, NO if not.
///
/// notes:			default is NO.
///
///********************************************************************************************************************

- (BOOL)				clipsDrawingToInterior
{
	return m_clipToInterior;
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
	[colour retain];
	[m_paperColour release];
	m_paperColour = colour;
	[self setNeedsDisplay:YES];
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
	[[self controllers] makeObjectsPerformSelector:@selector(exitTemporaryTextEditingMode)];
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

- (BOOL)			setActiveLayer:(DKLayer*) aLayer withUndo:(BOOL) undo;
{
	// we already own this, so don't retain it
	
	if ( aLayer != m_activeRef && [aLayer layerMayBecomeActive] && ![self locked])
	{
		if( undo )
			[[[self undoManager] prepareWithInvocationTarget:self] setActiveLayer:m_activeRef withUndo:YES];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingActiveLayerWillChange object:self];
		[[self controllers] makeObjectsPerformSelector:@selector(activeLayerWillChangeToLayer:) withObject:aLayer];
		
		[m_activeRef layerDidResignActiveLayer];
		m_activeRef = aLayer;
		[m_activeRef layerDidBecomeActiveLayer];
		[self invalidateCursors];

		[[self controllers] makeObjectsPerformSelector:@selector(activeLayerDidChangeToLayer:) withObject:aLayer];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawingActiveLayerDidChange object:self];
		
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
	return m_activeRef;
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
	
	NSString* layerName = [self uniqueLayerNameForName:[aLayer name]];
	[aLayer setName:layerName];

	[super addLayer:aLayer];

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
	
	[self setActiveLayer:anotherLayer withUndo:YES];
	[aLayer release];
}


///*********************************************************************************************************************
///
/// method:			uniqueLayerNameForName:
/// scope:			public method
/// overrides:
/// description:	disambiguates a layer's name by appending digits until there is no conflict
/// 
/// parameters:		<aName> a string containing the proposed name
/// result:			a string, either the original string or a modified version of it
///
/// notes:			it is not important that layer's have unique names, but a UI will usually want to do this, thus
///					when using the addLayer:andActivateIt: method, the name of the added layer is disambiguated.
///
///********************************************************************************************************************

- (NSString*)			uniqueLayerNameForName:(NSString*) aName
{
	int			numeral = 0;
	BOOL		found = YES;
	NSString*	temp = aName;
	NSArray*	keys = [[self layers] valueForKey:@"name"];
	
	while( found )
	{
		int	k = [keys indexOfObject:temp];
		
		if ( k == NSNotFound )
			found = NO;
		else
			temp = [NSString stringWithFormat:@"%@ %d", aName, ++numeral];
	}
	
	return temp;
}


#pragma mark -
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
		return [grid divisionDistance];
	else
		return NSMakePoint( 1.0, 1.0 );
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			gridLayer
/// scope:			public method
/// overrides:
/// description:	returns the grid layer, if there is one
/// 
/// parameters:		none
/// result:			the grid layer, or nil
///
/// notes:			Usually there will only be one grid, but if there is more than one this only finds the uppermost.
///
///********************************************************************************************************************

- (DKGridLayer*)	gridLayer
{
	return (DKGridLayer*)[self firstLayerOfClass:[DKGridLayer class]];
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
	return (DKGuideLayer*)[self firstLayerOfClass:[DKGuideLayer class]];
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
/// notes:			this is a convenience API to query the drawing's grid layer
///
///********************************************************************************************************************

- (float)			convertLength:(float) len
{
	return [[self gridLayer] gridDistanceForQuartzDistance:len];
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
/// notes:			this is a convenience API to query the drawing's grid layer
///
///********************************************************************************************************************

- (NSPoint)			convertPoint:(NSPoint) pt
{
	return [[self gridLayer] gridLocationForPoint:pt];
}	


#pragma mark -
#pragma mark - export
///*********************************************************************************************************************
///
/// method:			writeToFile:atomically:
/// scope:			public method
/// overrides:
/// description:	saves the entire drawing to a file
/// 
/// parameters:		<filename> the full path of the file 
///					<atom> YES to save to a temporary file and swap (safest), NO to overwrite file
/// result:			none
///
/// notes:			implies the binary format
///
///********************************************************************************************************************

- (void)				writeToFile:(NSString*) filename atomically:(BOOL) atom
{
	[[self drawingData] writeToFile:filename atomically:atom];
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
	NSRect	br = NSZeroRect;
	br.size = [self drawingSize];
	
	DKDrawingView*		view = [[DKDrawingView alloc] initWithFrame:br];
	DKViewController*	vc = [view makeViewController];
	
	[self addController:vc];
	
	NSData* data = [view dataWithPDFInsideRect:br];
	[view release];
	
	return data;
}


///*********************************************************************************************************************
///
/// method:			writePDFDataToPasteboard:
/// scope:			public method
/// overrides:
/// description:	copies the entire drawing as a PDF to the nominated pasteboard
/// 
/// parameters:		<pb> the pastebaord to write to
/// result:			none
///
/// notes:			see pdf
///
///********************************************************************************************************************

- (void)				writePDFDataToPasteboard:(NSPasteboard*) pb
{
	[pb declareTypes:[NSArray arrayWithObject:NSPDFPboardType] owner:self];
	[pb setData:[self pdf] forType:NSPDFPboardType];
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
	[super addLayer:aLayer];
	if ([self countOfLayers] == 1 || [self activeLayer] == nil)
		[self setActiveLayer:aLayer];
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
	// paint the paper colour over the view area - ignored when printing, when it is assumed
	// the the paper itself supplies the colour.
	
	if([NSGraphicsContext currentContextDrawingToScreen])
	{
		[[self paperColour] set];
		NSRectFill( rect );
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
		
		m_eventViewRef = (NSView*)aView;

		if ([self knobsShouldAdjustToViewScale] && aView != nil )
			[[self knobs] setControlKnobSizeForViewScale:[aView scale]];

		// if clipping to the interior, set up that clip now
		
		if ([self clipsDrawingToInterior])
			[NSBezierPath clipRect:[self interior]];
		
		// draw all the layer content
		
		[super drawRect:rect inView:aView];

		m_eventViewRef = nil;
		m_isForcedHQUpdate = NO;
	}
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


#pragma mark -
#pragma mark As an NSObject

- (void)				dealloc
{
//	LogEvent_(kReactiveEvent, @"dealloc - DKDrawing");

	[self setUndoManager:nil];

	[self exitTemporaryTextEditingMode];
	[self removeAllControllers];
	[mControllers release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	if (m_renderQualityTimer != nil)
	{
		[m_renderQualityTimer invalidate];
		[m_renderQualityTimer release];
		m_renderQualityTimer = nil;
	}
	
	[m_meta release];
	[m_paperColour release];

	m_activeRef = nil;
	
	[m_units release];
	[mUniqueKey release];
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
	
	[coder encodeSize:[self drawingSize] forKey:@"drawingSize"];
	[coder encodeBool:[self isFlipped] forKey:@"DKDrawing_isFlipped"];
	[coder encodeFloat:[self leftMargin] forKey:@"leftMargin"];
	[coder encodeFloat:[self rightMargin] forKey:@"rightMargin"];
	[coder encodeFloat:[self topMargin] forKey:@"topMargin"];
	[coder encodeFloat:[self bottomMargin] forKey:@"bottomMargin"];
	[coder encodeObject:[self drawingUnits] forKey:@"drawing_units"];
	[coder encodeFloat:[self unitToPointsConversionFactor] forKey:@"utp_conv"];
	
	[coder encodeObject:[self paperColour] forKey:@"papercolour"];
	[coder encodeObject:[self drawingInfo] forKey:@"info"];
	
	[coder encodeBool:[self snapsToGrid] forKey:@"gridsnap"];
	[coder encodeBool:[self snapsToGuides] forKey:@"guidesnap"];
	[coder encodeBool:[self clipsDrawingToInterior] forKey:@"clips"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	
	mUniqueKey = [[DKUniqueID uniqueKey] retain];
	
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
		m_leftMargin = [coder decodeFloatForKey:@"leftMargin"];
		m_rightMargin = [coder decodeFloatForKey:@"rightMargin"];
		m_topMargin = [coder decodeFloatForKey:@"topMargin"];
		m_bottomMargin = [coder decodeFloatForKey:@"bottomMargin"];
		[self setDrawingUnits:[coder decodeObjectForKey:@"drawing_units"] unitToPointsConversionFactor:[coder decodeFloatForKey:@"utp_conv"]];
		
		NSAssert(m_activeRef == nil, @"Expected init to zero");
		mControllers = [[NSMutableSet alloc] init];

		[self setKnobs:[DKKnob standardKnobs]];
		[self setPaperColour:[coder decodeObjectForKey:@"papercolour"]];
		[self setDrawingInfo:[coder decodeObjectForKey:@"info"]];
		
		[self setSnapsToGrid:[coder decodeBoolForKey:@"gridsnap"]];
		[self setSnapsToGuides:[coder decodeBoolForKey:@"guidesnap"]];
		[self setClipsDrawingToInterior:[coder decodeBoolForKey:@"clips"]];
		[self setKnobsShouldAdustToViewScale:YES];
		NSAssert(!m_useQandDRendering, @"Expected init to NO");
		
		NSAssert(m_renderQualityTimer == nil, @"Expected init to zero");
		m_lastRenderTime = [NSDate timeIntervalSinceReferenceDate];
		
		if (m_units == nil 
				|| m_knobs == nil 
				|| m_paperColour == nil 
				|| m_meta == nil)
		{
			[self autorelease];
			self = nil;
		}
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
#pragma mark DKUnarchivingHelper

@implementation DKUnarchivingHelper

- (Class)	unarchiver:(NSKeyedUnarchiver*) unarchiver cannotDecodeObjectOfClassName:(NSString*) name originalClasses:(NSArray*) classNames
{
	#pragma unused(unarchiver)
	#pragma unused(classNames)
	
	// check the first two letters - if it's 'GC' try substituting this with 'DK' and see if that works - many classnames were changed
	// in this way
	
	NSString*	newclass;
	NSString*	ss = [name substringWithRange:NSMakeRange( 0, 2 )];

	if ([ss isEqualToString:@"GC"])
		newclass = [NSString stringWithFormat:@"DK%@", [name substringWithRange:NSMakeRange( 2, [name length] - 2)]];
	else
		newclass = name;

	// other class name changes - just check and substitute them individually
	
	if ([newclass isEqualToString:@"DKDrawingLayer"])
		newclass = @"DKLayer";
	else if ([newclass isEqualToString:@"DKDrawingStyle"])
		newclass = @"DKStyle";
	else if ([newclass isEqualToString:@"DKGridDrawingLayer"])
		newclass = @"DKGridLayer";
	else if ([newclass isEqualToString:@"DKRenderer"])
		newclass = @"DKRasterizer";
	else if ([newclass isEqualToString:@"DKDrawableShapeWithReshape"])
		newclass = @"DKReshapableShape";
	else if ([newclass isEqualToString:@"DKRendererGroup"])
		newclass = @"DKRastGroup";
	else if ([newclass isEqualToString:@"DKEffectRenderGroup"])
		newclass = @"DKCIFilterRastGroup";
	else if ([newclass isEqualToString:@"DKBlendRenderGroup"])
		newclass = @"DKQuartzBlendRastGroup";
	else if ([newclass isEqualToString:@"DKImageRenderer"])
		newclass = @"DKImageAdornment";
	else if ([newclass isEqualToString:@"DKTextLabelRenderer"])
		newclass = @"DKTextAdornment";
	else if ([newclass isEqualToString:@"DKObjectDrawingToolLayer"])	// obsolete class - just convert to plain drawing layer
		newclass = @"DKObjectDrawingLayer";
		
	++mChangeCount;

	LogEvent_(kInfoEvent, @"substituting class '%@' for '%@'", newclass, name );
		
	return NSClassFromString(newclass);
}


- (unsigned)  changeCount
{
	return mChangeCount;
}


@end
