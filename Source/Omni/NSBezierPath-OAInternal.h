// Copyright 2006-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniAppKit/OpenStepExtensions.subproj/NSBezierPath-OAInternal.h 89482 2007-08-02 01:03:15Z kc $

#import <Cocoa/Cocoa.h>
#import "NSBezierPath-OAExtensions.h"

//#import <OmniBase/assertions.h>

#define OmniAppKit_EXTERN extern
#define OmniAppKit_PRIVATE_EXTERN __private_extern__

/*
 The two curves which participate in an intersection are arbitrarily termed "left" and "right". (This is easy to confuse with the more literal left and right,
 maybe they should be called A and B or "charm"/"strange" or something.)
 The aspect indicates, from the POV of the "left" curve, how the other curve crosses it (left->right, right->left, or seven other rarer possibilities).
 So despite the name it's actually the aspect of the right curve, as viewed by the left curve. I find it least confusing to have all struct members dealing
 with the left curve start with "left...", though, which leads to this somewhat odd name.
*/

struct intersectionInfo {
	double leftParameter, rightParameter;
	double leftParameterDistance, rightParameterDistance;
	OAIntersectionAspect leftEntryAspect, leftExitAspect;
};

typedef struct OAdPoint {
	double x;
	double y;
} OAdPoint;

#define MAX_INTERSECTIONS_WITH_LINE 3 // The maximum number of intersections between a cubic curve and a line
#define MAX_INTERSECTIONS_PER_ELT_PAIR 16 // Maximum intersections between two cubic curves (an overestimate; 9 is the real number)

OmniAppKit_EXTERN void _parameterizeLine(NSPoint* coefficients, NSPoint startPoint, NSPoint endPoint);
OmniAppKit_EXTERN void _parameterizeCurve(NSPoint* coefficients, NSPoint startPoint, NSPoint endPoint, NSPoint controlPoint1, NSPoint controlPoint2);
OmniAppKit_EXTERN NSInteger intersectionsBetweenLineAndLine(const NSPoint* l1, const NSPoint* l2, struct intersectionInfo* results);
OmniAppKit_EXTERN NSInteger intersectionsBetweenCurveAndLine(const NSPoint* c, const NSPoint* a, struct intersectionInfo* results);
OmniAppKit_EXTERN NSInteger intersectionsBetweenCurveAndCurve(const NSPoint* c1coefficients, const NSPoint* c2coefficients, struct intersectionInfo* results);
OmniAppKit_EXTERN NSInteger intersectionsBetweenCurveAndSelf(const NSPoint* coefficients, struct intersectionInfo* results);

// Happy fun arbitrary constants.
#define EPSILON 1e-10
#define FLATNESS 2e-5
