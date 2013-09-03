//
//  DKStyleReader.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by Jason Jobe on 3/16/07.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKStyleReader.h"

#import "DKExpression.h"
#import "DKParser.h"
#import "DKScriptingAdditions.h"


@implementation DKStyleReader
#pragma mark As a DKStyleReader
- (id)		evaluateScript:(NSString*) script
{
	return [self evaluateExpression:[mParser parseString:script]];
}


- (id)			readContentsOfFile:(NSString*) filename;
{
	return [mParser parseContentsOfFile:filename];
}


- (void)	loadBuiltinSymbols
{
	[self registerClass:@"DKStyle"			withShortName:@"style"];
	[self registerClass:@"DKStyle"			withShortName:@"seq"];
	
	[self registerClass:@"DKRastGroup"		withShortName:@"group"];
	[self registerClass:@"DKRastGroup"		withShortName:@"grp"];
	
	[self registerClass:@"NSColor"			withShortName:@"color"];
	[self registerClass:@"NSColor"			withShortName:@"colour"];
	[self registerClass:@"NSShadow"			withShortName:@"shadow"];
	[self registerClass:@"NSImage"			withShortName:@"image"];
	[self registerClass:@"DKStroke"			withShortName:@"stroke"];
	[self registerClass:@"DKFill"			withShortName:@"fill"];
	[self registerClass:@"DKHatching"		withShortName:@"hatch"];
	[self registerClass:@"DKFillPattern"	withShortName:@"pattern"];
	[self registerClass:@"DKGradient"		withShortName:@"gradient"];
	[self registerClass:@"DKLineDash"		withShortName:@"dash"];
	//[self registerClass:@"DKAquaRenderer"	withShortName:@"aqua"];
	[self registerClass:@"DKColorStop"		withShortName:@"stop"];
	[self registerClass:@"DKArrowStroke"	withShortName:@"arrows"];
	[self registerClass:@"DKZigZagStroke"	withShortName:@"zzstroke"];
	[self registerClass:@"DKZigZagFill"		withShortName:@"zzfill"];
	[self registerClass:@"DKCIFilterRastGroup"	 withShortName:@"fx"];
	[self registerClass:@"DKQuartzBlendRastGroup"	 withShortName:@"blend"];
	[self registerClass:@"DKTextAdornment"	withShortName:@"label"];
	[self registerClass:@"DKPathDecorator"	withShortName:@"pathdec"];
	[self registerClass:@"DKImageAdornment"	withShortName:@"imagedec"];
	
	// also set up the standard named colours we can deal with:
	
	[self addValue:[NSColor blackColor]		forSymbol:@"black"];
	[self addValue:[NSColor whiteColor]		forSymbol:@"white"];
	[self addValue:[NSColor redColor]		forSymbol:@"red"];
	[self addValue:[NSColor greenColor]		forSymbol:@"green"];
	[self addValue:[NSColor blueColor]		forSymbol:@"blue"];
	[self addValue:[NSColor cyanColor]		forSymbol:@"cyan"];
	[self addValue:[NSColor magentaColor]	forSymbol:@"magenta"];
	[self addValue:[NSColor yellowColor]	forSymbol:@"yellow"];
	[self addValue:[NSColor orangeColor]	forSymbol:@"orange"];
	[self addValue:[NSColor brownColor]		forSymbol:@"brown"];
	[self addValue:[NSColor purpleColor]	forSymbol:@"purple"];
	[self addValue:[NSColor grayColor]		forSymbol:@"gray"];
	[self addValue:[NSColor lightGrayColor] forSymbol:@"lightgray"];
	[self addValue:[NSColor darkGrayColor]	forSymbol:@"darkgray"];
	
	[self addValue:[NSColor colorWithCalibratedWhite:0.9 alpha:1.0] forSymbol:@"verylightgray"];
}


#pragma mark -
- (void)	registerClass:(id) aClass withShortName:(NSString*) sym
{
	Class factory;
	
	if ([aClass isKindOfClass:[NSString class]])
		factory = NSClassFromString(aClass);
	else
		factory = [aClass class];
	
	if (factory)
		[self addValue:factory forSymbol:sym];

}


#pragma mark -
#pragma mark As a DKEvaluator
- (id)		evaluateSimpleExpression:(DKExpression*) expr;
{
	Class	cl;
	id		obj;
	
	if ([expr isSequence])
		cl = [self evaluateSymbol:@"group"];
	else
		cl = [expr objectAtIndex:0];
	
	if([cl respondsToSelector:@selector(instantiateFromExpression:)])
		obj = [[cl instantiateFromExpression:expr] retain];
	else
		obj = [[[cl class] alloc] initWithExpression:expr];
	
	return [obj autorelease];
}


#pragma mark -
#pragma mark As an NSObject
- (void)	dealloc
{
	[mParser release];
	
	[super dealloc];
}


- (id)		init
{
	self = [super init];
	if (self != nil)
	{
		mParser = [[DKParser alloc] init];
		
		if (mParser == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	if (self != nil)
	{
		[self loadBuiltinSymbols];
	}
	return self;
}


@end
