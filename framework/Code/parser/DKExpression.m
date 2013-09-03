//*******************************************************************************************
//  DKExpression.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by Jason Jobe on 1/28/07.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//
//*******************************************************************************************/

#import "DKExpression.h"


@implementation DKExpression
#pragma mark As a DKExpression
- (void)		setType:(NSString*) aType
{
	[aType retain];
	[mType release];
	mType = aType;
}


- (NSString*)	type
{
	return mType;
}


- (BOOL)		isSequence
{
	if ([@"seq" isEqualToString:mType])
		return YES;
	
	if ([@"emptySeq" isEqualToString:mType])
		return YES;

	return NO;
}


- (BOOL)		isMethodCall
{
	if ([@"mcall" isEqualToString:mType])
		return YES;

	return NO;
}


#pragma mark -
- (BOOL)		isLiteralValue
{
    NSEnumerator*	curs = [mValues objectEnumerator];
    id				item;
	
    while ((item = [curs nextObject]))
    {
		if (! [item isLiteralValue])
			return NO;
    }
    
	return YES;
}


- (NSInteger)			argCount
{
	return [mValues count];
}


#pragma mark -
- (id)			valueAtIndex:(NSInteger) ndx
{
	if (ndx < 0)
		ndx = [mValues count] + ndx;
		
	id item = [mValues objectAtIndex:ndx];
	if ([item isKindOfClass:[DKExpressionPair class]])
		return [(DKExpressionPair*)item value];
	else
		return item;
}


- (id)			valueForKey:(NSString*) key
{
	Class PairClass = [DKExpressionPair class];
	NSEnumerator*		curs = [mValues objectEnumerator];
	DKExpressionPair*	pair;
	
	while ((pair = [curs nextObject]))
	{
		if ([pair isKindOfClass:PairClass] && [[pair key] isEqualToString:key])
			return [pair value];
	}
	
	return nil;
}


#pragma mark -
// This method may return a key:value "pair"

- (id)			objectAtIndex:(NSInteger) ndx
{
	if (ndx < 0)
		ndx = [mValues count] + ndx;
		
	return [mValues objectAtIndex:ndx];
}


- (void)		replaceObjectAtIndex:(NSInteger) ndx withObject:(id) obj
{
	[mValues replaceObjectAtIndex:ndx withObject:obj];
}


#pragma mark -
- (void)		addObject:(id) aValue
{
	[mValues addObject:aValue];
}


- (void)		addObject:(id) aValue forKey:(NSString*) key
{
	DKExpressionPair *pair = [[DKExpressionPair alloc] initWithKey:key value:aValue];
	
	[mValues addObject:pair];
	[pair release];
}


#pragma mark -
- (void)		applyKeyedValuesTo:(id) anObject
{
	Class PairClass = [DKExpressionPair class];
	
	NSEnumerator*		curs = [self objectEnumerator];
	DKExpressionPair*	pair;
	
	while ((pair = [curs nextObject]))
	{
		if ([pair isKindOfClass:PairClass])
			[anObject setValue:[pair value] forKey:[pair key]];
	}
}


#pragma mark -
- (NSString*)	selectorFromKeys
{
	return nil;
}


#pragma mark -
- (NSArray*)           allKeys
{
	NSMutableArray *keys = [NSMutableArray array];
	
	NSEnumerator*           curs = [mValues objectEnumerator];
	DKExpressionPair*       pair;
	Class PairClass = [DKExpressionPair class]; // loop optimization
	
	while ((pair = [curs nextObject]))
	{
		if ([pair isKindOfClass:PairClass])
			[keys addObject:[pair key]];
	}
	return keys;
}


- (NSEnumerator*)      keyEnumerator
{
	return [[self allKeys] objectEnumerator];
}


- (NSEnumerator*)      objectEnumerator
{
  return [mValues objectEnumerator];
}

#pragma mark -
#pragma mark As an NSObject
- (void)		dealloc
{
	[mValues release];
	[mType release];
	
	[super dealloc];
}


- (NSString*)	description
{
	NSMutableString *desc;
	NSString *start, *end;
	
	if ([@"seq" isEqualToString:mType] ||
		[@"emptySeq" isEqualToString:mType])
	{
		start = @"{";
		end = @"}\n";
	}
	else if ([@"expr" isEqualToString:mType] ||
		[@"emptyExpr" isEqualToString:mType])
	{
		start = @"(";
		end = @")\n";
	}
	else if ([@"mcall" isEqualToString:mType])
	{
		start = @"[";
		end = @"]\n";
	} else {
		start = @"";
		end = @"";
	}

	desc = [NSMutableString stringWithString:start];
	NSEnumerator *curs = [mValues objectEnumerator];
	id item;
	
	while ((item = [curs nextObject]))
		[desc appendFormat:@"%@ ", item];

	[desc appendString:end];
	return desc;
}


- (id)			init
{
	self = [super init];
	if (self != nil)
	{
		[self setType:@"expr"];
		mValues = [[NSMutableArray alloc] init];
		
		if (mType == nil 
				|| mValues == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


@end


#pragma mark -
@implementation DKExpressionPair 

- (id)			initWithKey:(NSString*) aKey value:(id) aValue
{
	if ((self = [super init]) != nil )
	{
		key = [aKey retain];
		value = [aValue retain];
	}
	return self;
}

- (NSString*)	key
{
	return key;
}

- (id)			value
{
	return value;
}


- (void)		setValue:(id) val
{
	[val retain];
	[value release];
	value = val;
}


- (BOOL)		isLiteralValue
{
	return [value isLiteralValue];
}


#pragma mark -
#pragma mark As an NSObject
- (void)		dealloc
{
	[key release];
	[value release];
	[super dealloc];
}


- (NSString*)	description
{
	return [NSString stringWithFormat:@"%@: %@", key, value];
}


@end


#pragma mark -
@implementation NSObject (DKExpressionSupport)

- (BOOL)		isLiteralValue
{
	return YES;
}

@end
