/// OctaveAlignedSpectrum2.swift
/// MuVis
/// The OctaveAlignedSpectrum2 visualization is exactly the same as the OctaveAlignedSpectrum visualization except that the each note-within-the-octave is
/// rendered in a different color - based on the same note coloring scheme used in the LinearOAS visualization.
///
/// Created by Keith Bromley on 20 Nov 2020.

import SwiftUI


struct OctaveAlignedSpectrum2: View {

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                GradientRectangle()
                OAS2_LiveSpectra()
                GrayRectangles(columnCount: 12)
                HorizontalLines(rowCount: 7, offset: 0.0, color: .black)
                VerticalLines(columnCount: 12)
                NoteNames(rowCount: 2, octavesPerRow: 1)
            }
        }
    }
}



struct GradientRectangle: View {
    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient( gradient: Gradient(colors: [.noteC_Color, .noteCsharp_Color, .noteD_Color, .noteDsharp_Color,
                                                                .noteE_Color, .noteF_Color, .noteFsharp_Color, .noteG_Color,
                                                                .noteGsharp_Color, .noteA_Color, .noteAsharp_Color, .noteB_Color]),
                                    startPoint: .leading,
                                    endPoint: .trailing)
            )
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of GradientRectangle struct



struct OAS2_LiveSpectra: View {
    @EnvironmentObject var audioManager: AudioManager  // Observe the instance of AudioManager passed from ContentView
    @EnvironmentObject var settings: Settings
    
    var body: some View {
        GeometryReader { geometry in
            /*
            This is a two-dimensional grid containing 7 row and 12 columns.
            Each of the 7 rows contains 1 octave or 12 notes or 12*8 = 96 points.
            Each of the 12 columns contains 7 octaves of that particular note.
            The entire grid renders 7 octaves or 7*12 = 84 notes or 7*96 = 672 points
            */

            let width: CGFloat  = geometry.size.width
            let height: CGFloat = geometry.size.height
    
            var x : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var y : CGFloat = 0.0       // The drawing origin is in the upper left corner.
            var upRamp : CGFloat = 0.0

            let rowCount : Int = 7  // The FFT provides 7 octaves (plus 5 unrendered notes)
            let rowHeight : CGFloat = height / CGFloat(rowCount)
            
            let devGain:  CGFloat = 0.3      // devGain  is the optimum gain  value suggested by the developer
            let gain  = devGain  * settings.userGain
            var amp:   CGFloat = 0.0        // amplitude = gain + (slope * point)
            var magY:  CGFloat = 0.0        // used as a preliminary part of the "y" value
            var CGrow: CGFloat = 0.0


            ForEach( 0 ..< rowCount, id: \.self ) { row in        //  0 <= row <= 6
            
                Path { path in

                    CGrow = CGFloat(row)
                    
                    //For each row, render a black blob covering the upper half, and revealing the spectrum in the lower half
                    // Start the path at the right row bottom:
                    path.move( to: CGPoint( x: width, y: height - CGrow * rowHeight) )
                    
                    // Extend the path at the right row top:
                    path.addLine( to: CGPoint( x: width, y: height - (CGrow + 1) * rowHeight ) )
                    
                    // Extend the path at the left row top:
                    path.addLine( to: CGPoint( x: 0.0, y: height - (CGrow + 1) * rowHeight ) )
                    
                    // Extend the path at the left row bottom:
                    path.addLine( to: CGPoint( x: 0.0, y: height - CGrow * rowHeight) )
                    
                    // Extend the path from left to right accross the pane
                    for point in 0 ..< pointsPerOctave {
                        upRamp =  CGFloat(point) / CGFloat(pointsPerOctave)   // upRamp goes from 0.0 to 1.0 as point goes from 0 to pointsPerOctave
                        x = upRamp * width
                        
                        amp = gain + settings.userSlope * CGFloat( row * pointsPerOctave + point )
                        magY = CGFloat(audioManager.muSpectrum[row * pointsPerOctave + point]) * rowHeight * amp
                        magY = min(max(0.0, magY), rowHeight)
                        y = height - CGrow * rowHeight - magY
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    // Extend the path all the way to the right-hand side:
                    amp = gain + settings.userSlope * CGFloat( (row+1) * pointsPerOctave )
                    magY = CGFloat(audioManager.muSpectrum[ (row+1) * pointsPerOctave]) * rowHeight * amp
                    magY = min(max(0.0, magY), rowHeight)
                    y = height - CGrow * rowHeight - magY
                    path.addLine( to: CGPoint( x: width, y: y ) )
                    
                    // Extend the path to the right row bottom:
                    path.addLine( to: CGPoint( x: width, y: height - CGrow * rowHeight) )
                    path.closeSubpath()

                    }  // end of Path{}
                    .foregroundColor( (settings.selectedColorScheme == .light) ? Color.white : Color.darkGray )
                    
            }  // end of ForEach()
            
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
