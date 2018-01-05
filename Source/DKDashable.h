//
//  DKDashable.h
//  DrawKit
//
//  Created by C.W. Betts on 1/4/18.
//  Copyright © 2018 DrawKit. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DKStrokeDash.h"


@protocol DKDashable <NSObject>
@property (nonatomic, strong) DKStrokeDash *dash;

@property (nonatomic) CGFloat width;
@property (nonatomic) NSLineCapStyle lineCapStyle;
@property (nonatomic) NSLineJoinStyle lineJoinStyle;

@property (strong) NSColor *colour;
@end
