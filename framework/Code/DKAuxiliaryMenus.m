//
//  DKAuxiliaryMenus.m
//  GCDrawKit
//
//  Created by graham on 10/03/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import "DKAuxiliaryMenus.h"


NSString*		kDKAuxiliaryMenusNibFile	= @"DK_Auxiliary_Menus";


@interface DKAuxiliaryMenus (Private)

- (id)					initWithNibName:(NSString*) nib;

@end


@implementation DKAuxiliaryMenus

static DKAuxiliaryMenus* sAuxMenus = nil;

+ (DKAuxiliaryMenus*)	auxiliaryMenus
{
	if( sAuxMenus == nil )
	{
		// loads the nib
		
		sAuxMenus = [[DKAuxiliaryMenus alloc] initWithNibName:kDKAuxiliaryMenusNibFile];
	}
	
	return sAuxMenus;
}



- (NSMenu*)				copyMenuForClass:(Class) aClass
{
	NSString* outletName = [NSString stringWithFormat:@"_%@Menu", NSStringFromClass( aClass )];
	NSMenu* menu = [self valueForKey:outletName];
	
	return [menu copy];
}


- (id)					initWithNibName:(NSString*) nib
{
	NSAssert( nib != nil, @"nib name was nil when initing auxiliary menus");
	
	self = [super init];
	if( self )
	{
		// load the nib file. This first looks in the main bundle's normal 'Resources' directory. If found it uses that, otherwise it
		// looks for the same named nib in the framework's resources. This allows the host app to redefine the menus which is the point of this.
		
		NSNib* tempNib = nil;
		
		tempNib = [[NSNib alloc] initWithNibNamed:nib bundle:[NSBundle mainBundle]];
		
		if( tempNib == nil )
		{
			NSBundle*	dkBundle = [NSBundle bundleForClass:[self class]];		
			tempNib = [[NSNib alloc] initWithNibNamed:nib bundle:dkBundle];
		}
		
		if( tempNib == nil )
		{
			[self autorelease];
			return nil;
		}
		
		mNib = tempNib;
		
		if( ![mNib instantiateNibWithOwner:self topLevelObjects:nil])
		{
			NSLog(@"failed to instantiate nib '%@' (name = '%@')", mNib, nib );
			[self autorelease];
			return nil;
		}
	}
	
	return self;
}


- (void)				dealloc
{
	[mNib release];
	[super dealloc];
}


@end
