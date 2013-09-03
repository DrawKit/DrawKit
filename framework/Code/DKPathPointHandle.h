//
//  DKPathPointHandle.h
//  GCDrawKit
//
//  Created by graham on 4/09/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DKHandle.h"

@interface DKOnPathPointHandle : DKHandle
@end


@interface DKLockedOnPathPointHandle : DKOnPathPointHandle
@end


@interface DKInactiveOnPathPointHandle : DKOnPathPointHandle
@end


@interface DKOffPathPointHandle : DKOnPathPointHandle
@end


@interface DKLockedOffPathPointHandle : DKOffPathPointHandle
@end


@interface DKInactiveOffPathPointHandle : DKOffPathPointHandle
@end
