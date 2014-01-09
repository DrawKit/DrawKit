/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

/** @brief Most drawables in DK have contextual menus associated with them.

Most drawables in DK have contextual menus associated with them. This objects allows those menus to be simply defined in a nib
 file in the framework, and overridden by a similar file in the host app. This object supplies one menu per object class.
 
 The default nib is set up so that the menus target first responder, such that DK's message forwarding handles menu validation as
 normal. When overriding the nib in an app, you need to copy the entire nib and extend or modify any menus as you wish.
*/
@interface DKAuxiliaryMenus : NSObject
{
	IBOutlet NSMenu*	_DKDrawableObjectMenu;
	IBOutlet NSMenu*	_DKDrawableShapeMenu;
	IBOutlet NSMenu*	_DKDrawablePathMenu;
	IBOutlet NSMenu*	_DKShapeGroupMenu;
	IBOutlet NSMenu*	_DKImageShapeMenu;
	IBOutlet NSMenu*	_DKArcPathMenu;
	IBOutlet NSMenu*	_DKRegularPolygonPathMenu;
	IBOutlet NSMenu*	_DKTextShapeMenu;
	IBOutlet NSMenu*	_DKTextPathMenu;
	
	NSNib*				mNib;
}

+ (DKAuxiliaryMenus*)	auxiliaryMenus;

- (NSMenu*)				copyMenuForClass:(Class) aClass;

@end

extern NSString*		kDKAuxiliaryMenusNibFile;

