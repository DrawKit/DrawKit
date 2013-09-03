//
//  DKSymbol.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by Jason Jobe on 4/25/05.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKSymbol.h"


#pragma mark Static Vars
static NSMutableDictionary* sSymbolMap;
static NSInteger sSymCounter = 0;


#pragma mark -
@implementation DKSymbol
#pragma mark As a DKSymbol
+ (NSMutableDictionary*)	symbolMap
{
    if (sSymbolMap == nil)
        sSymbolMap = [[NSMutableDictionary alloc] init];
   
	return sSymbolMap;
}


+ (DKSymbol*)				symbolForString:(NSString*) str
{
    DKSymbol *sym = [[DKSymbol symbolMap] valueForKey:str];
    
	if (sym == nil)
	{
        sym = [[DKSymbol alloc] initWithString:str index:(++sSymCounter)];
        [[DKSymbol symbolMap] setValue:sym forKey:[sym string]];
        [sym release];
    }
    
	return sym;
}


+ (DKSymbol*)				symbolForCString:(const char*) cstr length:(NSInteger) len
{
    NSString *str = [[NSString alloc] initWithCString:cstr length:len];
    DKSymbol* sym = [DKSymbol symbolForString:str];
    [str release];
    return sym;
}


#pragma mark -
- (id)						initWithString:(NSString*) str index:(NSInteger) ndx
{
	self = [super init];
	if (self != nil)
	{
		mString = [str retain];
		mIndex = ndx;
		
		if (mString == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}

-(NSInteger)						index
{
    return mIndex;
}


#pragma mark -
#pragma mark As an NSString
- (unichar)					characterAtIndex:(NSUInteger) ndx
{
	return [mString characterAtIndex:ndx];
}


- (void)					getCharacters:(unichar *) buffer range:(NSRange) aRange
{
	[mString getCharacters:buffer range:aRange];
}


- (BOOL)					isEqualToString:(NSString*) str
{
	return ((self == str) || [mString isEqualToString:str]);
}

- (NSUInteger)			length
{
	return [mString length];
}


-(NSString*)				string
{
    return mString;
}


#pragma mark -
- (BOOL)					isLiteralValue
{
	return NO;
}


- (BOOL)					isSmoothAtom
{
	return NO;
}


- (BOOL)					isSmoothIdentifier
{
	return YES;
}


// NSString protocol
#pragma mark -
#pragma mark As an NSObject
- (void)					dealloc
{
    [mString release];
	
    [super dealloc];
}


- (NSString*)				description
{
    return mString;
}

-(BOOL)						isEqualTo:(id) anObject
{
	return ((self == anObject) || [mString isEqualToString:[anObject description]]);
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)						copyWithZone:(NSZone*) zone
{
	#pragma unused(zone)
	
	return [self retain];
}


@end
