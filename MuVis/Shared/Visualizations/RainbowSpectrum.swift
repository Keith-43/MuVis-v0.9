/// RainbowSpectrum.swift
/// MuVis
///
/// The RainbowSpectrum is the first of the MuVis visualizations that depict the time-history of the muSpectra. That is, instead of rendering just the current
/// muSpectrum, they also render the most-recent 32 muSpectra - so they show how the envelope of each note varies with time. With a frame-rate of 0.1 seconds
/// per frame, these 32 muSpectra cover the last 3.2 seconds of the music we are hearing. (For iPhones and iPads, this history count is reduced from 32 to 16
/// so as to not overload their graphics capabilities.)
///
/// The RainbowSpectrum visualization uses a similar geometry to the TriOctSpectrum visualization wherein the lower three octaves of muSpectrum audio information
/// are rendered in the lower half-screen and the upper three octaves are rendered in the upper half-screen. The current muSpectrum is shown in the bottom and
/// top rows. And the muSpectrum history is shown as drifting (and shrinking) to the vertical mid-screen.
///
/// For variety, the colors of the upper half-screen and lower half-screen change over time.
///
/// Created by Keith Bromley on 16 Dec 2020.


import SwiftUI


struct RainbowSpectrum: View {

    @EnvironmentObject var audioManager: AudioManager  // We observe the instance of AudioManager passed to us from ContentView.
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        
        GeometryReader { geometry in
        
            let width: CGFloat  = geometry.size.width
            let height: CGFloat = geometry.size.height
            let halfHeight: CGFloat     = height * 0.5
            let quarterHeight: CGFloat  = height * 0.25
            
            var x : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y : CGFloat = 0.0       // The drawing origin is in the upper left corner.

            let devGain:  CGFloat 	= 0.2
            let gain  = devGain * settings.userGain
            var amp: CGFloat = 0.0  // amp = amplitude + (slope * bin)
            let colorSize: Int = 20_000    // This determines the frequency of the color change over time.
            var hue: Double = 0.0
            
            let octavesPerRow: Int = 3
            let pointsPerRow: Int = pointsPerNote * notesPerOctave * octavesPerRow  // pointsPerRow = 8 * 12 * 3 = 288
            
            var lineRampUp: CGFloat = 0.0
            var lineRampDown: CGFloat = 0.0
            
            var histOffset : Int = 0
            let tempIndexR0 = muSpecHistoryIndex * sixOctPointCount  // <- index to first element of the most-recent (hist=0) spectrum written
            var tempIndexR1 : Int = 0
            var tempIndexR2 : Int = 0
            var tempIndexR3 : Int = 0
            var tempIndexR4 : Int = 0
            
            
//---------------------------------------------------------------------------------------------------------------------

            // Rendering this line allows us to use Path{} to write the sampleHistory, and to set the background color.
            Path { path in
                // Store the first 72*8=576 points of the current muSpectrum[] array (containing 89*8=712 points)
                // in the muSpecHistory[] circular buffer at pointer = muSpecHistoryIndex * sixOctPointCount.
                // At this time instant, muSpecHistoryIndex * sixOctPointCount_sparse points to the most-recent point written
                // into the muSpecHistory buffer.
                muSpecHistoryIndex += 1  // This is the "index" for the sample that is about to be written into our circBuffer
                if (muSpecHistoryIndex >= muSpecHistoryCount) { muSpecHistoryIndex = 0 }
                // muSpecHistoryIndex will always be less than muSpecHistoryCount

                let tempIndexB0 = muSpecHistoryIndex * sixOctPointCount
                for point in 0 ..< sixOctPointCount {
                    muSpecHistory[tempIndexB0 + point] = audioManager.muSpectrum[point]
                }

                path.move( to: CGPoint(x: 0.0, y: height) )
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

            
//---------------------------------------------------------------------------------------------------------------------
            ForEach( 0 ..< muSpecHistoryCount, id: \.self) { hist in        //  0 <= hist < 32
            
                //  It is easier to visualize the graphics using lineNum & lineCount instead of hist & muSpecHistoryCount
                let lineNum = hist
                let lineCount = muSpecHistoryCount
                
                // Render the lower and upper triOct spectra:
                ForEach( 0 ..< 2, id: \.self) { triOct in		// triOct = 0, 1
                
                    Path { path in

                        histOffset = hist * sixOctPointCount
                        tempIndexR1 = tempIndexR0 - histOffset
                        tempIndexR2 = (tempIndexR1 >= 0) ? tempIndexR1 : tempIndexR1 + (muSpecHistoryCount*sixOctPointCount)
                        // We needed to account for wrap-around at the muSpecHistory[] ends

                        // As lineNum goes from 0 to lineCount, lineRampUp goes from 0.0 to 1.0:
                        lineRampUp = CGFloat(lineNum) / CGFloat(lineCount)

                        // As lineNum goes from 0 to lineCount, lineRampDown goes from 1.0 to 0.0:
                        lineRampDown =  CGFloat(lineCount - lineNum ) / CGFloat(lineCount)

                        // Each spectrum is rendered along a horizontal line extending from startX to endX.
                        let startX: CGFloat = 0.0   + lineRampUp * (0.33 * width)
                        let endX: CGFloat   = width - lineRampUp * (0.33 * width)
                        let spectrumWidth: CGFloat = endX - startX
                        let pointWidth: CGFloat = spectrumWidth / CGFloat(pointsPerRow)  // pointsPerRow= 3*12*8 = 288
                        
                        let ValY: CGFloat = lineRampUp * halfHeight
                
                        path.move( to: CGPoint( x: startX, y: (triOct == 0) ? height - ValY : ValY ) )

                        // We will render a total of sixOctPointCount points where sixOctPointCount = 72 * 8 = 576
                        // The lower triOct spectrum and the upper triOct spectrum each contain 288 points.
                
                        for point in 0 ..< pointsPerRow{     // 0 <= point < 288
                        
                            x = startX + ( CGFloat(point) * pointWidth )
                            x = min(max(startX, x), endX);
                            
                            tempIndexR3 = (triOct == 0) ? (tempIndexR2 + point) : (pointsPerRow + tempIndexR2 + point)
                            
                            tempIndexR4 = tempIndexR3 % (muSpecHistoryCount * sixOctPointCount)  // We needed to account for wrap-around at the muSpecHistory[] ends
                            
                            amp = (triOct == 0) ? (gain + settings.userSlope*CGFloat(point)) : (gain + settings.userSlope*CGFloat(pointsPerRow+point))
                            
                            let mag: CGFloat = CGFloat(muSpecHistory[tempIndexR4]) * amp * lineRampDown * quarterHeight
                            let magY = ValY + mag

                            y = (triOct == 0) ? height - magY : magY
                            path.addLine(to: CGPoint(x: x, y: y))
                            
                        }
                        path.addLine( to: CGPoint( x: endX, y: (triOct == 0) ? height - ValY : ValY ) )
                        
                        settings.colorIndex = (settings.colorIndex >= colorSize) ? 0 : settings.colorIndex + 1
                        hue = Double(settings.colorIndex) / Double(colorSize)      // 0.0 <= hue < 1.0
                        hue = (triOct == 0) ? hue : 1.0 - hue
                        
                    }
                    // Vary the line thickness to enhance the three-dimensional effect:
                    // As line goes from 0 to 31, LineWidth goes from 3.3 to 0.3
                    .stroke(lineWidth: 0.3 + (lineRampDown*3.0))
                    .foregroundColor(Color(hue: hue, saturation: 1.0, brightness: 1.0))

                }  // end of ForEach() loop over triOct
            }  // end of ForEach() loop over lineNum

            
        }  // end of GeometryReader
    }  //end of var body: some View
}  // end of RainbowSpectrumVis struct



/*
struct RainbowSpectrumVis_Previews: PreviewProvider {
    static var previews: some View {
        RainbowSpectrumVis()
    }
}
*/
