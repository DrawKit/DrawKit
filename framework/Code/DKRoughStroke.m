//
//  DKRoughStroke.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 14/04/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKRoughStroke.h"
#import "NSBezierPath+Geometry.h"
//#import "NSBezierPath+GPC.h"

@implementation DKRoughStroke
#pragma mark As a DKRoughStroke

- (void)					setRoughness:(CGFloat) roughness
{
	if( roughness != mRoughness )
	{
		mRoughness = roughness;
		[self invalidateCache];
	}
}


- (CGFloat)					roughness
{
	return mRoughness;
}

- (NSString*)				pathKeyForPath:(NSBezierPath*) path
{
	// form a simple hash from the path's size, length and current stroke width. Note that the precision is deliberately set to just 1 decimal
	// place so that minor rounding errors when doing path transforms don't generate different keys. Do not rely on this format, or attempt
	// to interpret it.
	
	return [NSString stringWithFormat:@"%.1f.%.1f.%.1f.%.1f", [path bounds].size.width, [path bounds].size.height, [path length], [self width]];
}


- (void)					invalidateCache
{
	[mPathCache removeAllObjects];
	[mCacheList removeAllObjects];
}


- (NSBezierPath*)			roughPathFromPath:(NSBezierPath*) path
{
	// is this path in the cache?
	
	NSString*			key = [self pathKeyForPath:path];
	NSBezierPath*		cp = [mPathCache objectForKey:key];
	NSAffineTransform*	tfm = [NSAffineTransform transform];
	NSRect				pb = [path bounds];
	
	if( cp == nil )
	{
		// not in the cache, so create it from scratch
		
		cp = [path bezierPathWithRoughenedStrokeOutline:[self roughness] * [self width]];
		
		if( cp != nil )
		{
			// set its origin to 0,0 based on the original path
			
			[tfm translateXBy:-pb.origin.x yBy:-pb.origin.y];
			NSBezierPath* temp = [tfm transformBezierPath:cp];
			
			// cache it for future re-use
			
			[mPathCache setObject:temp forKey:key];
			[mCacheList insertObject:temp atIndex:0];
			
			//NSLog(@"DKRoughStroke cached new path, key = %@", key );
			
			// if cache list capacity exceeded, discard oldest (least frequently re-used)
			
			if([mCacheList count] > kDKRoughPathCacheMaximumCapacity )
			{
				id oldest = [mCacheList lastObject];
				
				NSArray* keys = [mPathCache allKeysForObject:oldest];
				[mPathCache removeObjectsForKeys:keys];
				[mCacheList removeObject:oldest];
				
				//NSLog(@"DKRoughStroke discarded cached path");
			}
		}
	}
	else
	{
		// was cached, so move it to the head of the cache list so it is marked as recently used
		
		[mCacheList removeObject:cp];
		[mCacheList insertObject:cp atIndex:0];
		
		// align it to the path being rendered
		
		[tfm translateXBy:pb.origin.x yBy:pb.origin.y];
		cp = [tfm transformBezierPath:cp];
	}
	
	return cp;
}



#pragma mark -
#pragma mark As a DKStroke

- (id)						initWithWidth:(CGFloat) width colour:(NSColor*) colour
{
	self = [super initWithWidth:width colour:colour];
	if( self != nil )
	{
		mPathCache = [[NSMutableDictionary alloc] init];
		mCacheList = [[NSMutableArray alloc] init];
		[self setRoughness:0.25];
	}
	
	return self;
}

- (void)					renderPath:(NSBezierPath*) path
{
	[[self colour] setFill];
	[self applyAttributesToPath:path];
	
	NSBezierPath* pc = [self roughPathFromPath:path];
		
	[pc fill];
}


- (NSSize)					extraSpaceNeeded
{
	NSSize	es = [super extraSpaceNeeded];
	
	CGFloat widthVariation = [self width] * [self roughness];
	
	es.width += widthVariation;
	es.height += widthVariation;
	
	return es;
}


- (void)					setDash:(DKStrokeDash*) dash
{
	[super setDash:dash];
	[self invalidateCache];
}

#pragma mark -
#pragma mark As a NSObject

- (void)					dealloc
{
	[mPathCache release];
	[mCacheList release];
	[super dealloc];
}


#pragma mark -
#pragma mark As a GCObservableObject

+ (NSArray*)				observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:[NSArray arrayWithObject:@"roughness"]];
}


- (void)					registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Stroke Roughness" forKeyPath:@"roughness"];
}



#pragma mark -
#pragma mark As part of the NSCoding protocol

- (id)						initWithCoder:(NSCoder*) coder
{
	[super initWithCoder:coder];
	mPathCache = [[NSMutableDictionary alloc] init];
	mCacheList = [[NSMutableArray alloc] init];
	[self setRoughness:[coder decodeDoubleForKey:@"DKRoughStroke_roughness"]];
	
	return self;
}


- (void)					encodeWithCoder:(NSCoder*) coder
{
	[super encodeWithCoder:coder];
	[coder encodeDouble:[self roughness] forKey:@"DKRoughStroke_roughness"];
}

#pragma mark -
#pragma mark As part of the NSCopying protocol

- (id)						copyWithZone:(NSZone*) zone
{
	DKRoughStroke* rs = [super copyWithZone:zone];
	[rs setRoughness:[self roughness]];
	
	return rs;
}

@end
