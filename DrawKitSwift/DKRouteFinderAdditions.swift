//
//  DKRouteFinderAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 1/16/18.
//  Copyright © 2018 DrawKit. All rights reserved.
//

import DKDrawKit.DKRouteFinder


extension DKRouteFinder {
	
	public convenience init?(arrayOfPoints: [NSPoint]) {
		let arrayOFObjects = arrayOfPoints.map({NSValue(point: $0)})
		self.init(__arrayOfPoints: arrayOFObjects)
	}
	
	/// Returns the original points reordered into the shortest route.
	public func shortestRoute() -> [NSPoint] {
		return __shortestRoute().map({$0.pointValue})
	}
	
	/// Returns a list of integers which specifies the shortest route between the original points.
	public func shortestRouteOrder() -> [Int] {
		return __shortestRouteOrder().map({$0.intValue})
	}
}
