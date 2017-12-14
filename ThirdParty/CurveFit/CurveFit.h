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

extern NSBezierPath*		curveFitPath(NSBezierPath* inPath, CGFloat epsilon);
extern NSBezierPath*		smartCurveFitPath( NSBezierPath* inPath, CGFloat epsilon, CGFloat cornerAngleThreshold );

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
