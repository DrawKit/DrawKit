/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKCIFilterRastGroup.h"

#import "LogEvent.h"
#import "NSDictionary+DeepCopy.h"
#import "DKDrawableObject.h"
#import "NSBezierPath+Geometry.h"
#import <QuartzCore/QuartzCore.h>

@implementation DKCIFilterRastGroup
#pragma mark As a DKCIFilterRastGroup

+ (DKCIFilterRastGroup*)effectGroupWithFilter:(NSString*)filter
{
	DKCIFilterRastGroup* fg = [[self alloc] init];

	[fg setFilter:filter];

	return fg;
}

#pragma mark -
- (void)setFilter:(NSString*)filter
{
	LogEvent_(kStateEvent, @"setting fx filter: %@", filter);

	if (![filter isEqualToString:self.filter]) {
		m_filter = [filter copy];

		[self invalidateCache];
	}
}

@synthesize filter=m_filter;
@synthesize arguments=m_arguments;

#pragma mark -
- (void)invalidateCache
{
	m_cache = nil;
}

#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:@[@"filter", @"arguments"]];
}

- (void)registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Filter Type"
			 forKeyPath:@"filter"];
	[self setActionName:@"#kind# Filter Attributes"
			 forKeyPath:@"arguments"];
}

#pragma mark -
#pragma mark As an NSObject
- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		[self setFilter:@"CIOpTile"]; //CIVortexDistortion
		[self setClipping:kDKClippingInsidePath];

		if (m_filter == nil) {
			return nil;
		}
	}

	return self;
}

#pragma mark -
#pragma mark As part of DKRasterizerProtocol
- (NSSize)extraSpaceNeeded
{
	NSSize es = [super extraSpaceNeeded];

	if ([self clipping] != kDKClippingInsidePath) {
		es.width += (CIIMAGE_PADDING * 2);
		es.height += (CIIMAGE_PADDING * 2);
	}
	return es;
}

- (void)render:(DKDrawableObject*)object
{
	if (![self enabled])
		return;

	NSBezierPath* path = [self renderingPathForObject:object];
	NSRect br = [path bounds];
	NSSize extra = [self extraSpaceNeeded];

	NSRect imgRect = NSInsetRect(br, -extra.width, -extra.height);

	if (m_cache) {

	} else {
		NSImage* image = [[NSImage alloc] initWithSize:imgRect.size];
		[image setFlipped:YES];

		NSAffineTransform* tfm = [NSAffineTransform transform];
		[tfm translateXBy:extra.width - br.origin.x
					  yBy:extra.height - br.origin.y];
		//[tfm scaleXBy:1.0 yBy:-1.0];

		[image lockFocus];
		[tfm set];

		DKClippingOption saveClipping = [self clipping];
		[self setClippingWithoutNotifying:kDKClippingNone];

		[super render:object];
		[self setClippingWithoutNotifying:saveClipping];

		[image unlockFocus];

		// captured, now render it back to the drawing, applying the filter

		NSRect fr = NSZeroRect;
		fr.size = imgRect.size;

		SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
			switch ([self clipping])
		{
		default:
		case kDKClippingNone:
			break;

		case kDKClipInsidePath:
			[path addClip];
			break;

		case kDKClipOutsidePath:
			[path addInverseClip];
			break;
		}

		NSArray* inputKeys = [[CIFilter filterWithName:[self filter]] inputKeys];

		//NSLog(@"input keys = %@", inputKeys);

		NSMutableDictionary* args = [[self arguments] mutableCopy];

		if ([inputKeys containsObject:@"inputCenter"]) {
			// if the arguments don't contain a centre value, set it from the object's offset

			if (args == nil)
				args = [[NSMutableDictionary alloc] init];

			NSPoint pp;

			pp.x = imgRect.size.width * 0.5 + ([object offset].width * [object size].width);
			pp.y = imgRect.size.height * 0.5 + ([object offset].height * [object size].height);

			[args setObject:[CIVector vectorWithX:pp.x
												Y:pp.y]
					 forKey:@"inputCenter"];
		}

		[image drawInRect:imgRect
				 fromRect:fr
		  coreImageFilter:[self filter]
				arguments:args];

		RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
	}
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];

	[coder encodeObject:[self filter]
				 forKey:@"filter"];
	[coder encodeObject:[self arguments]
				 forKey:@"arguments"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil) {
		[self setFilter:[coder decodeObjectForKey:@"filter"]];
		[self setArguments:[coder decodeObjectForKey:@"arguments"]];

		BOOL clip = [coder decodeBoolForKey:@"DKCIFilterRastGroup_clipsToPath"];

		if (clip)
			[self setClipping:kDKClipInsidePath];

		if (m_filter == nil) {
			return nil;
		}
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
	DKCIFilterRastGroup* copy = [super copyWithZone:zone];

	[copy setFilter:[self filter]];

	NSDictionary* args = [[self arguments] deepCopy];
	[copy setArguments:args];

	return copy;
}

@end

#pragma mark -
@implementation NSImage (CoreImage)
#pragma mark As an NSImage
- (NSBitmapImageRep*)bitmapImageRepresentation
{
	Class bitmapImageRep = [NSBitmapImageRep class];

	for (NSImageRep* rep in [self representations]) {
		if ([rep isKindOfClass:bitmapImageRep]) {
			return (NSBitmapImageRep*)rep;
		}
	}

	return [NSBitmapImageRep imageRepWithData:[self TIFFRepresentation]];
}

- (void)drawAtPoint:(NSPoint)point fromRect:(NSRect)fromRect coreImageFilter:(NSString*)filterName arguments:(NSDictionary*)arguments
{
	NSBitmapImageRep* rep;

	@autoreleasepool {

		if (filterName) {
			rep = [self bitmapImageRepresentation];
			[rep drawAtPoint:point
					   fromRect:fromRect
				coreImageFilter:filterName
					  arguments:arguments];
		} else
			[self drawAtPoint:point
					 fromRect:fromRect
					operation:NSCompositeSourceOver
					 fraction:1.0];

	}
}

- (void)drawInRect:(NSRect)inrect fromRect:(NSRect)fromRect coreImageFilter:(NSString*)filterName arguments:(NSDictionary*)arguments
{
	NSBitmapImageRep* rep;
	
	@autoreleasepool {
		
		if (filterName) {
			rep = [self bitmapImageRepresentation];
			[rep drawInRect:inrect
				   fromRect:fromRect
			coreImageFilter:filterName
				  arguments:arguments];
		} else {
			[self drawInRect:inrect
					fromRect:fromRect
				   operation:NSCompositeSourceOver
					fraction:1.0];
		}
	}
}


@end

#pragma mark -
@implementation NSBitmapImageRep (CoreImage)
#pragma mark As an NSBitmapImageRep
- (void)drawAtPoint:(NSPoint)point fromRect:(NSRect)fromRect coreImageFilter:(NSString*)filterName arguments:(NSDictionary*)arguments
{
	CIFilter* filter;
	CIImage* before;
	CIImage* after;
	CIContext* ciContext;

	@autoreleasepool {
		before = nil;

		@try
		{
			before = [[CIImage alloc] initWithBitmapImageRep:self];
			if (before) {
				filter = [CIFilter filterWithName:filterName];
				[filter setDefaults];
				if (arguments)
					[filter setValuesForKeysWithDictionary:arguments];
				[filter setValue:before
						  forKey:@"inputImage"];
			} else
				filter = nil;

			after = [filter valueForKey:@"outputImage"];
			if (after) {
				if (![[arguments objectForKey:@"gt_noRenderPadding"] boolValue]) {
					/* Add a wide berth to the bounds -- the padding can be turned
					   off by passing an NSNumber with a YES value in the argument
					   "gt_noRenderPadding" in the argument dictionary. */
					fromRect.origin.x -= CIIMAGE_PADDING;
					fromRect.origin.y -= CIIMAGE_PADDING;
					fromRect.size.width += CIIMAGE_PADDING * 2.0;
					fromRect.size.height += CIIMAGE_PADDING * 2.0;
					point.x -= CIIMAGE_PADDING;
					point.y -= CIIMAGE_PADDING;
				}

				ciContext = [[NSGraphicsContext currentContext] CIContext];
				[ciContext drawImage:after
							 atPoint:NSPointToCGPoint(point)
							fromRect:NSRectToCGRect(fromRect)];
			}
		}
		@catch (NSException* e)
		{
			LogEvent_(kWheneverEvent, @"exception encountered during core image filtering: %@", e);
		}
		@finally
		{
			before = nil;
		}

	}
}

- (void)drawInRect:(NSRect)inrect fromRect:(NSRect)fromRect coreImageFilter:(NSString*)filterName arguments:(NSDictionary<NSString*,id>*)arguments;
{
	CIFilter* filter;
	CIImage* before = nil;
	CIImage* after;
	CIContext* ciContext;
	
	@autoreleasepool {
		@try {
			before = [[CIImage alloc] initWithBitmapImageRep:self];
			if (before) {
				filter = [CIFilter filterWithName:filterName];
				[filter setDefaults];
				if (arguments)
					[filter setValuesForKeysWithDictionary:arguments];
				[filter setValue:before
						  forKey:@"inputImage"];
			} else
				filter = nil;
			
			after = [filter valueForKey:@"outputImage"];
			if (after) {
				if (![[arguments objectForKey:@"gt_noRenderPadding"] boolValue]) {
					/* Add a wide berth to the bounds -- the padding can be turned
					 off by passing an NSNumber with a YES value in the argument
					 "gt_noRenderPadding" in the argument dictionary. */
					fromRect.origin.x -= CIIMAGE_PADDING;
					fromRect.origin.y -= CIIMAGE_PADDING;
					fromRect.size.width += CIIMAGE_PADDING * 2.0;
					fromRect.size.height += CIIMAGE_PADDING * 2.0;
					inrect.origin.x -= CIIMAGE_PADDING;
					inrect.origin.y -= CIIMAGE_PADDING;
					inrect.size.width += CIIMAGE_PADDING * 2.0;
					inrect.size.height += CIIMAGE_PADDING * 2.0;
				}
				
				ciContext = [[NSGraphicsContext currentContext] CIContext];
				[ciContext drawImage:after
							  inRect:NSRectToCGRect(inrect)
							fromRect:NSRectToCGRect(fromRect)];
			}
		} @catch (NSException* e) {
			LogEvent_(kWheneverEvent, @"exception encountered during core image filtering: %@", e);
		} @finally {
			before = nil;
		}
	}
}

@end
