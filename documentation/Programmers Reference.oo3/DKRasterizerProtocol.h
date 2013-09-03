///**********************************************************************************************************************************
///  DKRasterizerProtocol.h
///  DrawKit
///
///  Created by graham on 23/11/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import <Cocoa/Cocoa.h>

// renderers must implement the following formal protocol:

@protocol DKRasterizer

- (NSSize)			extraSpaceNeeded;
- (void)			render:(id) object;
- (void)			renderPath:(NSBezierPath*) path;

@end

// renderable objects need to implement the following informal protocol:

@interface NSObject (Rendering)

- (NSBezierPath*)	renderingPath;
- (float)			angle;
- (BOOL)			useLowQualityDrawing;

@end
