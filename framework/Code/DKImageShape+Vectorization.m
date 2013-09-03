///**********************************************************************************************************************************
///  DKImageShape+Vectorization.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 25/06/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#ifdef qUsePotrace

#import "DKImageShape+Vectorization.h"

#import "DKStyle.h"
#import "DKObjectDrawingLayer.h"
#import "DKShapeGroup.h"
#import "DKStroke.h"
#import "LogEvent.h"


#pragma mark Contants (Non-localized)
NSString*	kDKIncludeStrokeStyle	= @"kDKIncludeStrokeStyle";		// BOOL
NSString*	kDKStrokeStyleWidth		= @"kDKStrokeStyleWidth";		// float
NSString*	kDKStrokeStyleColour	= @"kDKStrokeStyleColour";		// NSColor


#pragma mark Static Vars
static DKVectorizingMethod			sVecMethod = kDKVectorizeColour;
static NSInteger							sVecGrayLevels = 32;
static NSInteger							sVecColourPrecision = 5;
static DKColourQuantizationMethod	sQuantizationMethod = kDKColourQuantizeOctree;
static NSDictionary*				sTraceParams = nil;	// use default


#pragma mark -
@implementation DKImageShape (Vectorization)
#pragma mark As a DKImageShape
+ (void)			setPreferredVectorizingMethod:(DKVectorizingMethod) method
{
	sVecMethod = method;
}


+ (void)			setPreferredVectorizingLevels:(NSInteger) levelsOfGray
{
	sVecGrayLevels = levelsOfGray;
}


+ (void)			setPreferredVectorizingPrecision:(NSInteger) colourPrecision
{
	sVecColourPrecision = colourPrecision;
}


+ (void)			setPreferredQuantizationMethod:(DKColourQuantizationMethod) qm;
{
	sQuantizationMethod = qm;
}


#pragma mark -
+ (void)			setTracingParameters:(NSDictionary*) traceInfo
{
	[traceInfo retain];
	[sTraceParams release];
	sTraceParams = traceInfo;
}


+ (NSDictionary*)	tracingParameters
{
	return sTraceParams;
}


#pragma mark -
- (DKShapeGroup*)	makeGroupByVectorizing
{
	NSArray* shapes = [self makeObjectsByVectorizing];
	
	if ([shapes count] > 0 )
	{
		DKShapeGroup* group = [[DKShapeGroup alloc] initWithObjectsInArray:shapes];
		[group setLocation:[self location]];
		return [group autorelease];
	}
	else
		return nil;
}


- (DKShapeGroup*)	makeGroupByGrayscaleVectorizingWithLevels:(NSInteger) levelsOfGray
{
	NSArray* shapes = [self makeObjectsByGrayscaleVectorizingWithLevels:levelsOfGray];
	
	if ([shapes count] > 0 )
	{
		DKShapeGroup* group = [[DKShapeGroup alloc] initWithObjectsInArray:shapes];
		[group setLocation:[self location]];
		return [group autorelease];
	}
	else
		return nil;
}


- (DKShapeGroup*)	makeGroupByColourVectorizingWithPrecision:(NSInteger) colourPrecision
{
	NSArray* shapes = [self makeObjectsByColourVectorizingWithPrecision:colourPrecision];
	
	if ([shapes count] > 0 )
	{
		DKShapeGroup* group = [[DKShapeGroup alloc] initWithObjectsInArray:shapes];
		[group setLocation:[self location]];
		return [group autorelease];
	}
	else
		return nil;
}


#pragma mark -
- (NSArray*)		makeObjectsByVectorizing
{
	if ( sVecMethod == kDKVectorizeColour )
		return [self makeObjectsByColourVectorizingWithPrecision:sVecColourPrecision];
	else
		return [self makeObjectsByGrayscaleVectorizingWithLevels:sVecGrayLevels];
}


- (NSArray*)		makeObjectsByGrayscaleVectorizingWithLevels:(NSInteger) levelsOfGray
{
	NSArray* result = [[self imageAtRenderedSize] vectorizeToGrayscale:levelsOfGray];
	
//	LogEvent_(kInfoEvent, @"vectorized, planes = %d", [result count]);
	
	NSEnumerator*		iter = [result objectEnumerator];
	DKImageVectorRep*	rep;
	DKDrawableShape*	shape;
	NSBezierPath*		path;
	NSMutableArray*		listOfShapes;
	
	listOfShapes = [[NSMutableArray alloc] init];
	
	while(( rep = [iter nextObject]))
	{
		[rep setTracingParameters:sTraceParams];

		path = [rep vectorPath];
		
		if ( path && ![path isEmpty])
		{
			shape = [DKDrawableShape drawableShapeWithBezierPath:path];
			[shape setStyle:[DKStyle styleWithFillColour:[rep colour] strokeColour:nil]];
			[listOfShapes addObject:shape];
			
			// check if trace params dict contains request for stroke - if so, set it up
			
			if ( sTraceParams && [sTraceParams objectForKey:kDKIncludeStrokeStyle])
			{
				NSColor* strokeColour = [sTraceParams objectForKey:kDKStrokeStyleColour];
				CGFloat	 strokeWidth = [[sTraceParams objectForKey:kDKStrokeStyleWidth] doubleValue];
			
				DKStroke* stroke = [DKStroke strokeWithWidth:strokeWidth colour:strokeColour];
				[[shape style] addRenderer:stroke];
			}
		}
	}
	
	return [listOfShapes autorelease];
}


- (NSArray*)		makeObjectsByColourVectorizingWithPrecision:(NSInteger) colourPrecision
{
	NSArray* result = [[self imageAtRenderedSize] vectorizeToColourWithPrecision:colourPrecision quantizationMethod:sQuantizationMethod];
	
//	LogEvent_(kInfoEvent, @"vectorized, planes = %d", [result count]);
	
	NSEnumerator*		iter = [result objectEnumerator];
	DKImageVectorRep*	rep;
	DKDrawableShape*	shape;
	NSBezierPath*		path;
	NSMutableArray*		listOfShapes;
	
	listOfShapes = [[NSMutableArray alloc] init];
	
	while(( rep = [iter nextObject]))
	{
		[rep setTracingParameters:sTraceParams];
		
		path = [rep vectorPath];		// actually performs the bitmap trace if necessary
		
		if ( path && ![path isEmpty])
		{
			shape = [DKDrawableShape drawableShapeWithBezierPath:path];
			[shape setStyle:[DKStyle styleWithFillColour:[rep colour] strokeColour:nil]];
			[listOfShapes addObject:shape];

			// check if trace params dict contains request for stroke - if so, set it up
			
			if ( sTraceParams && [sTraceParams objectForKey:kDKIncludeStrokeStyle])
			{
				NSColor* strokeColour = [sTraceParams objectForKey:kDKStrokeStyleColour];
				CGFloat	 strokeWidth = [[sTraceParams objectForKey:kDKStrokeStyleWidth] doubleValue];
			
				DKStroke* stroke = [DKStroke strokeWithWidth:strokeWidth colour:strokeColour];
				[[shape style] addRenderer:stroke];
			}
		}
	}
	
	return [listOfShapes autorelease];
}


#pragma mark -
- (IBAction)		vectorize:(id) sender
{
	#pragma unused(sender)
	
	DKShapeGroup* group = [self makeGroupByVectorizing];

	// now add the group to the layer
	
	if ( group )
	{	
		DKObjectDrawingLayer* odl = (DKObjectDrawingLayer*)[self layer];
		
		[odl recordSelectionForUndo];
		[odl addObject:group];
		[odl removeObject:self];
		[odl replaceSelectionWithObject:group];
		[odl commitSelectionUndoWithActionName:NSLocalizedString(@"Vectorize Image", @"undo string for vectorize")];
	}
}




@end

#endif /* defined qUsePotrace */
