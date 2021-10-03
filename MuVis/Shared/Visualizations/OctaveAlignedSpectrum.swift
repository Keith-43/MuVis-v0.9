/// OctaveAlignedSpectrum.swift
/// MuVis
///
/// The OctaveAlignedSpectrum (OAS) visualization is one of the bedrock visualizations of this app. It is similar to the LinearOAS visualization except that the
/// octaves are laid out one above the other. This is ideal for examining the harmonic structure.
///
/// The graphical structure depicted is a grid of 7 rows by 12 columns. Each of the 7 rows contains all 12 notes within that one octave.
/// Each of the 12 columns contains 7 octaves of that particular note. If we render with a resolution of 8 points per note,
/// then each row contains 12 * 8 = 96 points, and the entire grid contains 96 * 7 = 672 points.
///
/// Each octave is a standard spectrum display (converted from linear to exponential frequency) covering one octave. Each octave is overlaid one octave above the
/// next-lower octave. (Note that this requires compressing the frequency range by a factor of two for each octave.)
///
/// We typically use the muSpectrum array to render it. But we could render it directly from the Spectrum array. The top row would show half of the spectral bins
/// (but over an exponential axis). The next-to-the-top row would show half of the remaining bins (but stretched by a factor of 2 to occupy the same length as the
/// top row). The next-lower-row would show half of the remaining bins (but stretched by a factor of 4 to occupy the same length as the top row). And so on.
/// Observe that the bottom row might contain only a small number of bins (perhaps 12) whereas the top row might contain a very large number of bins (perhaps
/// 12 times two-raised-to-the-sixth-power). The resultant increased resolution at the higher octaves might prove very useful in determining when a vocalist
/// is on- or off-pitch.
///
/// Created by Keith Bromley on 20 Nov 2020.

import SwiftUI


struct OctaveAlignedSpectrum: View {

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                GrayRectangles(columnCount: 12)
                HorizontalLines(rowCount: 7, offset: 0.0, color: .black)
                VerticalLines(columnCount: 12)
                NoteNames(rowCount: 2, octavesPerRow: 1)
                LiveSpectra()
            }
        }
    }
}



struct GrayRectangles: View {
    @EnvironmentObject var settings: Settings
    var columnCount: Int
    var body: some View {
        GeometryReader { geometry in
            let width: CGFloat  = geometry.size.width   // The drawing origin is in the upper left corner.
            let height: CGFloat = geometry.size.height  // The drawing origin is in the upper left corner.
            let columnWidth : CGFloat = width / CGFloat(columnCount)

            //                               C      C#    D      D#     E     F      F#    G      G#    A      A#    B
            let accidentalNote: [Bool] = [  false, true, false, true, false, false, true, false, true, false, true, false,
                                            false, true, false, true, false, false, true, false, true, false, true, false,
                                            false, true, false, true, false, false, true, false, true, false, true, false,
                                            false, true, false, true, false, false, true, false, true, false, true, false,
                                            false, true, false, true, false, false, true, false, true, false, true, false,
                                            false, true, false, true, false, false, true, false, true, false, true, false ]
            
            ForEach( 0 ..< columnCount, id: \.self) { columnNum in        //  0 <= column < 12 or 36 or 72
                // For each octave, draw 5 rectangles across the pane (representing the 5 accidentals (i.e., sharp/flat notes):
                if(accidentalNote[columnNum] == true) {  // This condition selects the column values for the notes C#, D#, F#, G#, and A#
                    Rectangle()
                        .fill( (settings.selectedColorScheme == .light) ? Color.lightGray.opacity(0.25) : Color.black.opacity(0.25) )
                        .frame(width: columnWidth, height: height)
                        .offset(x: CGFloat(columnNum) * columnWidth, y: 0.0)
                }
            }
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of GrayRectangles struct



struct HorizontalLines: View {
    var rowCount: Int
    var offset: CGFloat
    var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            let width: CGFloat  = geometry.size.width   // The drawing origin is in the upper left corner.
            let height: CGFloat = geometry.size.height  // The drawing origin is in the upper left corner.
            let rowHeight : CGFloat = height / CGFloat(rowCount)
            
            //  Draw 8 horizontal lines across the pane (separating the 7 octaves):
            ForEach( 0 ..< rowCount+1, id: \.self) { row in        //  0 <= row < 7+1
            
                Path { path in
                path.move(   to: CGPoint(x: CGFloat(0.0), y: CGFloat(row) * rowHeight - offset * rowHeight) )
                path.addLine(to: CGPoint(x: width,        y: CGFloat(row) * rowHeight - offset * rowHeight) )
                }
                .stroke(lineWidth: 1.0)
                .foregroundColor(color)
            }
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of HorizontalLines struct



struct VerticalLines: View {
    var columnCount: Int

    var body: some View {
        GeometryReader { geometry in
            let width: CGFloat  = geometry.size.width   // The drawing origin is in the upper left corner.
            let height: CGFloat = geometry.size.height  // The drawing origin is in the upper left corner.
            let columnWidth : CGFloat = width / CGFloat(columnCount)
            
            //  Draw 12 vertical lines across the pane (separating the 12 notes):
            ForEach( 0 ..< columnCount+1, id: \.self) { column in        //  0 <= column < 11+1
            
                Path { path in
                    path.move(   to: CGPoint(x: CGFloat(column) * columnWidth, y: CGFloat(0.0)) )
                    path.addLine(to: CGPoint(x: CGFloat(column) * columnWidth, y: height) )
                }
                .stroke(lineWidth: 1.0)
                .foregroundColor(.black)
            }
        }  // end of GeometryReader
    }  // end of var body: some View
}  // end of VerticalLines struct



struct NoteNames: View {
    var rowCount: Int
    var octavesPerRow: Int
    
    var body: some View {
        GeometryReader { geometry in
            let width: CGFloat  = geometry.size.width   // The drawing origin is in the upper left corner.
            let height: CGFloat = geometry.size.height  // The drawing origin is in the upper left corner.
            let octaveWidth: CGFloat = width / CGFloat(octavesPerRow)
            let noteWidth: CGFloat = width / CGFloat(octavesPerRow * notesPerOctave)
            
            ForEach(0 ..< rowCount) { rows in
                let row = CGFloat(rows)
                
                  ForEach(0 ..< octavesPerRow) { octave in
                    let oct = CGFloat(octave)
                    
                    Text("C")
                        .platformFont()
                        .frame(width: noteWidth, height: 0.05*height)
                        .offset(x: oct * octaveWidth + 0 * noteWidth, y: 0.95 * row * height)
                    Text("D")
                        .platformFont()
                        .frame(width: noteWidth, height: 0.05*height)
                        .offset(x: oct * octaveWidth + 2 * noteWidth, y: 0.95 * row * height)
                    Text("E")
                        .platformFont()
                        .frame(width: noteWidth, height: 0.05*height)
                        .offset(x: oct * octaveWidth + 4 * noteWidth, y: 0.95 * row * height)
                    Text("F")
                        .platformFont()
                        .frame(width: noteWidth, height: 0.05*height)
                        .offset(x: oct * octaveWidth + 5 * noteWidth, y: 0.95 * row * height)
                    Text("G")
                        .platformFont()
                        .frame(width: noteWidth, height: 0.05*height)
                        .offset(x: oct * octaveWidth + 7 * noteWidth, y: 0.95 * row * height)
                    Text("A")
                        .platformFont()
                        .frame(width: noteWidth, height: 0.05*height)
                        .offset(x: oct * octaveWidth + 9 * noteWidth, y: 0.95 * row * height)
                    Text("B")
                        .platformFont()
                        .frame(width: noteWidth, height: 0.05*height)
                        .offset(x: oct * octaveWidth + 11 * noteWidth, y: 0.95 * row * height)
                }
            }
        }
    }
}



struct LiveSpectra: View {
    @EnvironmentObject var audioManager: AudioManager  // We observe the instance of AudioManager passed to us from ContentView.
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
            
            Path { path in
            
                for row in 0 ..< rowCount {
                    CGrow = CGFloat(row)
                    path.move( to: CGPoint( x: 0.0, y: height - CGrow * rowHeight ) )
                    
                    magY = CGFloat(audioManager.muSpectrum[row * pointsPerOctave]) * rowHeight * gain
                    magY = min(max(0.0, magY), rowHeight)
                    y = height - CGrow * rowHeight - magY
                    path.addLine( to: CGPoint( x: 0.0, y: y ) )

                    for point in 1 ..< pointsPerOctave {
                        upRamp =  CGFloat(point) / CGFloat(pointsPerOctave)   // upRamp goes from 0.0 to 1.0 as point goes from 0 to pointsPerOctave
                        x = upRamp * width
                        
                        amp = gain + settings.userSlope * CGFloat( row * pointsPerOctave + point )
                        magY = CGFloat(audioManager.muSpectrum[row * pointsPerOctave + point]) * rowHeight * amp
                        magY = min(max(0.0, magY), rowHeight)
                        y = height - CGrow * rowHeight - magY
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    amp = gain + settings.userSlope * CGFloat( (row+1) * pointsPerOctave )
                    magY = CGFloat(audioManager.muSpectrum[ (row+1) * pointsPerOctave]) * rowHeight * amp
                    magY = min(max(0.0, magY), rowHeight)
                    y = height - CGrow * rowHeight - magY
                    path.addLine( to: CGPoint( x: width, y: y ) )
                    
                    path.addLine( to: CGPoint( x: width, y: height - CGrow * rowHeight ) )
                    path.addLine( to: CGPoint( x: 0.0,   y: height - CGrow * rowHeight ) )
                    path.closeSubpath()
                }
                
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
                
            }  // end of Path{}
            .foregroundColor(.init(red: 192.0/255.0, green: 57.0/255.0, blue: 43.0/255.0, opacity: 1.0))  // Pomegranate color

            // Text("Period = \(Int(1000.0*settings.timePassed))")   // This prints the elapsed time/frame in milliseconds (typically about 100)

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
