/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKReshapableShape.h"

#import "DKGeometryUtilities.h"

@implementation DKReshapableShape
#pragma mark As a DKReshapableShape

- (void)setShapeProvider:(id)provider selector:(SEL)selector
{
	m_shapeProvider = provider;
	m_shapeSelector = selector;

	//LogEvent_(kReactiveEvent, @"selector = '%@'", [NSString stringWithCString:sel_getName( selector )]);
}

- (id)shapeProvider
{
	return m_shapeProvider;
}

- (SEL)shapeSelector
{
	return m_shapeSelector;
}

#pragma mark -
- (void)setOptionalParameter:(id)objParam
{
	// sets the optional parameter that is passed to the shape provider. As long as this is an object
	// it can be anything that has been informally agreed between the provider and providee beforehand.
	// Typically it would be an NSNumber or a dictionary of multiple parameters.

	if (objParam != m_optionalParam) {
		m_optionalParam = objParam;

		// allow a change of param to force an update of the shape:

		[self reshapePath];
	}
}

- (id)optionalParameter
{
	return m_optionalParam;
}

#pragma mark -
- (NSBezierPath*)providedShapeForRect:(NSRect)r
{
	shapeProviderFunction sp;

	sp = (shapeProviderFunction)[[self shapeProvider] methodForSelector : [self shapeSelector]];

	if (sp)
		return sp([self shapeProvider], [self shapeSelector], r, [self optionalParameter]);
	else
		return nil;
}

#pragma mark -
#pragma mark As a DKDrawableShape
- (void)adoptPath:(NSBezierPath*)path
{
	// overrides standard shape so that if a new path is adopted directly, the shape provider is discarded.

	[super adoptPath:path];
	[self setShapeProvider:nil
				  selector:nil];
}

- (void)reshapePath
{
	// called when shape is resized to recompute the path.

	if ([self shapeProvider] != nil) {
		NSRect r;

		r.size = [self size];

		// if we have zero size, nothing to do

		if (r.size.width == 0.0 || r.size.height == 0.0)
			return;

		r.origin = [self location];

		// canonical  rect is centred at origin

		r.origin.x -= r.size.width * 0.5;
		r.origin.y -= r.size.height * 0.5;

		// need to set up rect so that widths and heights are always +ve

		r = NormalizedRect(r);

		// ask provider for the path.

		NSBezierPath* p = [self providedShapeForRect:r];

		if (p != nil && ![p isEmpty]) {
			// copy p in case it was a shared factory object - we don't want to accidentally transform it

			p = [p copy];
			r = [p bounds];

			// transform the path back to the stored path's canonical form. Because the shape may be
			// rotated but that's ignored for obtaining a new path, this is not the exact same transform
			// as the one used for drawing the shape, but
			// a simplified one that only scales and translates.

			if (r.size.width != 0.0 && r.size.height != 0.0) {
				NSAffineTransform* tfm = [NSAffineTransform transform];
				[tfm translateXBy:[self location].x
							  yBy:[self location].y];
				[tfm scaleXBy:r.size.width
						  yBy:r.size.height];
				[tfm invert];
				[p transformUsingAffineTransform:tfm];

				[self setPath:p];
			}
		}
	}
}

/*- (void)		parentGeometryChanged
{
	[self reshapePath];
}*/

#pragma mark -
#pragma mark As an NSObject

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];

	[coder encodeObject:[self shapeProvider]
				 forKey:@"provider"];
	[coder encodeObject:NSStringFromSelector([self shapeSelector])
				 forKey:@"DKReshapeable_shapeSelector"];
	[coder encodeObject:[self optionalParameter]
				 forKey:@"optparam"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil) {
		SEL selector;

		selector = NSSelectorFromString([coder decodeObjectForKey:@"DKReshapeable_shapeSelector"]);

		if (selector == NULL) {
			// migrate older format to current one

			selector = sel_registerName([[coder decodeObjectForKey:@"selector"] cStringUsingEncoding:NSASCIIStringEncoding]);
		}

		[self setShapeProvider:[coder decodeObjectForKey:@"provider"]
					  selector:selector];
		[self setOptionalParameter:[coder decodeObjectForKey:@"optparam"]];
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
	DKReshapableShape* copy = [super copyWithZone:zone];

	[copy setShapeProvider:[self shapeProvider]
				  selector:[self shapeSelector]];
	[copy setOptionalParameter:[self optionalParameter]];

	return copy;
}

@end
