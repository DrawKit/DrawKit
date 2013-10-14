/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */
//
//  DKDrawableShape+Utilities.h
//  GCDrawKit
//
//  Created by Graham Cox on 13/06/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DKDrawableShape.h"

@interface DKDrawableShape (Utilities)

// utilities for calculating regions within a shape and drawing images allowing
// for scale, rotation, etc.

/** @brief Return a rectangular path with given size and origin
 * @note
 * Not affected by the object's current offset
 * @param relRect a rectangle expressed relative to the unit square
 * @return a rectangular path transformed to the current true size, position and angle of the shape
 * @public
 */
- (NSBezierPath*)			pathWithRelativeRect:(NSRect) relRect;

/** @brief Return a rectangular path with given relative origin but absolute final size
 * @note
 * Not affected by the object's current offset. By specifying a final size the resulting path can
 * represent a fixed-sized region independent of the object's current size.
 * @param relLoc a point expressed relative to the unit square
 * @param size the final desired size o fthe rectangle
 * @return a rectangular path transformed to the current true size, position and angle of the shape
 * @public
 */
- (NSBezierPath*)			pathWithRelativePosition:(NSPoint) relLoc finalSize:(NSSize) size;

/** @brief Return a rectangular path offset from a given partcode
 * @note
 * The resulting path is positioned at a fixed offset and size relative to a partcode (a corner, say)
 * in such a way that the object's size and angle set the positioning and orientation of the path
 * but not its actual size. This is useful for adding an adornment to the shape that is unscaled
 * by the object, such as the text indicator shown by DKTextShape
 * @param size the final desired size of the rectangle
 * @param offset an offset in absolute units from the nominated partcode position
 * @param pc the partcode that the path is positioned relative to
 * @return a rectangular path transformed to the current true size, position and angle of the shape
 * @public
 */
- (NSBezierPath*)			pathWithFinalSize:(NSSize) size offsetBy:(NSPoint) offset fromPartcode:(NSInteger) pc;

/** @brief Transforms a path to the final size and position relative to a partcode
 * @note
 * The resulting path is positioned at a fixed offset and size relative to a partcode (a corner, say)
 * in such a way that the object's size and angle set the positioning and orientation of the path
 * but not its actual size. This is useful for adding an adornment to the shape that is unscaled
 * by the object, such as the text indicator shown by DKTextShape
 * @param path the path to transform
 * @param size the final desired size of the rectangle
 * @param offset an offset in absolute units from the nominated partcode position
 * @param pc the partcode that the path is positioned relative to
 * @return the transformed path
 * @public
 */
- (NSBezierPath*)			path:(NSBezierPath*) inPath withFinalSize:(NSSize) size offsetBy:(NSPoint) offset fromPartcode:(NSInteger) pc;

/** @brief Convert a point from relative coordinates to absolute coordinates
 * @note
 * Not affected by the object's current offset
 * @param relLoc a point expressed relative to the unit square
 * @return the absolute point taking into account scale, position and angle
 * @public
 */
- (NSPoint)					pointForRelativeLocation:(NSPoint) relLoc;

@end
