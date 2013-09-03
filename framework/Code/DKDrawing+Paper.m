///**********************************************************************************************************************************
///  DKDrawing+Paper.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 14/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************


#import "DKDrawing+Paper.h"


@implementation DKDrawing (Paper)


///*********************************************************************************************************************
///
/// method:			isoA0PaperSize:
/// scope:			public class method
/// description:	returns the size (in Quartz drawing units) of an A0 piece of paper.
/// 
/// parameters:		<portrait> YES if in portrait orientation, NO for landscape.
/// result:			the paper size
///
/// notes:			result may be passed directly to setDrawingSize:
///
///********************************************************************************************************************

+ (NSSize)				isoA0PaperSize:(BOOL) portrait
{
	// A0 is defined as a sheet 1m^2 in area with sides of ratio 1:sqrt(2) which gives 841 x 1189 mm
	
	NSSize a0;
	
	if ( portrait )
	{
		a0.width = 841.0 * 2.83465;
		a0.height = 1189.0 * 2.83465;
	}
	else
	{
		a0.width = 1189.0 * 2.83465;
		a0.height = 841.0 * 2.83465;
	}
	
	return a0;
}


///*********************************************************************************************************************
///
/// method:			isoA1PaperSize:
/// scope:			public class method
/// description:	returns the size (in Quartz drawing units) of an A1 piece of paper.
/// 
/// parameters:		<portrait> YES if in portrait orientation, NO for landscape.
/// result:			the paper size
///
/// notes:			result may be passed directly to setDrawingSize:
///
///********************************************************************************************************************

+ (NSSize)				isoA1PaperSize:(BOOL) portrait
{
	NSSize a1 = [self isoA0PaperSize:!portrait];
	
	if ( portrait )
		a1.width /= 2.0;
	else
		a1.height /= 2.0;
		
	return a1;
}


///*********************************************************************************************************************
///
/// method:			isoA2PaperSize:
/// scope:			public class method
/// description:	returns the size (in Quartz drawing units) of an A2 piece of paper.
/// 
/// parameters:		<portrait> YES if in portrait orientation, NO for landscape.
/// result:			the paper size
///
/// notes:			result may be passed directly to setDrawingSize:
///
///********************************************************************************************************************

+ (NSSize)				isoA2PaperSize:(BOOL) portrait
{
	NSSize a2 = [self isoA1PaperSize:!portrait];
	
	if ( portrait )
		a2.width /= 2.0;
	else
		a2.height /= 2.0;
		
	return a2;
}


///*********************************************************************************************************************
///
/// method:			isoA3PaperSize:
/// scope:			public class method
/// description:	returns the size (in Quartz drawing units) of an A3 piece of paper.
/// 
/// parameters:		<portrait> YES if in portrait orientation, NO for landscape.
/// result:			the paper size
///
/// notes:			result may be passed directly to setDrawingSize:
///
///********************************************************************************************************************

+ (NSSize)				isoA3PaperSize:(BOOL) portrait
{
	NSSize a3 = [self isoA2PaperSize:!portrait];
	
	if ( portrait )
		a3.width /= 2.0;
	else
		a3.height /= 2.0;
		
	return a3;
}


///*********************************************************************************************************************
///
/// method:			isoA4PaperSize:
/// scope:			public class method
/// description:	returns the size (in Quartz drawing units) of an A4 piece of paper.
/// 
/// parameters:		<portrait> YES if in portrait orientation, NO for landscape.
/// result:			the paper size
///
/// notes:			result may be passed directly to setDrawingSize:
///
///********************************************************************************************************************

+ (NSSize)				isoA4PaperSize:(BOOL) portrait
{
	NSSize a4 = [self isoA3PaperSize:!portrait];
	
	if ( portrait )
		a4.width /= 2.0;
	else
		a4.height /= 2.0;
		
	return a4;
}


///*********************************************************************************************************************
///
/// method:			isoA5PaperSize:
/// scope:			public class method
/// description:	returns the size (in Quartz drawing units) of an A5 piece of paper.
/// 
/// parameters:		<portrait> YES if in portrait orientation, NO for landscape.
/// result:			the paper size
///
/// notes:			result may be passed directly to setDrawingSize:
///
///********************************************************************************************************************

+ (NSSize)				isoA5PaperSize:(BOOL) portrait
{
	NSSize a5 = [self isoA4PaperSize:!portrait];
	
	if ( portrait )
		a5.width /= 2.0;
	else
		a5.height /= 2.0;
		
	return a5;
}


@end
