///  Settings.swift
///  MuVis
///
///  Created by Keith Bromley on 16 Feb 2021.

import Foundation
import SwiftUI


class Settings: ObservableObject {

    static let settings = Settings()  // This singleton instantiates the Settings class


    // User Settings:
    // The following are variables that the app's user gets to adjust - using the buttons and sliders provided in
    // the user interface within the ContentView struct.
                            
    @Published var userGain:  CGFloat = 1.0 // the user's adjustment to the developer's choice for "gain"
                                            // Changed in ContentView; Published to all visualizations

    @Published var userSlope: CGFloat = 0.0 // the user's choice for "slope"  ( 0.0 <= userSlope <= 0.01 )
                                            // Changed in ContentView; Published to all visualizations
                                            
    @Published var selectedColorScheme: ColorScheme = .light
                                            // Changed in ContentView; Published to all visualizations
                                            



    // Developer Settings:
    // The following are constants and variables that the app's developer has selected for optimum performance.
    // Sometimes variables need to be here for persistence between instantiantions of a visualization.

    var colorIndex: Int = 0     // used in Harmonograph
    var frameCounter: Int = 0   // used in SpinningEllipse
    var frameIncrement: Int = 1 // used in SpinningEllipse

    var oldHorAngle: Double = 0.0  // old angle of horizontal waveform      used in Harmomograph
    var oldVerAngle: Double = 0.0  // old angle of vertical waveform        used in Harmonograph

    var offsetX: CGFloat = 0.0		// used in Wormhole to dynamically move the ellipse-center start
    var offsetY: CGFloat = 0.0		// used in Wormhole to dynamically move the ellipse-center start
    var incrementX: CGFloat = 0.001 // used in Wormhole to dynamically move the ellipse-center start
    var incrementY: CGFloat = 0.0001// used in Wormhole to dynamically move the ellipse-center start

    var previousAudioURL: URL = URL(string: "https://www.google.com")!
    
    // Performance Monitoring:
    var date = NSDate()
    var timePassed: Double = 0.0
    var timePassedForLastTenFrames: [Double] = [Double](repeating: 0.0, count: 10) // timePassed for each of the previous 10 frames
    var pointer: Int = 0     // pointer into the above array   0 <= pointer < 10

}
