///**********************************************************************************************************************************
///  DKCIFilterRastGroup.m
///  DrawKit
///
///  Created by graham on 16/03/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKCIFilterRastGroup.h"

#import "LogEvent.h"
#import "NSDictionary+DeepCopy.h"
#import "DKDrawableObject.h"

#import <QuartzCore/QuartzCore.h>


@implementation DKCIFilterRastGroup
#pragma mark As a DKCIFilterRastGroup
+ (DKCIFilterRastGroup*)	effectGroupWithFilter:(NSString*) filter
{
	DKCIFilterRastGroup* fg = [[DKCIFilterRastGroup alloc] init];
	
	[fg setFilter:filter];
	
	return [fg autorelease];
}


#pragma mark -
- (void)					setFilter:(NSString*) filter
{
	LogEvent_(kStateEvent, @"setting fx filter: %@", filter);
	
	if ( filter != [self filter])
	{
		[filter retain];
		[m_filter release];
		m_filter = filter;
	
		[self invalidateCache];
	}
}


- (NSString*)				filter
{
	return m_filter;
}


#pragma mark -
- (void)					setArguments:(NSDictionary*) dict
{
	[dict retain];
	[m_arguments release];
	m_arguments = dict;
}


- (NSDictionary*)			arguments
{
	return m_arguments;
}


#pragma mark -
- (void)					setClipsToPath:(BOOL) ctp
{
	m_clipToPath = ctp;
}


- (BOOL)					clipsToPath
{
	return m_clipToPath;
}


#pragma mark -
- (void)					invalidateCache
{
	[m_cache release];
	m_cache = nil;
}


#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)				observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"clipsToPath", @"filter", @"arguments", nil ]];
}


- (void)					registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Clips To Path" forKeyPath:@"clipsToPath"];
	[self setActionName:@"#kind# Filter Type" forKeyPath:@"filter"];
	[self setActionName:@"#kind# Filter Attributes" forKeyPath:@"arguments"];
}


#pragma mark -
#pragma mark As an NSObject
- (void)					dealloc
{
	[m_cache release];
	[m_arguments release];
	[m_filter release];
	
	[super dealloc];
}


- (id)						init
{
	self = [super init];
	if (self != nil)
	{
		[self setFilter:@"CIOpTile"];	//CIVortexDistortion
		NSAssert(m_arguments == nil, @"Expected init to zero");
		NSAssert(m_cache == nil, @"Expected init to zero");
		
		m_clipToPath = YES;
		
		if (m_filter == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	
	return self;
}


#pragma mark -
#pragma mark As part of DKRasterizerProtocol
- (NSSize)		extraSpaceNeeded
{
	NSSize es = [super extraSpaceNeeded];
	
	if(![self clipsToPath])
	{
		es.width += (CIIMAGE_PADDING * 2);
		es.height += (CIIMAGE_PADDING * 2);
	}
	return es;
}


- (void)		render:(DKDrawableObject*) object
{
	if ( ![self enabled])
		return;
	
	NSRect	br = [[self renderingPathForObject:object] bounds];
	NSSize	extra = [self extraSpaceNeeded];
	
	NSRect imgRect = NSInsetRect( br, -extra.width, -extra.height );
	
	if( m_cache )
	{
	
	
	}
	else
	{
		NSImage* image = [[NSImage alloc] initWithSize:imgRect.size];
		[image setFlipped:YES];
		
		NSAffineTransform*	tfm = [NSAffineTransform transform];
		[tfm translateXBy:extra.width - br.origin.x yBy:extra.height - br.origin.y];
		//[tfm scaleXBy:1.0 yBy:-1.0];
		
		[image lockFocus];
		[tfm set];
		
		[super render:object];
		
		[image unlockFocus];
		
		// captured, now render it back to the drawing, applying the filter
		
		NSRect fr = NSZeroRect;
		fr.size = imgRect.size;
		
		[NSGraphicsContext saveGraphicsState];

		if([self clipsToPath])
			[[self renderingPathForObject:object] addClip];
			
		NSArray* inputKeys = [[CIFilter filterWithName:[self filter]] inputKeys];
		
		//NSLog(@"input keys = %@", inputKeys);
		
		NSMutableDictionary*	args = [[self arguments] mutableCopy];

		if([inputKeys containsObject:@"inputCenter"])
		{
			// if the arguments don't contain a centre value, set it from the object's offset
			
			if ( args == nil )
				args = [[NSMutableDictionary alloc] init];
			
			NSPoint					pp;
			
			pp.x = imgRect.size.width * 0.5f + ( [object offset].width * [object size].width );
			pp.y = imgRect.size.height * 0.5f + ( [object offset].height * [object size].height);
			
			[args setObject:[CIVector vectorWithX:pp.x Y:pp.y] forKey:@"inputCenter"];
		}
		
		[image drawAtPoint:imgRect.origin fromRect:fr coreImageFilter:[self filter] arguments:args];
		[NSGraphicsContext restoreGraphicsState];
		[image release];
		
		[args release];
	}
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)					encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self filter] forKey:@"filter"];
	[coder encodeObject:[self arguments] forKey:@"arguments"];
	[coder encodeBool:[self clipsToPath] forKey:@"DKCIFilterRastGroup_clipsToPath"];
}


- (id)						initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setFilter:[coder decodeObjectForKey:@"filter"]];
		[self setArguments:[coder decodeObjectForKey:@"arguments"]];
		[self setClipsToPath:[coder decodeBoolForKey:@"DKCIFilterRastGroup_clipsToPath"]];
		
		if (m_filter == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)						copyWithZone:(NSZone*) zone
{
	DKCIFilterRastGroup* copy = [super copyWithZone:zone];
	
	[copy setFilter:[self filter]];
	[copy setArguments:[[self arguments] deepCopy]];
	
	return copy;
}


@end


#pragma mark -
@implementation NSImage (CoreImage)
#pragma mark As an NSImage
- (NSBitmapImageRep *)	bitmapImageRepresentation
{
	NSImageRep *rep;
	NSEnumerator *e;
	Class bitmapImageRep;

	bitmapImageRep = [NSBitmapImageRep class];
	e = [[self representations] objectEnumerator];
	
	while ((rep = [e nextObject]) != nil)
	{
		if ([rep isKindOfClass: bitmapImageRep])
			break;
	}
	
	if (!rep)
		rep = [NSBitmapImageRep imageRepWithData:[self TIFFRepresentation]];
	
	return (NSBitmapImageRep *) rep;
}


- (void)				drawAtPoint:(NSPoint) point fromRect:(NSRect) fromRect coreImageFilter:(NSString*) filterName arguments:(NSDictionary*) arguments
{
	NSAutoreleasePool *pool;
	NSBitmapImageRep *rep;
		
	pool = [[NSAutoreleasePool alloc] init];
	
	if (filterName)
	{
		rep = [self bitmapImageRepresentation];
		[rep drawAtPoint: point fromRect:fromRect coreImageFilter:filterName arguments:arguments];
	}
	else
		[self drawAtPoint: point fromRect:fromRect operation:NSCompositeSourceOver fraction:1.0f];

	[pool release];
}


@end



#pragma mark -
@implementation NSBitmapImageRep (CoreImage)
#pragma mark As an NSBitmapImageRep
- (void)			drawAtPoint:(NSPoint) point fromRect:(NSRect) fromRect coreImageFilter:(NSString *) filterName arguments:(NSDictionary *) arguments
{
	NSAutoreleasePool *pool;
	CIFilter *filter;
	CIImage *before;
	CIImage *after;
	CIContext *ciContext;
	
	pool = [[NSAutoreleasePool alloc] init];
	before = nil;
	
	@try 
	{
		before = [[CIImage alloc] initWithBitmapImageRep: self];
		if (before)
		{
			filter = [CIFilter filterWithName: filterName];
			[filter setDefaults];
			if (arguments)
				[filter setValuesForKeysWithDictionary: arguments];
			[filter setValue: before forKey: @"inputImage"];
		}
		else
			filter = nil;
		
		after = [filter valueForKey: @"outputImage"];		
		if (after)
		{
			if (![[arguments objectForKey: @"gt_noRenderPadding"] boolValue])
			{
				/* Add a wide berth to the bounds -- the padding can be turned
				   off by passing an NSNumber with a YES value in the argument
				   "gt_noRenderPadding" in the argument dictionary. */
				fromRect.origin.x -= CIIMAGE_PADDING;
				fromRect.origin.y -= CIIMAGE_PADDING;
				fromRect.size.width += CIIMAGE_PADDING * 2.0f;
				fromRect.size.height += CIIMAGE_PADDING * 2.0f;
				point.x -= CIIMAGE_PADDING;
				point.y -= CIIMAGE_PADDING;
			}

			ciContext = [[NSGraphicsContext currentContext] CIContext];
			[ciContext drawImage:after atPoint:*(CGPoint *)(&point) fromRect:*(CGRect *)(&fromRect)];
		}
	}
	@catch (NSException *e)
	{
		LogEvent_(kWheneverEvent, @"exception encountered during core image filtering: %@", e);
	}
	@finally
	{
		[before release];
	}
	
	[pool release];
}


@end
