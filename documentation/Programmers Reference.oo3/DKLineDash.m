//
//  DKLineDash.m
//  DrawingArchitecture
//
//  Created by graham on 10/09/2006.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "DKLineDash.h"

#import "DKDrawKitMacros.h"


#pragma mark Static Vars
static NSMutableDictionary* sDashDict = nil;


#pragma mark -
@implementation DKLineDash
#pragma mark As a DKLineDash
+ (DKLineDash*)	defaultDash
{
	return [[[DKLineDash alloc] init] autorelease];
}


+ (DKLineDash*)	dashWithPattern:(float[]) dashes count:(int) count
{
	return [[[DKLineDash alloc] initWithPattern:dashes count:count] autorelease];
}


+ (DKLineDash*)	dashWithName:(NSString*) name
{
	return [sDashDict objectForKey:name];
}


+ (void)		registerDash:(DKLineDash*) dash withName:(NSString*) name
{
	if ( sDashDict == nil )
		sDashDict = [[NSMutableDictionary alloc] init];
		
	[sDashDict setObject:dash forKey:name];
}


+ (NSArray*)	registeredDashes
{
	NSMutableArray*	list = [NSMutableArray array];
	NSArray*		keys = [[sDashDict allKeys] sortedArrayUsingSelector:@selector(compare:)];
	NSEnumerator*	iter = [keys objectEnumerator];
	NSString*		key;
	
	while(( key = [iter nextObject]))
		[list addObject:[sDashDict valueForKey:key]];
		
	return list;
	
	//return [sDashDict allValues];
}


#pragma mark -
+ (void)		saveDefaults
{
	//[[NSUserDefaults standardUserDefaults] setObject:sDashDict forKey:@"dk_line_dash_library"];
}


+ (void)		loadDefaults
{
	//sDashDict = [[[NSUserDefaults standardUserDefaults] objectForKey:@"dk_line_dash_library"] mutableCopy];
}


#pragma mark -
- (id)			initWithPattern:(float[]) dashes count:(int) count
{
	NSAssert(sizeof(dashes) <= 8 * sizeof(float), @"Expected dashes to be no more than 8 floats");
	self = [super init];
	if (self != nil)
	{
		[self setDashPattern:dashes count:count];
		NSAssert(m_phase == 0.0, @"Expected init to zero");
		m_scaleToLineWidth = YES;
	}
	
	return self;
}


- (void)		setDashPattern:(float[]) dashes count:(int) count
{
	//_count = MAX( 0, MIN( count, 8 ));
	
	m_count = LIMIT( count, 0, 8 );
	
	unsigned i;
	for( i = 0; i < m_count; i++ )
		m_pattern[i] = dashes[i];
}


- (void)		getDashPattern:(float[]) dashes count:(int*) count
{
	*count = m_count;
	unsigned i;
	for( i = 0; i < m_count; i++ )
		dashes[i] = m_pattern[i];
}


- (int)			count
{
	return m_count;
}


- (void)		setPhase:(float) ph
{
	m_phase = LIMIT( ph, 0, [self length]);
}


- (float)		phase
{
	return m_phase;
}


- (float)		length
{
	// returns the length of the dash pattern before it repeats
	
	float		m = 0;
	unsigned	i;
	
	for( i = 0; i < m_count; ++i )
		m += m_pattern[i];
		
	return m;
}


#pragma mark -
- (void)		setScalesToLineWidth:(BOOL) stlw
{
	m_scaleToLineWidth = stlw;
}


- (BOOL)		scalesToLineWidth
{
	return m_scaleToLineWidth;
}


#pragma mark -
- (void)		applyToPath:(NSBezierPath*) path
{
	[self applyToPath:path withPhase:[self phase]];
}


- (void)		applyToPath:(NSBezierPath*) path withPhase:(float) phase
{
	// if scales to line width, use path's line width to multiply each element of the pattern
	
	if([self scalesToLineWidth])
	{
		float		scale = [path lineWidth];
		float		dp[8];
		unsigned	i;
		
		for( i = 0; i < m_count; ++i )
			dp[i] = m_pattern[i] * scale;
			
		[path setLineDash:dp count:m_count phase:-phase * scale];
	}
	else
		[path setLineDash:m_pattern count:m_count phase:-phase];
}


#pragma mark -
- (NSString*)	styleScript
{
	NSMutableString* s = [[NSMutableString alloc] init];
	
	[s setString:@"(dash "];
	
	int i;
	
	for ( i = 0; i < [self count]; ++i )
		[s appendFormat:@"%1.1f ", m_pattern[i]];
	
	[s appendString:@")"];
	return [s autorelease];
}


- (NSImage*)	dashSwatchImageWithSize:(NSSize) size strokeWidth:(float) width
{
	NSImage*		image = [[NSImage alloc] initWithSize:size];
	NSBezierPath*	path;
	NSPoint			a, b;
	
	a.x = 0;
	b.x = size.width;
	a.y = b.y = size.height / 2.0;
	
	path = [NSBezierPath bezierPath];
	[path setLineWidth:width];
	[path setLineCapStyle:NSButtLineCapStyle];
	[self applyToPath:path];
	[path moveToPoint:a];
	[path lineToPoint:b];
	
	// draw into image
	
	[image lockFocus];
	[[NSColor blackColor] set];
	[path stroke];
	[image unlockFocus];
	
	return [image autorelease];
}


- (NSImage*)	standardDashSwatchImage
{
	return [self dashSwatchImageWithSize:kGCStandardDashSwatchImageSize strokeWidth:kGCStandardDashSwatchStrokeWidth];
}


#pragma mark -
#pragma mark As an NSObject
+ (void)		initialize
{
	float			d[8];
	float			count;
	
	d[0] = d[1] = 1.0;
	count = 2;
	[self registerDash:[self dashWithPattern:d count:count] withName:@"default_1"];

	d[0] = 8.0;
	d[1] = 2.0;
	count = 2;
	[self registerDash:[self dashWithPattern:d count:count] withName:@"default_3"];
	
	d[0] = 4.0;
	d[1] = 1.0;
	count = 2;
	[self registerDash:[self dashWithPattern:d count:count] withName:@"default_2"];
	
	d[0] = 4.0;
	d[1] = 1.0;
	d[2] = 1.0;
	d[3] = 1.0;
	count = 4;
	[self registerDash:[self dashWithPattern:d count:count] withName:@"default_4"];
	
	d[0] = 8.0;
	d[1] = 2.0;
	d[2] = 1.0;
	d[3] = 2.0;
	count = 4;
	[self registerDash:[self dashWithPattern:d count:count] withName:@"default_5"];
	
	d[0] = 8.0;
	d[1] = 2.0;
	d[2] = 8.0;
	d[3] = 2.0;
	d[4] = 1.0;
	d[5] = 2.0;
	count = 6;
	[self registerDash:[self dashWithPattern:d count:count] withName:@"default_6"];
}


- (id)			init
{
	self = [super init];
	if (self != nil)
	{
		m_pattern[0] = 5.0;
		m_pattern[1] = 5.0;
		NSAssert(m_pattern[2] == 0.0, @"Expected init to zero");
		NSAssert(m_pattern[3] == 0.0, @"Expected init to zero");
		NSAssert(m_pattern[4] == 0.0, @"Expected init to zero");
		NSAssert(m_pattern[5] == 0.0, @"Expected init to zero");
		NSAssert(m_pattern[6] == 0.0, @"Expected init to zero");
		NSAssert(m_pattern[7] == 0.0, @"Expected init to zero");
		// Catch if someone changes the array size without considering the init method.
		NSAssert(sizeof(m_pattern) == 8 * sizeof(float), @"init expects the m_pattern array to only be 8 floats");
		NSAssert(m_phase == 0.0, @"Expected init to zero");
		m_count = 2;
		m_scaleToLineWidth = YES;
	}
	return self;
}


#pragma mark -
#pragma mark As part of GraphicsAttributes Protocol
- (void)		setValue:(id) val forNumericParameter:(int) pnum
{
	if ( pnum < 8 && pnum >= 0 )
	{
		m_count = pnum + 1;
		m_pattern[pnum] = [val floatValue];
	}
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)		encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[coder encodeArrayOfObjCType:@encode(float) count:[self count] at:m_pattern];
	[coder encodeFloat:[self phase] forKey:@"phase"];
	[coder encodeInt:[self count] forKey:@"count"];
	[coder encodeBool:[self scalesToLineWidth] forKey:@"scale_to_width"];
}


- (id)			initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super init];
	if (self != nil)
	{
		m_count = [coder decodeIntForKey:@"count"];
		
		if( m_count > 8 )
			m_count = 8;
			
		[coder decodeArrayOfObjCType:@encode(float) count:m_count at:m_pattern];
		[self setScalesToLineWidth:[coder decodeBoolForKey:@"scale_to_width"]];
		[self setPhase:[coder decodeFloatForKey:@"phase"]];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)			copyWithZone:(NSZone*) zone
{
	DKLineDash* copy = [[[self class] allocWithZone:zone] init];
	
	[copy setDashPattern:m_pattern count:m_count];
	[copy setScalesToLineWidth:[self scalesToLineWidth]];
	[copy setPhase:[self phase]];
	
	return copy;
}


@end
