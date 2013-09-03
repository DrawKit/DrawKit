///**********************************************************************************************************************************
///  NSObject+GraphicsAttributes.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 09/03/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "NSObject+GraphicsAttributes.h"

#import "DKExpression.h"
#import "LogEvent.h"


@interface DKExpression (DKRasterizerHelper)

- (void)		applyValuesTo:anObject skippingFirstElement:(BOOL) skipit;

@end

#pragma mark -
@implementation DKExpression (DKRasterizerHelper)

- (void)		applyValuesTo:anObject skippingFirstElement:(BOOL) skipit
{
	Class PairClass = [DKExpressionPair class];
	NSEnumerator* curs = [mValues objectEnumerator];
	DKExpressionPair* pair;
	NSInteger position = 0;
	
	if (skipit)
		[curs nextObject];
	
	while ((pair = [curs nextObject]))
	{
		if ([pair isKindOfClass:PairClass])
			[anObject setValue:[pair value] forKey:[pair key]];
		else
			[anObject setValue:pair forNumericParameter:position];
		
		++position;
	}
}

@end



#pragma mark -
@implementation NSObject (GraphicsAttributes)
#pragma mark As an NSObject
- (id)				initWithExpression:(DKExpression*) expr;
{
	self = [self init];
	if (self != nil)
	{
		LogEvent_(kLifeEvent, @"initialising with parameters: %@", expr);
		
		// subclasses may need to override this and look for key/value pairs in the dictionary
		// pertaining to properties they implement. The keys can either be specific
		// names or enumerated parameters (where no key was supplied).
		
		// as a convenience, this is handled here generically using KVC, so if you make your
		// class KVC compliant around the desired spec string syntax, it "just works".
		
		if ([expr isSequence])
		{
			[expr applyValuesTo:self skippingFirstElement:NO];
		}else
		{
			[expr applyValuesTo:self skippingFirstElement:YES];
		}
	}
	
	return self;
}


- (void)			setValue:(id) val forNumericParameter:(NSInteger) pnum
{
	// for anonymous parameters in the spec string, positional notation is relied on. Each param will be
	// assigned a numeric key according to its position, starting at 0. This method is called for each
	// parameter recovered from the params dictionary.
	
	// it is up to subclasses to know what they are expecting here and to extract and set the appropriate
	// property. Subclasses must override and implement this for anonymous parameters to work.
	
	// Do not rely on this being called in the order of the parameters.

	LogEvent_(kReactiveEvent, @"anonymous parameter #%d, value = %@", pnum, val );
}


#pragma mark -
- (NSImage*)		imageResourceNamed:(NSString*) name
{
	NSString *path = [[NSBundle bundleForClass:[self class]] pathForImageResource:name];
	NSImage *image = [[NSImage alloc] initByReferencingFile:path];
	if (image == nil)
		LogEvent_(kWheneverEvent, @"ERROR: Unable to locate Image resource %@", name);
	return [image autorelease];
}


@end
