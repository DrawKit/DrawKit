///**********************************************************************************************************************************
///  DKRasterizer.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 23/11/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKRasterizerProtocol.h"
#import "GCObservableObject.h"


@class DKRastGroup;


// clipping values:


typedef enum
{
	kDKClippingNone			= 0,
	kDKClipOutsidePath		= 1,
	kDKClipInsidePath		= 2
}
DKClippingOption;



@interface DKRasterizer : GCObservableObject <DKRasterizer, NSCoding, NSCopying>
{
@private
	DKRastGroup*		mContainerRef;		// group that contains this
	NSString*			m_name;				// optional name
	BOOL				m_enabled;			// YES if actually drawn
	DKClippingOption	mClipping;			// set path clipping to this
}

+ (DKRasterizer*)	rasterizerFromPasteboard:(NSPasteboard*) pb;

- (DKRastGroup*)	container;
- (void)			setContainer:(DKRastGroup*) container;

- (void)			setName:(NSString*) name;
- (NSString*)		name;
- (NSString*)		label;

- (BOOL)			isValid;
- (NSString*)		styleScript;

- (void)			setEnabled:(BOOL) enable;
- (BOOL)			enabled;

- (void)			setClipping:(DKClippingOption) clipping;
- (void)			setClippingWithoutNotifying:(DKClippingOption) clipping;
- (DKClippingOption) clipping;

- (NSBezierPath*)	renderingPathForObject:(id<DKRenderable>) object;

- (BOOL)			copyToPasteboard:(NSPasteboard*) pb;

@end


extern NSString*	kDKRasterizerPasteboardType;

extern NSString*	kDKRasterizerPropertyWillChange;
extern NSString*	kDKRasterizerPropertyDidChange;
extern NSString*	kDKRasterizerChangedPropertyKey;


/*
 DKRasterizer is an abstract base class that implements the DKRasterizer protocol. Concrete subclasses
 include DKStroke, DKFill, DKHatching, DKFillPattern, DKGradient, etc.
 
 A renderer is given an object and renders it according to its behaviour to the current context. It can
 do whatever it wants. Normally it will act upon the object's path so as a convenience the renderPath method
 is called by default. Subclasses can override at the object or the path level, as they wish.
 
 Renderers are obliged to accurately return the extra space they need to perform their rendering, over and
 above the bounds of the path. For example a standard stroke is aligned on the path, so the extra space should
 be half of the stroke width in both width and height. This additional space is used to compute the correct bounds
 of a shape when a set of rendering operations is applied to it.

*/


@interface NSObject (DKRendererDelegate)

- (NSBezierPath*)	renderer:(DKRasterizer*) aRenderer willRenderPath:(NSBezierPath*) aPath;

@end


/*
 Renderers can now have a delegate attached which is able to modify behaviours such as changing the path rendered, etc.

*/
