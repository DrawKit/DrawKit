///**********************************************************************************************************************************
///  DKGeometryUtilities.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 22/10/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import <Cocoa/Cocoa.h>

#ifdef __cplusplus
extern "C"
{
#endif


NSRect				NSRectFromTwoPoints( const NSPoint a, const NSPoint b );
NSRect				NSRectCentredOnPoint( const NSPoint p, const NSSize size );
NSRect				UnionOfTwoRects( const NSRect a, const NSRect b );
NSRect				UnionOfRectsInSet( const NSSet* aSet );
NSSet*				DifferenceOfTwoRects( const NSRect a, const NSRect b );
NSSet*				SubtractTwoRects( const NSRect a, const NSRect b );

BOOL				AreSimilarRects( const NSRect a, const NSRect b, const CGFloat epsilon );

CGFloat				PointFromLine( const NSPoint inPoint, const NSPoint a, const NSPoint b );
NSPoint				NearestPointOnLine( const NSPoint inPoint, const NSPoint a, const NSPoint b );
CGFloat				RelPoint( const NSPoint inPoint, const NSPoint a, const NSPoint b );
NSInteger			PointInLineSegment( const NSPoint inPoint, const NSPoint a, const NSPoint b );

NSPoint				BisectLine( const NSPoint a, const NSPoint b );
NSPoint				Interpolate( const NSPoint a, const NSPoint b, const CGFloat proportion);
CGFloat				LineLength( const NSPoint a, const NSPoint b );

CGFloat				SquaredLength( const NSPoint p );
NSPoint				DiffPoint( const NSPoint a, const NSPoint b );
CGFloat				DiffPointSquaredLength( const NSPoint a, const NSPoint b );
NSPoint				SumPoint( const NSPoint a, const NSPoint b );

NSPoint				EndPoint( NSPoint origin, CGFloat angle, CGFloat length );
CGFloat				Slope( const NSPoint a, const NSPoint b );
CGFloat				AngleBetween( const NSPoint a, const NSPoint b, const NSPoint c );
CGFloat				DotProduct( const NSPoint a, const NSPoint b );
NSPoint				Intersection( const NSPoint aa, const NSPoint ab, const NSPoint ba, const NSPoint bb );
NSPoint				Intersection2( const NSPoint p1, const NSPoint p2, const NSPoint p3, const NSPoint p4 );

NSRect				CentreRectOnPoint( const NSRect inRect, const NSPoint p );
NSPoint				MapPointFromRect( const NSPoint p, const NSRect rect );
NSPoint				MapPointToRect( const NSPoint p, const NSRect rect );
NSPoint				MapPointFromRectToRect( const NSPoint p, const NSRect srcRect, const NSRect destRect );
NSRect				MapRectFromRectToRect( const NSRect inRect, const NSRect srcRect, const NSRect destRect );

NSRect				ScaleRect( const NSRect inRect, const CGFloat scale );
NSRect				ScaledRectForSize( const NSSize inSize, NSRect const fitRect );
NSRect				CentreRectInRect(const NSRect r, const NSRect cr );
NSBezierPath*		RotatedRect( const NSRect r, const CGFloat radians );

NSRect				NormalizedRect( const NSRect r );
NSAffineTransform*	RotationTransform( const CGFloat radians, const NSPoint aboutPoint );

//NSPoint			PerspectiveMap( NSPoint inPoint, NSSize sourceSize, NSPoint quad[4]);

NSPoint				NearestPointOnCurve( const NSPoint inp, const NSPoint bez[4], double* tValue );
NSPoint				Bezier( const NSPoint* v, const NSInteger degree, const double t, NSPoint* Left, NSPoint* Right );

CGFloat				BezierSlope( const NSPoint bez[4], const CGFloat t );

extern const NSPoint NSNotFoundPoint;


#ifdef __cplusplus
}
#endif

