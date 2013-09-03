//
//  NSBezierPath+Combinatorial.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 28/05/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "NSBezierPath+Combinatorial.h"
#import "NSBezierPath-OAExtensions.h"
#import "NSBezierPath+Geometry.h"


@interface NSBezierPath (CombinatorialPrivate)

- (void)			appendSplitElementFromPath:(NSBezierPath*) path withIntersectionInfo:(OABezierPathIntersection*) info rightOrLeft:(BOOL) isRight trailingOrLeading:(BOOL) isLeading;
- (void)			appendElementsFromPath:(NSBezierPath*) path fromIndex:(NSInteger) firstIndex toIndex:(NSInteger) nextIndex;
- (void)			appendElementsFromPath:(NSBezierPath*) inRange:(NSRange) range;
- (NSArray*)		breakApartWithIntersectionInfo:(PathIntersectionList) info rightOrLeft:(BOOL) isRight;

@end




@implementation NSBezierPath (Combinatorial)


- (void)	showIntersectionsWithPath:(NSBezierPath*) path
{
	// test method, uses the Omni code to find the intersections, then draws a blob at the found points.
	
	PathIntersectionList	ptList = [self allIntersectionsWithPath:path];
	// walk the list, and draw
	
	OABezierPathIntersection	ps;
	NSUInteger					i;
	NSBezierPath*				blob;
	NSRect						blobRect;
	
	blobRect.size = NSMakeSize( 5, 5 );
	
	for( i = 0; i < ptList.count; ++i )
	{
		ps = ptList.intersections[i];
		
		blobRect.origin = ps.location;
		blobRect = NSOffsetRect( blobRect, -2.5, -2.5 );
		
		blob = [NSBezierPath bezierPathWithOvalInRect:blobRect];
		
		// select a colour based on direction
		
		switch( ps.right.firstAspect )
		{
			default:
			case intersectionEntryLeft:
				[[NSColor redColor] set];
				break;
				
			case intersectionEntryAt:
				[[NSColor yellowColor] set];
				break;
				
			case intersectionEntryRight:
				[[NSColor blueColor] set];
				break;
		}
		[blob fill];
		// label it so we can see the order
		
		NSString* str = [NSString stringWithFormat:@"%ld", (long)i];
		[str drawAtPoint:blobRect.origin withAttributes:nil];
		
		//NSLog(@"intersection = %d, element = %d", i, ps.left.segment);
	}
}


- (NSBezierPath*)	renormalizePath
{
	// this returns a path such that all of its subpaths are in a clockwise direction. It may return self if there is nothing to do. This is done first for each subpath
	// contributing to a boolean operation so that the logic to perform the combinations is made more straightforward.
	
	// first see if there's nothing to do and , err, do it...

	if([self countSubPaths] == 1)
	{
		if([self isClockwise])
			return self;
		else
			return [self bezierPathByReversingPath];
	}
	
	// more than one subpath, so break the path apart and recurse, collecting the subpaths back into a new path. This
	// will only be executed once at the top level as paths are not hierarchical.
	
	NSBezierPath*	newPath = [NSBezierPath bezierPath];
	NSArray*		subs = [self subPaths];
	NSUInteger		i;
	
	for( i = 0; i < [subs count]; ++i )
	{
		NSBezierPath* sub = [subs objectAtIndex:i];
		[newPath appendBezierPath:[sub renormalizePath]];
	}
	
	return newPath;
}


- (void)			appendElementsFromPath:(NSBezierPath*) path inRange:(NSRange) range
{
	// copies the elements within the range from <path> to the receiver. If the range exceeds the number of elements in the path, the rest of the
	// elements are copied. If the range starts beyond the end of the path, this does nothing. If <path> completes with a closePath, it is not appended to this path.
	// the path should not contain any subpaths.
		
	NSAssert( path != nil, @"can't append from a nil path");
	
	NSUInteger				i, m = MIN( NSMaxRange( range ) + 1, (NSUInteger)[path elementCount]);
	NSBezierPathElement		element;
	NSPoint					points[3];
	NSPoint					pointForClosure;
	
	pointForClosure = [path currentpointForSegment:0];
	
	NSLog(@"appending in range %@, max = %ld", NSStringFromRange( range ), (long)m);
	
	if ( range.location >= (NSUInteger)[path elementCount])
		return;
	
	for( i = range.location; i < m; ++i )
	{
		element = [path elementAtIndex:i associatedPoints:points];
		
		switch( element )
		{
			case NSCurveToBezierPathElement:
				if([self isEmpty])
					[self moveToPoint:points[2]];
				else
					[self curveToPoint:points[2] controlPoint1:points[0] controlPoint2:points[1]];
				break;
				
			case NSClosePathBezierPathElement:
				points[0] = pointForClosure;	// fall through
			case NSLineToBezierPathElement:
				if([self isEmpty])
					[self moveToPoint:points[0]];
				else
					[self lineToPoint:points[0]];
				break;
				
			default:
			case NSMoveToBezierPathElement:
				break;
		}
	}
}


- (void)			appendElementsFromPath:(NSBezierPath*) path fromIndex:(NSInteger) firstIndex toIndex:(NSInteger) nextIndex
{
	// given a path, this copies the elements, from <first> to <next> inclusive, to this path. index values must be +ve. If nextIndex < firstIndex, the copy
	// wraps around and copies elements from the beginning of the path up to <nextIndex>. If it does this, it converts closePaths to lineTos and
	// skips the leading moveTo of the contributing path.
	
	NSAssert( path != nil, @"can't append elements from a nil path");
	NSAssert( firstIndex >= 0, @"index value is negative");
	NSAssert( nextIndex >= 0, @"index value is negative");
	
	NSLog(@"appending elements from %ld to %ld", (long)firstIndex, (long)nextIndex );
	
	BOOL isWrapping = (nextIndex < firstIndex);
	
	NSInteger end = nextIndex;
	
	if( isWrapping )
		end = [path elementCount];
		
	[self appendElementsFromPath:path inRange:NSMakeRange( firstIndex, end - firstIndex )];
	
	if( isWrapping )
		[self appendElementsFromPath:path inRange:NSMakeRange( 0, nextIndex )];
}



- (void)	appendSplitElementFromPath:(NSBezierPath*) path withIntersectionInfo:(OABezierPathIntersection*) info rightOrLeft:(BOOL) isRight trailingOrLeading:(BOOL) isLeading;
{
	NSAssert( path != nil, @"can't append elements from nil path");
	
	NSInteger		segment;
	CGFloat	t;
	
	if( isRight )
	{
		segment = info->right.segment;
		t = info->right.parameter;
	}
	else
	{
		segment = info->left.segment;
		t = info->left.parameter;
	}
	
	// segment must be in range
	
	if( segment >= [path elementCount] || segment < 0 )
		return;
	
	NSPoint				points[4];
	NSBezierPathElement element = [path elementAtIndex:segment associatedPoints:&points[1]];
	points[0] = [path currentpointForSegment:element];
	
	if( element == NSCurveToBezierPathElement )
	{
		NSPoint left[4], right[4];
		splitBezierCurveTo( points, t, left, right );
		
		if( isLeading )
			[self curveToPoint:right[3] controlPoint1:right[1] controlPoint2:right[2]];
		else
			[self curveToPoint:left[3] controlPoint1:left[1] controlPoint2:left[2]];
	}
	else
	{
		if ( isLeading )
			[self lineToPoint:points[1]];
		else
			[self lineToPoint:info->location];
	}
}


- (NSArray*)		breakApartWithIntersectionInfo:(PathIntersectionList) info rightOrLeft:(BOOL) isRight
{
	// divides the receiver into as many parts as necessary at the intersection points. The intersection info is followed down the left or right avenues according to
	// the flag. To assist with the subsequent recombination, the path starting points are relocated to the first intersection point.
	
	NSUInteger		i, m = info.count;
	NSInteger				startIndex, endIndex;
	NSMutableArray*	parts = [NSMutableArray array];
	NSBezierPath*	piece;
	
	for( i = 0; i < 1; ++i )
	{
		if( isRight )
		{
			startIndex = info.intersections[i].right.segment;
			
			if( i == ( m - 1 ))
				endIndex = info.intersections[0].right.segment - 1;
			else
				endIndex = info.intersections[i+1].right.segment - 1;
		}
		else
		{
			startIndex = info.intersections[i].left.segment;
			if( i == ( m - 1 ))
				endIndex = info.intersections[0].left.segment - 1;
			else
				endIndex = info.intersections[i+1].left.segment - 1;
				
		}
	
		if( endIndex < 0 )
			endIndex = [self elementCount] - 1;

		piece = [NSBezierPath bezierPath];
		
		//[piece moveToPoint:info.intersections[i].location];
		//[piece appendSplitElementFromPath:self withIntersectionInfo:&info.intersections[i] rightOrLeft:isRight trailingOrLeading:YES];
		[piece appendElementsFromPath:self fromIndex:startIndex + 1 toIndex:endIndex];
		//[piece appendSplitElementFromPath:self withIntersectionInfo:&info.intersections[i+1] rightOrLeft:isRight trailingOrLeading:NO];
		
		//NSLog(@"original path = %@", self );
		//[piece appendElementsFromPath:self fromIndex:4 toIndex:2];
		//NSLog(@"new path = %@", piece );
		
		[parts addObject:piece];
	}
	
	return parts;
}


- (NSBezierPath*)	performBooleanOp:(DKBooleanOperation) op withPath:(NSBezierPath*) path
{
	#pragma unused(op)
	
	// first renormalize both contributing paths
	
	NSBezierPath* leftPath, *rightPath;
	
	leftPath = [self renormalizePath];
	rightPath = [path renormalizePath];
	
	// find the intersections
	
	PathIntersectionList	ptList = [leftPath allIntersectionsWithPath:rightPath];
	
	// assemble the new path. We start at the first intersection point, which will begin the new path. This point is common to all operations, unlike the first point
	// of either source path, which may not be included in an intersection.
	
	NSBezierPath* newPath = [NSBezierPath bezierPath];
	
	BOOL			phase = NO;		// phase tracks whether we are following the left or right path
	NSBezierPath*	srcPath;		// srcPath is the one we are following at the moment.
	NSUInteger		sectIndex;		// index to which intersection is currently being actioned
	NSPoint			previousPoint;	// the last end point of a segment
	NSInteger				firstElement;	// tracks the index of the very first element we use
	
	// interSect is set to the current intersection we are using.
	
	struct OABezierPathIntersectionHalf interSect;
	
	sectIndex = 0;
	srcPath = leftPath;							// start with the left path
	interSect = ptList.intersections[0].left;
	firstElement = interSect.segment;
	
	// new path starts here regardless
	
	previousPoint = ptList.intersections[0].location;
	[newPath moveToPoint:previousPoint];
	
	while( sectIndex < ptList.count )
	{
		// the loop starts with the most recent intersection point, so by definition this is splitting a segment.
		
		NSInteger						lmIndex, nextIndex;
		NSBezierPathElement		element;
		NSPoint					points[4];	// up to four segment points (4 for curves, 2 for lines) 0 = previous end point or start of segment.
		
		points[0] = previousPoint;
		lmIndex = interSect.segment;
		element = [srcPath elementAtIndex:lmIndex associatedPoints:&points[1]];
		
		if( element == NSCurveToBezierPathElement )
		{
			// split the curve segment
			
			NSPoint	leftPoints[4], rightPoints[4];
			
			splitBezierCurveTo( points, interSect.parameter, leftPoints, rightPoints );
			[newPath curveToPoint:rightPoints[3] controlPoint1:rightPoints[1] controlPoint2:rightPoints[2]];
			previousPoint = rightPoints[3];
		}
		else
		{
			// line segment
			
			[newPath lineToPoint:points[0]];
			previousPoint = points[0];
		}
		++lmIndex;
		
		// which element of the source path contains the next intersection?
		
		++sectIndex;
		
		if( sectIndex >= ptList.count )
		{
			// no more intersections, so all that remains is to copy the remainder of the srcPath to the newPath,
			// looping if needed so that the first part of the path is also copied, and append the final split.
			
			[newPath appendElementsFromPath:srcPath fromIndex:lmIndex toIndex:[srcPath elementCount]];
			
			// and the first part:
			
			if( firstElement > 0 )
				[newPath appendElementsFromPath:srcPath fromIndex:0 toIndex:firstElement - 1];
			
			// and the final split:
			
		}
		else
		{
			if( phase )
				nextIndex = ptList.intersections[sectIndex].right.segment - 1;
			else
				nextIndex = ptList.intersections[sectIndex].left.segment - 1;
			
			// copy elements from src to new between the two indexes. Might need two calls if we wrap around the path start point.
			
			if ( nextIndex < lmIndex )
			{
				// need to wrap around
				
				[newPath appendElementsFromPath:srcPath fromIndex:lmIndex toIndex:[srcPath elementCount]];
				lmIndex = 0;
			}
			
			[newPath appendElementsFromPath:srcPath fromIndex:lmIndex toIndex:nextIndex];
			lmIndex = nextIndex + 1;
			
			// ready to handle the next intersection, which is another split, still on the current path.
			
			element = [srcPath elementAtIndex:lmIndex associatedPoints:&points[1]];
			
			if( element == NSCurveToBezierPathElement )
			{
				// split the curve segment
				
				NSPoint	leftPoints[4], rightPoints[4];
				
				splitBezierCurveTo( points, interSect.parameter, leftPoints, rightPoints );
				[newPath curveToPoint:leftPoints[3] controlPoint1:leftPoints[1] controlPoint2:leftPoints[2]];
				previousPoint = leftPoints[3];
			}
			else
			{
				// line segment which ends at the intersection point
				
				previousPoint = ptList.intersections[sectIndex].location;
				[newPath lineToPoint:previousPoint];
			}
			
			// now we swap to the alternate path and set up for the next loop
			
			phase = !phase;
			
			if( phase )
			{
				srcPath = rightPath;						// src is right path
				interSect = ptList.intersections[sectIndex].right;
			}
			else
			{
				srcPath = leftPath;							// src is the left path
				interSect = ptList.intersections[sectIndex].left;
			}
		}
	}

	free (ptList.intersections );
	return newPath;
}



- (NSArray*)		dividePathWithPath:(NSBezierPath*) path
{
	// divides the receiver and <path> into parts split at the intersecting points between the two paths. The result is an array which in turn consists of two further
	// arrays - the first containing the receiver's parts, the second the other path's. The other operations can be built by recombining the parts in various ways.
	
	NSAssert( path != nil, @"cannot divide by a nil path");
	
	NSMutableArray* allParts;
	NSArray*		leftParts;
	//NSArray*		rightParts;
	
	allParts = [NSMutableArray array];
	
	// normalize
	
	NSBezierPath* left, *right;
	
	left = [self renormalizePath];
	right = [path renormalizePath];
	
	// find the intersections
	
	PathIntersectionList ptList = [left allIntersectionsWithPath:right];
	
	leftParts = [left breakApartWithIntersectionInfo:ptList rightOrLeft:NO];
	//rightParts = [right breakApartWithIntersectionInfo:ptList rightOrLeft:YES];
	
	free(ptList.intersections);
	
	[allParts addObject:leftParts];
	//[allParts addObject:rightParts];
	
	return allParts;
}


@end
