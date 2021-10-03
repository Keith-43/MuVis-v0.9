/// SpinningEllipse.swift
/// MuVis
///
/// The SpinningEllipse visualization makes the RainbowEllipse more dynamic by making it spin.
/// Also, an angular offset is applied to each muSpectrum to make the inward drifting of the spectral history more interesting.
///
/// Created by Keith Bromley on 1 March 2021. (adapted from his previous java version (called Nautilus2) in the Polaris app)


import SwiftUI


struct SpinningEllipse: View {

    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView.
    @EnvironmentObject var settings: Settings
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
        
            // The important ellipse parameters are:
            let width:  CGFloat = geometry.size.width
            let height: CGFloat = geometry.size.height
            let X0: CGFloat = 0.5 * width   // the origin of the ellipses
            let Y0: CGFloat = 0.55 * height // the origin of the ellipses (Deliberately set below the halfway line)
            let A0: CGFloat = width  / 2.0  // the horizontal radius of the largest ellipse
            let B0: CGFloat = 0.45 * height // the vertical   radius of the largest ellipse (Constrained by the pane bottom)
            var B:  CGFloat = 0.0           // used as the time-varying reduced B0 value
            
            var x : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var theta:  Double = 0.0    // The angle theta starts at the 12 o'clock position and proceeds clockwise.
            var theta1: Double = 0.0
            
            let devGain:  CGFloat = 0.1     // devGain  is the optimum gain  value suggested by the developer
            let gain  = devGain  * settings.userGain    // userGain  multiplies devGain  by a slider value from 0.0 to 2.0
            var amp:   CGFloat = 0.0        // amplitude = gain + (slope * point)
            var mag:   CGFloat = 0.0        // used as a preliminary part of the audio amplitude value
            
            let octaveCount: Int = 6  // The FFT provides 7 octaves (plus 5 unrendered notes)
            let octaveFraction: Double = 1.0 / Double(octaveCount)      // octaveFraction = 1/6 = 0.1666666
            let pointFraction:  Double = octaveFraction / Double(pointsPerOctave)  // pointFraction = 1/(6*144)
            
            let ellipseCount: Int = muSpecHistoryCount  // number of ellipses rendered to show the history of each spectrum
            
            var octaveOffset: Int = 0
            var histOffset:   Int = 0
            let tempIndexR0 = muSpecHistoryIndex * sixOctPointCount  // index to first element of the most-recent (hist=0) spectrum written
            var tempIndexR1 : Int = 0
            var tempIndexR2 : Int = 0
            var tempIndexR3 : Int = 0

            var angleOffset: Double = 0.0           // angleOffset controls the rotation of the spiral
            let secondsPerCycle: Int = 60           // seconds per revolution of the ellipse
            let framesPerCycle: Int = secondsPerCycle * 25      // frames per revolution of the ellipse = 3000
            
            let angleInc: Double = 0.01
            var rotationIsClockwise: Bool = false               // toggles spiral rotation direction
            var hue: Double = 0.0
            
            
            
// ---------------------------------------------------------------------------------------------------------------------

            // Rendering this line allows us to use Path{} to write the sampleHistory, and to set the background color.
            Path { path in
                // Store the first 72*8=576 points of the current muSpectrum[] array (containing 89*8=712 points)
                // in the muSpecHistory[] circular buffer at pointer = muSpecHistoryIndex * sixOctPointCount.
                // At this time instant, muSpecHistoryIndex * sixOctPointCount_sparse points to the most-recent point written
                // into the muSpecHistory buffer.
                muSpecHistoryIndex += 1  // This is the "index" for the sample that is about to be written into our circBuffer
                if (muSpecHistoryIndex >= muSpecHistoryCount) { muSpecHistoryIndex = 0 } // muSpecHistoryIndex will always be less than muSpecHistoryCount

                let tempIndexB0 = muSpecHistoryIndex * sixOctPointCount
                for point in 0 ..< sixOctPointCount {
                    muSpecHistory[tempIndexB0 + point] = audioManager.muSpectrum[point]
                }

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
            // First render the ellipseCount ellipses - each with its own old spectrum:
            // Render octave 0 of the spectrum between the 12 o'clock and  2 o'clock ellipse positions:
            // Render octave 1 of the spectrum between the  2 o'clock and  4 o'clock ellipse positions:
            // Render octave 2 of the spectrum between the  4 o'clock and  6 o'clock ellipse positions:
            // Render octave 3 of the spectrum between the  6 o'clock and  8 o'clock ellipse positions:
            // Render octave 4 of the spectrum between the  8 o'clock and 10 o'clock ellipse positions:
            // Render octave 5 of the spectrum between the 10 o'clock and 12 o'clock ellipse positions:
            // The radius of each ellipse goes from halfHeight to zero:
                
            ForEach( 0 ..< muSpecHistoryCount, id: \.self) { hist in        //  0 <= hist < 32
                let ellipseNum = hist  //  It is easier to visualize the graphics using ellipseNum & ellipseCount instead of hist & muSpecHistoryCount

                // As ellipseNum goes from 0 to ellipseCount, ellipseRampUp goes from 0.0 to 1.0:
                let ellipseRampUp: CGFloat = CGFloat(ellipseNum) / CGFloat(ellipseCount)

                // As ellipseNum goes from 0 to ellipseCount, ellipseRampDown goes from 1.0 to 0.0:
                let ellipseRampDown: CGFloat = CGFloat(ellipseCount - ellipseNum) / CGFloat(ellipseCount)
                
                ForEach( 0 ..< octaveCount, id: \.self) { oct in        //  0 <= oct < 6
                
                    Path { path in
                        
                        // Only increment the frameCounter when we start a new octave (i.e., a new ellipse):
                        if(oct == 0) {
                        
                            settings.frameCounter = settings.frameCounter + settings.frameIncrement

                            if (settings.frameCounter >= framesPerCycle)
                            {   rotationIsClockwise = !rotationIsClockwise  // cycle duration = 2 * 300 / 60 = 10 seconds
                                settings.frameIncrement = -1
                            }

                            if (settings.frameCounter <= -framesPerCycle)
                            {   rotationIsClockwise = !rotationIsClockwise
                                settings.frameIncrement = 1
                            }
                        
                            angleOffset = angleOffset + angleInc
                            
                            B = B0 * CGFloat(settings.frameCounter) / CGFloat(framesPerCycle)
                        }
                        
                        theta = Double(ellipseRampUp) * angleOffset + ( Double(oct) * octaveFraction )
                        
                        x = X0 + ellipseRampDown * A0 * CGFloat( sin(2.0 * Double.pi * theta ) )
                        y = Y0 - ellipseRampDown * B  * CGFloat( cos(2.0 * Double.pi * theta ) )
                        path.move( to: CGPoint(x: x, y: y) )
                        
                        // Now ensure that we read the correct spectral data from the muSpecHistory[] array:
                        histOffset = hist * sixOctPointCount
                        octaveOffset = oct * pointsPerOctave
                        tempIndexR1 = tempIndexR0 - histOffset + octaveOffset
                        tempIndexR2 = (tempIndexR1 >= 0) ? tempIndexR1 : tempIndexR1 + (muSpecHistoryCount*sixOctPointCount)
                        
                        for point in 0 ..< pointsPerOctave {    // 12 * 8 = 96 = number of points per octave

                            theta1 = theta + ( Double(point) * pointFraction )  // 0 <= theta < 1

                            x = X0 + ellipseRampDown * A0 * CGFloat( sin(2.0 * Double.pi * theta1) )

                            // We needed to account for wrap-around at the muSpecHistory[] ends:
                            tempIndexR3 = (tempIndexR2 + point) % (muSpecHistoryCount * sixOctPointCount)

                            amp = gain + settings.userSlope * CGFloat(octaveOffset + point)
                            mag = amp * CGFloat(muSpecHistory[tempIndexR3])
                            mag = min(max(0.0, mag), 1.0)   // Limit over- and under-saturation.
                            y = Y0 - ellipseRampDown * B * CGFloat( cos(2.0 * Double.pi * theta1 )) - (mag * Y0 * ellipseRampDown)
                            path.addLine(to: CGPoint(x: x,  y: y ) )
                        }
                        
                        hue = Double(oct) * octaveFraction
                        
                    }  // end of Path
                    .stroke(lineWidth: 0.1 + (ellipseRampDown * 3.0))   // lineWidth goes from 3.1 to 0.1
                    .foregroundColor(Color(hue: hue, saturation: 1.0, brightness: 1.0))
                    
                } // end of ForEach(oct)
                
            }  // end of ForEach(ellipseNum)
               
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of SpinningEllipse struct



/*
struct SpinningEllipse_Previews: PreviewProvider {
    static var previews: some View {
        SpinningEllipse()
    }
}
*/
