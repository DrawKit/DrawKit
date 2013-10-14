/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */
//
//  DKPathPointHandle.h
//  GCDrawKit
//
//  Created by Graham Cox on 4/09/09.
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
