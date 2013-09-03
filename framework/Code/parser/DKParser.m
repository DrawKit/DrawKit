/*******************************************************************************************
//  DKParser.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by Jason Jobe on 1/28/07.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//
*******************************************************************************************/

#import "DKParser.h"

#import "DKExpression.h"
#import "DKSymbol.h"

#define PARSER_TYPE DKParser*

#include "reader.m"


NSInteger dk_lex (id *val, YYLTYPE *yloc, void *reader)
{
    DKParser *self = (DKParser*)reader;
	yloc->first_line = self->scanr.curline;
	NSInteger tok = scan (&self->scanr);
	self->scanr.token = tok;
	yloc->last_line = self->scanr.curline;
	*val = [self currentToken];
	return tok;
}
#include "reader_g.m"


@implementation DKParser
#pragma mark As a DKParser
- (void)registerFactoryClass:fClass forKey:(NSString*)key;
{
	if ([fClass isKindOfClass:[NSString class]])
		fClass = NSClassFromString (fClass);
		
	if (fClass)
		[mFactories setValue:fClass forKey:key];
}

#pragma mark -
- parseData:(NSData*)someData
{
	[mParseStack removeAllObjects];
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	scan_init_buf(&scanr, (char*)[someData bytes]);
	dk_parse(self);
	scan_finalize(&scanr);
	[pool release];

	return ([mParseStack count] ? [mParseStack objectAtIndex:0] : nil);
}

- parseString:(NSString*)inString;
{	
	NSData *input = [inString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	return [self parseData:input];
}

- parseContentsOfFile:(NSString*)filename;
{
	NSMutableData *input = [[NSMutableData alloc] initWithContentsOfFile:filename];
	const char *term = "\0";
	[input appendBytes:term length:1];
	return [self parseData:input];
}

#pragma mark -
- delegate;
{
	return mDelegate;
}

- (void)setDelegate:anObject;
{
	if (mDelegate)
		[mDelegate autorelease];
	mDelegate = [anObject retain];
}

#pragma mark -
#pragma mark - Settings
-(void)setThrowErrorIfMissingFactory:(BOOL)flag;
{
	throwErrorIfMissingFactory = flag;
}

-(BOOL)willThrowErrorIfMissingFactory;
{
	return throwErrorIfMissingFactory;
}

#pragma mark -
#pragma mark - Parser interface
#warning 64BIT: Check formatting arguments
-(void)parseError:(NSString*)fmt, ...
{
    va_list argumentList;
   	va_start(argumentList, fmt);  
#warning 64BIT: Check formatting arguments
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:argumentList];
    va_end(argumentList);

#warning 64BIT: Check formatting arguments
	NSString *error = [NSString stringWithFormat:@"DKParser parse ERROR: line: %d \n%@",
		scanr.curline, msg];

#warning 64BIT: Check formatting arguments
	NSLog (error);
}

#pragma mark -
- currentToken
{
	id token;
	switch (scanr.token) {
		case TK_String:
			// trim off the quotes
			token = [NSString stringWithCString:&scanr.data[1] length:scanr.len -2];
		break;
		case TK_Keyword:
			// trim off the trailing ':'
			token = [NSString stringWithCString:scanr.data length:scanr.len -1];
		break;
		case TK_Identifier:
		token = [DKSymbol symbolForCString:scanr.data length:scanr.len];
		break;
		case TK_Hex:
			token = [NSString stringWithCString:scanr.data length:scanr.len];
			break;
		case TK_Real:
		case TK_Integer:
		{
			NSString *stringValue, *error;
			stringValue = [NSString stringWithCString:scanr.data length:scanr.len];

			if (![numberFormatter getObjectValue:&token forString:stringValue errorDescription:&error])
				[self parseError:@"BAD NUMBER Format in %@", stringValue];
		}
		break;
		default:
			token = [NSString stringWithCString:scanr.data length:scanr.len];
	} 
	return token;
}

#pragma mark -
- (NSArray*)parseStack;
{
	return mParseStack;
}

#pragma mark -
-(void)push:value
{	
	[mParseStack addObject:value];
}


- pop
{	
	id value = [[[mParseStack lastObject] retain] autorelease];
	[mParseStack removeLastObject];

	return value;
}

- instantiate:(NSString*)type;
{
    Class factory = [mFactories valueForKey:type];
	
    // Some default types
    if (factory == Nil)
    {
        if ([type isEqualToString:@"array"])
            return [NSMutableArray array];
        else
        {
           DKExpression* expr = [[[DKExpression alloc] init] autorelease];
	   [(DKExpression*)expr setType:type];
	   return expr;
        }
    } else {
      return [[[factory alloc] init] autorelease];
    }
      //	return [self instantiateType:type withExpression:nil popping:NO];
}

- (void)setNodeValue:value forKey:(NSString*)key;
{
	DKExpression *dict = [mParseStack lastObject];
	[dict addObject:value forKey:key];
}

- (void)addNode:node
{
	NSMutableArray *array = [mParseStack lastObject];
	if (array == nil)
		array = mParseStack;
	[array addObject:node];
}


#pragma mark -
#pragma mark As an NSObject
-(void)dealloc
{
	[numberFormatter release];
	
	[mDelegate release];
	[mParseStack release];
	[mFactories release];
	
	[super dealloc];
}


- (NSString*) description
{
	return [NSString stringWithFormat:@"<DKParser %@>", mParseStack];
}


- (id)init
{
	self = [super init];
	if (self != nil)
	{
		// All scanr members set to zero.
		mFactories = [[NSMutableDictionary alloc] init];
		mParseStack = [[NSMutableArray alloc] init];
		NSAssert(mDelegate == nil, @"Expected init to zero");
		
		numberFormatter = [[NSNumberFormatter alloc] init];
		
		// Default settings
		throwErrorIfMissingFactory = YES;
		
		if (mFactories == nil 
				|| mParseStack == nil 
				|| numberFormatter == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


@end


#pragma mark -
@implementation DKParser (ParserDebugging)

- (void)setGrammarDebug:(BOOL)flag;
{
	extern NSInteger dk_debug;
	dk_debug = flag;
}

@end

#ifdef DKTEST

int main (int argc, char** argv)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	DKParser *reader = [[DKParser alloc] init];
	id node;

	[reader setThrowErrorIfMissingFactory:NO];
//	[reader setGrammarDebug:YES];
	
//	node = [reader parseString:@"(do with:1,234.56 and: 'single string')"];
//	NSLog (@"NODE: %@", node);
	
	if (argc > 1) {
		node = [reader parseContentsOfFile:[NSString stringWithCString:argv[1]]];
		fprintf (stdout, "%s\n", [[node description] cString]);
	}
	[pool release];
	return 0;
}

#endif

