/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

/** @brief Most drawables in DK have contextual menus associated with them.

 Most drawables in DK have contextual menus associated with them. This objects allows those menus to be simply defined in a nib
 file in the framework, and overridden by a similar file in the host app. This object supplies one menu per object class.
 
 The default nib is set up so that the menus target first responder, such that DK's message forwarding handles menu validation as
 normal. When overriding the nib in an app, you need to copy the entire nib and extend or modify any menus as you wish.
*/
@interface DKAuxiliaryMenus : NSObject {
	IBOutlet NSMenu* _DKDrawableObjectMenu;
	IBOutlet NSMenu* _DKDrawableShapeMenu;
	IBOutlet NSMenu* _DKDrawablePathMenu;
	IBOutlet NSMenu* _DKShapeGroupMenu;
	IBOutlet NSMenu* _DKImageShapeMenu;
	IBOutlet NSMenu* _DKArcPathMenu;
	IBOutlet NSMenu* _DKRegularPolygonPathMenu;
	IBOutlet NSMenu* _DKTextShapeMenu;
	IBOutlet NSMenu* _DKTextPathMenu;

	NSNib* mNib;
}

@property (class, readonly, retain) DKAuxiliaryMenus*auxiliaryMenus;

- (NSMenu*)copyMenuForClass:(Class)aClass;

@end

extern NSNibName kDKAuxiliaryMenusNibFile;
