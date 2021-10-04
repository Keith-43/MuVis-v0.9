///  MuVisApp.swift
///  MuVis
///
///  Created by Keith Bromley on 17 Nov 2020.

import SwiftUI

// Declare and intialize global constants and variables:

var micEnabled: Bool = false        // true means microphone is on and its audio is being captured.
var filePlayEnabled: Bool = true    // Either micEnabled or filePlayEnabled is always true (but not both).

let fftLength: Int  =  4096         // The number of audio samples inputted to the FFT operation each frame.
let binCount: Int   = fftLength/2   // The number of frequency bins provided in the FFT output (binCount=2048 for fftLength=4096)
let halfBinCount = binCount / 2     // halfBinCount = 1024 for fftLength = 4096
let quarterBinCount = binCount / 4  // quarterBinCount = 512 for fftLength = 4096

let twelfthRoot2      : Float = pow(2.0, 1.0 / 12.0)     // twelfth root of two = 1.059463094359
let twentyFourthRoot2 : Float = pow(2.0, 1.0 / 24.0)     // twenty-fourth root of two = 1.029302236643
let freqC1            : Float = 55.0 * pow(twelfthRoot2, -9.0)      // C1 = 32.7032 Hz
let leftFreqC1        : Float = freqC1 / twentyFourthRoot2

let pointsPerNote    = 8  // The number of frequency samples within one musical note.
let notesPerOctave   = 12 // An octave contains 12 musical notes.
let totalNoteCount   = 89 // from C1 to E8 is 89 notes  (  0 <= note < 89 ) (E8 is the highest note we can observe at 11,025 sps.)
let pointsPerOctave  = notesPerOctave * pointsPerNote  // 12 * 8 = 96
let totalPointCount  = totalNoteCount * pointsPerNote  // 89 * 8 = 712  // total number of points provided by the interpolator

let sixOctNoteCount  = 72	// the number of notes within six octaves
let sixOctPointCount = sixOctNoteCount * pointsPerNote  // 72 * 8 = 576   // number of points within six octaves
let halfSixOctPointCount = sixOctPointCount / 2         // 36 * 8 = 288   // number of points within three octaves

// Create a circular buffer to store the past 24 blocks of muSpectrum[]. It stores 32 * 72 * 8 = 18,432 points.
var muSpecHistoryCount : Int = 32   // macOS: Keep the 32 most-recent values of muSpectrum[point] in a circular buffer
                                    // iOS: reduce this to muSpecHistoryCount = 16 to reduce the memory load.
var muSpecHistoryIndex : Int = 0    // Index for writing to the muSpecHistory buffer
var muSpecHistory: [Float] = [Float](repeating: 0.0, count: muSpecHistoryCount * sixOctPointCount)

let circBufferLength: Int = 5510   // store the most recent 5510 audio samples in our circular buffer  Must be >= 4096+1102=5198  I chose 5*1102 = 5510

var index: Int = 0                 // Use this index as a write/read pointer into our circBuffer.


// The following colors are declared and defined in the Colors.xcassets project folder:
extension Color {
    static let lightGray        = Color(red: 0.7, green: 0.7, blue: 0.7)    // denotes accidental notes in keyboard overlay in light mode
    static let darkGray         = Color(red: 0.3, green: 0.3, blue: 0.3)    // denotes natural notes in keyboard overlay in dark mode
    static let noteA_Color      = Color(red: 0.5, green: 0.0, blue: 1.0)
    static let noteAsharp_Color = Color(red: 1.0, green: 0.0, blue: 1.0)    // magenta
    static let noteB_Color      = Color(red: 1.0, green: 0.0, blue: 0.7)
    static let noteC_Color      = Color(red: 1.0, green: 0.0, blue: 0.0)    // red
    static let noteCsharp_Color = Color(red: 1.0, green: 0.5, blue: 0.0)
    static let noteD_Color      = Color(red: 1.0, green: 1.0, blue: 0.0)    // yellow
    static let noteDsharp_Color = Color(red: 0.1, green: 1.0, blue: 0.0)
    static let noteE_Color      = Color(red: 0.0, green: 1.0, blue: 0.0)    // green
    static let noteF_Color      = Color(red: 0.0, green: 1.0, blue: 0.7)
    static let noteFsharp_Color = Color(red: 0.0, green: 1.0, blue: 1.0)    // cyan
    static let noteG_Color      = Color(red: 0.0, green: 0.5, blue: 1.0)
    static let noteGsharp_Color = Color(red: 0.0, green: 0.0, blue: 1.0)	// blue
}

let noteColor: [Color] = [  Color.noteC_Color, Color.noteCsharp_Color, Color.noteD_Color, Color.noteDsharp_Color,
                            Color.noteE_Color, Color.noteF_Color, Color.noteFsharp_Color, Color.noteG_Color,
                            Color.noteGsharp_Color, Color.noteA_Color, Color.noteAsharp_Color, Color.noteB_Color ]
     
     
// I found experimentally that font.body looks good on macOS and font.footnote looks good on iOS:
// https://stackoverflow.com/questions/61289969/swiftui-change-text-size-for-macos
extension Text {
    func platformFont() -> Text {
        #if canImport(AppKit) || targetEnvironment(macCatalyst) // same as #if os(macOS)
            return self.font(.body)
        #elseif canImport(UIKit)                                // same as #if os(iOS)
            return self.font(.footnote)
        #else
            return self
        #endif
    }
}
     
     

@main
struct MuVisApp: App {
    
    var body: some Scene {
        WindowGroup {
            #if os(macOS)
                ContentView().environmentObject(AudioManager.audioManager).environmentObject(Settings.settings)
                    .navigationTitle("MuVis  -  Music Visualizer")      // This is the app's name used as a window title in the titlebar
                    .frame( minWidth:  100.0, idealWidth:  500.0, maxWidth:  .infinity,
                            minHeight: 100.0, idealHeight: 500.0, maxHeight: .infinity, alignment: .center)
            #else
                ContentView().environmentObject(AudioManager.audioManager).environmentObject(Settings.settings)
                    // .ignoresSafeArea()
            #endif
        }
    }
}
