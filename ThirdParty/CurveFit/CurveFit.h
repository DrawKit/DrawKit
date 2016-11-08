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

#ifdef __cplusplus
extern "C"
{
#endif

// curve fit vector paths using bezier curve fitting:

NSBezierPath*		curveFitPath(NSBezierPath* inPath, float epsilon);
NSBezierPath*		smartCurveFitPath( NSBezierPath* inPath, float epsilon, float cornerAngleThreshold );

#ifdef __cplusplus
}
#endif

// curve fit vector path using poTrace smoothing algorithm:


#ifndef SIGN
#define SIGN(x)		((x) > 0? 1 : (x) < 0? -1 : 0)
#endif


#define kDKDefaultCornerThreshold		(pi / 6)

#endif /* defined(qUseCurveFit) */
