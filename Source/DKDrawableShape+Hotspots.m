/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawableShape+Hotspots.h"

#import "DKDrawing.h"
#import "DKKnob.h"
#import "LogEvent.h"
#import "DKObjectOwnerLayer.h"

@implementation DKDrawableShape (Hotspots)
#pragma mark As a DKDrawableShape
- (NSInteger)addHotspot:(DKHotspot*)hspot
{
	if (m_customHotSpots == nil)
		m_customHotSpots = [[NSMutableArray alloc] init];

	[m_customHotSpots addObject:hspot];
	[hspot setOwner:self];
	[hspot setPartcode:[m_customHotSpots count] - 1 + kDKHotspotBasePartcode];

	return [hspot partcode];
}

- (void)removeHotspot:(DKHotspot*)hspot
{
	[m_customHotSpots removeObject:hspot];
}

- (void)setHotspots:(NSArray*)spots
{
	m_customHotSpots = [spots mutableCopy];

	[m_customHotSpots makeObjectsPerformSelector:@selector(setOwner:)
									  withObject:self];
}

- (NSArray*)hotspots
{
	return m_customHotSpots;
}

#pragma mark -
- (DKHotspot*)hotspotForPartCode:(NSInteger)pc
{
	NSEnumerator* iter = [[self hotspots] objectEnumerator];
	DKHotspot* hs;

	while ((hs = [iter nextObject])) {
		if ([hs partcode] == pc)
			return hs;
	}

	return nil; // not found
}

- (DKHotspot*)hotspotUnderMouse:(NSPoint)mp
{
	NSEnumerator* iter = [[self hotspots] objectEnumerator];
	DKHotspot* hs;

	while ((hs = [iter nextObject])) {
		if (NSPointInRect(mp, [self hotspotRect:hs]))
			return hs;
	}

	return nil; // not found
}

- (NSPoint)hotspotPointForPartcode:(NSInteger)pc
{
	DKHotspot* hs = [self hotspotForPartCode:pc];

	return [self convertPointFromRelativeLocation:[hs relativeLocation]];
}

#pragma mark -
- (NSRect)hotspotRect:(DKHotspot*)hs
{
	NSRect hsr;
	NSPoint p = [self convertPointFromRelativeLocation:[hs relativeLocation]];

	hsr.size = kDKDefaultHotspotSize;
	hsr.origin.x = p.x - (hsr.size.width / 2);
	hsr.origin.y = p.y - (hsr.size.height / 2);

	return hsr;
}

- (void)drawHotspotAtPoint:(NSPoint)hp inState:(DKHotspotState)state
{
#pragma unused(state)
	NSColor* hc = [NSColor yellowColor];

	//if( state == kDKHotspotStateOn )
	//	hc = [hc shadowWithLevel:0.5];

	[[[self layer] knobs] drawKnobAtPoint:hp
								   ofType:kDKHotspotKnobType
									angle:[self angle] + FORTYFIVE_DEGREES
						  highlightColour:hc];
}

- (void)drawHotspotsInState:(DKHotspotState)state
{
	NSEnumerator* iter = [[self hotspots] objectEnumerator];
	DKHotspot* hs;
	NSPoint p;

	while ((hs = [iter nextObject])) {
		p = [self convertPointFromRelativeLocation:[hs relativeLocation]];
		[hs drawHotspotAtPoint:p
					   inState:state];
	}
}

@end

#pragma mark -
@implementation DKHotspot
#pragma mark As a DKHotspot
- (instancetype)initHotspotWithOwner:(DKDrawableShape*)shape partcode:(NSInteger)pc delegate:(id)delegate
{
	self = [super init];
	if (self != nil) {
		[self setOwner:shape
			withPartcode:pc];
		NSAssert(m_partcode == pc, @"Expected m_partcode set to pc");
		m_relLoc = NSZeroPoint;
		NSAssert(NSEqualPoints(m_relLoc, NSZeroPoint), @"Expected init to zero");
		[self setDelegate:delegate];

		if (m_owner == nil) {
			return nil;
		}
	}
	return self;
}

#pragma mark -
@synthesize owner=m_owner;

- (void)setOwner:(DKDrawableShape*)shape withPartcode:(NSInteger)pc
{
	m_owner = shape;
	[self setPartcode:pc];
}

#pragma mark -
@synthesize partcode=m_partcode;
@synthesize relativeLocation=m_relLoc;

#pragma mark -
- (void)drawHotspotAtPoint:(NSPoint)p inState:(DKHotspotState)state
{
	[[self owner] drawHotspotAtPoint:p
							 inState:state];
}

#pragma mark -
@synthesize delegate=m_delegate;

#pragma mark -
- (void)startMouseTracking:(NSEvent*)event inView:(NSView*)view
{
	LogEvent_(kReactiveEvent, @"hotspot started tracking, partcode = %ld", (long)m_partcode);

	if ([self delegate] && [[self delegate] respondsToSelector:@selector(hotspot:
																   willBeginTrackingWithEvent:
																					   inView:)])
		[[self delegate] hotspot:self
			willBeginTrackingWithEvent:event
								inView:view];
}

- (void)continueMouseTracking:(NSEvent*)event inView:(NSView*)view
{
	//	LogEvent_(kReactiveEvent, @"hotspot continued tracking, partcode = %d", m_partcode );

	if ([self delegate] && [[self delegate] respondsToSelector:@selector(hotspot:
																   isTrackingWithEvent:
																				inView:)])
		[[self delegate] hotspot:self
			 isTrackingWithEvent:event
						  inView:view];
}

- (void)endMouseTracking:(NSEvent*)event inView:(NSView*)view
{
	LogEvent_(kReactiveEvent, @"hotspot stopped tracking, partcode = %ld", (long)m_partcode);

	if ([self delegate] && [[self delegate] respondsToSelector:@selector(hotspot:
																   didEndTrackingWithEvent:
																					inView:)])
		[[self delegate] hotspot:self
			didEndTrackingWithEvent:event
							 inView:view];
}

#pragma mark -
#pragma mark As an NSObject

- (instancetype)init
{
	return self = [self initHotspotWithOwner:nil partcode:0 delegate:nil];
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[coder encodeConditionalObject:m_owner
							forKey:@"owner"];
	[coder encodeInteger:m_partcode
				  forKey:@"partcode"];
	[coder encodePoint:m_relLoc
				forKey:@"relative_location"];
	[coder encodeConditionalObject:m_delegate
							forKey:@"delegate"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super init];
	if (self != nil) {
		m_owner = [coder decodeObjectForKey:@"owner"];
		m_partcode = [coder decodeIntegerForKey:@"partcode"];
		m_relLoc = [coder decodePointForKey:@"relative_location"];
		m_delegate = [coder decodeObjectForKey:@"delegate"];

		if (m_owner == nil) {
			return nil;
		}
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
#pragma unused(zone)

	DKHotspot* copy = [[DKHotspot alloc] init];
	copy.relativeLocation=m_relLoc;
	copy.partcode=m_partcode;

	return copy;
}

@end
