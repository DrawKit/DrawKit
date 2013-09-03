//
//  DKScriptingAdditions.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by Jason Jobe on 3/16/07.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKScriptingAdditions.h"

#import "DKExpression.h"


@implementation NSColor (DKStyleExpressions)
#pragma mark As a NSColor
+ (NSColor*)	instantiateFromExpression:(DKExpression*)expr
{
	NSColor *color;
	id val;
	
/*
	if ([expr argCount] == 2)
	{
		id val = [expr valueAtIndex:1];
		if ([val isKindOfClass:[NSColor class]])
			color = val;
	}
	else
*/
	if ((val = [expr valueForKey:@"r"]))
	{
		color = [NSColor colorWithCalibratedRed:[val doubleValue]
										  green:[[expr valueForKey:@"g"] doubleValue]
										   blue:[[expr valueForKey:@"b"] doubleValue]
										  alpha:[[expr valueForKey:@"a"] doubleValue]];
	}
	else if ((val = [expr valueForKey:@"red"]))
	{
		color = [NSColor colorWithCalibratedRed:[val doubleValue]
										  green:[[expr valueForKey:@"green"] doubleValue]
										   blue:[[expr valueForKey:@"blue"] doubleValue]
										  alpha:[[expr valueForKey:@"alpha"] doubleValue]];
	} else {
		color = [NSColor colorWithCalibratedRed:[[expr valueAtIndex:1] doubleValue]
										  green:[[expr valueAtIndex:2] doubleValue]
										   blue:[[expr valueAtIndex:3] doubleValue]
										  alpha:[[expr valueAtIndex:4] doubleValue]];
	}
	return color;
}

- (NSString*)	styleScript
{
	NSColor* cc = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];	
#warning 64BIT: Check formatting arguments
	return [NSString stringWithFormat:@"(colour r:%1.2f g:%1.2f b:%1.2f a:%1.2f)", [cc redComponent], [cc greenComponent], [cc blueComponent], [cc alphaComponent]];
}

@end


#pragma mark -
@implementation NSShadow (DKStyleExpressions)
#pragma mark As a NSShadow
+ (NSShadow*)	instantiateFromExpression:(DKExpression*) expr;
{
	// shadows are specified by:
	// 0 or colour = shadow colour (NSColor)
	// 1 or blur   = blur radius (float)
	// 2 or x	   = x offset (float)
	// 3 or y      = y offset (float)
	
	NSSize	 so = NSMakeSize( 10, 10 );
	//	float	 br = 10.0;
	id val;
	
	NSShadow *obj = [[[NSShadow alloc] init] autorelease];
	
	if ([expr argCount] == 1) {
		// use default values
		[obj setShadowColor:[NSColor blackColor]];
		[obj setShadowOffset:so];
		[obj setShadowBlurRadius:10.0];
		return obj;
	}
	
	if ((val = [expr valueForKey:@"colour"]) ||
		(val = [expr valueForKey:@"color"]))
	{
		// using keys
		[obj setShadowColor:val];
		
		so.width = [[expr valueForKey:@"x"] doubleValue];
		so.height = [[expr valueForKey:@"y"] doubleValue];
		[obj setShadowOffset:so];
		
		[obj setShadowBlurRadius:[[expr valueForKey:@"blur"] doubleValue]];
	}
	else {
		[obj setShadowColor:[expr valueAtIndex:1]];
		[obj setShadowBlurRadius:[[expr valueAtIndex:2] doubleValue]];
		so.width = [[expr valueAtIndex:3] doubleValue];
		so.height = [[expr valueAtIndex:4] doubleValue];
		[obj setShadowOffset:so];
	}
	return obj;
}

- (NSString*)	styleScript
{
#warning 64BIT: Check formatting arguments
	return [NSString stringWithFormat:@"(shadow colour:%@ blur:%1.1f x:%1.1f y:%1.1f)", [[self shadowColor] styleScript], [self shadowBlurRadius], [self shadowOffset].width, [self shadowOffset].height];
}

@end

