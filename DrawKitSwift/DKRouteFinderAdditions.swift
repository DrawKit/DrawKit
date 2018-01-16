//
//  DKRouteFinderAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 1/16/18.
//  Copyright © 2018 DrawKit. All rights reserved.
//

import DKDrawKit.DKRouteFinder


extension DKRouteFinder {
	public func shortestRoute() -> [NSPoint] {
		return __shortestRoute().map({$0.pointValue})
	}
	
	public func shortestRouteOrder() -> [Int] {
		return __shortestRouteOrder().map({$0.intValue})
	}
}
