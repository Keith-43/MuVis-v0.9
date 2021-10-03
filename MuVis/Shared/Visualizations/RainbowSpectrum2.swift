/// RainbowSpectrum2.swift
/// MuVis
///
/// The RainbowSpectrum2 visualization is simple a more dynamic version of the RainbowSpectrum visualization. Also, the colors are different.
///
/// The rows showing the current muSpectrum are no longer static at the top and bottom of the screen - but move dynamically between the midpoint and
/// the top and bottom of the screen.
///
/// Created by Keith Bromley on 16 Dec 2020.


import SwiftUI


struct RainbowSpectrum2: View {

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
            var hueIndex: Double = 0.0
            
            let octavesPerRow: Int = 3
            let pointsPerRow: Int = pointsPerNote * notesPerOctave * octavesPerRow  // pointsPerRow = 12 * 12 * 3 = 432
            
            var lineRampUp: CGFloat = 0.0
            var lineRampDown: CGFloat = 0.0
            
            let now = Date()
            let time = now.timeIntervalSinceReferenceDate
            let frequency: Double = 0.1  // 1 cycle per 10 seconds
            var vertOffset: Double = 0.0  // vertOffset oscillates between -1 and +1.
            
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
                if (muSpecHistoryIndex >= muSpecHistoryCount) { muSpecHistoryIndex = 0 } // muSpecHistoryIndex will always be less than muSpecHistoryCount

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
                        tempIndexR2 = (tempIndexR1 >= 0) ? tempIndexR1 : tempIndexR1 + (muSpecHistoryCount*sixOctPointCount)  // We need to account for wrap-around at the muSpecHistory[] ends

                        // As lineNum goes from 0 to lineCount, lineRampUp goes from 0.0 to 1.0:
                        lineRampUp = CGFloat(lineNum) / CGFloat(lineCount)

                        // As lineNum goes from 0 to lineCount, lineRampDown goes from 1.0 to 0.0:
                        lineRampDown =  CGFloat(lineCount - lineNum ) / CGFloat(lineCount)

                        // Each spectrum is rendered along a horizontal line extending from startX to endX.
                        let startX: CGFloat = 0.0   + lineRampUp * (0.33 * width)
                        let endX: CGFloat   = width - lineRampUp * (0.33 * width)
                        let spectrumWidth: CGFloat = endX - startX
                        let pointWidth: CGFloat = spectrumWidth / CGFloat(pointsPerRow)  // pointsPerRow= 3*12*8 = 288
                        
                        vertOffset = cos(2.0 * Double.pi * frequency * time )  // vertOffset oscillates between -1 and +1.
                        let ValY: CGFloat = lineRampDown * (quarterHeight - ( quarterHeight * CGFloat(vertOffset)) ) + (lineRampUp * halfHeight)
                
                        path.move( to: CGPoint( x: startX, y: (triOct == 0) ? height - ValY : ValY ) )

                        // We will render a total of shortSixOctPointCount points where sixOctavePointCount = 72 * 8 = 576
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
                        
                        hueIndex = (triOct == 0) ? 0.66 : 0.0  // lower triOct is blue;  upper triOct is red
                        
                    }
                    // Vary the line thickness to enhance the three-dimensional effect:
                    // As line goes from 0 to 31, LineWidth goes from 3.2 to 0.2
                    .stroke(lineWidth: 0.2 + (lineRampDown*3.0))
                    .foregroundColor(Color(hue: hueIndex, saturation: 1.0, brightness: 1.0))
                    //  foregroundColor wants a Color, but LinearGradient is a struct that conforms to the protocols ShapeStyle and View.

                }  // end of ForEach() loop over triOct

            }  // end of ForEach() loop over lineNum
            
        }  // end of GeometryReader
    }  //end of var body: some View
}  // end of RainbowSpectrum2 struct



/*
struct RainbowSpectrum2_Previews: PreviewProvider {
    static var previews: some View {
        RainbowSpectrum2()
    }
}
*/
