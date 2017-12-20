//
//  DKDrawableObjectAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 12/18/17.
//  Copyright © 2017 DrawKit. All rights reserved.
//

import DKDrawKit.DKDrawableObject
import DKDrawKit.DKDrawableObject.Metadata

extension DKDrawableObject {
	public var metadata: [String: DKMetadataItem] {
		get {
			return __metadata() as NSDictionary as! [String: DKMetadataItem]
		}
		set {
			setMetadata(newValue)
		}
	}
}
