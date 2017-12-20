//
//  DKMetadataStorableAdditions.swift
//  DrawKitSwift
//
//  Created by C.W. Betts on 12/20/17.
//  Copyright © 2017 DrawKit. All rights reserved.
//

import DKDrawKit.DKMetadataStorable

extension DKMetadataStorable {
	public var metadata: [String: DKMetadataItem] {
		get {
			setupMetadata()
			return __metadata()! as NSDictionary as! [String: DKMetadataItem]
		}
		set {
			__setMetadata(newValue)
		}
	}
}
