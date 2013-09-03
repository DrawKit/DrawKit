//
//  DKEvaluator.mm
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by Jason Jobe on 2007-03-07.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKEvaluator.h"

#import "DKExpression.h"
#import "DKSymbol.h"


@implementation DKEvaluator
#pragma mark As a DKEvaluator
- (void)	addValue:(id) value forSymbol:(NSString*) symbol
{
	[mSymbolTable setValue:value forKey:symbol];
}


#pragma mark -
- (id)		evaluateSymbol:(NSString*) symbol
{
  id sym = [mSymbolTable valueForKeyPath:symbol];
  return (sym ? sym : symbol);
}


- (id)		evaluateObject:(id) anObject
{
	if ([anObject isLiteralValue])
		return anObject;

	if ([anObject isKindOfClass:[DKSymbol class]])
		return [self evaluateSymbol:anObject];

	if ([anObject isKindOfClass:[DKExpression class]])
		return [self evaluateExpression:anObject];

	if ([anObject isKindOfClass:[DKExpressionPair class]])
	{
		id val = [self evaluateObject:[(DKExpressionPair*)anObject value]];
		return [[[DKExpressionPair alloc] initWithKey:[(DKExpressionPair*)anObject key] value:val] autorelease];
	}
	
	return anObject;
}


- (id)		evaluateExpression:(DKExpression*) expr
{
	if ([expr isLiteralValue])
		return [self evaluateSimpleExpression:expr];

	id value;
	
	NSEnumerator *curs = [expr objectEnumerator];
	DKExpression *sexpr = [[DKExpression alloc] init];
	[sexpr setType: [expr type]];
	id item;
	
	while ((item = [curs nextObject]))
			[sexpr addObject:[self evaluateObject:item]];

	value = [[self evaluateSimpleExpression:sexpr] retain];
	[sexpr release];
	
	return [value autorelease];
}


- (id)		evaluateSimpleExpression:(DKExpression*) expr
{
	return expr;
}

#pragma mark -
#pragma mark As an NSObject
- (void)	dealloc
{
	[mSymbolTable release];
	
	[super dealloc];
}


- (id)		init
{
	self = [super init];
	if (self != nil)
	{
		mSymbolTable = [[NSMutableDictionary alloc] init];
		
		if (mSymbolTable == nil)
		{
			[self autorelease];
			self = nil;
		}
    }
	return self;
}


@end
