/// LinearOAS.swift
/// MuVis
/// The LinearOAS visualization is similar to the muSpectrum visualization in that it shows an amplitude vs. exponential-frequency spectrum of the audio waveform.
/// The horizontal axis covers a total of 72 notes (i.e., 6 octaves) from C1 (about 33 Hz) to B6 (about 1,976 Hz). For a pleasing effect, the vertical axis shows both an
/// upward-extending muSpectrum in the upper-half screen and a downward-extending muSpectrum in the lower-half screen.
///
/// We have added a piano-keyboard overlay to clearly differentiate the black notes (in gray) from the white notes (in white).
/// Also, we have added note names for the white notes at the top and bottom.
///
/// The spectral peaks comprising each note are a separate color. The colors of the grid are consistent across all octaves - hence all octaves of a "C" note are red;
/// all octaves of an "E" note are green, and all octaves of a "G" note are light blue, etc. Many of the subsequent visualizations use this same note coloring scheme.
/// I have subjectively selected these to provide high color difference between adjacent notes.
///
/// The visual appearance of this spectrum is of each note being rendered as a small blob of a different color. However, in fact, we implement this effect by having
/// static vertical blocks depicting the note colors and then having the non-spectrum rendered as one big white /dark-gray blob covering the non-spectrum portion
/// of the spectrum display. The static colored vertical blocks are rendered first; then the dynamic white / dark-gray big blob; then the gray "black notes";
/// and finally the note names.
///
/// Created by Keith Bromley on 29 Nov 2020.

import SwiftUI


struct LinearOAS: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ColorRectangles(columnCount: 72)
                LiveMuSpectrum()
                GrayRectangles(columnCount: 72)
                VerticalLines(columnCount: 72)
                NoteNames(rowCount: 2, octavesPerRow: 6)
            }
        }
    }
}



struct LiveMuSpectrum : View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        GeometryReader { geometry in
        
            let width  : CGFloat = geometry.size.width
            let height : CGFloat = geometry.size.height
            let halfHeight : CGFloat = height * 0.5

            var x : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var upRamp : CGFloat = 0.0

            let devGain:  CGFloat = 0.4     // devGain  is the optimum gain  value suggested by the developer
            let gain  = devGain  * settings.userGain
            var amp:  CGFloat = 0.0     // amp = amplitude + (slope * bin)            let gain = devGain * settings.userGain
            var magY: CGFloat = 0.0     // used as a preliminary part of the "y" value
            
            // Bottom white / dark-gray blob:
            Path { path in
            
                path.move   ( to: CGPoint( x: width, y: halfHeight) )   // right midpoint
                path.addLine( to: CGPoint( x: width, y: height))        // right bottom
                path.addLine( to: CGPoint( x: 0.0,   y: height))        // left bottom
                path.addLine( to: CGPoint( x: 0.0,   y: halfHeight))    // left midpoint
                
                for point in 1 ..< sixOctPointCount {
                    upRamp =  CGFloat(point) / CGFloat(sixOctPointCount)   // upRamp goes from 0.0 to 1.0 as point goes from 0 to sixOctPointCount
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
        
        
            // Top white / dark-gray blob:
            Path { path in
                path.move   ( to: CGPoint( x: width, y: halfHeight) )   // right midpoint
                path.addLine( to: CGPoint( x: width, y: 0.0))           // right top
                path.addLine( to: CGPoint( x: 0.0,   y: 0.0))           // left top
                path.addLine( to: CGPoint( x: 0.0,   y: halfHeight))    // left midpoint
                
                for point in 1 ..< sixOctPointCount {
                    upRamp =  CGFloat(point) / CGFloat(sixOctPointCount)   // upRamp goes from 0.0 to 1.0 as point goes from 0 to pointsPerRow
                    x = upRamp * width
                    
                    amp = gain + settings.userSlope * CGFloat(point)
                    magY = CGFloat(audioManager.muSpectrum[point]) * halfHeight * amp
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
struct LinearOAS_Previews: PreviewProvider {
    static var previews: some View {
        TriOctSpectrumVis()
    }
}
*/

