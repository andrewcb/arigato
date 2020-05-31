//
//  Zoom.swift
//  ARigEditor
//
//  Created by acb on 2020-05-31.
//  Copyright © 2020 acb. All rights reserved.
//
//  Functions for UI zoom-related computations

import Foundation

func computeZoomScale(fromLevel level: Int) -> CGFloat {
    return pow(2, CGFloat(level))
}
