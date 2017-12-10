/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKGeometryUtilities.h"
#import "NSBezierPath+Geometry.h"
#import "DKDrawKitMacros.h"
#import "LogEvent.h"

// this point constant is arbitrary but it is intended to be very unlikely to arise by chance. It can be used to signal "not found" when
// returning a point value from a function.

const NSPoint NSNotFoundPoint = { -10000000.2, -999999.6 };

/** @brief Forms a rectangle from any two corner points

 The rect is normalised, in that the relative positions of a and b do not affect the result - the
 rect always extends in the positive x and y directions.
 @param a a rect
 @paran b a rect
 @return the rectangle formed by a and b at the opposite corners */
NSRect NSRectFromTwoPoints(const NSPoint a, const NSPoint b)
{
	NSRect r;

	r.size.width = ABS(b.x - a.x);
	r.size.height = ABS(b.y - a.y);

	r.origin.x = MIN(a.x, b.x);
	r.origin.y = MIN(a.y, b.y);

	return r;
}

/** @brief Forms a rectangle of the given size centred on p
 @param p a point
 @param size the rect size
 @return the rectangle */
NSRect NSRectCentredOnPoint(const NSPoint p, const NSSize size)
{
	NSRect r;

	r.size = size;
	r.origin.x = p.x - (size.width * 0.5f);
	r.origin.y = p.y - (size.height * 0.5f);

	return r;
}

/** @brief Returns the smallest rect that encloses both a and b

 Unlike NSUnionRect, this is practical when either or both of the input rects have a zero
 width or height. For convenience, if either a or b is EXACTLY NSZeroRect, the other rect is
 returned, but in all other cases it correctly forms the union. While NSUnionRect might be
 considered mathematically correct, since a rect of zero width or height cannot "contain" anything
 in the set sense, what's more practically required for real geometry is to allow infinitely thin
 lines and points to push out the "envelope" of the rectangular space they define. That's what this does.
 @param a a rect
 @paran b a rect
 @return the rectangle that encloses a and b */
NSRect UnionOfTwoRects(const NSRect a, const NSRect b)
{
	if (NSEqualRects(a, NSZeroRect))
		return b;
	else if (NSEqualRects(b, NSZeroRect))
		return a;
	else {
		NSPoint tl, br;

		tl.x = MIN(NSMinX(a), NSMinX(b));
		tl.y = MIN(NSMinY(a), NSMinY(b));
		br.x = MAX(NSMaxX(a), NSMaxX(b));
		br.y = MAX(NSMaxY(a), NSMaxY(b));

		return NSRectFromTwoPoints(tl, br);
	}
}

/** @brief Returns the smallest rect that encloses all rects in the set
 @param aSet a set of NSValues containing rect values
 @return the rectangle that encloses all rects */
NSRect UnionOfRectsInSet(const NSSet* aSet)
{
	NSEnumerator* iter = [aSet objectEnumerator];
	NSValue* val;
	NSRect ur = NSZeroRect;

	while ((val = [iter nextObject]))
		ur = UnionOfTwoRects(ur, [val rectValue]);

	return ur;
}

/** @brief Returns the area that is different between two input rects, as a list of rects

 This can be used to optimize upates. If a and b are "before and after" rects of a visual change,
 the resulting list is the area to update assuming that nothing changed in the common area,
 which is frequently so. If a and b are equal, the result is empty. If a and b do not intersect,
 the result contains a and b.
 @param a, b a pair of rects
 @return an array of rect NSValues */
NSSet* DifferenceOfTwoRects(const NSRect a, const NSRect b)
{
	NSMutableSet* result = [NSMutableSet set];

	// if a == b, there is no difference, so return the empty set

	if (!NSEqualRects(a, b)) {
		NSRect ir = NSIntersectionRect(a, b);

		if (NSEqualRects(ir, NSZeroRect)) {
			// no intersection, so result is the two input rects

			[result addObject:[NSValue valueWithRect:a]];
			[result addObject:[NSValue valueWithRect:b]];
		} else {
			// a and b do intersect, so collect all the pieces by subtracting <ir> from each

			[result unionSet:SubtractTwoRects(a, ir)];
			[result unionSet:SubtractTwoRects(b, ir)];
		}
	}

	return result;
}

NSSet* SubtractTwoRects(const NSRect a, const NSRect b)
{
	// subtracts <b> from <a>, returning the pieces left over. If a and b don't intersect the result is correct
	// but unnecessary, so the caller should test for intersection first.

	NSMutableSet* result = [NSMutableSet set];

	CGFloat rml, lmr, upb, lwt, mny, mxy;

	rml = MAX(NSMaxX(b), NSMinX(a));
	lmr = MIN(NSMinX(b), NSMaxX(a));
	upb = MAX(NSMaxY(b), NSMinY(a));
	lwt = MIN(NSMinY(b), NSMaxY(a));
	mny = MIN(NSMaxY(a), NSMaxY(b));
	mxy = MAX(NSMinY(a), NSMinY(b));

	NSRect rr, rl, rt, rb;

	rr = NSMakeRect(rml, mxy, NSMaxX(a) - rml, mny - mxy);
	rl = NSMakeRect(NSMinX(a), mxy, lmr - NSMinX(a), mny - mxy);
	rt = NSMakeRect(NSMinX(a), upb, NSWidth(a), NSMaxY(a) - upb);
	rb = NSMakeRect(NSMinX(a), NSMinY(a), NSWidth(a), lwt - NSMinY(a));

	// add any non empty rects to the result

	if (rr.size.width > 0 && rr.size.height > 0)
		[result addObject:[NSValue valueWithRect:rr]];

	if (rl.size.width > 0 && rl.size.height > 0)
		[result addObject:[NSValue valueWithRect:rl]];

	if (rt.size.width > 0 && rt.size.height > 0)
		[result addObject:[NSValue valueWithRect:rt]];

	if (rb.size.width > 0 && rb.size.height > 0)
		[result addObject:[NSValue valueWithRect:rb]];

	return result;
}

BOOL AreSimilarRects(const NSRect a, const NSRect b, const CGFloat epsilon)
{
	// return YES if the rects a and b are within <epsilon> of each other.

	if (ABS(a.origin.x - b.origin.x) > epsilon)
		return NO;

	if (ABS(a.origin.y - b.origin.y) > epsilon)
		return NO;

	if (ABS(a.size.width - b.size.width) > epsilon)
		return NO;

	if (ABS(a.size.height - b.size.height) > epsilon)
		return NO;

	return YES;
}

#pragma mark -

/**  */
CGFloat PointFromLine(const NSPoint inPoint, const NSPoint a, const NSPoint b)
{
	NSPoint cp = NearestPointOnLine(inPoint, a, b);

	return hypot((inPoint.x - cp.x), (inPoint.y - cp.y));
}

/**  */
NSPoint NearestPointOnLine(const NSPoint inPoint, const NSPoint a, const NSPoint b)
{
	CGFloat mag = hypot((b.x - a.x), (b.y - a.y));

	if (mag > 0.0) {
		CGFloat u = (((inPoint.x - a.x) * (b.x - a.x)) + ((inPoint.y - a.y) * (b.y - a.y))) / (mag * mag);

		if (u <= 0.0)
			return a;
		else if (u >= 1.0)
			return b;
		else {
			NSPoint cp;

			cp.x = a.x + u * (b.x - a.x);
			cp.y = a.y + u * (b.y - a.y);

			return cp;
		}
	} else
		return a;
}

NSInteger PointInLineSegment(const NSPoint inPoint, const NSPoint a, const NSPoint b)
{
	// returns 0 if <inPoint> falls within the region defined by the line segment a-b, -1 if it's beyond the point a, 1 if beyond b. The "region" is an
	// infinite plane defined by all possible lines parallel to a-b.

	CGFloat mag = hypot((b.x - a.x), (b.y - a.y));

	if (mag > 0.0) {
		CGFloat u = (((inPoint.x - a.x) * (b.x - a.x)) + ((inPoint.y - a.y) * (b.y - a.y))) / (mag * mag);
		return (u >= 0 && u <= 1.0) ? 0 : (u < 0) ? -1 : 1;
	} else
		return -1;
}

/**  */
CGFloat RelPoint(const NSPoint inPoint, const NSPoint a, const NSPoint b)
{
	CGFloat d1, d2;

	d1 = LineLength(a, inPoint);
	d2 = LineLength(a, b);

	if (d2 != 0.0)
		return d1 / d2;
	else
		return 0.0;
}

#pragma mark -

/**  */
NSPoint BisectLine(const NSPoint a, const NSPoint b)
{
	NSPoint p;

	p.x = (a.x + b.x) * 0.5f;
	p.y = (a.y + b.y) * 0.5f;
	return p;
}

/**  */
NSPoint Interpolate(const NSPoint a, const NSPoint b, const CGFloat proportion)
{
	NSPoint p;

	p.x = a.x + ((b.x - a.x) * proportion);
	p.y = a.y + ((b.y - a.y) * proportion);
	return p;
}

CGFloat LineLength(const NSPoint a, const NSPoint b)
{
	return hypot(b.x - a.x, b.y - a.y);
}

#pragma mark -
CGFloat SquaredLength(const NSPoint p)
{
	return (p.x * p.x) + (p.y * p.y);
}

NSPoint DiffPoint(const NSPoint a, const NSPoint b)
{
	// returns the difference of two points

	NSPoint c;

	c.x = a.x - b.x;
	c.y = a.y - b.y;

	return c;
}

CGFloat DiffPointSquaredLength(const NSPoint a, const NSPoint b)
{
	// returns the square of the distance between two points

	return SquaredLength(DiffPoint(a, b));
}

NSPoint SumPoint(const NSPoint a, const NSPoint b)
{
	// returns the sum of two points

	NSPoint pn;

	pn.x = a.x + b.x;
	pn.y = a.y + b.y;

	return pn;
}

#pragma mark -
NSPoint EndPoint(NSPoint origin, CGFloat angle, CGFloat length)
{
	// returns the end point of a line given its origin, length and angle relative to x axis

	NSPoint ep;

	ep.x = origin.x + (cos(angle) * length);
	ep.y = origin.y + (sin(angle) * length);
	return ep;
}

CGFloat Slope(const NSPoint a, const NSPoint b)
{
	// returns the slope of a line given its end points, in radians

	return atan2(b.y - a.y, b.x - a.x);
}

CGFloat AngleBetween(const NSPoint a, const NSPoint b, const NSPoint c)
{
	// returns the angle formed between three points abc where b is the vertex.

	return Slope(a, b) - Slope(b, c);
}

CGFloat DotProduct(const NSPoint a, const NSPoint b)
{
	return (a.x * b.x) + (a.y * b.y);
}

NSPoint Intersection(const NSPoint aa, const NSPoint ab, const NSPoint ba, const NSPoint bb)
{
	// return the intersecting point of two lines a and b, whose end points are passed in. If the lines are parallel,
	// the result is undefined (NaN)

	NSPoint i;
	CGFloat sa, sb, ca, cb;

	sa = Slope(aa, ab);
	sb = Slope(ba, bb);

	ca = aa.y - sa * aa.x;
	cb = ba.y - sb * ba.x;

	i.x = (cb - ca) / (sa - sb);
	i.y = sa * i.x + ca;

	return i;
}

NSPoint Intersection2(const NSPoint p1, const NSPoint p2, const NSPoint p3, const NSPoint p4)
{
	// return the intersecting point of two lines SEGMENTS p1-p2 and p3-p4, whose end points are passed in. If the lines are parallel,
	// the result is NSNotFoundPoint. Uses an alternative algorithm from Intersection() - this is faster and more usable. This only returns a
	// point if the two segments actually intersect - it doesn't project the lines.

	CGFloat d = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y);

	// if d is 0, then lines are parallel and don't intersect

	if (d == 0.0)
		return NSNotFoundPoint;

	CGFloat ua = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / d;
	//float ub = ((p2.x - p1.x)*(p1.y - p3.y) - (p2.y - p1.y)*(p1.x - p3.x))/d;

	if (ua >= 0.0 && ua <= 1.0) {
		// segments do intersect

		NSPoint ip;

		ip.x = p1.x + ua * (p2.x - p1.x);
		ip.y = p1.y + ua * (p2.y - p1.y);

		return ip;
	} else
		return NSNotFoundPoint;
}

#pragma mark -
NSRect CentreRectOnPoint(const NSRect inRect, const NSPoint p)
{
	// relocates the rect so its centre is at p. Does not change the rect's size

	NSRect r = inRect;

	r.origin.x = p.x - (inRect.size.width * 0.5f);
	r.origin.y = p.y - (inRect.size.height * 0.5f);
	return r;
}

NSPoint MapPointFromRect(const NSPoint p, const NSRect rect)
{
	// given a point <p> within <rect> this returns it mapped to a 0..1 interval
	NSPoint pn;

	pn.x = (p.x - rect.origin.x) / rect.size.width;
	pn.y = (p.y - rect.origin.y) / rect.size.height;

	return pn;
}

NSPoint MapPointToRect(const NSPoint p, const NSRect rect)
{
	// given a point <p> in 0..1 space, maps it to <rect>
	NSPoint pn;

	pn.x = (p.x * rect.size.width) + rect.origin.x;
	pn.y = (p.y * rect.size.height) + rect.origin.y;

	return pn;
}

NSPoint MapPointFromRectToRect(const NSPoint p, const NSRect srcRect, const NSRect destRect)
{
	// maps a point <p> in <srcRect> to the same relative location within <destRect>

	return MapPointToRect(MapPointFromRect(p, srcRect), destRect);
}

NSRect MapRectFromRectToRect(const NSRect inRect, const NSRect srcRect, const NSRect destRect)
{
	// maps a rect from <srcRect> to the same relative position within <destRect>

	NSPoint p1, p2;

	p1 = inRect.origin;
	p2.x = NSMaxX(inRect);
	p2.y = NSMaxY(inRect);

	p1 = MapPointFromRectToRect(p1, srcRect, destRect);
	p2 = MapPointFromRectToRect(p2, srcRect, destRect);

	return NSRectFromTwoPoints(p1, p2);
}

#pragma mark -

NSRect ScaleRect(const NSRect inRect, const CGFloat scale)
{
	// multiplies the width and height of <inrect> by <scale> and offsets the origin by half the difference, which
	// keeps the original centre of the rect at the same point. Values > 1 expand the rect, < 1 shrink it.

	NSRect r = inRect;

	r.size.width *= scale;
	r.size.height *= scale;

	r.origin.x -= 0.5 * (r.size.width - inRect.size.width);
	r.origin.y -= 0.5 * (r.size.height - inRect.size.height);

	return r;
}

NSRect ScaledRectForSize(const NSSize inSize, const NSRect fitRect)
{
	// returns a rect having the same aspect ratio as <inSize>, scaled to fit within <fitRect>. The shorter side is centred
	// within <fitRect> as appropriate

	CGFloat ratio = inSize.width / inSize.height;
	NSRect r;

	CGFloat hxs, vxs;

	hxs = inSize.width / fitRect.size.width;
	vxs = inSize.height / fitRect.size.height;

	if (hxs >= vxs) {
		// fitting width, centering height

		r.size.width = fitRect.size.width;
		r.size.height = r.size.width / ratio;
		r.origin.x = fitRect.origin.x;
		r.origin.y = fitRect.origin.y + ((fitRect.size.height - r.size.height) / 2.0);
	} else {
		// fitting height, centering width

		r.size.height = fitRect.size.height;
		r.size.width = r.size.height * ratio;
		r.origin.y = fitRect.origin.y;
		r.origin.x = fitRect.origin.x + ((fitRect.size.width - r.size.width) / 2.0);
	}

	return r;
}

NSRect CentreRectInRect(const NSRect r, const NSRect cr)
{
	// centres <r> over <cr>, returning a rect the same size as <r>

	NSRect nr;

	nr.size = r.size;

	nr.origin.x = NSMinX(cr) + ((cr.size.width - r.size.width) / 2.0);
	nr.origin.y = NSMinY(cr) + ((cr.size.height - r.size.height) / 2.0);

	return nr;
}

NSBezierPath* RotatedRect(const NSRect r, const CGFloat radians)
{
	// turns the rect into a path, rotated about its centre by <radians>

	NSBezierPath* path = [NSBezierPath bezierPathWithRect:r];
	return [path rotatedPath:radians];
}

#pragma mark -
NSRect NormalizedRect(const NSRect r)
{
	// returns the same rect as the input, but adjusts any -ve width or height to be +ve and
	// compensates the origin.

	NSRect nr = r;

	if (r.size.width < 0) {
		nr.size.width = -r.size.width;
		nr.origin.x -= nr.size.width;
	}

	if (r.size.height < 0) {
		nr.size.height = -r.size.height;
		nr.origin.y -= nr.size.height;
	}

	return nr;
}

NSAffineTransform* RotationTransform(const CGFloat angle, const NSPoint cp)
{
	// return a transform that will cause a rotation about the point given at the angle given

	NSAffineTransform* xfm = [NSAffineTransform transform];
	[xfm translateXBy:cp.x
				  yBy:cp.y];
	[xfm rotateByRadians:angle];
	[xfm translateXBy:-cp.x
				  yBy:-cp.y];

	return xfm;
}

#pragma mark -
#pragma mark bezier curve utils

static NSPoint* ConvertToBezierForm(const NSPoint inp, const NSPoint bez[4]);
static NSInteger FindRoots(NSPoint* w, NSInteger degree, double* t, NSInteger depth);
static NSInteger CrossingCount(NSPoint* v, NSInteger degree);
static NSInteger ControlPolygonFlatEnough(NSPoint* v, NSInteger degree);
static double ComputeXIntercept(NSPoint* v, NSInteger degree);

#define MAXDEPTH 64
#define EPSILON (ldexp(1.0, -MAXDEPTH - 1))

#define SGN(a) (((a) < 0) ? -1 : 0)

#pragma mark -
/*
  ConvertToBezierForm :
 *		Given a point and a Bezier curve, generate a 5th-degree
 *		Bezier-format equation whose solution finds the point on the
      curve nearest the user-defined point. */
static NSPoint* ConvertToBezierForm(const NSPoint inp, const NSPoint bez[4])
{
	NSInteger i, j, k, m, n, ub, lb;
	NSInteger row, column; // Table indices
	NSPoint c[4]; // V(i)'s - P
	NSPoint d[3]; // V(i+1) - V(i)
	NSPoint* w; // Ctl pts of 5th-degree curve
	double cdTable[3][4]; // Dot product of c, d

	static double z[3][4] = { /* Precomputed "z" for cubics	*/
							  { 1.0, 0.6, 0.3, 0.1 },
							  { 0.4, 0.6, 0.6, 0.4 },
							  { 0.1, 0.3, 0.6, 1.0 }, };

	/*Determine the c's -- these are vectors created by subtracting*/
	/* point P from each of the control points				*/
	for (i = 0; i <= 3; i++) {
		c[i] = DiffPoint(bez[i], inp);
	}

	/* Determine the d's -- these are vectors created by subtracting*/
	/* each control point from the next					*/
	for (i = 0; i < 3; i++) {
		d[i].x = (bez[i + 1].x - bez[i].x) * 3.0;
		d[i].y = (bez[i + 1].y - bez[i].y) * 3.0;
	}

	/* Create the c,d table -- this is a table of dot products of the */
	/* c's and d's							*/

	for (row = 0; row < 3; row++) {
		for (column = 0; column <= 3; column++) {
			cdTable[row][column] = DotProduct(d[row], c[column]);
		}
	}

	/* Now, apply the z's to the dot products, on the skew diagonal*/
	/* Also, set up the x-values, making these "points"		*/

	w = (NSPoint*)malloc(6 * sizeof(NSPoint));

	for (i = 0; i <= 5; i++) {
		w[i].y = 0.0;
		w[i].x = (double)(i) / 5;
	}

	n = 3;
	m = 2;

	for (k = 0; k <= n + m; k++) {
		lb = MAX(0, k - m);
		ub = MIN(k, n);

		for (i = lb; i <= ub; i++) {
			j = k - i;
			w[i + j].y += cdTable[j][i] * z[j][i];
		}
	}

	return w;
}

/*
  FindRoots :
 *	Given a 5th-degree equation in Bernstein-Bezier form, find
 *	all of the roots in the interval [0, 1].  Return the number
 *	of roots found. */
static NSInteger FindRoots(NSPoint* w, NSInteger degree, double* t, NSInteger depth)
{
	NSInteger i;
	NSPoint Left[6], Right[6]; // control polygons
	NSInteger left_count, right_count;
	double left_t[6], right_t[6];

	switch (CrossingCount(w, degree)) {
	default:
		break;

	case 0: // No solutions here
		return 0;

	case 1: // Unique solution
		// Stop recursion when the tree is deep enough
		// if deep enough, return 1 solution at midpoint

		if (depth >= MAXDEPTH) {
			t[0] = (w[0].x + w[5].x) / 2.0;
			return 1;
		}

		if (ControlPolygonFlatEnough(w, degree)) {
			t[0] = ComputeXIntercept(w, degree);
			return 1;
		}
		break;
	}

	// Otherwise, solve recursively after
	// subdividing control polygon

	Bezier(w, degree, 0.5, Left, Right);
	left_count = FindRoots(Left, degree, left_t, depth + 1);
	right_count = FindRoots(Right, degree, right_t, depth + 1);

	// Gather solutions together
	for (i = 0; i < left_count; i++) {
		t[i] = left_t[i];
	}
	for (i = 0; i < right_count; i++) {
		t[i + left_count] = right_t[i];
	}

	// Send back total number of solutions

	return (left_count + right_count);
}

/*
 CrossingCount :
 *	Count the number of times a Bezier control polygon 
 *	crosses the 0-axis. This number is >= the number of roots.
 * */
static NSInteger CrossingCount(NSPoint* v, NSInteger degree)
{
	NSInteger i;
	NSInteger n_crossings = 0; /*  Number of zero-crossings	*/
	NSInteger sign, old_sign; /*  Sign of coefficients	*/

	old_sign = SGN(v[0].y);

	for (i = 1; i <= degree; i++) {
		sign = SGN(v[i].y);

		if (sign != old_sign)
			n_crossings++;
		old_sign = sign;
	}
	return n_crossings;
}

/*
  ControlPolygonFlatEnough :
 *	Check if the control polygon of a Bezier curve is flat enough
 *	for recursive subdivision to bottom out.
 * */
static NSInteger ControlPolygonFlatEnough(NSPoint* v, NSInteger degree)
{
	NSInteger i; // Index variable
	double* distance; // Distances from pts to line
	double max_distance_above; // maximum of these
	double max_distance_below;
	double error; // Precision of root
	double intercept_1,
		intercept_2,
		left_intercept,
		right_intercept;
	double a, b, c; // Coefficients of implicit
	// eqn for line from V[0]-V[deg]

	/* Find the  perpendicular distance		*/
	/* from each interior control point to 	*/
	/* line connecting V[0] and V[degree]	*/
	distance = (double*)malloc((NSUInteger)(degree + 1) * sizeof(double));
	double abSquared;

	/* Derive the implicit equation for line connecting first */
	/*  and last control points */

	a = v[0].y - v[degree].y;
	b = v[degree].x - v[0].x;
	c = v[0].x * v[degree].y - v[degree].x * v[0].y;

	abSquared = (a * a) + (b * b);

	for (i = 1; i < degree; i++) {
		// Compute distance from each of the points to that line
		distance[i] = a * v[i].x + b * v[i].y + c;
		if (distance[i] > 0.0) {
			distance[i] = (distance[i] * distance[i]) / abSquared;
		}
		if (distance[i] < 0.0) {
			distance[i] = -((distance[i] * distance[i]) / abSquared);
		}
	}

	/* Find the largest distance	*/
	max_distance_above = 0.0;
	max_distance_below = 0.0;
	for (i = 1; i < degree; i++) {
		if (distance[i] < 0.0) {
			max_distance_below = MIN(max_distance_below, distance[i]);
		}
		if (distance[i] > 0.0) {
			max_distance_above = MAX(max_distance_above, distance[i]);
		}
	}
	free((char*)distance);

	double det, dInv;
	double a1, b1, c1, a2, b2, c2;

	/*  Implicit equation for zero line */
	a1 = 0.0;
	b1 = 1.0;
	c1 = 0.0;

	/*  Implicit equation for "above" line */
	a2 = a;
	b2 = b;
	c2 = c + max_distance_above;

	det = a1 * b2 - a2 * b1;
	dInv = 1.0 / det;

	intercept_1 = (b1 * c2 - b2 * c1) * dInv;

	/*  Implicit equation for "below" line */
	a2 = a;
	b2 = b;
	c2 = c + max_distance_below;

	det = a1 * b2 - a2 * b1;
	dInv = 1.0 / det;

	intercept_2 = (b1 * c2 - b2 * c1) * dInv;

	/* Compute intercepts of bounding box	*/
	left_intercept = MIN(intercept_1, intercept_2);
	right_intercept = MAX(intercept_1, intercept_2);

	error = 0.5 * (right_intercept - left_intercept);
	if (error < EPSILON) {
		return 1;
	} else {
		return 0;
	}
}

/*
  ComputeXIntercept :
 *	Compute intersection of chord from first control point to last
  	with 0-axis.
  */

static double ComputeXIntercept(NSPoint* v, NSInteger degree)
{
	double XLK, YLK, XNM, YNM, XMK, YMK;
	double det, detInv;
	double S;
	double X;

	XLK = 1.0;
	YLK = 0.0;
	XNM = v[degree].x - v[0].x;
	YNM = v[degree].y - v[0].y;
	XMK = v[0].x;
	YMK = v[0].y;

	det = XNM * YLK - YNM * XLK;
	detInv = 1.0 / det;

	S = (XNM * YMK - YNM * XMK) * detInv;
	X = XLK * S;

	return X;
}

#pragma mark -
/*
  NearestPointOnCurve :
  	Compute the parameter value of the point on a Bezier
 *		curve segment closest to some arbtitrary, user-input point.
 *		Return the point on the curve at that parameter value.
 * */

NSPoint NearestPointOnCurve(const NSPoint inp, const NSPoint bez[4], double* tValue)
{
	NSPoint* w; // Ctl pts for 5th-degree eqn
	double t_candidate[5]; // Possible roots
	NSInteger n_solutions; // Number of roots found
	double t; // Parameter value of closest pt

	// Convert problem to 5th-degree Bezier form

	w = ConvertToBezierForm(inp, bez);

	// Find all possible roots of 5th-degree equation

	n_solutions = FindRoots(w, 5, t_candidate, 0);
	free((char*)w);

	// Compare distances of P to all candidates, and to t=0, and t=1

	double dist, new_dist;
	NSPoint p;
	NSInteger i;

	// Check distance to beginning of curve, where t = 0

	dist = DiffPointSquaredLength(inp, bez[0]);
	t = 0.0;

	// Find distances for candidate points

	for (i = 0; i < n_solutions; i++) {
		p = Bezier(bez, 3, t_candidate[i], NULL, NULL);

		new_dist = DiffPointSquaredLength(inp, p);
		if (new_dist < dist) {
			dist = new_dist;
			t = t_candidate[i];
		}
	}

	// Finally, look at distance to end point, where t = 1.0

	new_dist = DiffPointSquaredLength(inp, bez[3]);
	if (new_dist < dist) {
		t = 1.0;
	}

	/*  Return the point on the curve at parameter value t */
	//    LogEvent_(kInfoEvent, @"t : %4.12f", t);

	if (tValue)
		*tValue = t;

	return Bezier(bez, 3, t, NULL, NULL);
}

/*
  Bezier : 
 *	Evaluate a Bezier curve at a particular parameter value
      Fill in control points for resulting sub-curves if "Left" and
 *	"Right" are non-null.
  */
NSPoint Bezier(const NSPoint* v, const NSInteger degree, const double t, NSPoint* Left, NSPoint* Right)
{
	NSInteger i, j; /* Index variables	*/
	NSPoint Vtemp[6][6];

	/* Copy control points	*/
	for (j = 0; j <= degree; j++) {
		Vtemp[0][j] = v[j];
	}

	/* Triangle computation	*/
	for (i = 1; i <= degree; i++) {
		for (j = 0; j <= degree - i; j++) {
			Vtemp[i][j].x = (1.0 - t) * Vtemp[i - 1][j].x + t * Vtemp[i - 1][j + 1].x;
			Vtemp[i][j].y = (1.0 - t) * Vtemp[i - 1][j].y + t * Vtemp[i - 1][j + 1].y;
		}
	}

	if (Left) {
		for (j = 0; j <= degree; j++) {
			Left[j] = Vtemp[j][0];
		}
	}
	if (Right) {
		for (j = 0; j <= degree; j++) {
			Right[j] = Vtemp[degree - j][j];
		}
	}

	return (Vtemp[degree][0]);
}

#pragma mark -
CGFloat BezierSlope(const NSPoint bez[4], const CGFloat t)
{
	// returns the slope of the curve defined by the bezier control points <bez[0..3]> at the t value given. This slope can be used to determine
	// the angle of something placed at that point tangent to the curve, such as a text character, etc. Add 90 degrees to get the normal to any
	// point. For text on a path, you also need to calculate t based on a linear length along the path.

	double x, y, tt;
	double ax, bx, cx; // coefficients for cubic in x
	double ay, by, cy; // coefficients for cubic in y

	// compute the coefficients of the bezier function:

	cx = 3.0 * (bez[1].x - bez[0].x);
	bx = 3.0 * (bez[2].x - bez[1].x) - cx;
	ax = bez[3].x - bez[0].x - cx - bx;

	cy = 3.0 * (bez[1].y - bez[0].y);
	by = 3.0 * (bez[2].y - bez[1].y) - cy;
	ay = bez[3].y - bez[0].y - cy - by;

	tt = LIMIT(t, 0.0, 1.0);

	// tangent is first derivative, i.e. quadratic differentiated from cubic:

	x = (3.0 * ax * tt * tt) + (2.0 * bx * tt) + cx;
	y = (3.0 * ay * tt * tt) + (2.0 * by * tt) + cy;

	return atan2(y, x);
}
