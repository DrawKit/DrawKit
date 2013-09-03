//
//  DKDrawableShape+Utilities.m
//  GCDrawKit
//
//  Created by graham on 13/06/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import "DKDrawableShape+Utilities.h"


@implementation DKDrawableShape (Utilities)


///*********************************************************************************************************************
///
/// method:			pathWithRelativeRect:
/// scope:			public instance method
/// overrides:		
/// description:	return a rectangular path with given size and origin
/// 
/// parameters:		<relRect> a rectangle expressed relative to the unit square
/// result:			a rectangular path transformed to the current true size, position and angle of the shape
///
/// notes:			not affected by the object's current offset
///
///********************************************************************************************************************

- (NSBezierPath*)			pathWithRelativeRect:(NSRect) relRect
{
	NSBezierPath* path = [NSBezierPath bezierPathWithRect:relRect];
	NSAffineTransform* transform = [self transformIncludingParent];
	[path transformUsingAffineTransform:transform];
	
	return path;
}


///*********************************************************************************************************************
///
/// method:			pathWithRelativePosition:finalSize:
/// scope:			public instance method
/// overrides:		
/// description:	return a rectangular path with given relative origin but absolute final size
/// 
/// parameters:		<relLoc> a point expressed relative to the unit square
///					<size> the final desired size o fthe rectangle
/// result:			a rectangular path transformed to the current true size, position and angle of the shape
///
/// notes:			not affected by the object's current offset. By specifying a final size the resulting path can
///					represent a fixed-sized region independent of the object's current size.
///
///********************************************************************************************************************

- (NSBezierPath*)			pathWithRelativePosition:(NSPoint) relLoc finalSize:(NSSize) size
{
	// work out a fully relative rect
	
	NSRect relRect;
	
	relRect.origin = relLoc;
	relRect.size.width = size.width / [self size].width;
	relRect.size.height = size.height / [self size].height;
	
	return [self pathWithRelativeRect:relRect];
}


///*********************************************************************************************************************
///
/// method:			pathWithFinalSize:offsetBy:fromPartcode:
/// scope:			public instance method
/// overrides:		
/// description:	return a rectangular path offset from a given partcode
/// 
/// parameters:		<size> the final desired size of the rectangle
///					<offset> an offset in absolute units from the nominated partcode position
///					<pc> the partcode that the path is positioned relative to
/// result:			a rectangular path transformed to the current true size, position and angle of the shape
///
/// notes:			The resulting path is positioned at a fixed offset and size relative to a partcode (a corner, say)
///					in such a way that the object's size and angle set the positioning and orientation of the path
///					but not its actual size. This is useful for adding an adornment to the shape that is unscaled
///					by the object, such as the text indicator shown by DKTextShape
///
///********************************************************************************************************************

- (NSBezierPath*)			pathWithFinalSize:(NSSize) size offsetBy:(NSPoint) offset fromPartcode:(NSInteger) pc
{
	NSSize ss = [self size];
	
	if( ss.width > 0.0 && ss.height > 0.0 )
	{
		NSPoint	p = [self pointForPartcode:pc];
		NSAffineTransform* transform = [self transformIncludingParent];
		[transform invert];
		p = [transform transformPoint:p];
		
		p.x += ( offset.x / ss.width );
		p.y += ( offset.y / ss.height );
		
		return [self pathWithRelativePosition:p finalSize:size];
	}
	else
		return nil;
}


///*********************************************************************************************************************
///
/// method:			path:withFinalSize:offsetBy:fromPartcode:
/// scope:			public instance method
/// overrides:		
/// description:	transforms a path to the final size and position relative to a partcode
/// 
/// parameters:		<path> the path to transform
///					<size> the final desired size of the rectangle
///					<offset> an offset in absolute units from the nominated partcode position
///					<pc> the partcode that the path is positioned relative to
/// result:			the transformed path
///
/// notes:			The resulting path is positioned at a fixed offset and size relative to a partcode (a corner, say)
///					in such a way that the object's size and angle set the positioning and orientation of the path
///					but not its actual size. This is useful for adding an adornment to the shape that is unscaled
///					by the object, such as the text indicator shown by DKTextShape
///
///********************************************************************************************************************

- (NSBezierPath*)			path:(NSBezierPath*) inPath withFinalSize:(NSSize) size offsetBy:(NSPoint) offset fromPartcode:(NSInteger) pc
{
	NSAssert( inPath != nil, @"can't do this with a nil path");
	
	// eliminate the path's origin offset and size it to the desired final size
	
	NSSize	ss = [self size];
	
	if( ss.width > 0 && ss.height > 0 )
	{
		NSPoint	p = [self pointForPartcode:pc];
		NSAffineTransform* transform = [self transformIncludingParent];
		[transform invert];
		p = [transform transformPoint:p];
		
		p.x += ( offset.x / ss.width );
		p.y += ( offset.y / ss.height );

		NSRect pr = [inPath bounds];
		
		NSAffineTransform* tfm = [NSAffineTransform transform];
		[tfm translateXBy:p.x yBy:p.y];
		[tfm scaleXBy:size.width / (pr.size.width * ss.width) yBy:size.height / (pr.size.height * ss.height)];
		[tfm translateXBy:-pr.origin.x yBy:-pr.origin.y];
		
		NSBezierPath* newPath = [tfm transformBezierPath:inPath];
	
		[newPath transformUsingAffineTransform:[self transformIncludingParent]];
		
		return newPath;
	}
	else
		return nil;
}



///*********************************************************************************************************************
///
/// method:			pointForRelativeLocation:
/// scope:			public instance method
/// overrides:		
/// description:	convert a point from relative coordinates to absolute coordinates
/// 
/// parameters:		<relLoc> a point expressed relative to the unit square
/// result:			the absolute point taking into account scale, position and angle
///
/// notes:			not affected by the object's current offset
///
///********************************************************************************************************************

- (NSPoint)					pointForRelativeLocation:(NSPoint) relLoc
{
	NSAffineTransform* transform = [self transformIncludingParent];
	return [transform transformPoint:relLoc];
}




@end
