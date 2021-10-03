/// Cymbal.swift
/// MuVis
///
/// The Cymbal visualization is a different way of depicting the current muSpectrum. It was inspired by contemplating the vibrational patterns of a cymbal.
/// It is purely an aesthetic depiction (with no attempt at real-world modeling).
///
/// On a Mac, we render 6 octaves of the muSpectrum at 12 notes/octave and 2 points/note. Thus, each muSpectrum contains 6 * 12 * 2 = 144 points.
/// This Cymbal visualization renders 144 concentric circles (all with their origin at the pane center) with their radius proportional to these 144 musical-frequency points.
/// 72 of these are note centers, and 72 are the interspersed inter-note midpoints. We dynamically change the line width of these circles to denote the muSpectrum
/// amplitude.
///
/// On an iPhone or iPad, we decrease the circleCount from 144 to 36 to reduce the graphics load (to avoid freezes and crashes when the app runs on more-limited
/// devices).
///
/// For aesthetic effect, we overlay a green plot of the current muSpectrum (replicated from mid-screen to the right edge and from mid-screen to the left edge)
/// on top of the circles.
///
/// A toggle is provided to the developer to render either ovals (wherein all of the shapes are within the visualization pane) or circles (wherein the top and bottom
/// are clipped as outside of the visualization pane)
///
/// My iPad4 could not keep up with the graphics load of rendering 144 circles, so I reduced the circleCount to 36 for iOS devices.
///
/// Created by Keith Bromley in June 2021. (adapted from his previous java version in the Polaris app)


import SwiftUI


struct Cymbal: View {

    @EnvironmentObject var audioManager: AudioManager  // We observe the instance of AudioManager passed to us from ContentView.
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        GeometryReader { geometry in
        
            let shapeOval: Bool = false  // used to select rendering circles or ovals/ellipses
        
            // The important ellipse parameters are:
            var circleCount: Int = 144  // macOS devices generally have sufficient graphics resources to render 144 circles.
            let width:  CGFloat = geometry.size.width
            let height: CGFloat = geometry.size.height
            let halfWidth:  CGFloat =  0.5 * width
            let halfHeight: CGFloat =  0.5 * height
            let X0: CGFloat = 0.5 * width   // the origin of the ellipses
            let Y0: CGFloat = 0.5 * height  // the origin of the ellipses
            let A0: CGFloat = 0.5 * width   // the horizontal radius of the largest ellipse
            let B0: CGFloat = shapeOval ? halfHeight : halfWidth  // the vertical radius of the largest ellipse
            
            var x : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var theta:  Double = 0.0    // The angle theta starts at the 12 o'clock position and proceeds clockwise.
            
            let devGain:  CGFloat = 0.5      // devGain  is the optimum gain  value suggested by the developer
            let gain  = devGain  * settings.userGain    // userGain  multiplies devGain  by a slider value from 0.0 to 2.0
            var amp: CGFloat = 0.0          // amplitude = gain + (slope * point)
            var mag: CGFloat = 0.0          // used as a preliminary part of the audio amplitude value
            var thisLineWidth: CGFloat = 0.0
            

// ---------------------------------------------------------------------------------------------------------------------
            // Rendering this invisible line allows us to use Path{} to set the circleCount and the background color.
            Path { path in
            
                #if os(iOS)
                    circleCount = 36  // Throttle back graphics load for iOS devices
                #endif
            
                path.move( to: CGPoint(x: 0.0, y: height) )     // This line just allows us to use the Path{} to write the muSpecHistory
                path.addLine(to: CGPoint(x: width, y: height) )
                
                /*
                // Performance monitor:
                let timePassed: Double = -settings.date.timeIntervalSinceNow  // Find elapsed time since last timer reset.
                
                // Insert most-recent timeInterval into the array (over-writing the oldest timeInterval):
                settings.pointer = (settings.pointer  < 9) ? settings.pointer + 1 : 0
                settings.timePassedForLastTenFrames[settings.pointer] = timePassed
                
                var sum: Double = 0.0
                for i in 0 ..< 10 {
                    sum += settings.timePassedForLastTenFrames[i]
                }

                let period: Double = 0.1 * 1000.0 * sum     // period (in milliseconds)
                print("msPerFrame: \( lround( period) )")   // lround() rounds to nearest int and returns that Int.
                settings.date = NSDate()                    // Reset the timer to the current time.
                */
                
            }
            .stroke(lineWidth: 0.0)
            .background((settings.selectedColorScheme == .light) ? Color.white : Color.black)    // Toggle between black and white background color.



// ---------------------------------------------------------------------------------------------------------------------
            // Render the 144 concentric circle/ovals:
            ForEach( 0 ..< circleCount, id: \.self) { circleNum in
                
                Path { path in

                    let circleNum1 = circleCount-1-circleNum // corrects the erroneous backward counting of the ForEach(cicleNum)
                     
                    // As circleNum1 goes from 0 to circleCount, rampUp goes from 0.0 to 1.0:
                    let rampUp: CGFloat = CGFloat(circleNum1) / CGFloat(circleCount)

                    x = X0 + rampUp * A0 * CGFloat( sin(2.0 * Double.pi * theta ) )
                    y = Y0 - rampUp * B0 * CGFloat( cos(2.0 * Double.pi * theta ) )
                    path.move( to: CGPoint(x: x, y: y) )

                    for point in 0 ..< sixOctPointCount {
                        theta = Double(point) / Double(sixOctPointCount)  // 0 <= theta < 1
                        x = X0 + rampUp * A0 * CGFloat( sin(2.0 * Double.pi * theta) )
                        y = Y0 - rampUp * B0 * CGFloat( cos(2.0 * Double.pi * theta) )
                        path.addLine(to: CGPoint(x: x,  y: y ) )
                    }
                    
                    #if os(macOS)
                        let circleNum2 = 4 * circleNum1  // 4 * 144 = 576
                    #endif
                    
                    #if os(iOS)
                        let circleNum2 = 16 * circleNum1  // 16 * 36 = 576
                    #endif
                    
                    amp = gain + settings.userSlope * CGFloat(circleNum2)
                    thisLineWidth = amp * CGFloat( audioManager.muSpectrum[circleNum2] )
                }
                .stroke(lineWidth: thisLineWidth)
                .foregroundColor(Color(hue: 1.0, saturation: 1.0, brightness: 1.0))
                
            } // end of ForEach(circleNum)

// ---------------------------------------------------------------------------------------------------------------------
            // Now render a four-fold muSpectrum[] across the middle of the pane:
            
            ForEach( 0 ..< 2, id: \.self) { row in      // We have a lower and an upper row.
                ForEach( 0 ..< 2, id: \.self) { column in      // We have a left and a right column.

                    Path { path in
                        let spectrumHeight = (row == 0) ? -0.1 * height : 0.1 * height  // makes spectrum negative for lower row
                        let spectrumWidth = (column == 0) ? -halfWidth : halfWidth  // makes spectrum go to left for left column
                        
                        path.move( to: CGPoint( x: X0, y: Y0 ) )
                        
                        for point in 0 ..< sixOctPointCount {
                            let upRamp =  CGFloat(point) / CGFloat(sixOctPointCount)
                            x = X0 + upRamp * spectrumWidth
                            amp = gain + settings.userSlope * CGFloat(point)
                            mag = CGFloat(audioManager.muSpectrum[point]) * spectrumHeight * amp
                            y = halfHeight + mag
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(lineWidth: 1.0)
                    .foregroundColor(.init(red: 0.0, green: 1.0, blue: 0.0))  // foreground color = green
                }  // end of ForEach(column)
            }  // end of ForEach(row)
            
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of Cymbal struct



/*
struct Cymbal_Previews: PreviewProvider {
    static var previews: some View {
        Cymbal()
    }
}
*/
