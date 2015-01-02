/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKRasterizer.h"
#import "DKStyle.h"
#import "LogEvent.h"
#import "NSBezierPath+Geometry.h"

NSString* kDKRasterizerPasteboardType = @"kDKRendererPasteboardType";
NSString* kDKRasterizerPropertyWillChange = @"kDKRasterizerPropertyWillChange";
NSString* kDKRasterizerPropertyDidChange = @"kDKRasterizerPropertyDidChange";
NSString* kDKRasterizerChangedPropertyKey = @"kDKRasterizerChangedPropertyKey";

@implementation DKRasterizer
#pragma mark As a DKRasterizer

+ (DKRasterizer*)rasterizerFromPasteboard:(NSPasteboard*)pb
{
	// creates a renderer from the pasteboard if possible. Returns the renderer, or nil.

	NSAssert(pb != nil, @"expected a non-nil pasteboard");

	DKRasterizer* rend = nil;
	NSString* typeString = [pb availableTypeFromArray:[NSArray arrayWithObject:kDKRasterizerPasteboardType]];

	if (typeString != nil) {
		NSData* data = [pb dataForType:typeString];

		if (data != nil)
			rend = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	}

	return rend;
}

/** @brief Returns the immediate container of this object, if owned by a group
 @return the object's container group, if any
 */
- (DKRastGroup*)container
{
	return mContainerRef;
}

/** @brief Sets the immediate container of this object

 This is a weak reference as the object is owned by its container. Generally this is called as
 required when the object is added to a group, so should not be used by app code
 @param container the objects's container - must be a group, or nil
 */
- (void)setContainer:(DKRastGroup*)container
{
	if (container != nil && ![container isKindOfClass:[DKRastGroup class]])
		[NSException raise:NSInternalInconsistencyException
					format:@"attempt to set the container to an illegal object type"];

	mContainerRef = container;
}

#pragma mark -

/** @brief Set the name of the renderer

 Named renderers can be referred to in scripts or bound to in the UI. The name is copied for safety.
 @param name the name to give the renderer
 */
- (void)setName:(NSString*)name
{
	NSString* nameCopy = [name copy];

	[m_name release];
	m_name = nameCopy;
}

/** @brief Get the name of the renderer

 Named renderers can be referred to in scripts or bound to in the UI
 @return the renderer's name
 */
- (NSString*)name
{
	return m_name;
}

/** @brief Get the name or classname of the renderer

 Named renderers can be referred to in scripts or bound to in the UI
 @return the renderer's name or classname
 */
- (NSString*)label
{
	if ([self name])
		return [self name];
	else
		return NSStringFromClass([self class]);
}

#pragma mark -

/** @brief Queries whether the renderer is valid, that is, it will draw something.

 Used to optimize drawing - invalid renderers are skipped
 @return YES if the renderer will draw something, NO otherwise
 */
- (BOOL)isValid
{
	return NO;
}

/** @brief Return the equivalent style script for this renderer

 Subclasses shold override this - the default method returns the object's description for debugging.
 @return a string, representing the script that would create an equivalent renderer if parsed
 */
- (NSString*)styleScript
{
	return [NSString stringWithFormat:@"(%@)", self];
}

#pragma mark -

/** @brief Set whether the renderer is enabled or not

 Disabled renderers won't draw anything, so this can be used to temporarily turn off part of a
 larget set of renderers (in a style, say) from the UI, but without actually deleting the renderer
 @param enable YES to enable, NO to disable
 */
- (void)setEnabled:(BOOL)enable
{
	m_enabled = enable;
}

/** @brief Query whether the renderer is enabled or not

 Disabled renderers won't draw anything, so this can be used to temporarily turn off part of a
 larget set of renderers (in a style, say) from the UI, but without actually deleting the renderer
 @return YES if enabled, NO if not
 */
- (BOOL)enabled
{
	return m_enabled;
}

/** @brief Set whether the rasterizer's effect is clipped to the path or not, and if so, which side
 @param clipping a DKClippingOption value
 */
- (void)setClipping:(DKClippingOption)clipping
{
	mClipping = clipping;
}

- (void)setClippingWithoutNotifying:(DKClippingOption)clipping
{
	mClipping = clipping;
}

/** @brief Whether the rasterizer's effect is clipped to the path or not, and if so, which side
 @return a DKClippingOption value
 */
- (DKClippingOption)clipping
{
	return mClipping;
}

#pragma mark -

/** @brief Returns the path to render given the object doing the rendering

 This method is called internally by render: to obtain the path to be rendered. It is factored to
 allow a delegate to modify the path just before rendering, and to allow special subclasses to
 override it to modify the path for special effects. The normal behaviour is simply to ask the
 object for its rendering path.
 @param object the object to render
 @return the rendering path */
- (NSBezierPath*)renderingPathForObject:(id<DKRenderable>)object
{
	return [object renderingPath];
}

- (BOOL)copyToPasteboard:(NSPasteboard*)pb
{
	NSAssert(pb != nil, @"expected pasteboard to be non-nil");

	NSData* data = [NSKeyedArchiver archivedDataWithRootObject:self];

	if (data != nil) {
		[pb declareTypes:[NSArray arrayWithObject:kDKRasterizerPasteboardType]
				   owner:self];
		return [pb setData:data
				   forType:kDKRasterizerPasteboardType];
	}

	return NO;
}

#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)observableKeyPaths
{
	return [NSArray arrayWithObjects:@"name", @"enabled", @"clipping", nil];
}

- (NSString*)actionNameForKeyPath:(NSString*)keypath changeKind:(NSKeyValueChange)kind
{
	if ([keypath isEqualToString:@"enabled"]) {
		if ([self enabled])
			return NSLocalizedString(@"Enable Style Component", @"undo string for enable component");
		else
			return NSLocalizedString(@"Disable Style Component", @"undo string for enable component");
	} else
		return [super actionNameForKeyPath:keypath
								changeKind:kind];
}

#pragma mark -
#pragma mark As an NSObject
- (void)dealloc
{
	[m_name release];
	[super dealloc];
}

- (id)init
{
	self = [super init];
	if (self != nil) {
		m_enabled = YES;
		mClipping = kDKClippingNone;
	}
	return self;
}

#pragma mark -
#pragma mark As part of DKRasterizer Protocol

/** @brief Returns the amount of extra space the renderer needs to draw its output over and above the bounds
 of the object or path requesting the render

 Default method returns zero extra space needed. Subclasses need to accurately return the amount
 needed. If they don't you risk drawing outside the object's bounds which will lead to improper
 updates and erasure of pixels.
 @return a size, the additional width and height needed
 */
- (NSSize)extraSpaceNeeded
{
	return NSZeroSize;
}

/** @brief Renders an object

 Default method extracts the path and calls -renderPath:
 @param object the object to render
 */
- (void)render:(id<DKRenderable>)object
{
	if (![object conformsToProtocol:@protocol(DKRenderable)])
		return;

	if ([self enabled]) {
		NSBezierPath* path = [self renderingPathForObject:object];
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

		[self renderPath:path];
		RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
	}
}

/** @brief Renders an object's path

 Default method does nothing. Subclasses will override this (or -render:) and implement the actual
 rendering
 @param path the path to render
 */
- (void)renderPath:(NSBezierPath*)path
{
#pragma unused(path)

	// placeholder
}

/** @brief Queries whther the rasterizer implements a fill or not

 Default is NO - subclasses must override to return this appropriately. A style uses this result
 to determine whether it implements any fills, which in turn affect swatches, object hit-testing
 and so on.
 @return YES if the rasterizer is considered a fill type
 */
- (BOOL)isFill
{
	return NO;
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[coder encodeObject:[self name]
				 forKey:@"name"];
	[coder encodeBool:[self enabled]
			   forKey:@"enabled"];
	[coder encodeInteger:[self clipping]
				  forKey:@"DKRasterizer_clipping"];
}

- (id)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super init];
	if (self != nil) {
		[self setName:[coder decodeObjectForKey:@"name"]];
		[self setEnabled:[coder decodeBoolForKey:@"enabled"]];
		[self setClipping:[coder decodeIntegerForKey:@"DKRasterizer_clipping"]];
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
	DKRasterizer* copy = [[[self class] allocWithZone:zone] init];

	[copy setName:[self name]];
	[copy setEnabled:[self enabled]];
	[copy setClipping:[self clipping]];

	return copy;
}

#pragma mark -
#pragma mark As part of NSKeyValueObserving Protocol

/** @brief Intercepts impending change via KVC to force an update of any client objects

 Assumes top level of hierarchy is in fact a style. In practice it nearly always will be, but if
 not should not cause any problems. This also sends a notificaiton which can be used in more
 general-purpose situations such as when a rasterizer is used without a style.
 @param key the key for the value about to be changed
 */
- (void)willChangeValueForKey:(NSString*)key
{
	LogEvent_(kKVOEvent, @"%@ about to change '%@'", self, key);

	NSDictionary* info = [NSDictionary dictionaryWithObject:key
													 forKey:kDKRasterizerChangedPropertyKey];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKRasterizerPropertyWillChange
														object:self
													  userInfo:info];

	id top = [[self container] root];

	if (top && [top respondsToSelector:@selector(notifyClientsBeforeChange)])
		[top notifyClientsBeforeChange];

	[super willChangeValueForKey:key];
}

/** @brief Notifies that a property change took place

 Sends a notificaiton which can be used in more
 general-purpose situations such as when a rasterizer is used without a style.
 @param key the key for the value that was changed
 */
- (void)didChangeValueForKey:(NSString*)key
{
	[super didChangeValueForKey:key];

	NSDictionary* info = [NSDictionary dictionaryWithObject:key
													 forKey:kDKRasterizerChangedPropertyKey];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKRasterizerPropertyDidChange
														object:self
													  userInfo:info];
}

@end

#pragma mark -
@implementation NSObject (DKRendererDelegate)
#pragma mark Renderer Delegate
- (NSBezierPath*)renderer:(DKRasterizer*)aRenderer willRenderPath:(NSBezierPath*)aPath
{
#pragma unused(aRenderer)

	// default is to return the path entirely unmodified

	return aPath;
}

@end
