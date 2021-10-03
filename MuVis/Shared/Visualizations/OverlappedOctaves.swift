/// OverlappedOctaves.swift
/// MuVis
///
/// The OverlappedOctaves visualization is a variation of the upper half of the LinearOAS visualization - except that it stacks notes that are an octave apart.
/// That is, it has a grid of one row tall and 12 columns wide. All of the "C" notes are stacked together (i.e., a ZStack) in the left-hand box; all of the "C#" notes are
/// stacked together (i.e., a ZStack) in the second box, etc. We use the same note color coding scheme as used in the LinearOAS.
///
/// We overlay a stack of 7 octaves of the muSpectrum with the lowest-frequency octave at the back, and the highest-frequency octave at the front.
/// The octave's lowest frequency is at the left pane edge, and it's highest frequency is at the right pane edge.
///
/// Each octave is a standard spectrum display (converted from linear to exponential frequency) covering one octave.
/// Each octave is overlaid one octave over the next-lower octave. (Note that this requires compressing the frequency range by a factor of two for each octave.)
///
/// The leftmost column represents all of the musical "C" notes, that is: notes 0, 12, 24, 36, 48, and 60.
/// The rightmost column represents all of the musical "B" notes, that is: notes 11, 23, 35, 47, 59, and 71.
///
/// Overlaying this grid is a color scheme representing the white and black keys of a piano keyboard. Also, the name of the note is displayed in each column.
///
/// Created by Keith Bromley in June 2021 from an earlier java version developed for the Polaris project.

import SwiftUI


struct OverlappedOctaves: View {
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                GrayRectangles(columnCount: 12)
                VerticalLines(columnCount: 12)
                NoteNames(rowCount: 2, octavesPerRow: 1)
                OverlappedOctaves_LiveSpectra()
            }
        }
    }
}



struct OverlappedOctaves_LiveSpectra: View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        GeometryReader { geometry in

            let width: CGFloat  = geometry.size.width
            let height: CGFloat = geometry.size.height
    
            var x : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var upRamp : CGFloat = 0.0
            let octaveCount: Int = 6    // The FFT provides 7 octaves (plus 5 unrendered notes)
            
            let devGain:  CGFloat = 0.1     // devGain  is the optimum gain  value suggested by the developer
            let gain  = devGain  * settings.userGain
            var amp:   CGFloat = 0.0        // amplitude = gain + (slope * point)
            var magY:  CGFloat = 0.0        // used as a preliminary part of the "y" value
            
            let colorSize: Int = 10_000     // This determines the frequency of the color change over time.
            var hue:  Double = 0.0
            
            
//---------------------------------------------------------------------------------------------------------------------
            ForEach( 0 ..< octaveCount, id: \.self) { oct in        //  0 <= oct <= 5

                Path { path in

                    // Start the polygon at the pane's lower right corner:
                    path.move( to: CGPoint( x: width, y: height ) )

                    // Extend the polygon outline to the pane's lower left:
                    path.addLine( to: CGPoint( x: 0.0, y: height ) )

                    // Extend the polygon outline upward to the first sample point:
                    magY = CGFloat(audioManager.muSpectrum[oct * pointsPerOctave]) * height * gain // pointsPerOctave = 12*8=96
                    magY = min(max(0.0, magY), height)
                    y = height - magY
                    path.addLine( to: CGPoint( x: 0.0, y: y ) )

                    // Now render the remaining 95 points of the polygon across the pane from left to right:
                    for point in 1 ..< pointsPerOctave {
                        upRamp =  CGFloat(point) / CGFloat(pointsPerOctave)   // upRamp goes from 0.0 to 1.0 as point goes from 0 to pointsPerOctave
                        
                        x = upRamp * width
                        amp = gain + settings.userSlope * CGFloat(point)
                        magY = CGFloat(audioManager.muSpectrum[oct * pointsPerOctave + point]) * height * amp
                        magY = min(max(0.0, magY), height)
                        y = height - magY
                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    // Finally, extend the polygon back to the pane's lower right corner:
                    path.addLine( to: CGPoint( x: width, y: height ) )
                    path.closeSubpath()
                    
                    settings.colorIndex = (settings.colorIndex >= colorSize) ? 0 : settings.colorIndex + 1
                    hue = Double(settings.colorIndex) / Double(colorSize)          // 0.0 <= hue < 1.0
                    hue = ( hue + Double(oct) * 0.16 ).truncatingRemainder(dividingBy: 1.0)
                    
                }  // end of Path{}
                .foregroundColor(Color(hue: hue, saturation: 1.0, brightness: 1.0))
                
            }
            
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of LiveSpectra struct



/*
struct OctaveAlignedSpectrumVis_Previews: PreviewProvider {
    static var previews: some View {
        OctaveAlignedSpectrumVis()
    }
}
*/
