/*
 *  CurveFit.h
///  DrawKit ©2005-2008 Apptree.net
 *
 *  Created by graham on 05/11/2006.
 *  Copyright 2006 Apptree.net. All rights reserved.
 *
 */

// utils:

#ifdef qUseCurveFit

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C"
{
#endif

// curve fit vector paths using bezier curve fitting:

/** Given an input path in vector form (flattened), this converts it to the C++ data structure list of points and processes it via the
 curve fit method in the bezier-utils lib. It then converts the result back to NSBezierPath form. Note - the caller is responsible for passing
 a flattened path.
 */
extern NSBezierPath* curveFitPath(NSBezierPath* inPath, CGFloat epsilon);

/** This curve fits a flattened path, but is much smarter about which parts of the path to curve fit and which to leave alone. It
 also properly deals with separate subpaths within the original path (holes).

 A line segment that is longer than a given threshhold is not curve-fitted, and sharp corners also define boundaries for curve
 segments. Existing curved segments are copied to the result without any changes.
 */
extern NSBezierPath* smartCurveFitPath(NSBezierPath* inPath, CGFloat epsilon, CGFloat cornerAngleThreshold);

#ifdef __cplusplus
}
#endif

// curve fit vector path using poTrace smoothing algorithm:


#ifndef SIGN
#define SIGN(x)		((x) > 0? 1 : (x) < 0? -1 : 0)
#endif


#define kDKDefaultCornerThreshold		(M_PI / 6)

NS_ASSUME_NONNULL_END

#endif /* defined(qUseCurveFit) */
