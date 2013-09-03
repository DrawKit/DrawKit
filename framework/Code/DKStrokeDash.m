//
//  DKStrokeDash.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 10/09/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKStrokeDash.h"
#import "DKDrawKitMacros.h"


#pragma mark Static Vars
static NSMutableDictionary* sDashDict = nil;


static NSUInteger euclid_hcf( NSUInteger a, NSUInteger b )
{
	if( b == 0 )
		return a;
	else
		return euclid_hcf( b, a % b );
}


#pragma mark -
@implementation DKStrokeDash
#pragma mark As a DKStrokeDash
+ (DKStrokeDash*)	defaultDash
{
	return [[[DKStrokeDash alloc] init] autorelease];
}


+ (DKStrokeDash*)	dashWithPattern:(CGFloat[]) dashes count:(NSInteger) count
{
	return [[[DKStrokeDash alloc] initWithPattern:dashes count:count] autorelease];
}


+ (DKStrokeDash*)	dashWithName:(NSString*) name
{
	return [sDashDict objectForKey:name];
}


+ (void)		registerDash:(DKStrokeDash*) dash withName:(NSString*) name
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
}


+ (DKStrokeDash*)	equallySpacedDashToFitSize:(NSSize) aSize dashLength:(CGFloat) len
{
	// frequently we'd like to allow a dash to adjust itself so that the corners of a given rect lie exactly in the middle of a dash element. This
	// method computes one. <aSize> specifies the width and height of a rectangle the dash will exactly fit, and <len> is the desired overall dash
	// length (mark + space). The returned dash will be close to <len> in length but will vary as much as needed to fit the size. This works by
	// finding the highest common factor of the width and height using Euclid's algorithm, then finding the closest value to <len> that is a whole
	// multiple of the hcf. The returned dash has equal mark/space ratio and a phase of 0, which should permit it to be used to stroke the rectangle directly.
	
	NSUInteger a, b;
	CGFloat	 hcf, rem, halfLen;
	
	halfLen = len * 0.5f;
	a = (NSUInteger)floor( fabs( aSize.width ));
	b = (NSUInteger)floor( fabs( aSize.height ));
	
	hcf = (CGFloat) euclid_hcf( a, b );
	rem = fmodf( halfLen, hcf );
	
	NSLog(@"size = %@, hcf = %f, rem = %f, halfLen = %f", NSStringFromSize( aSize ), hcf, rem, halfLen );
	
	if ( rem > ( hcf * 0.5f ))
		halfLen += ( hcf - rem );
	else
		halfLen -= rem;
	
	CGFloat d[2];
	
	d[0] = d[1] = hcf;
	DKStrokeDash* dash = [self dashWithPattern:d count:2];
	[dash setScalesToLineWidth:NO];
	
	return dash;
}


#pragma mark -
+ (void)		saveDefaults
{
}


+ (void)		loadDefaults
{
}


#pragma mark -
- (id)			initWithPattern:(CGFloat[]) dashes count:(NSInteger) count
{
	NSAssert(sizeof(dashes) <= 8 * sizeof(CGFloat), @"Expected dashes to be no more than 8 floats");
	self = [super init];
	if (self != nil)
	{
		[self setDashPattern:dashes count:count];
		NSAssert(m_phase == 0.0, @"Expected init to zero");
		m_scaleToLineWidth = YES;
	}
	
	return self;
}


- (void)		setDashPattern:(CGFloat[]) dashes count:(NSInteger) count
{
	//_count = MAX( 0, MIN( count, 8 ));
	
	m_count = LIMIT( count, 0, 8 );
	
	BOOL		valid = NO;
	NSUInteger	i;
	
	for( i = 0; i < m_count; i++ )
	{
		m_pattern[i] = fabs(dashes[i]);
		
		if( m_pattern[i] > 0.0 )
			valid = YES;
	}
	
	// check that there is at least one element that is non-zero
	
	if( !valid )
		m_pattern[0] = 1.0;
}


- (void)		getDashPattern:(CGFloat[]) dashes count:(NSInteger*) count
{
	*count = m_count;
	NSUInteger i;
	for( i = 0; i < m_count; i++ )
		dashes[i] = m_pattern[i];
}


- (NSInteger)			count
{
	return m_count;
}


- (void)		setPhase:(CGFloat) ph
{
	// the phase of the dash, ignoring any line width scaling.
	m_phase = LIMIT( ph, 0, [self length]);

	//NSLog(@"dash %@ setting phase %f (actual = %f)", self, ph, m_phase );
}


- (void)		setPhaseWithoutNotifying:(CGFloat) ph
{
	// allows a renderer to change the phase without notifying, which triggers more drawing, etc.
	
	m_phase = LIMIT( ph, 0, [self length]);
}


- (CGFloat)		phase
{
	return m_phase;
}


- (CGFloat)		length
{
	// returns the length of the dash pattern before it repeats. Note that if the pattern is scaled to the line width,
	// this returns the unscaled length, so the client needs to multiply the result by the line width if necessary.
	
	CGFloat		m = 0;
	NSUInteger	i;
	
	for( i = 0; i < m_count; ++i )
		m += m_pattern[i];
	
	return m;
}


- (CGFloat)		lengthAtIndex:(NSUInteger) indx
{
	if( indx < m_count )
		return m_pattern[indx];
	else
		return 0.0;
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


- (void)		setIsBeingEdited:(BOOL) edit
{
	// an editor should set htis for the duration of an edit. It prevents certain properties being changed by rasterizers during the edit
	// which can cause contention for those properties.
	
	mEditing = edit;
}


- (BOOL)		isBeingEdited
{
	return mEditing;
}


#pragma mark -
- (void)		applyToPath:(NSBezierPath*) path
{
	m_phase = LIMIT([self phase], 0, [self length]);
	[self applyToPath:path withPhase:[self phase]];
}


- (void)		applyToPath:(NSBezierPath*) path withPhase:(CGFloat) phase
{
	// if scales to line width, use path's line width to multiply each element of the pattern
	
	if([self scalesToLineWidth])
	{
		CGFloat		scale = [path lineWidth];
		CGFloat		dp[8];
		NSUInteger	i;
		
		for( i = 0; i < m_count; ++i )
			dp[i] = m_pattern[i] * scale;
			
		[path setLineDash:dp count:m_count phase:-phase * scale];
	}
	else
		[path setLineDash:m_pattern count:m_count phase:-phase];
}


#pragma mark -


- (NSImage*)	dashSwatchImageWithSize:(NSSize) size strokeWidth:(CGFloat) width
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
	return [self dashSwatchImageWithSize:kDKStandardDashSwatchImageSize strokeWidth:kDKStandardDashSwatchStrokeWidth];
}


#pragma mark -
#pragma mark As an NSObject
+ (void)		initialize
{
	CGFloat			d[8];
	CGFloat			count;
	
	d[0] = d[1] = 1.0;
	count = 2;
	[self registerDash:[self dashWithPattern:d count:count] withName:@"default_1"];

	d[0] = 8.0;
	d[1] = 2.0;
	count = 2;
	[self registerDash:[self dashWithPattern:d count:count] withName:@"default_3"];
	
	d[0] = 3.0;
	d[1] = 3.0;
	count = 2;
	[self registerDash:[self dashWithPattern:d count:count] withName:@"default_7"];

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
		// Catch if someone changes the array size without considering the init method.
		NSAssert(sizeof(m_pattern) == 8 * sizeof(CGFloat), @"init expects the m_pattern array to only be 8 floats");
		m_count = 2;
		m_scaleToLineWidth = YES;
	}
	return self;
}


#pragma mark -
#pragma mark As part of GraphicsAttributes Protocol
- (void)		setValue:(id) val forNumericParameter:(NSInteger) pnum
{
	if ( pnum < 8 && pnum >= 0 )
	{
		m_count = pnum + 1;
		m_pattern[pnum] = [val doubleValue];
	}
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)		encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[coder encodeArrayOfObjCType:@encode(CGFloat) count:[self count] at:m_pattern];
	[coder encodeDouble:[self phase] forKey:@"phase"];
	[coder encodeInteger:[self count] forKey:@"count"];
	[coder encodeBool:[self scalesToLineWidth] forKey:@"scale_to_width"];
}


- (id)			initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super init];
	if (self != nil)
	{
		m_count = [coder decodeIntegerForKey:@"count"];
		
		if( m_count > 8 )
			m_count = 8;
			
		[coder decodeArrayOfObjCType:@encode(CGFloat) count:m_count at:m_pattern];
		[self setScalesToLineWidth:[coder decodeBoolForKey:@"scale_to_width"]];
		[self setPhase:[coder decodeDoubleForKey:@"phase"]];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)			copyWithZone:(NSZone*) zone
{
	DKStrokeDash* copy = [[[self class] allocWithZone:zone] init];
	
	[copy setDashPattern:m_pattern count:m_count];
	[copy setScalesToLineWidth:[self scalesToLineWidth]];
	[copy setPhase:[self phase]];
	
	return copy;
}


@end
