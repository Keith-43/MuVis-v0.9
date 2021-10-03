/// RainbowOAS.swift
/// MuVis
///
/// The RainbowOAS visualization uses the same Cartesian grid geometry as the OctaveAlignedSpectrum visualization.  However, instead of rendering just the
/// current muSpectrum, it also renders the most-recent 32 muSpectra history - so it shows how the envelope of each note varies with time.
/// Iterative scaling is used to make the older spectral values appear to drift into the background.
///
/// The 6 rows of the visualization cover 6 octaves.  Octave-wide spectra are rendered on rows 0, 1, 2 and on rows 4, 5, 6.  All iterate towards the vertical-midpoint
/// of the screen.  Octave 0 is rendered along row 0 at the bottom of the visualization pane.  Octave 5 is rendered along row 6 at the top of the visualization pane.
/// Using a resolution of 8 points per note, each row consists of 12 * 8 = 96 points covering 1 octave.  The 6 rows show a total of 6 * 96 = 576 points.
///
/// In addition to the current 576-point muSpectrum, we also render the previous 32 muSpectra.  Hence, the above figure shows a total of 576 * 32 =
/// 18,432 data points.  We use two ForEach loops.  The inner loop counts through the 6 octaves.  The outer loop counts through the 32 spectra stored in the
/// muSpecHistory[] buffer.
///
/// Again, for iPhones and iPads, the number 32 is reduced to 16 to lower the graphics load.
///
/// The different octaves are rendered in different vivid colors - hence the name RainbowOAS.
///
/// Created by Keith Bromley on 20 Dec 2020.


import SwiftUI


struct RainbowOAS: View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        
        GeometryReader { geometry in

            let width: CGFloat = geometry.size.width
            let height: CGFloat = geometry.size.height
                
            var x: CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y: CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var startX: CGFloat = 0.0
            var endX: CGFloat = width
            var spectrumWidth: CGFloat = 0.0
            var lineRampUp: CGFloat = 0.0
            var lineRampDown: CGFloat = 0.0
            var pointWidth: CGFloat = 0.0
            
            let octaveCount: Int = 6   // The FFT provides 7 octaves (plus 5 unrendered notes)
            let rowCount = octaveCount  // row = 0,1,2,3,4,5
            let lineCount = muSpecHistoryCount  //  It is easier to visualize the graphics using line & lineCount instead of hist & muSpecHistoryCount
            let rowHeight: CGFloat = height    / CGFloat(rowCount)
            let lineHeight: CGFloat = rowHeight / CGFloat(lineCount)
            
            var octOffset: Int = 0
            var histOffset: Int = 0
            let tempIndexR0 = muSpecHistoryIndex * sixOctPointCount  // <- index to first element of the most-recent (hist=0) spectrum written
            var tempIndexR1: Int = 0
            var tempIndexR2: Int = 0
            var tempIndexR3: Int = 0
                     
            let devGain:  CGFloat = 0.15
            let gain  = devGain * settings.userGain
            var amp:  CGFloat = 0.0     // amp = amplitude + (slope * bin)
            var magY: CGFloat = 0.0    // used as a preliminary part of the "y" value
            var rowY: CGFloat = 0.0    // used as a preliminary part of the "y" value
            
            var octaveColor: Color = Color.white



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


            
            ForEach( 0 ..< muSpecHistoryCount, id: \.self) { hist in        //  0 <= hist < 32
                let line = hist  //  It is easier to visualize the graphics using line & lineCount instead of hist & muSpecHistoryCount
                
                ForEach( 0 ..< octaveCount, id: \.self) { oct in        //  0 <= oct < 6
                
                    Path { path in
                    
                        rowY = (oct < 3) ? height - (CGFloat(oct) * rowHeight) : CGFloat((5-oct)) * rowHeight
                        
                        histOffset = hist * sixOctPointCount
                        octOffset  = oct * pointsPerOctave
                        tempIndexR1 = tempIndexR0 - histOffset + octOffset
                        tempIndexR2 = (tempIndexR1 >= 0) ? tempIndexR1 : tempIndexR1 + (muSpecHistoryCount*sixOctPointCount)

                        // lineRampUp goes from 0.0 to 1.0 as line goes from 0 to lineCount
                        lineRampUp   =  CGFloat(line) / CGFloat(lineCount)
                        // lineRampDown goes from 1.0 to 0.0 as line goes from 0 to lineCount
                        lineRampDown =  CGFloat(lineCount - line) / CGFloat(lineCount)
                        
                        // Each spectrum is rendered along a horizontal line extending from startX to endX.
                        startX = 0.0   + lineRampUp * (0.33 * width);
                        endX   = width - lineRampUp * (0.33 * width);
                        spectrumWidth = endX - startX;
                        pointWidth = spectrumWidth / CGFloat(pointsPerOctave)

                        switch oct {
                            case 0: y = rowY - CGFloat(hist) * CGFloat(3.0) * lineHeight
                            case 1: y = rowY - CGFloat(hist) * CGFloat(2.0) * lineHeight
                            case 2: y = rowY - CGFloat(hist) *                lineHeight
                            case 3: y = rowY + CGFloat(hist) *                lineHeight
                            case 4: y = rowY + CGFloat(hist) * CGFloat(2.0) * lineHeight
                            case 5: y = rowY + CGFloat(hist) * CGFloat(3.0) * lineHeight
                            default: y = 0.0
                        }
                        path.move( to: CGPoint( x: startX, y: y ) )

                        for point in 1 ..< pointsPerOctave {
                            x = startX + ( CGFloat(point) * pointWidth )
                            x = min(max(startX, x), endX);
                            
                            // We need to account for wrap-around at the muSpecHistory[] ends
                            tempIndexR3 = (tempIndexR2 + point) % (muSpecHistoryCount * sixOctPointCount)
                            amp  = gain + settings.userSlope * CGFloat(oct * pointsPerOctave + point)
                            magY = amp * CGFloat(muSpecHistory[tempIndexR3]) * lineRampDown * rowHeight

                            switch oct {
                                case 0: y = rowY - CGFloat(hist) * CGFloat(3.0) * lineHeight - magY
                                case 1: y = rowY - CGFloat(hist) * CGFloat(2.0) * lineHeight - magY
                                case 2: y = rowY - CGFloat(hist) *                lineHeight - magY
                                case 3: y = rowY + CGFloat(hist) *                lineHeight + magY
                                case 4: y = rowY + CGFloat(hist) * CGFloat(2.0) * lineHeight + magY
                                case 5: y = rowY + CGFloat(hist) * CGFloat(3.0) * lineHeight + magY
                                default: y = 0.0
                            }
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        
                        switch oct {
                            case 0:  octaveColor = Color.red
                            case 1:  octaveColor = Color.green
                            case 2:  octaveColor = Color.blue
                            case 3:  octaveColor = Color.noteAsharp_Color
                            case 4:  octaveColor = Color.noteFsharp_Color
                            case 5:  octaveColor = Color.red
                            default: octaveColor = Color.black
                        }
                        
                    }  // end of Path{}
                    // Vary the line thickness to enhance the three-dimensional effect:
                    // As line goes from 0 to 31, lineWidth goes from 3.2 to 0.2
                    .stroke(lineWidth: 0.2 + (lineRampDown*3.0))
                    .foregroundColor(octaveColor)
        
                }  // end of ForEach(oct)
            }  // end of ForEach(hist)
            
        }  // end of GeometryReader
    }  //end of var body: some View
}  // end of RainbowOASVis struct



/*
struct RainbowOASVis_Previews: PreviewProvider {
    static var previews: some View {
        RainbowOASVis()
    }
}
*/
