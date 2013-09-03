///**********************************************************************************************************************************
///  DKStyle+SimpleAccess.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 08/07/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKStyle+SimpleAccess.h"
#import "DKFill.h"
#import "DKStroke.h"
#import "DKHatching.h"
#import "DKTextAdornment.h"
#import "DKImageAdornment.h"



@implementation DKStyle (SimpleAccess)


+ (DKStyle*)	styleWithDotDensity:(CGFloat) percent foreColour:(NSColor*) fore backColour:(NSColor*) back
{
	// returns a style having a solid fill of <backColour> overlaid by a hatching with a dot screen of <density> and <foreColour>. Useful
	// to create styles with a dot screen pattern. Note that density is in percent, not 0..1

	DKStyle* style = [self styleWithFillColour:back strokeColour:nil];
	DKHatching* dotHatch = [DKHatching hatchingWithDotDensity:percent / 100.0];
	
	if( dotHatch )
	{
		[dotHatch setColour:fore];
		[style addRenderer:dotHatch];
	}
	
	return style;
}


- (DKStroke*)		stroke
{
	if([self hasStroke])
		return (DKStroke*)[[self renderersOfClass:[DKStroke class]] lastObject];
	else
		return nil;
}


- (DKFill*)			fill
{
	if([self hasFill])
		return (DKFill*)[[self renderersOfClass:[DKFill class]] lastObject];
	else
		return nil;
}



- (void)		setFillColour:(NSColor*) fillColour
{
	if([self locked])
		return;
	
	if ( fillColour == nil )
	{
		// remove all fill properties
		
		[self removeRenderersOfClass:[DKFill class] inSubgroups:YES];
		[[self undoManager] setActionName:NSLocalizedString(@"Remove Fill", @"undo for style remove fill")];
	}
	else if( ![self hasFill])
	{
		// add a fill property at the back of the render list
		
		DKFill* newFill = [DKFill fillWithColour:fillColour];
		[self insertRenderer:newFill atIndex:0];
		[[self undoManager] setActionName:NSLocalizedString(@"Add Fill", @"undo for style add fill")];
	}
	else
	{
		DKFill* fill = (DKFill*)[[self renderersOfClass:[DKFill class]] lastObject];
		[fill setEnabled:YES];
		[fill setColour:fillColour];
	}
}



- (NSColor*)	fillColour
{
	if([self hasFill])
	{
		DKFill* fill = (DKFill*)[[self renderersOfClass:[DKFill class]] lastObject];
		return [fill colour];
	}
	else
		return nil;
}




- (void)		setStrokeColour:(NSColor*) strokeColour
{
	if([self locked])
		return;

	if ( strokeColour == nil )
	{
		// remove all stroke properties
		
		[self removeRenderersOfClass:[DKStroke class] inSubgroups:YES];
		[[self undoManager] setActionName:NSLocalizedString(@"Remove Stroke", @"undo for style remove stroke")];
	}
	else if( ![self hasStroke])
	{
		// add a stroke property at the back of the render list
		
		DKStroke* newStroke = [DKStroke strokeWithWidth:1.0 colour:strokeColour];
		[self addRenderer:newStroke];
		[[self undoManager] setActionName:NSLocalizedString(@"Add Stroke", @"undo for style add stroke")];
	}
	else
	{
		DKStroke* stroke = (DKStroke*)[[self renderersOfClass:[DKStroke class]] lastObject];
		[stroke setEnabled:YES];
		[stroke setColour:strokeColour];
	}
}



- (NSColor*)	strokeColour
{
	if([self hasStroke])
	{
		DKStroke* stroke = (DKStroke*)[[self renderersOfClass:[DKStroke class]] lastObject];
		return [stroke colour];
	}
	else
		return nil;
}



- (void)		setStrokeWidth:(CGFloat) strokeWidth
{
	if([self locked])
		return;

	if([self hasStroke])
	{
		// ...get the stroke property and set its width to the float value of the sender
		
		DKStroke* stroke = (DKStroke*)[[self renderersOfClass:[DKStroke class]] lastObject];
		[stroke setWidth:strokeWidth];
	}
}



- (CGFloat)		strokeWidth
{
	if([self hasStroke])
	{
		// ...get the stroke property and set its width to the float value of the sender
		
		DKStroke* stroke = (DKStroke*)[[self renderersOfClass:[DKStroke class]] lastObject];
		return [stroke width];
	}
	else
		return 0.0;
}


- (void)		setStrokeDash:(DKStrokeDash*) aDash
{
	if([self locked])
		return;

	if([self hasStroke])
	{
		// ...get the stroke property and set its dash
		
		DKStroke* stroke = (DKStroke*)[[self renderersOfClass:[DKStroke class]] lastObject];
		[stroke setDash:aDash];
	}
}


- (DKStrokeDash*) strokeDash
{
	if([self hasStroke])
	{
		DKStroke* stroke = (DKStroke*)[[self renderersOfClass:[DKStroke class]] lastObject];
		return [stroke dash];
	}
	else
		return nil;
}



- (void)			setStrokeLineCapStyle:(NSLineCapStyle) capStyle
{
	if([self locked])
		return;

	if([self hasStroke])
	{
		DKStroke* stroke = (DKStroke*)[[self renderersOfClass:[DKStroke class]] lastObject];
		[stroke setLineCapStyle:capStyle];
	}
}


- (NSLineCapStyle)	strokeLineCapStyle
{
	if([self hasStroke])
	{
		DKStroke* stroke = (DKStroke*)[[self renderersOfClass:[DKStroke class]] lastObject];
		return [stroke lineCapStyle];
	}
	else
		return NSButtLineCapStyle;
}




- (void)			setStrokeLineJoinStyle:(NSLineJoinStyle) joinStyle
{
	if([self locked])
		return;

	if([self hasStroke])
	{
		DKStroke* stroke = (DKStroke*)[[self renderersOfClass:[DKStroke class]] lastObject];
		[stroke setLineJoinStyle:joinStyle];
	}
}



- (NSLineJoinStyle)	strokeLineJoinStyle
{
	if([self hasStroke])
	{
		DKStroke* stroke = (DKStroke*)[[self renderersOfClass:[DKStroke class]] lastObject];
		return [stroke lineJoinStyle];
	}
	else
		return NSButtLineCapStyle;
}



- (void)			setString:(NSString*) aString
{
	if([self locked])
		return;

	if ( aString == nil )
	{
		// remove all text adornment properties
		
		[self removeRenderersOfClass:[DKTextAdornment class] inSubgroups:YES];
		[[self undoManager] setActionName:NSLocalizedString(@"Remove Text", @"undo for style remove text")];
	}
	else if( ![self hasTextAdornment])
	{
		// add a text property at the back of the render list
		
		DKTextAdornment* newTA = [DKTextAdornment textAdornmentWithText:aString];
		[self addRenderer:newTA];
		[[self undoManager] setActionName:NSLocalizedString(@"Add Text", @"undo for style add text")];
	}
	else
	{
		DKTextAdornment* ta = (DKTextAdornment*)[[self renderersOfClass:[DKTextAdornment class]] lastObject];
		[ta setEnabled:YES];
		[ta setLabel:aString];
	}
}


- (NSString*)		string
{
	if([self hasTextAdornment])
	{
		DKTextAdornment* ta = (DKTextAdornment*)[[self renderersOfClass:[DKTextAdornment class]] lastObject];
		return [ta string];
	}
	else
		return nil;
}


- (BOOL)			hasImageComponent
{
	return [self containsRendererOfClass:[DKImageAdornment class]];
}



- (void)			setImageComponent:(NSImage*) anImage
{
	if([self locked])
		return;
	
	if ( anImage == nil )
	{
		// remove all image adornment properties
		
		[self removeRenderersOfClass:[DKImageAdornment class] inSubgroups:YES];
		[[self undoManager] setActionName:NSLocalizedString(@"Remove Image", @"undo for style remove image")];
	}
	else if( ![self hasImageComponent])
	{
		// add a text property at the back of the render list
		
		DKImageAdornment* newTA = [DKImageAdornment imageAdornmentWithImage:anImage];
		[self addRenderer:newTA];
		[[self undoManager] setActionName:NSLocalizedString(@"Add Image", @"undo for style add image")];
	}
	else
	{
		DKImageAdornment* ta = (DKImageAdornment*)[[self renderersOfClass:[DKImageAdornment class]] lastObject];
		[ta setEnabled:YES];
		[ta setImage:anImage];
	}
}


- (NSImage*)		imageComponent
{
	if([self hasImageComponent])
	{
		DKImageAdornment* ta = (DKImageAdornment*)[[self renderersOfClass:[DKImageAdornment class]] lastObject];
		return [ta image];
	}
	else
		return nil;
}


@end
