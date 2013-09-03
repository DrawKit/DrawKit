///**********************************************************************************************************************************
///  DKArrowStroke.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 20/03/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKArrowStroke.h"
#import "DKStyle.h"
#import "DKDrawablePath.h"
#import "DKStrokeDash.h"
#import "NSBezierPath+Geometry.h"
#import "NSBezierPath+Text.h"
#import "NSBezierPath+Editing.h"
#import "DKShapeFactory.h"
#import "NSShadow+Scaling.h"

#pragma mark Static Vars
static NSMutableDictionary*	sDimLinesAttributes = nil;

NSString*				kDKPositiveToleranceKey		= @"DKPositiveTolerance";
NSString*				kDKNegativeToleranceKey		= @"DKNegativeTolerance";
NSString*				kDKDimensionValueKey		= @"DKDimensionValue";
NSString*				kDKDimensionUnitsKey		= @"DKDimensionUnits";

#pragma mark -
@implementation DKArrowStroke
#pragma mark As a DKArrowStroke
+ (void)			setDimensioningLineTextAttributes:(NSDictionary*) attrs
{
	NSMutableDictionary* temp = [attrs mutableCopy];
	[sDimLinesAttributes release];
	sDimLinesAttributes = temp;
}


+ (NSDictionary*)	dimensioningLineTextAttributes
{
	if ( sDimLinesAttributes == nil )
	{
		// set default dimensioning lines attributes
		
		sDimLinesAttributes = [[NSMutableDictionary alloc] init];
		
		[sDimLinesAttributes setObject:[NSFont fontWithName:@"Helvetica Bold" size:8] forKey:NSFontAttributeName];
		[sDimLinesAttributes setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
		
		NSMutableParagraphStyle* ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		
		[ps setAlignment:NSCenterTextAlignment];
		[sDimLinesAttributes setObject:ps forKey:NSParagraphStyleAttributeName];
		[ps release];
	}
	
	return sDimLinesAttributes;
}


+ (DKArrowStroke*)	standardDimensioningLine
{
	static DKArrowStroke*	dml = nil;
	
	if ( dml == nil )
	{
		dml = [[DKArrowStroke alloc] init];
		
		[dml setDimensioningLineOptions:kDKDimensionPlaceAboveLine];
		[dml setArrowHeadAtStart:kDKArrowHeadDimensionLine];
		[dml setArrowHeadAtEnd:kDKArrowHeadDimensionLine];
		[dml setWidth:1.0];
		[dml setArrowHeadLength:12];
		[dml setArrowHeadWidth:7];
	}
	
	return dml;
}


+ (NSNumberFormatter*)	defaultDimensionLineFormatter
{
	// returns a default formatter for formatting a dimensioning line. The default sets a format with 2 decimal places and the dimensioning line
	// text attributes. This is set as the formatter when dimensioning is enabled for the rasterizer.
	
	NSNumberFormatter* fmt = [[NSNumberFormatter alloc] init];
	
	[fmt setNumberStyle:NSNumberFormatterDecimalStyle];
	[fmt setMaximumFractionDigits:2];
	[fmt setMinimumFractionDigits:2];
	[fmt setNilSymbol:@"--"];
	[fmt setNotANumberSymbol:@"-"];
	[fmt setZeroSymbol:@"0"];
	
	NSDictionary* attrs = [[self dimensioningLineTextAttributes] copy];
	[fmt setTextAttributesForPositiveValues:attrs];
	[fmt setTextAttributesForNegativeValues:attrs];
	[fmt setTextAttributesForZero:attrs];
	[attrs release];
	
	return [fmt autorelease];
	
}


#pragma mark -
- (void)				setArrowHeadAtStart:(DKArrowHeadKind) sa
{
	mArrowHeadAtStart = sa;
}


- (void)				setArrowHeadAtEnd:(DKArrowHeadKind) se
{
	mArrowHeadAtEnd = se;
}


- (DKArrowHeadKind)		arrowHeadAtStart
{
	return mArrowHeadAtStart;
}


- (DKArrowHeadKind)		arrowHeadAtEnd
{
	return mArrowHeadAtEnd;
}


#pragma mark -

- (void)				setArrowHeadWidth:(CGFloat) width
{
	m_arrowWidth = width;
}


- (CGFloat)				arrowHeadWidth
{
	return m_arrowWidth;
}



- (void)				setArrowHeadLength:(CGFloat) length
{
	m_arrowLength = length;
}


- (CGFloat)				arrowHeadLength
{
	return m_arrowLength;
}


#pragma mark -
- (void)				standardArrowForStrokeWidth:(CGFloat) sw
{
	// compute suitable arrow head length and width from the stroke width - the formula
	// here is intended to allow arrows to "look right" and in proportion when the stroke width is changed.
	
	CGFloat w = (( sw - 1.5 ) * 0.4 ) + 1.5;
	
	[self setArrowHeadWidth:w * 6];
	[self setArrowHeadLength:MAX( 10, w * 6)];
}


#ifdef DRAWKIT_DEPRECATED
- (void)				setOutlineColour:(NSColor*) colour width:(CGFloat) width
{
	[colour retain];
	[m_outlineColour release];
	m_outlineColour = colour;
	m_outlineWidth = width;
}
#endif


- (void)				setOutlineColour:(NSColor*) colour
{
	[colour retain];
	[m_outlineColour release];
	m_outlineColour = colour;
}


- (NSColor*)			outlineColour
{
	return m_outlineColour;
}


- (void)				setOutlineWidth:(CGFloat) width
{
	m_outlineWidth = width;
}


- (CGFloat)				outlineWidth
{
	return m_outlineWidth;
}


#pragma mark -
- (NSImage*)			arrowSwatchImageWithSize:(NSSize) size strokeWidth:(CGFloat) width
{
	NSImage*		image = [[NSImage alloc] initWithSize:size];
	NSBezierPath*	path;
	NSPoint			a, b;
	NSSize			extra = [self extraSpaceNeeded];
	
	a.x = extra.width;
	b.x = size.width - extra.width;
	a.y = b.y = size.height / 2.0;
	
	path = [NSBezierPath bezierPath];
	[path moveToPoint:a];
	[path lineToPoint:b];
	
	CGFloat saved = [self width];
	m_width = width;	// do not use [self setWidth:] as KVO can cause an infinite loop here
	
	DKDrawablePath* temp = [DKDrawablePath drawablePathWithBezierPath:path];
	
	[image setFlipped:YES];
	// draw into image
	
	[image lockFocus];
	[self render:temp];
	[image unlockFocus];
	m_width = saved;
	
	return [image autorelease];
}


- (NSImage*)			standardArrowSwatchImage
{
	return [self arrowSwatchImageWithSize:kDKStandardArrowSwatchImageSize strokeWidth:kDKStandardArrowSwatchStrokeWidth];
}


#pragma mark -

- (CGFloat)				trimLengthForKind:(DKArrowHeadKind) kind
{
	CGFloat trim = [self arrowHeadLength] * 0.9;

	switch( kind )
	{
		default:
			break;
			
		case kDKArrowHeadNone:
		case kDKArrowHeadRound:
		case kDKArrowHeadSquare:
		case kDKArrowHeadDiamond:
			trim = 0.0;
			break;
			
		case kDKArrowHeadInflected:
			trim = [self arrowHeadLength] * 0.67;
			break;
			
		case kDKArrowHeadSingleFeather:
		case kDKArrowHeadDoubleFeather:
		case kDKArrowHeadTripleFeather:
			trim = [self arrowHeadLength] * 0.1;
			break;
	}
	
	return trim;
}


- (NSBezierPath*)		arrowHeadElementForKind:(DKArrowHeadKind) kind
{
	// returns the arrow head for the given kind in the unit rect centered at the origin - it must be scaled, rotated
	// and translated to the right place on the path.
	
	NSBezierPath* path = nil;
	
	switch( kind )
	{
		default:
		case kDKArrowHeadNone:
			break;
			
		case kDKArrowHeadDimensionLine:
		case kDKArrowHeadStandard:
			path = [DKShapeFactory arrowhead];
			break;
			
		case kDKArrowHeadInflected:
			path = [DKShapeFactory inflectedArrowhead];
			break;

		case kDKArrowHeadRound:
			return [[DKShapeFactory oval] bezierPathByReversingPath];
			
		case kDKArrowHeadSingleFeather:
			return [[DKShapeFactory arrowTailFeatherWithRake:0.6] bezierPathByReversingPath];

		case kDKArrowHeadDoubleFeather:
			return [[DKShapeFactory arrowTailFeatherWithRake:0.71] bezierPathByReversingPath];

		case kDKArrowHeadTripleFeather:
			return [[DKShapeFactory arrowTailFeatherWithRake:1] bezierPathByReversingPath];
			
		case kDKArrowHeadDimensionLineAndBar:
			path = [DKShapeFactory arrowhead];
			[path appendBezierPathWithRect:NSMakeRect( -0.5, -0.5, 0.025, 1.0 )];
			break;
			
		case kDKArrowHeadSquare:
			return [[DKShapeFactory rect] bezierPathByReversingPath];
			break;
			
		case kDKArrowHeadDiamond:
			return [[DKShapeFactory regularPolygon:4] bezierPathByReversingPath];
	}
	
	// the paths are all centred on the origin. More usefully the origin should be at the point or other place
	// where the real path terminates, so offset the result by half a unit to the right
	
	NSAffineTransform* tsl = [NSAffineTransform transform];
	[tsl translateXBy:0.5 yBy:0];
	[path transformUsingAffineTransform:tsl];
	
	return [path bezierPathByReversingPath];
}


- (NSBezierPath*)		arrowHeadForPath:(NSBezierPath*) path ofKind:(DKArrowHeadKind) kind orientation:(BOOL) flip multiple:(NSInteger) n
{
	// this method returns the arrow head element indicated by the parameters
	
	NSAssert( path != nil, @"can't make arrow heads for a nil path");
	
	if ( kind == kDKArrowHeadStandard ||
		 kind == kDKArrowHeadDimensionLine ||
		 kind == kDKArrowHeadDimensionLineAndBar)
	{
		// this arrowhead is curved to match the actual curvature of the path at the place where the arrow heads will go
		// angle in degrees is half the atan(y/x)
		
		CGFloat	degrees = (atan2f([self arrowHeadWidth], [self arrowHeadLength]) * 90.0 ) / pi;
		CGFloat	hyp = hypotf([self arrowHeadWidth], [self arrowHeadLength]);
		
		NSBezierPath* headPath;
		
		if ( flip )
			headPath = [path bezierPathWithArrowHeadForEndOfLength:hyp angle:degrees closingPath:YES];
		else
			headPath = [path bezierPathWithArrowHeadForStartOfLength:hyp angle:degrees closingPath:YES];
			
		if ( kind == kDKArrowHeadDimensionLineAndBar )
		{
			// add the bar
			
			NSBezierPath* barPath = [NSBezierPath bezierPathWithRect:NSMakeRect( -0.25f, [self arrowHeadWidth] * -0.75f, 0.5f, [self arrowHeadWidth] * 1.5)];
			
			CGFloat		slope;
			NSPoint		ep;
			
			if( flip )
				ep = [path pointOnPathAtLength:[path length] slope:&slope];
			else
				ep = [path pointOnPathAtLength:0.0 slope:&slope];
				
			NSAffineTransform* tfm = [NSAffineTransform transform];
			[tfm translateXBy:ep.x yBy:ep.y];
			[tfm rotateByRadians:slope];
			
			[barPath transformUsingAffineTransform:tfm];
			[headPath appendBezierPath:barPath];
		}
		
		return headPath;
	}
	else
	{
		// set up the number of parts to make for feathers:
		
		CGFloat featherScaleFactor = 1.0;
		CGFloat featherSpacingFactor = 1.05;
		
		switch( kind )
		{
			default:
				n = 1;
				break;
				
			case kDKArrowHeadDoubleFeather:
				n = 2;
				featherScaleFactor = 0.9;
				featherSpacingFactor = 0.75;
				break;
				
			case kDKArrowHeadTripleFeather:
				n = 3;
				featherScaleFactor = 0.8;
				featherSpacingFactor = 0.6;
				break;
		}
		
		NSBezierPath*	arrow = [NSBezierPath bezierPath];
		NSInteger				i;
		
		for( i = 0; i < n; ++i )
		{
			NSBezierPath* head = [self arrowHeadElementForKind:kind];
			
			if ( head != nil )
			{
				// transform it to the end point of the path, scaled to the current head length, rotated to the path angle
				
				CGFloat	pathLength;
				CGFloat	adjustment;
				CGFloat	slope;
				
				pathLength = flip? [path length] : 0.0;
				
				// adjustment is the amount of offset applied from the end of the path according to the multiple factor n
				
				adjustment = i * [self arrowHeadLength] * featherScaleFactor * featherSpacingFactor;
				
				if ( flip )
					pathLength -= adjustment;
				else
					pathLength += adjustment;
					
				// get the path point and slope at this position along the path
				
				NSPoint sp = [path pointOnPathAtLength:pathLength slope:&slope];
				
				// flipped heads point the other way
				
				if ( flip )
					slope += pi;
				
				NSAffineTransform* scl = [NSAffineTransform transform];
				
				switch( kind )
				{
					case kDKArrowHeadRound:
						[scl scaleXBy:[self arrowHeadWidth] yBy:[self arrowHeadWidth]];
						break;
						
					case kDKArrowHeadDoubleFeather:
						[scl scaleXBy:[self arrowHeadLength] * featherScaleFactor yBy:[self arrowHeadWidth]];
						break;
					
					case kDKArrowHeadTripleFeather:
						[scl scaleXBy:[self arrowHeadLength] * featherScaleFactor yBy:[self arrowHeadWidth]];
						break;

					default:
						[scl scaleXBy:[self arrowHeadLength] yBy:[self arrowHeadWidth]];
						break;
				}
				
				NSAffineTransform* rot = [NSAffineTransform transform];
				[rot rotateByRadians:slope];
				
				NSAffineTransform* tsl = [NSAffineTransform transform];
				[tsl translateXBy:sp.x yBy:sp.y];
				[scl appendTransform:rot];
				[scl appendTransform:tsl];
				
				[head transformUsingAffineTransform:scl];
				
				[arrow appendBezierPath:head];
			}
		}
		return arrow;
	}
}


- (NSBezierPath*)		arrowHeadForPathStart:(NSBezierPath*) path
{
	// returns the arrow head path for the start, translated, scaled etc to the right place
	
	return [self arrowHeadForPath:path ofKind:[self arrowHeadAtStart] orientation:NO multiple:0];
}


- (NSBezierPath*)		arrowHeadForPathEnd:(NSBezierPath*) path
{
	// returns the arrow head path for the end, translated, scaled etc to the right place
	
	return [self arrowHeadForPath:path ofKind:[self arrowHeadAtEnd] orientation:YES multiple:0];
}



#pragma mark -

- (NSBezierPath*)			arrowPathFromOriginalPath:(NSBezierPath*) inPath fromObject:(id) obj
{
	// given the input path, this returns the complete arrow path including arrow heads, tails and any dimensioning text. The path may
	// be filled to render the completed object.
	
	NSAssert( inPath != nil, @"nil path for creating arrow stroke path");
	NSAssert( obj != nil, @"nil object for creating arrow stroke path");
	
	if ([inPath elementCount] < 2)
		return nil;
	
	CGFloat trimStart, trimEnd;
	
	trimStart = [self trimLengthForKind:[self arrowHeadAtStart]];
	trimEnd = [self trimLengthForKind:[self arrowHeadAtEnd]];

	NSBezierPath* shaft = inPath;		// shaft of the arrow will become the new path
	
	if ( trimStart > 0.0 )
		shaft = [shaft bezierPathByTrimmingFromLength:trimStart];
		
	if ( trimEnd > 0.0 )
		shaft = [shaft bezierPathByTrimmingToLength:[shaft length] - trimEnd];
		
	// check that the path hasn't been trimmed to nothing
	
	if( shaft == nil || [shaft elementCount] < 2 || [shaft length] <= 0.0 )
		return nil;
		
	// copy the path at this point for use with later dimensioning text calculation
	
	NSBezierPath* shaftCopy = [shaft copy];
	
	// if the dimensioning options are for the dim text to be applied in line, a section of sufficient
	// length needs to be knocked out of the middle of the path
	
	if([self dimensioningLineOptions] == kDKDimensionPlaceInLine )
	{
		CGFloat dimWidth = [self widthOfDimensionTextForObject:obj];	// add some padding at each end
		CGFloat padding = MAX( dimWidth / 5.0, 8.0 );
		
		shaft = [shaft bezierPathByTrimmingFromCentre:dimWidth + padding];
	}

	[shaft setLineWidth:[self width]];
	[shaft setLineCapStyle:[self lineCapStyle]];
	[shaft setLineJoinStyle:[self lineJoinStyle]];
	
	if ([self dash])
		[[self dash] applyToPath:shaft]; 
	else
		[shaft setLineDash:NULL count:0 phase:0.0];
	
	// convert the shaft to its outline:

	shaft = [shaft strokedPath];
	[shaft setWindingRule:NSNonZeroWindingRule];

	if ([self arrowHeadAtStart] != kDKArrowHeadNone)
		[shaft appendBezierPath:[self arrowHeadForPathStart:inPath]];
	
	if ([self arrowHeadAtEnd] != kDKArrowHeadNone)
		[shaft appendBezierPath:[self arrowHeadForPathEnd:inPath]];
		
	// if it's a dimensioning line, append the dimension text
	
	if([self dimensioningLineOptions] != kDKDimensionNone )
	{
		NSAttributedString* dim = [self dimensionTextForObject:obj];
		
		if ( dim != nil )
		{
			CGFloat lineHeight = [[self font] xHeight];
			CGFloat dy;
			
			switch([self dimensioningLineOptions])
			{
				default:
				case kDKDimensionPlaceAboveLine:
					dy = 2.0f + ([self width] / 2 );
					break;
					
				case kDKDimensionPlaceBelowLine:
					dy = -lineHeight - ([self width] / 2 ) - 2.0f;
					break;
					
				case kDKDimensionPlaceInLine:
					dy = lineHeight * -0.5f;
					break;
			}
			
			NSBezierPath* textPath = [shaftCopy bezierPathWithTextOnPath:dim yOffset:dy];
			
			if ( textPath != nil && [textPath elementCount] > 1 )
				[shaft appendBezierPath:textPath];
		}
	}
	[shaftCopy release];
	
	return shaft;
}


#pragma mark -
#pragma mark - dimensioning lines

- (void)						setFormatter:(NSNumberFormatter*) fmt
{
	[fmt retain];
	[m_dims_formatter release];
	m_dims_formatter = fmt;
}


- (NSNumberFormatter*)			formatter
{
	return m_dims_formatter;
}


- (void)						setFormat:(NSString*) format
{
	[m_dims_formatter setFormat:format];
}


- (void)						setDimensioningLineOptions:(DKDimensioningLineOptions) dimOps
{
	if( dimOps != mDimensionOptions )
	{
		mDimensionOptions = dimOps;
		
		if( dimOps != kDKDimensionNone && m_dims_formatter == nil )
			[self setFormatter:[[self class] defaultDimensionLineFormatter]];
	}
}


- (DKDimensioningLineOptions)	dimensioningLineOptions
{
	return mDimensionOptions;
}


- (NSAttributedString*)			dimensionTextForObject:(id) obj
{
	NSAttributedString* dimText = nil;
	
	if ([self dimensioningLineOptions] != kDKDimensionNone )
	{
		NSString*	dimstr;
		CGFloat		lengthOfPath = [[obj renderingPath] length];
		
		if([obj respondsToSelector:@selector(convertLength:)])
			lengthOfPath = [obj convertLength:lengthOfPath];
		
		if ([self formatter])
		{
			dimText = [[self formatter] attributedStringForObjectValue:[NSNumber numberWithDouble:lengthOfPath] withDefaultAttributes:[[self class] dimensioningLineTextAttributes]];
		}
		else
		{
			dimstr = [NSString stringWithFormat:@"%.2f", lengthOfPath];
			dimText = [[NSAttributedString alloc] initWithString:dimstr attributes:[[self class] dimensioningLineTextAttributes]];
			[dimText autorelease];
		}
		
		if([self dimensionToleranceOption] != kDKDimensionToleranceNotShown)
		{
			NSMutableAttributedString* str = [dimText mutableCopy];
			NSString* tolText = [self toleranceTextForObject:obj];
			
			NSDictionary*	attrs = [self textAttributes];
			NSAttributedString* temp = [[NSAttributedString alloc] initWithString:tolText attributes:attrs];
			[str appendAttributedString:temp];
			[temp release];
			dimText = [str autorelease];
		}
	}
	
	return dimText;
}


- (NSString*)				toleranceTextForObject:(id) object
{
	if([self dimensionToleranceOption] == kDKDimensionToleranceNotShown )
		return @"";
	else
	{
		NSDictionary* dims = nil;
		
		if([object respondsToSelector:@selector(dimensionValuesForArrowStroke:)])
			dims = [object dimensionValuesForArrowStroke:self];
		
		CGFloat plusTol, minusTol;
		
		plusTol = minusTol = 0.05;
		
		if( dims )
		{
			plusTol = [[dims objectForKey:kDKPositiveToleranceKey] doubleValue];
			minusTol = [[dims objectForKey:kDKNegativeToleranceKey] doubleValue];
		}
		
		if( plusTol == minusTol )
			return [NSString stringWithFormat:@" ±%.2f", plusTol];
		else
			return [NSString stringWithFormat:@" +%.2f, -%.2f", plusTol, minusTol];
	}
}


- (CGFloat)			widthOfDimensionTextForObject:(id) obj
{
	NSAttributedString* dimStr = [self dimensionTextForObject:obj];
	return [dimStr size].width;
}


- (void)						setDimensionTextKind:(DKDimensionTextKind) kind
{
	if( kind != [self dimensionTextKind])
	{
		mDimTextKind = kind;
		
		NSString* prefix = @"", *suffix = @"";
		
		// the text kind really just sets various prefixes and suffixes in the formatter
		
		switch( kind )
		{
			default:
			case kDKDimensionLinear:
				break;
				
			case kDKDimensionDiameter:
				prefix = [NSString stringWithFormat:@"%C", 0x2300];		// unicode 'diameter' symbol
				break;
				
			case kDKDimensionRadius:
				prefix = @"R";
				break;
				
			case kDKDimensionAngle:
				suffix = @"°";
				break;
		}
		[[self formatter] setPositivePrefix:prefix];
		[[self formatter] setNegativePrefix:prefix];
		[[self formatter] setPositiveSuffix:suffix];
		[[self formatter] setNegativeSuffix:suffix];
	}
}


- (DKDimensionTextKind)			dimensionTextKind
{
	return mDimTextKind;
}


- (void)						setDimensionToleranceOption:(DKDimensionToleranceOption) option
{
	mDimToleranceOptions = option;
}


- (DKDimensionToleranceOption)	dimensionToleranceOption
{
	return mDimToleranceOptions;
}



- (void)			setTextAttributes:(NSDictionary*) dict
{
	[[self formatter] setTextAttributesForPositiveValues:dict];
	[[self formatter] setTextAttributesForNegativeValues:dict];
	[[self formatter] setTextAttributesForZero:dict];
}


- (NSDictionary*)	textAttributes
{
	return [[self formatter] textAttributesForPositiveValues];
}


- (void)			setFont:(NSFont*) font
{
	NSMutableDictionary* dict = [[self textAttributes] mutableCopy];
	[dict setObject:font forKey:NSFontAttributeName];
	[self setTextAttributes:dict];
	[dict release];
}


- (NSFont*)			font
{
	return [[self textAttributes] objectForKey:NSFontAttributeName];
}


#pragma mark -
#pragma mark As a DKStroke

- (void)			setWidth:(CGFloat) w
{
	[self standardArrowForStrokeWidth:w];
	[super setWidth:w];
}


#pragma mark -
#pragma mark As a GCObservableObject

+ (NSArray*)		observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"arrowHeadAtStart",
																						@"arrowHeadAtEnd",
																						@"arrowHeadWidth",
																						@"arrowHeadLength",
																						@"dimensioningLineOptions",
																						@"outlineColour",
																						@"outlineWidth",
																						@"textAttributes",
																						@"formatter",
																						@"dimensionTextKind",
																						@"dimensionToleranceOption",
																						nil]];
}


- (void)			registerActionNames
{
	[super registerActionNames];
	
	[self setActionName:@"#kind# Arrow Head Type" forKeyPath:@"arrowHeadAtStart"];
	[self setActionName:@"#kind# Arrow Head Type" forKeyPath:@"arrowHeadAtEnd"];
	[self setActionName:@"#kind# Arrow Width" forKeyPath:@"arrowHeadWidth"];
	[self setActionName:@"#kind# Arrow Length" forKeyPath:@"arrowHeadLength"];
	[self setActionName:@"#kind# Dimension Line" forKeyPath:@"dimensioningLineOptions"];
	[self setActionName:@"#kind# Outline Colour" forKeyPath:@"outlineColour"];
	[self setActionName:@"#kind# Outline Width" forKeyPath:@"outlineWidth"];
	[self setActionName:@"#kind# Dimension Text Format" forKeyPath:@"formatter"];
	[self setActionName:@"#kind# Dimension Text Format" forKeyPath:@"textAttributes"];
	[self setActionName:@"#kind# Dimension Text Format" forKeyPath:@"dimensionTextKind"];
	[self setActionName:@"#kind# Dimension Tolerance" forKeyPath:@"dimensionToleranceOption"];
}



#pragma mark -
#pragma mark As an NSObject

- (void)			dealloc
{
	[m_dims_formatter release];
	
	[super dealloc];
}


- (id)			init
{
	self = [super init];
	if (self != nil)
	{
		[self setArrowHeadAtStart:kDKArrowHeadNone];
		[self setArrowHeadAtEnd:kDKArrowHeadStandard];
		m_dims_formatter = nil;
		m_outlineColour = nil;
		m_outlineWidth = 0.0;
		[self setWidth:1.0];
		mDimToleranceOptions = kDKDimensionToleranceShown;
	}
	
	return self;
}


#pragma mark -
#pragma mark As part of DKRasterizerProtocol

- (NSSize)		extraSpaceNeeded
{
	if ([self enabled])
	{
		NSSize es = [super extraSpaceNeeded];
		CGFloat ahWidth = [self arrowHeadWidth] + [self outlineWidth];
		
		if([self shadow])
			ahWidth += [[self shadow] extraSpace];
		
		es.width = MAX( es.width, ahWidth );
		es.height = MAX( es.height, ahWidth );

		if ([self dimensioningLineOptions] != kDKDimensionNone )
		{
			NSAttributedString* str = [self dimensionTextForObject:nil];
			NSSize strSize = [str size];
			
			es.height = MAX( es.width, strSize.height * 0.7f );
			es.width = MAX( es.height, strSize.height * 0.7f );
		}

		return es;
	}
	else
		return NSZeroSize;
}


- (void)		render:(id<DKRenderable>) obj
{
	if( ![obj conformsToProtocol:@protocol(DKRenderable)] || ![self enabled])
		return;

	[[self colour] set];
	
	if([self shadow] != nil && [DKStyle willDrawShadows])
		[[self shadow] setAbsolute];
	
	NSBezierPath* ap = [self arrowPathFromOriginalPath:[obj renderingPath] fromObject:obj];
	
	if ( ap != nil )
	{
		[ap fill];
		
		if([self outlineColour] != nil )
		{
			[ap setLineWidth:[self outlineWidth]];
			[[self outlineColour] setStroke];
			[ap stroke];
		}
	}
}


#pragma mark -
#pragma mark As part of NSCoding Protocol

- (void)		encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeInteger:[self arrowHeadAtStart] forKey:@"DKArrowStroke_arrowStart"];
	[coder encodeInteger:[self arrowHeadAtEnd] forKey:@"DKArrowStroke_arrowEnd"];
	
	[coder encodeDouble:[self arrowHeadLength] forKey:@"DKArrowStroke_arrowLength"];
	[coder encodeDouble:[self arrowHeadWidth] forKey:@"DKArrowStroke_arrowWidth"];
	
	[coder encodeInteger:[self dimensioningLineOptions] forKey:@"DKArrowStroke_dimOptions"];
	[coder encodeObject:[self formatter] forKey:@"DKArrowStroke_formatter"];
	[coder encodeObject:[self outlineColour] forKey:@"DKArrowStroke_outlineColour"];
	[coder encodeDouble:[self outlineWidth] forKey:@"DKArrowStroke_outlineWidth"];
	[coder encodeInteger:[self dimensionTextKind] forKey:@"DKArrowStroke_dimTextKind"];
	[coder encodeInteger:[self dimensionToleranceOption] forKey:@"DKArrowStroke_dimToleranceOption"];
}


- (id)			initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setArrowHeadAtStart:[coder decodeIntegerForKey:@"DKArrowStroke_arrowStart"]];
		[self setArrowHeadAtEnd:[coder decodeIntegerForKey:@"DKArrowStroke_arrowEnd"]];
		
		[self setArrowHeadLength:[coder decodeDoubleForKey:@"DKArrowStroke_arrowLength"]];
		[self setArrowHeadWidth:[coder decodeDoubleForKey:@"DKArrowStroke_arrowWidth"]];
		
		// will set up initial default formatter if dimension text is enabled:
		
		[self setDimensioningLineOptions:[coder decodeIntegerForKey:@"DKArrowStroke_dimOptions"]];
		mDimTextKind = [coder decodeIntegerForKey:@"DKArrowStroke_dimTextKind"];
		
		// but if one was saved (later files) it is used:
		
		NSNumberFormatter* fmt = [coder decodeObjectForKey:@"DKArrowStroke_formatter"];
		
		if( fmt )
			[self setFormatter:fmt];
		
		[self setOutlineColour:[coder decodeObjectForKey:@"DKArrowStroke_outlineColour"]];
		[self setOutlineWidth:[coder decodeDoubleForKey:@"DKArrowStroke_outlineWidth"]];
		[self setDimensionToleranceOption:[coder decodeIntegerForKey:@"DKArrowStroke_dimToleranceOption"]];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol

- (id)			copyWithZone:(NSZone*) zone
{
	DKArrowStroke*	copy = [super copyWithZone:zone];
	
	[copy setArrowHeadAtStart:[self arrowHeadAtStart]];
	[copy setArrowHeadAtEnd:[self arrowHeadAtEnd]];
	
	[copy setArrowHeadWidth:[self arrowHeadWidth]];
	[copy setArrowHeadLength:[self arrowHeadLength]];
	[copy setDimensioningLineOptions:[self dimensioningLineOptions]];
	
	NSNumberFormatter* fc = [[[self formatter] copy] autorelease];
	[copy setFormatter:fc];
	
	[copy setOutlineColour:[self outlineColour]];
	[copy setOutlineWidth:[self outlineWidth]];
	[copy setDimensionToleranceOption:[self dimensionToleranceOption]];
	
	copy->mDimTextKind = [self dimensionTextKind];
	
	return copy;
}


@end
