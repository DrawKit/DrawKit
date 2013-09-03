///**********************************************************************************************************************************
///  DKArrowStroke.m
///  DrawKit
///
///  Created by graham on 20/03/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKArrowStroke.h"

#import "DKDrawablePath.h"
#import "DKLineDash.h"
#import "NSBezierPath+Geometry.h"
#import "NSBezierPath+Editing.h"
#import "DKShapeFactory.h"
#import "NSShadow+Scaling.h"

#pragma mark Static Vars
static NSMutableDictionary*	sDimLinesAttributes = nil;


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
		
		[sDimLinesAttributes setObject:[NSFont fontWithName:@"Helvetica Bold" size:11] forKey:NSFontAttributeName];
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

- (void)				setArrowHeadWidth:(float) width
{
	m_arrowWidth = width;
}


- (float)				arrowHeadWidth
{
	return m_arrowWidth;
}



- (void)				setArrowHeadLength:(float) length
{
	m_arrowLength = length;
}


- (float)				arrowHeadLength
{
	return m_arrowLength;
}


#pragma mark -
- (void)				standardArrowForStrokeWidth:(float) sw
{
	// compute suitable arrow head length and width from the stroke width - the formula
	// here is intended to allow arrows to "look right" and in proportion when the stroke width is changed.
	
	float w = (( sw - 1.5 ) * 0.4 ) + 1.5;
	
	[self setArrowHeadWidth:w * 6];
	[self setArrowHeadLength:MAX( 10, w * 6)];
}


- (void)				setOutlineColour:(NSColor*) colour width:(float) width
{
	[colour retain];
	[m_outlineColour release];
	m_outlineColour = colour;
	m_outlineWidth = width;
}


- (NSColor*)			outlineColour
{
	return m_outlineColour;
}


- (float)				outlineWidth
{
	return m_outlineWidth;
}


#pragma mark -
- (NSImage*)			arrowSwatchImageWithSize:(NSSize) size strokeWidth:(float) width
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
	
	float saved = [self width];
	m_width = width;	// do not use [self setWidth:] as KVO can cause an infinite loop here
	
	DKDrawablePath* temp = [DKDrawablePath drawablePathWithPath:path];
	
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
	return [self arrowSwatchImageWithSize:kGCStandardArrowSwatchImageSize strokeWidth:kGCStandardArrowSwatchStrokeWidth];
}


#pragma mark -

- (float)				trimLengthForKind:(DKArrowHeadKind) kind
{
	float trim = [self arrowHeadLength] * 0.9;

	switch( kind )
	{
		default:
			break;
			
		case kDKArrowHeadNone:
		case kDKArrowHeadRound:
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
	}
	
	// the paths are all centred on the origin. More usefully the origin should be at the point or other place
	// where the real path terminates, so offset the result by half a unit to the right
	
	NSAffineTransform* tsl = [NSAffineTransform transform];
	[tsl translateXBy:0.5 yBy:0];
	[path transformUsingAffineTransform:tsl];
	
	return [path bezierPathByReversingPath];
}


- (NSBezierPath*)		arrowHeadForPath:(NSBezierPath*) path ofKind:(DKArrowHeadKind) kind orientation:(BOOL) flip multiple:(int) n
{
	// this method returns the arrow head element indicated by the parameters
	
	NSAssert( path != nil, @"can't make arrow heads for a nil path");
	
	if ( kind == kDKArrowHeadStandard ||
		 kind == kDKArrowHeadDimensionLine ||
		 kind == kDKArrowHeadDimensionLineAndBar)
	{
		// this arrowhead is curved to match the actual curvature of the path at the place where the arrow heads will go
		// angle in degrees is half the atan(y/x)
		
		float	degrees = (atan2f([self arrowHeadWidth], [self arrowHeadLength]) * 90.0 ) / pi;
		float	hyp = hypotf([self arrowHeadWidth], [self arrowHeadLength]);
		
		NSBezierPath* headPath;
		
		if ( flip )
			headPath = [path bezierPathWithArrowHeadForEndOfLength:hyp angle:degrees closingPath:YES];
		else
			headPath = [path bezierPathWithArrowHeadForStartOfLength:hyp angle:degrees closingPath:YES];
			
		if ( kind == kDKArrowHeadDimensionLineAndBar )
		{
			// add the bar
			
			NSBezierPath* barPath = [NSBezierPath bezierPathWithRect:NSMakeRect( -0.25f, [self arrowHeadWidth] * -0.75f, 0.5f, [self arrowHeadWidth] * 1.5)];
			
			float		slope;
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
		
		float featherScaleFactor = 1.0;
		float featherSpacingFactor = 1.05;
		
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
		int				i;
		
		for( i = 0; i < n; ++i )
		{
			NSBezierPath* head = [self arrowHeadElementForKind:kind];
			
			if ( head != nil )
			{
				// transform it to the end point of the path, scaled to the current head length, rotated to the path angle
				
				float	pathLength;
				float	adjustment;
				float	slope;
				
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
	
	float trimStart, trimEnd;
	
	trimStart = [self trimLengthForKind:[self arrowHeadAtStart]];
	trimEnd = [self trimLengthForKind:[self arrowHeadAtEnd]];

	NSBezierPath* shaft;		// shaft of the arrow will become the new path
	
	if ( trimStart > 0.0 )
		shaft = [inPath bezierPathByTrimmingFromLength:trimStart];
	else
		shaft = [[inPath copy] autorelease];
		
	if ( trimEnd > 0.0 )
		shaft = [shaft bezierPathByTrimmingToLength:[shaft length] - trimEnd];
		
	// check that the path hasn't been trimmed to nothing
	
	if( shaft == nil || [shaft elementCount] < 2 )
		return nil;
	
	// if the dimensioning options are for the dim text to be applied in line, a section of sufficient
	// length needs to be knocked out of the middle of the path
	
	if([self dimensioningLineOptions] == kDKDimensionPlaceInLine )
	{
		float dimWidth = [self widthOfDimensionTextForObject:obj];	// add some padding at each end
		shaft = [shaft bezierPathByTrimmingFromCentre:dimWidth + 8.0f];
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
			NSFont* font = [[[self class] dimensioningLineTextAttributes] objectForKey:NSFontAttributeName];
			float lineHeight = [font ascender];
			float dy;
			
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
					dy = 0.5f + ( lineHeight * -0.5f );
					break;
			}
			
			NSBezierPath* textPath = [inPath bezierPathWithTextOnPath:dim yOffset:dy];
			
			if ( textPath != nil && [textPath elementCount] > 1 )
				[shaft appendBezierPath:textPath];
		}
	}
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
	mDimensionOptions = dimOps;
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
		float		lengthOfPath = [[obj renderingPath] length];
		
		lengthOfPath = [obj convertLength:lengthOfPath];
		
		if ([self formatter])
			dimstr = [[self formatter] stringForObjectValue:[NSNumber numberWithFloat:lengthOfPath]];
		else
			dimstr = [NSString stringWithFormat:@"%.2f", lengthOfPath];
			
		dimText = [[NSAttributedString alloc] initWithString:dimstr attributes:[[self class] dimensioningLineTextAttributes]];
		
		[dimText autorelease];
	}
	
	return dimText;
}


- (float)			widthOfDimensionTextForObject:(id) obj
{
	NSAttributedString* dimStr = [self dimensionTextForObject:obj];
	return [dimStr size].width;
}


#pragma mark -
#pragma mark As a DKStroke

- (void)			setWidth:(float) w
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
																						@"dimensioningLineOptions", nil]];
}


- (void)			registerActionNames
{
	[super registerActionNames];
	
	[self setActionName:@"#kind# Arrow Head Type" forKeyPath:@"arrowHeadAtStart"];
	[self setActionName:@"#kind# Arrow Head Type" forKeyPath:@"arrowHeadAtEnd"];
	[self setActionName:@"#kind# Arrow Width" forKeyPath:@"arrowHeadWidth"];
	[self setActionName:@"#kind# Arrow Length" forKeyPath:@"arrowHeadLength"];
	[self setActionName:@"#kind# Dimension Line" forKeyPath:@"dimensioningLineOptions"];
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
		float ahWidth = [self arrowHeadWidth] + [self outlineWidth];
		
		if([self shadow])
			ahWidth += [[self shadow] extraSpace];
		
		es.width = MAX( es.width, ahWidth );
		es.height = MAX( es.height, ahWidth );

		if ([self dimensioningLineOptions] != kDKDimensionNone )
		{
			es.height += 10;
			es.width += 10;
		}

		return es;
	}
	else
		return NSZeroSize;
}


- (void)		render:(id) obj
{
	[[self colour] set];
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
	
	[coder encodeInt:[self arrowHeadAtStart] forKey:@"DKArrowStroke_arrowStart"];
	[coder encodeInt:[self arrowHeadAtEnd] forKey:@"DKArrowStroke_arrowEnd"];
	
	[coder encodeFloat:[self arrowHeadLength] forKey:@"DKArrowStroke_arrowLength"];
	[coder encodeFloat:[self arrowHeadWidth] forKey:@"DKArrowStroke_arrowWidth"];
	
	[coder encodeInt:[self dimensioningLineOptions] forKey:@"DKArrowStroke_dimOptions"];
	[coder encodeObject:[self formatter] forKey:@"DKArrowStroke_formatter"];
	[coder encodeObject:[self outlineColour] forKey:@"DKArrowStroke_outlineColour"];
	[coder encodeFloat:[self outlineWidth] forKey:@"DKArrowStroke_outlineWidth"];
}


- (id)			initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setArrowHeadAtStart:[coder decodeIntForKey:@"DKArrowStroke_arrowStart"]];
		[self setArrowHeadAtEnd:[coder decodeIntForKey:@"DKArrowStroke_arrowEnd"]];
		
		[self setArrowHeadLength:[coder decodeFloatForKey:@"DKArrowStroke_arrowLength"]];
		[self setArrowHeadWidth:[coder decodeFloatForKey:@"DKArrowStroke_arrowWidth"]];
		[self setDimensioningLineOptions:[coder decodeIntForKey:@"DKArrowStroke_dimOptions"]];
		[self setFormatter:[coder decodeObjectForKey:@"DKArrowStroke_formatter"]];
		
		[self setOutlineColour:[coder decodeObjectForKey:@"DKArrowStroke_outlineColour"] width:[coder decodeFloatForKey:@"DKArrowStroke_outlineWidth"]];
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
	
	[copy setOutlineColour:[self outlineColour] width:[self outlineWidth]];
	
	return copy;
}


@end
