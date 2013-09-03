//
//  NSAffineTransform+DKAdditions.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 27/05/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import <Cocoa/Cocoa.h>


@interface NSAffineTransform (DKAdditions)


- (NSAffineTransform*)		mapFrom:(NSRect) src to:(NSRect) dst;
- (NSAffineTransform*)		mapFrom:(NSRect) src to:(NSRect) dst dstAngle:(CGFloat) radians;

- (NSAffineTransform*)		scaleBounds:(NSRect) bounds toHeight:(CGFloat) height centeredDistance:(CGFloat) distance abovePoint:(NSPoint) location;
- (NSAffineTransform*)		scaleBounds:(NSRect) bounds toHeight: (CGFloat) height centeredAboveOrigin:(CGFloat) distance;
- (NSAffineTransform*)		flipVertical:(NSRect) bounds;

@end


// stolen from Apple sample code "speedy categories"




