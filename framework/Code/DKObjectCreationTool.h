///**********************************************************************************************************************************
///  DKObjectCreationTool.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 09/06/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKDrawingTool.h"


@class DKStyle;



@interface DKObjectCreationTool : DKDrawingTool
{
@private
	id			m_prototypeObject;
	BOOL		mEnableStylePickup;
	BOOL		mDidPickup;
	NSPoint		mLastPoint;
	NSInteger	mPartcode;

@protected	
	id			m_protoObject;
}

+ (void)				registerDrawingToolForObject:(id <NSCopying>) shape withName:(NSString*) name;
+ (void)				setStyleForCreatedObjects:(DKStyle*) aStyle;
+ (DKStyle*)			styleForCreatedObjects;

- (id)					initWithPrototypeObject:(id <NSObject>) aPrototype;

- (void)				setPrototype:(id <NSObject>) aPrototype;
- (id)					prototype;
- (id)					objectFromPrototype;

- (void)				setStyle:(DKStyle*) aStyle;
- (DKStyle*)			style;

- (void)				setStylePickupEnabled:(BOOL) pickup;
- (BOOL)				stylePickupEnabled;

- (NSImage*)			image;

@end


#define  kDKDefaultToolSwatchSize		(NSMakeSize( 64, 64 ))

extern NSString*		kDKDrawingToolWillMakeNewObjectNotification;
extern NSString*		kDKDrawingToolCreatedObjectsStyleDidChange;

/*

This tool class is used to make all kinds of drawable objects. It works by copying a prototype object which will be some kind of drawable, adding
it to the target layer as a pending object, then proceeding as for an edit operation. When complete, if the object is valid it is committed to
the layer as a permanent item.

The prototype object can have all of its parameters set up in advance as required, including an attached style.

You can also set up a style to be applied to all new objects initially as an independent parameter.



*/
