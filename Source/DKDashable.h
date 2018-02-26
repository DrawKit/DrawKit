//
//  DKDashable.h
//  DrawKit
//
//  Created by C.W. Betts on 1/4/18.
//  Copyright © 2018 DrawKit. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DKStrokeDash.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DKDashable <NSObject>
@property (nonatomic, strong, nullable) DKStrokeDash* dash;

@property (nonatomic) CGFloat width;
@property (nonatomic) NSLineCapStyle lineCapStyle;
@property (nonatomic) NSLineJoinStyle lineJoinStyle;

@property (strong) NSColor* colour;
@end

NS_ASSUME_NONNULL_END
