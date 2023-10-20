//
//  CircularProgressView.swift
//  ObjectCaptureProject
//
//  Created by Reconlabs on 2023/10/19.
//

import Foundation
import SwiftUI

struct CircularProgressView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack {
            Spacer()
            ZStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .light ? .black : .white))
                Spacer()
            }
            Spacer()
        }
    }
}
