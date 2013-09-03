///**********************************************************************************************************************************
///  DKHatching.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 06/10/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKRasterizer.h"


@class DKStrokeDash;


@interface DKHatching : DKRasterizer <NSCoding, NSCopying>
{
@private
	NSBezierPath*	m_cache;
	NSBezierPath*	mRoughenedCache;
	NSColor*		m_hatchColour;
	DKStrokeDash*	m_hatchDash;
	NSLineCapStyle	m_cap;
	NSLineJoinStyle	m_join;
	CGFloat			m_leadIn;
	CGFloat			m_spacing;
	CGFloat			m_angle;
	CGFloat			m_lineWidth;
	BOOL			m_angleRelativeToObject;
	BOOL			mRoughenStrokes;
	CGFloat			mRoughness;
	CGFloat			mWobblyness;
}

+ (DKHatching*)		defaultHatching;
+ (DKHatching*)		hatchingWithLineWidth:(CGFloat) w spacing:(CGFloat) spacing angle:(CGFloat) angle;
+ (DKHatching*)		hatchingWithDotPitch:(CGFloat) pitch diameter:(CGFloat) diameter;
+ (DKHatching*)		hatchingWithDotDensity:(CGFloat) density;

- (void)			hatchPath:(NSBezierPath*) path;
- (void)			hatchPath:(NSBezierPath*) path objectAngle:(CGFloat) oa;

- (void)			setAngle:(CGFloat) radians;
- (CGFloat)			angle;
- (void)			setAngleInDegrees:(CGFloat) degs;
- (CGFloat)			angleInDegrees;
- (void)			setAngleIsRelativeToObject:(BOOL) rel;
- (BOOL)			angleIsRelativeToObject;

- (void)			setSpacing:(CGFloat) spacing;
- (CGFloat)			spacing;
- (void)			setLeadIn:(CGFloat) amount;
- (CGFloat)			leadIn;

- (void)			setWidth:(CGFloat) width;
- (CGFloat)			width;
- (void)			setLineCapStyle:(NSLineCapStyle) lcs;
- (NSLineCapStyle)	lineCapStyle;
- (void)			setLineJoinStyle:(NSLineJoinStyle) ljs;
- (NSLineJoinStyle)	lineJoinStyle;

- (void)			setColour:(NSColor*) colour;
- (NSColor*)		colour;

- (void)			setDash:(DKStrokeDash*) dash;
- (DKStrokeDash*)	dash;
- (void)			setAutoDash;

- (void)			setRoughness:(CGFloat) amount;
- (CGFloat)			roughness;
- (void)			setWobblyness:(CGFloat) wobble;
- (CGFloat)			wobblyness;

- (void)			invalidateCache;
- (void)			calcHatchInRect:(NSRect) rect;

@end



/*

This class provides a simple hatching fill for a path. It draws equally-spaced solid lines of a given thickness at a
particular angle. Subclass for more sophisticated hatches.

Can be set as a fill style in a DKStyle object.

The hatch is cached in an NSBezierPath object based on the bounds of the path. If another path is hatched that is smaller
than the cached size, it is not rebuilt. It is rebuilt if the angle or spacing changes or a bigger path is hatched. Linewidth also
doesn't change the cache.

*/
