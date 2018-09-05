/**
 @author Jason Job
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKGradientExtensions.h"

#import "LogEvent.h"

@implementation NSView (DKGradientExtensions)

- (void)dragStandardSwatchGradient:(DKGradient*)gradient slideBack:(BOOL)slideBack event:(NSEvent*)event
{
	NSSize size;
	size.width = 28;
	size.height = 28;
	[self dragGradient:gradient
			swatchSize:size
			 slideBack:slideBack
				 event:event];
}

- (void)dragGradient:(DKGradient*)gradient swatchSize:(NSSize)size slideBack:(BOOL)slideBack event:(NSEvent*)event
{
	if (gradient == nil)
		return;

	NSPoint pt = [event locationInWindow];
	pt = [self convertPoint:pt
				   fromView:nil];

	NSImage* swatchImage = [gradient swatchImageWithSize:size
											  withBorder:YES];
	NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSDragPboard];

	// this method must not write data to the pasteboard. That must have been done prior to calling it.	That's because
	// the gradient object does not have a single pasteboard representation - it depends on the context of the drag.

	//	[gradient writeToPasteboard:pboard];
	//	[gradient writeFileToPasteboard:pboard];

	pt.x -= size.width / 2;
	pt.y += size.height / 2;

	[[NSCursor currentCursor] push];
	[[NSCursor closedHandCursor] set];

	[self dragImage:swatchImage
				 at:pt
			 offset:size
			  event:event
		 pasteboard:pboard
			 source:self
		  slideBack:slideBack];

	[NSCursor pop];
}

- (void)dragColor:(NSColor*)color swatchSize:(NSSize)size slideBack:(BOOL)slideBack event:(NSEvent*)event
{
	NSPoint pt = [event locationInWindow];
	pt = [self convertPoint:pt
				   fromView:nil];
	NSImage* swatchImage = [color swatchImageWithSize:size
										   withBorder:YES];

	NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[pboard declareTypes:@[NSPasteboardTypeColor]
				   owner:self];
	[color writeToPasteboard:pboard];

	pt.x -= size.width / 2;
	pt.y -= size.height / 2;

	[self dragImage:swatchImage
				 at:pt
			 offset:size
			  event:event
		 pasteboard:pboard
			 source:self
		  slideBack:slideBack];
}

@end

#pragma mark -
@implementation NSColor (DKGradientExtensions)

- (NSImage*)swatchImageWithSize:(NSSize)size withBorder:(BOOL)showBorder
{
	NSImage* swatchImage = [[NSImage alloc] initWithSize:size];
	NSRect box = NSMakeRect(0.0, 0.0, size.width, size.height);

	[[NSGraphicsContext currentContext] saveGraphicsState];
	[swatchImage lockFocus];
	[self drawSwatchInRect:box];

	if (showBorder) {
		[[NSColor grayColor] set];
		NSFrameRectWithWidth(box, 1.0);
	}
	[swatchImage unlockFocus];
	[[NSGraphicsContext currentContext] restoreGraphicsState];

	return swatchImage;
}

@end

#pragma mark -
@implementation DKGradient (DKGradientPlistTransformations)

+ (BOOL)supportsSimpleDictionaryKeyValueCoding
{
	return YES;
}
- (BOOL)supportsSimpleDictionaryKeyValueCoding
{
	return YES;
}

@end

#pragma mark -
@implementation DKColorStop (DKGradientPlistTransformations)

+ (BOOL)supportsSimpleDictionaryKeyValueCoding
{
	return YES;
}
- (BOOL)supportsSimpleDictionaryKeyValueCoding
{
	return YES;
}

@end

#pragma mark -
@implementation DKGradient (DKGradientExtensions)

- (void)setUpExtensionData
{
	if (m_extensionData == nil) {
		m_extensionData = [[NSMutableDictionary alloc] init];
	}
}

#pragma mark -
- (void)setRadialStartingPoint:(NSPoint)p
{
	[self setUpExtensionData];
	[m_extensionData setPoint:p
					   forKey:@"radialstartingpoint"];
}

- (void)setRadialEndingPoint:(NSPoint)p
{
	[self setUpExtensionData];
	[m_extensionData setPoint:p
					   forKey:@"radialendingpoint"];
}

- (void)setRadialStartingRadius:(CGFloat)rad
{
	[self setUpExtensionData];
	[m_extensionData setFloat:rad
					   forKey:@"radialstartingradius"];
}

- (void)setRadialEndingRadius:(CGFloat)rad
{
	[self setUpExtensionData];
	[m_extensionData setFloat:rad
					   forKey:@"radialendingradius"];
}

#pragma mark -
- (NSPoint)radialStartingPoint
{
	return [m_extensionData pointForKey:@"radialstartingpoint"];
}

- (NSPoint)radialEndingPoint
{
	return [m_extensionData pointForKey:@"radialendingpoint"];
}

- (CGFloat)radialStartingRadius
{
	return [m_extensionData floatForKey:@"radialstartingradius"];
}

- (CGFloat)radialEndingRadius
{
	return [m_extensionData floatForKey:@"radialendingradius"];
}

#pragma mark -
- (BOOL)hasRadialSettings
{
	if (m_extensionData)
		return ([m_extensionData valueForKey:@"radialstartingpoint.x"] != nil && [m_extensionData valueForKey:@"radialendingpoint.x"] != nil);

	return NO;
}

#pragma mark -
- (NSPoint)mapPoint:(NSPoint)p fromRect:(NSRect)rect
{
	p.x = (p.x - rect.origin.x) / rect.size.width;
	p.y = (p.y - rect.origin.y) / rect.size.height;

	return p;
}

- (NSPoint)mapPoint:(NSPoint)p toRect:(NSRect)rect
{
	p.x = (p.x * rect.size.width) + rect.origin.x;
	p.y = (p.y * rect.size.height) + rect.origin.y;

	return p;
}

#pragma mark -
- (void)convertOldKey:(NSString*)key
{
	//	LogEvent_(kReactiveEvent, @"converting old key: %@ in %@", key, self );

	NSPoint p = [[m_extensionData valueForKey:key] pointValue];
	[m_extensionData removeObjectForKey:key];
	[m_extensionData setPoint:p
					   forKey:key];
}

- (void)convertOldKeys
{
	for (NSString* key in m_extensionData) {
		NSValue* value = [m_extensionData valueForKey:key];

		if ([value isKindOfClass:[NSValue class]]) {
			const char* ctyp = [value objCType];

			if (strcmp(ctyp, @encode(NSPoint)) == 0)
				[self convertOldKey:key];
		}
	}
}

@end

#pragma mark -
@implementation NSDictionary (StructEncoding)

- (NSPoint)pointForKey:(id)key
{
	NSPoint p;

	p.x = [self floatForKey:[key stringByAppendingString:@".x"]];
	p.y = [self floatForKey:[key stringByAppendingString:@".y"]];
	return p;
}

#pragma mark -
- (float)floatForKey:(id)key
{
	return [[self objectForKey:key] floatValue];
}

@end

#pragma mark -
@implementation NSMutableDictionary (StructEncoding)

- (void)setPoint:(NSPoint)p forKey:(id)key
{
	[self setFloat:p.x
			forKey:[key stringByAppendingString:@".x"]];
	[self setFloat:p.y
			forKey:[key stringByAppendingString:@".y"]];
}

#pragma mark -
- (void)setFloat:(float)f forKey:(id)key
{
	[self setObject:@(f)
			 forKey:key];
}

@end
