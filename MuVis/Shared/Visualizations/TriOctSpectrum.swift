/// TriOctSpectrum.swift
/// MuVis
///
/// The TriOctSpectrum visualization is similar to the LinearOAS visualization in that it shows a muSpectrum of six octaves of the audio waveform -
/// however it renders it as two separate muSpectrum displays.
///
/// It has the format of a downward-facing muSpectrum in the lower half-screen covering the lower three octaves, and an upward-facing muSpectrum in the upper
/// half-screen covering the upper three octaves. Each half screen shows three octaves. (The name "bi- tri-octave muSpectrum" seemed unduly cumbersome,
/// so I abbreviated it to "tri-octave spectrum"). The specific note frequencies are:
///
/// *         262 Hz                                   523 Hz                                    1046 Hz                            1976 Hz
/// *          C4                                          C5                                           C6                                       B6
/// *           |                                               |                                               |                                          |
/// *          W B W B W W B W B W B W W B W B W W B W B W B W W B W B W W B W B W B W
/// *
/// *          W B W B W W B W B W B W W B W B W W B W B W B W W B W B W W B W B W B W
/// *           |                                               |                                               |                                          |
/// *          C1                                          C2                                            C3                                      B3
/// *          33Hz                                   65 Hz                                       130 Hz                               247 Hz
///
/// As with the LinearOAS visualization, the spectral peaks comprising each note are a separate color, and the colors of the grid are consistent across all octaves -
/// hence all octaves of a "C" note are red; all octaves of an "E" note are green, and all octaves of a "G" note are light blue, etc.
/// Also, we have added a piano-keyboard overlay to clearly differentiate the black notes (in gray) from the white notes (in white).
/// Also, we have added note names for the white notes at the top and bottom.
///
/// The visual appearance of these two MuSpectra is of each note being rendered as a small blob of a different color. However, in fact, we implement this effect by
/// having static vertical blocks depicting the note colors and then having the non-spectrum rendered as two big white / dark-gray blobs covering the non-spectrum
/// portion of the spectrum display - one each for the upper-half-screen and the lower-half-screen. The static colored vertical blocks are rendered first; then the
/// dynamic white / dark-gray big blobs; then the gray "black notes"; and finally the note names.
///
/// Created by Keith Bromley on 29/  Nov 2020.


import SwiftUI


struct TriOctSpectrum: View {
    @EnvironmentObject var audioManager: AudioManager  // We observe the instance of AudioManager passed to us from ContentView.
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ColorRectangles(columnCount: 36)
                DoubleSpectrum()
                GrayRectangles(columnCount: 36) // overlays the screen with semi-transparent gray rectangles denoting the piano's keyboard.
                VerticalLines(columnCount: 36)
                HorizontalLines(rowCount: 2, offset: 0.0, color: .black)
                NoteNames(rowCount: 2, octavesPerRow: 3)
            }
        }
    }
}



struct ColorRectangles: View {
    var columnCount: Int
    
    var body: some View {
        GeometryReader { geometry in
        
            let width: CGFloat  = geometry.size.width   // The drawing origin is in the upper left corner.
            let height: CGFloat = geometry.size.height  // The drawing origin is in the upper left corner.
            let columnWidth : CGFloat = width / CGFloat(columnCount)

            // Fill 36 colored rectangles across the pane.
            HStack(alignment: .center, spacing: 0.0) {
            
                ForEach( 0 ..< columnCount, id: \.self) { column in        //  0 <= rect < 36
                    let noteNum = column % notesPerOctave
                    Rectangle()
                        .fill(noteColor[noteNum])
                        .frame(width: columnWidth, height: height)
                }
            }
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of ColorRectangles struct




struct DoubleSpectrum : View {
    @EnvironmentObject var audioManager: AudioManager  // We observe the instance of AudioManager passed from ContentView.
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        GeometryReader { geometry in
        
            let width  : CGFloat = geometry.size.width
            let height : CGFloat = geometry.size.height
            let halfHeight : CGFloat = height * 0.5

            var x : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var upRamp : CGFloat = 0.0

            let devGain:  CGFloat = 0.3     // devGain  is the optimum gain  value suggested by the developer
            let gain = devGain * settings.userGain
            var amp:  CGFloat = 0.0     // amp = amplitude + (slope * bin)
            var magY: CGFloat = 0.0     // used as a preliminary part of the "y" value
            
            let octavesPerRow : Int = 3
            let pointsPerRow : Int = pointsPerNote * notesPerOctave * octavesPerRow  //  12 * 12 * 3 = 432
            
            // Bottom spectrum contains lower three octaves:
            Path { path in
            
                path.move   ( to: CGPoint( x: width, y: halfHeight) )   // right midpoint
                path.addLine( to: CGPoint( x: width, y: height))        // right bottom
                path.addLine( to: CGPoint( x: 0.0,   y: height))        // left bottom
                path.addLine( to: CGPoint( x: 0.0,   y: halfHeight))    // left midpoint
                
                for point in 1 ..< pointsPerRow {
                    upRamp =  CGFloat(point) / CGFloat(pointsPerRow)   // upRamp goes from 0.0 to 1.0 as point goes from 0 to pointsPerRow
                    x = upRamp * width
                    amp = gain + settings.userSlope * CGFloat(point)
                    magY = CGFloat(audioManager.muSpectrum[point]) * halfHeight * amp
                    magY = min(max(0.0, magY), halfHeight)
                    y = halfHeight + magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine( to: CGPoint( x: width, y: halfHeight ) )
                path.closeSubpath()
            }
            .foregroundColor( (settings.selectedColorScheme == .light) ? Color.white : Color.darkGray )
        
            // Top spectrum contains the upper three octaves:
            Path { path in
                path.move   ( to: CGPoint( x: width, y: halfHeight) )   // right midpoint
                path.addLine( to: CGPoint( x: width, y: 0.0))           // right top
                path.addLine( to: CGPoint( x: 0.0,   y: 0.0))           // left top
                path.addLine( to: CGPoint( x: 0.0,   y: halfHeight))    // left midpoint
                
                for point in 1 ..< pointsPerRow {
                    upRamp =  CGFloat(point) / CGFloat(pointsPerRow)   // upRamp goes from 0.0 to 1.0 as point goes from 0 to pointsPerRow
                    x = upRamp * width
                    
                    amp = gain + settings.userSlope * CGFloat(pointsPerRow + point)
                    magY = CGFloat(audioManager.muSpectrum[pointsPerRow + point]) * halfHeight * amp
                    magY = min(max(0.0, magY), halfHeight)
                    y = halfHeight - magY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine( to: CGPoint( x: width, y: halfHeight ) )
                path.closeSubpath()
                
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
            .foregroundColor( (settings.selectedColorScheme == .light) ? Color.white : Color.darkGray )


        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of DoubleSpectrum struct



/*
struct TriOctSpectrumVis_Previews: PreviewProvider {
    static var previews: some View {
        TriOctSpectrumVis()
    }
}
*/

