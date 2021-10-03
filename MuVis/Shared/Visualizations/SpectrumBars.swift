/// SpectrumBarsVis.swift
/// MuVis
///
/// This is basically the same as the muSpectrum plot - but with much fancier dynamic graphics.
///
/// This visualization was copied from Matt Pfeiffer's tutorial "Audio Visualizer Using AudioKit and SwiftUI" at
/// https://audiokitpro.com/audiovisualizertutorial/
/// https://github.com/Matt54/SwiftUI-AudioKit-Visualizer
/// I believe that this is copied from the FFTView visualization within the AudioKitUI framework.
///

import SwiftUI


struct SpectrumBars: View {

    @EnvironmentObject var audioManager: AudioManager  // We observe the instance of AudioManager passed to us from ContentView.
    @EnvironmentObject var settings: Settings
    
    var linearGradient : LinearGradient = LinearGradient(gradient: Gradient(colors: [.red, .yellow, .green]), startPoint: .top, endPoint: .center)
    var paddingFraction: CGFloat = 0.2
    var includeCaps: Bool = true

    var body: some View {
    
        let devGain: Float = 0.3        // devGain  is the optimum gain value suggested by the developer
        let gain  = devGain  * Float(settings.userGain)
        let amp: Float = gain             // amp = amplitude + (slope * bin)
        
        HStack(spacing: 0.0){
            ForEach(0 ..< sixOctNoteCount) { note in
                // amp = gain + settings.userSlope * Float(note)  // ViewBuilder does not accept this line.  Solution: Eliminate slope for this visualization
                AmplitudeBar(amplitude: amp * audioManager.muSpectrum[8*note+4],
                            linearGradient: linearGradient,
                            paddingFraction: paddingFraction,
                            includeCaps: includeCaps)
            }
            //  The muSpectrum[] array uses pointsPerNote = 8.  Therefore:
            //  Inter-note midpoints are at index = 8*note = 0, 8, 16, 24.    Note centers are at index = 8*note+4 = 4, 12, 20, 28
        }
        .background((settings.selectedColorScheme == .light) ? Color.white : Color.black)
    }
    
}  // end of SpectrumBars struct



struct AmplitudeBar: View {
    @EnvironmentObject var settings: Settings
    var amplitude: Float
    var linearGradient : LinearGradient
    var paddingFraction: CGFloat = 0.2
    var includeCaps: Bool = true
        
    var body: some View {
        GeometryReader
            { geometry in
            
            ZStack(alignment: .bottom){
                
                // Colored rectangle in back of ZStack
                Rectangle()
                    .fill(self.linearGradient)
                
                // Dynamic black mask padded from bottom in relation to the amplitude
                Rectangle()
                    .fill((settings.selectedColorScheme == .light) ? Color.white : Color.black) // Toggle between black and white background color.
                    .mask(Rectangle().padding(.bottom, geometry.size.height * CGFloat(amplitude)))
                    .animation(.easeOut(duration: 0.15))
                
                // White bar with slower animation for floating effect
                if(includeCaps){
                    addCap(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .padding(geometry.size.width * paddingFraction / 2)
            .border( (settings.selectedColorScheme == .light) ? Color.white : Color.black, width: geometry.size.width * paddingFraction / 2)
        }
    }
    
    // Creates the Cap View - seperate method allows variable definitions inside a GeometryReader
    func addCap(width: CGFloat, height: CGFloat) -> some View {
        let padding = width * paddingFraction / 2
        let capHeight = height * 0.005
        let capDisplacement = height * 0.02
        let capOffset = -height * CGFloat(amplitude) - capDisplacement - padding * 2
        let capMaxOffset = -height + capHeight + padding * 2
        
        return Rectangle()
            .fill((settings.selectedColorScheme == .light) ? Color.black : Color.white)
            .frame(height: capHeight)
            .offset(x: 0.0, y: -height > capOffset - capHeight ? capMaxOffset : capOffset) //ternary prevents offset from pushing cap outside of it's frame
            .animation(.easeOut(duration: 0.6))
    }
    
}  // end of AmplitudeBar struct



/*
struct SpectrumBarsVis_Previews: PreviewProvider {
    static var previews: some View {
        SpectrumBarsVis(amplitudes: Array(repeating: 0.95, count: 50))
    }
}
*/
