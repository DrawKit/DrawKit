//
//  DKGradientExtensions.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by Jason Jobe on 3/3/07.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKGradientExtensions.h"

#import "LogEvent.h"


@implementation NSView (DKGradientExtensions)

- (void) dragStandardSwatchGradient:(DKGradient*)gradient slideBack:(BOOL)slideBack event:(NSEvent *)event
{
	NSSize size;
	size.width = 28;
	size.height = 28;
	[self dragGradient:gradient swatchSize:size slideBack:slideBack event:event];
}

- (void) dragGradient:(DKGradient*)gradient swatchSize:(NSSize)size slideBack:(BOOL)slideBack event:(NSEvent*) event
{
	if ( gradient == nil )
		return;

	NSPoint pt = [event locationInWindow];
	pt = [self convertPoint:pt fromView:nil];
	
	NSImage *swatchImage = [gradient swatchImageWithSize:size withBorder:YES];
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];

	// this method must not write data to the pasteboard. That must have been done prior to calling it.	That's because
	// the gradient object does not have a single pasteboard representation - it depends on the context of the drag.
	
	//	[gradient writeToPasteboard:pboard];
	//	[gradient writeFileToPasteboard:pboard];
	
	pt.x -= size.width/2;
	pt.y += size.height/2;
	
	[swatchImage setFlipped:NO];
	
	[[NSCursor currentCursor] push];
	[[NSCursor closedHandCursor] set];

	[self dragImage:swatchImage at:pt offset:size event:event
		 pasteboard:pboard
			 source:self slideBack:slideBack];
			 
	[NSCursor pop];
}

- (void) dragColor:(NSColor*)color swatchSize:(NSSize)size slideBack:(BOOL)slideBack event:(NSEvent *)event
{
	NSPoint pt = [event locationInWindow];
	pt = [self convertPoint:pt fromView:nil];
	NSImage *swatchImage = [color swatchImageWithSize:size withBorder:YES];
	
	
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[pboard declareTypes:[NSArray arrayWithObject:NSColorPboardType] owner:self];
	[color writeToPasteboard:pboard];
	
	pt.x -= size.width/2;
	pt.y -= size.height/2;
	
	[self dragImage:swatchImage at:pt offset:size event:event
		 pasteboard:pboard
			 source:self slideBack:slideBack];
}

@end


#pragma mark -
@implementation NSColor (DKGradientExtensions)

- (NSImage*) swatchImageWithSize:(NSSize) size withBorder:(BOOL) showBorder
{
	NSImage *swatchImage = [[NSImage alloc] initWithSize:size];
	NSRect box = NSMakeRect(0.0, 0.0, size.width, size.height);
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	[swatchImage lockFocus];
	[self drawSwatchInRect:box];
	
	if (showBorder)
	{
		[[NSColor grayColor] set];
		NSFrameRectWithWidth( box, 1.0 );
	}
	[swatchImage unlockFocus];
	[[NSGraphicsContext currentContext] restoreGraphicsState];
	
	return [swatchImage autorelease];
}

@end


#pragma mark -
@implementation DKGradient (DKGradientPlistTransformations)

+ (BOOL) supportsSimpleDictionaryKeyValueCoding { return YES; }
- (BOOL) supportsSimpleDictionaryKeyValueCoding { return YES; }

@end


#pragma mark -
@implementation DKColorStop (DKGradientPlistTransformations)

+ (BOOL) supportsSimpleDictionaryKeyValueCoding { return YES; }
- (BOOL) supportsSimpleDictionaryKeyValueCoding { return YES; }

@end


#pragma mark -
@implementation DKGradient (DKGradientExtensions)

- (void)		setUpExtensionData
{
	if (m_extensionData == nil)
	{
		m_extensionData = [[NSMutableDictionary alloc] init];
	}
}


#pragma mark -
- (void)		setRadialStartingPoint:(NSPoint) p
{
	[self setUpExtensionData];
	[m_extensionData setPoint:p forKey:@"radialstartingpoint"];
}


- (void)		setRadialEndingPoint:(NSPoint) p
{
	[self setUpExtensionData];
	[m_extensionData setPoint:p forKey:@"radialendingpoint"];
}


- (void)		setRadialStartingRadius:(CGFloat) rad
{
	[self setUpExtensionData];
	[m_extensionData setFloat:rad forKey:@"radialstartingradius"];
}


- (void)		setRadialEndingRadius:(CGFloat) rad
{
	[self setUpExtensionData];
	[m_extensionData setFloat:rad forKey:@"radialendingradius"];
}


#pragma mark -
- (NSPoint)		radialStartingPoint
{
	return [m_extensionData pointForKey:@"radialstartingpoint"];
}


- (NSPoint)		radialEndingPoint
{
	return [m_extensionData pointForKey:@"radialendingpoint"];
}


- (CGFloat)		radialStartingRadius;
{
	return [m_extensionData floatForKey:@"radialstartingradius"];
}


- (CGFloat)		radialEndingRadius
{
	return [m_extensionData floatForKey:@"radialendingradius"];
}


#pragma mark -
- (BOOL)		hasRadialSettings
{
	// return YES if there are valid radial settings. 
	
	if ( m_extensionData )
		return ([m_extensionData valueForKey:@"radialstartingpoint.x"] != nil && [m_extensionData valueForKey:@"radialendingpoint.x"] != nil );
	
	return NO;
}


#pragma mark -
- (NSPoint)		mapPoint:(NSPoint) p fromRect:(NSRect) rect
{
	// given a point <p> within <rect> this returns it mapped to a 0..1 interval
	
	p.x = ( p.x - rect.origin.x ) / rect.size.width;
	p.y = ( p.y - rect.origin.y ) / rect.size.height;
	
	return p;
}


- (NSPoint)		mapPoint:(NSPoint) p toRect:(NSRect) rect
{
	// given a point <p> in 0..1 space, maps it to <rect>
	
	p.x = ( p.x * rect.size.width ) + rect.origin.x;
	p.y = ( p.y * rect.size.height ) + rect.origin.y;
	
	return p;
}


#pragma mark -
- (void)		convertOldKey:(NSString*) key
{
	// given a key to an old NSPoint based struct, this converts it to the new archiver-compatible storage
//	LogEvent_(kReactiveEvent, @"converting old key: %@ in %@", key, self );
	
	NSPoint p = [[m_extensionData valueForKey:key] pointValue];
	[m_extensionData removeObjectForKey:key];
	[m_extensionData setPoint:p forKey:key]; 
}


- (void)		convertOldKeys
{
	NSEnumerator*	iter = [[m_extensionData allKeys] objectEnumerator];
	NSString*		key;
	id				value;
	const char*		ctyp;
	
	while(( key = [iter nextObject]))
	{
		value = [m_extensionData valueForKey:key];
		
		if ([value isKindOfClass:[NSValue class]])
		{
			ctyp = [value objCType];
			
			if ( strcmp( ctyp, @encode(NSPoint)) == 0 )
				[self convertOldKey:key];
		}
	}
}


@end


#pragma mark -
@implementation NSDictionary (StructEncoding)

- (void)		setPoint:(NSPoint) p forKey:(id) key
{
	[self setFloat:p.x forKey:[key stringByAppendingString:@".x"]];
	[self setFloat:p.y forKey:[key stringByAppendingString:@".y"]];
}


- (NSPoint)		pointForKey:(id) key
{
	NSPoint p;
	
	p.x = [self floatForKey:[key stringByAppendingString:@".x"]];
	p.y = [self floatForKey:[key stringByAppendingString:@".y"]];
	return p;
}


#pragma mark -
- (void)		setFloat:(float) f forKey:(id) key
{
	[self setValue:[NSNumber numberWithDouble:f] forKey:key];
}


- (float)floatForKey:(id) key
{
	return [[self valueForKey:key] doubleValue];
}


@end
