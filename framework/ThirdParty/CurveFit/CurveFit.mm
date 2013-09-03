/*
 *  CurveFit.mm
///  DrawKit ©2005-2008 Apptree.net
 *
 *  Created by graham on 05/11/2006.
 *  Copyright 2006 Apptree.net. All rights reserved.
 *
 */

#ifdef qUseCurveFit

#import "CurveFit.h"
#import "bezier-utils.h"
#import "../../Code/NSBezierPath+Geometry.h"
#import "../../Code/DKGeometryUtilities.h"



NSBezierPath*			curveFitPath(NSBezierPath* inPath, float epsilon)
{
	// given an input path in vector form (flattened), this converts it to the C++ data structure list of points and processes it via the
	// curve fit method in the bezier-utils lib. It then converts the result back to NSBezierPath form. Note - the caller is responsible for passing
	// a flattened path.
	
	Geom::Point*	pd;
	int				ec, i;
	NSPoint			p[3];
	NSBezierPath*	result = [NSBezierPath bezierPath];
	
	ec = [inPath elementCount];
	
	if ( ec < 3 )
	{
		[result appendBezierPath:inPath];
		return result;
	}
	
	pd = (Geom::Point*) malloc( sizeof( Geom::Point ) * ec );
	
	for( i = 0; i < ec; ++i )
	{
		[inPath elementAtIndex:i associatedPoints:p];
		pd[i] = Geom::Point((Geom::Coord)p[0].x, (Geom::Coord)p[0].y);
	}
	
	// converted, now try the curve fit. Note that we don't know how much space we need to store the result, and the code doesn't give
	// us a way to find out, so we just create a big buffer and hope for the best.
	
	int				segments, maxSegments;
	Geom::Point*	segBuffer;
	
	maxSegments = 256;
	segBuffer = (Geom::Point*) malloc( sizeof( Geom::Point ) * maxSegments * 4 );
	
	// do the fitting:
	
	segments = bezier_fit_cubic_r( segBuffer, pd, ec, epsilon, maxSegments );
	
	if ( segments > 0 )
	{
		//NSLog(@"curve fit generated %d segments", segments );
		
		// we got a result, so convert it back to an NSBezierPath. The result is returned as quads of points (presumably this means that
		// there is a lot of duplication).
		
		NSPoint temp[3];
		int		segElement;
		
		temp[0].x = segBuffer[0][Geom::X];
		temp[0].y = segBuffer[0][Geom::Y];
		[result moveToPoint:temp[0]];
		
		for( i = 0; i < segments; ++i )
		{
			segElement = ( i * 4 ) + 1;
			
			temp[0].x = segBuffer[segElement][Geom::X];
			temp[0].y = segBuffer[segElement++][Geom::Y];
			temp[1].x = segBuffer[segElement][Geom::X];
			temp[1].y = segBuffer[segElement++][Geom::Y];
			temp[2].x = segBuffer[segElement][Geom::X];
			temp[2].y = segBuffer[segElement][Geom::Y];
		
			[result curveToPoint:temp[2] controlPoint1:temp[0] controlPoint2:temp[1]];
		}
	}
	
	// clean up
	
	free( pd );
	free( segBuffer );
	
	return result;
}


NSBezierPath*		smartCurveFitPath( NSBezierPath* inPath, float epsilon, float cornerAngleThreshold )
{
	// this curve fits a flattened path, but is much smarter about which parts of the path to curve fit and which to leave alone. It
	// also properly deals with separate subpaths within the original path (holes).
	
	// a line segment that is longer than a given threshhold is not curve-fitted, and sharp corners also define boundaries for curve
	// segments. Existing curved segments are copied to the result without any changes.
	
	int						i, ec = [inPath elementCount];
	NSBezierPathElement		elem;
	NSPoint					ap[3], np[3];
	NSPoint					lastPoint = NSZeroPoint;
	NSPoint					firstPoint = NSZeroPoint;
	NSBezierPath*			result;
	NSBezierPath*			temp;
	float					angle;
	
	result = [NSBezierPath bezierPath];
	[result setWindingRule:[inPath windingRule]];
	
	if ( ec > 0 )
	{
		temp = [NSBezierPath bezierPath];	// holds the accumulated elements for each subsection
		
		for( i = 0; i < ec; ++i )
		{
			elem = [inPath elementAtIndex:i associatedPoints:ap];
			
			switch( elem )
			{
				case NSMoveToBezierPathElement:
					// if temp has accumulated anything, curve fit it and append to result
					
					if ([temp elementCount] > 1 )
					{
						[result appendBezierPathRemovingInitialMoveToPoint:curveFitPath( temp, epsilon )];
						[temp removeAllPoints];
					}
					[temp moveToPoint:ap[0]];
					[result moveToPoint:ap[0]];
					lastPoint = firstPoint = ap[0];
					break;
				
				case NSLineToBezierPathElement:

					if ([temp isEmpty])
						[temp moveToPoint:ap[0]];
					else
						[temp lineToPoint:ap[0]];
						
					// find out if there is a sharp turn here, or the contributing lengths are long

					if( i < ( ec - 1 ))
					{
						elem = [inPath elementAtIndex:i+1 associatedPoints:np];
						
						if ( elem == NSClosePathBezierPathElement )
							np[0] = firstPoint;
						
						angle = AngleBetween( lastPoint, ap[0], np[0] );
					}
					else
						angle = AngleBetween( lastPoint, ap[0], firstPoint );

					lastPoint = ap[0];

					// compare sharp-turniness against the threshold
					
					if( ABS( angle ) > cornerAngleThreshold )
					{
						// accumulated subcurve is complete and can be processed
						
						if ([temp elementCount] > 1 )
						{
							[result appendBezierPathRemovingInitialMoveToPoint:curveFitPath( temp, epsilon )];
						
							// will now start a new temp path
						
							[temp removeAllPoints];
							[temp moveToPoint:ap[0]];
						}
					}	
					break;
				
				case NSCurveToBezierPathElement:
					if ([temp elementCount] > 1 )
					{
						[result appendBezierPathRemovingInitialMoveToPoint:curveFitPath( temp, epsilon )];
						[temp removeAllPoints];
					}
					[result curveToPoint:ap[2] controlPoint1:ap[0] controlPoint2:ap[1]];
					lastPoint = ap[2];
					break;
				
				case NSClosePathBezierPathElement:
					if ([temp elementCount] > 1 )
					{
						[temp lineToPoint:firstPoint];
						[result appendBezierPathRemovingInitialMoveToPoint:curveFitPath( temp, epsilon )];
						[temp removeAllPoints];
					}
					[result closePath];
					lastPoint = firstPoint;
					break;
				default:
					assert("Encountered invalid switch case.");
					break;
			}
		}
	}
	return result;
}


#endif /* defined(qUseCurveFit) */


