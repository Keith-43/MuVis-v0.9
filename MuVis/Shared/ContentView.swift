///  ContentView.swift
///  MuVis
///
///  Created by Keith Bromley on 20 Nov 2020.


import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var settings: Settings
    
    @State private var visNum: Int = 0      // visualization number - used as an index into the visualizationList array
    @State private var enableSongFileSelection: Bool = false
    
    struct Visualization {
        var name: String        // The visualization's name is shown as text in the titlebar
        var location: AnyView   // A visualization's location is the View that renders it.
    }

    let visualizationList: [Visualization] =  [
            Visualization (name: "Spectrum",                    location: AnyView(Spectrum() ) ),
            Visualization (name: "MuSpectrum",                  location: AnyView(MuSpectrum() ) ),
            Visualization (name: "Spectrum Bars",               location: AnyView(SpectrumBars() ) ),
            Visualization (name: "Linear OAS",                  location: AnyView(LinearOAS() ) ),
            Visualization (name: "Overlapped Octaves",          location: AnyView(OverlappedOctaves() ) ),
            Visualization (name: "Octave Aligned Spectrum",     location: AnyView(OctaveAlignedSpectrum() ) ),
            Visualization (name: "Octave Aligned Spectrum2 ",   location: AnyView(OctaveAlignedSpectrum2() ) ),
            Visualization (name: "Elliptical OAS",              location: AnyView(EllipticalOAS() ) ),
            Visualization (name: "Spiral OAS",                  location: AnyView(SpiralOAS() ) ),
            Visualization (name: "Harmonic Alignment",          location: AnyView(HarmonicAlignment() ) ),
            Visualization (name: "Harmonic Alignment 3",        location: AnyView(HarmonicAlignment3() ) ),
            Visualization (name: "TriOct Spectrum",             location: AnyView(TriOctSpectrum() ) ),
            Visualization (name: "Harmonograph",                location: AnyView(Harmonograph() ) ),
            Visualization (name: "Cymbal",                      location: AnyView(Cymbal() ) ),
            Visualization (name: "Rainbow Spectrum",            location: AnyView(RainbowSpectrum() ) ),
            Visualization (name: "Rainbow Spectrum 2",          location: AnyView(RainbowSpectrum2() ) ),
            Visualization (name: "Rainbow OAS",                 location: AnyView(RainbowOAS() ) ),
            Visualization (name: "Rainbow Ellipse",             location: AnyView(RainbowEllipse() ) ),
            Visualization (name: "Spinning Ellipse",            location: AnyView(SpinningEllipse() ) ),
            Visualization (name: "Wormhole",                    location: AnyView(Wormhole() ) ) ]

    
    var body: some View {
    
        VStack {
            
            // Only show the "Visualization Name" text field for large-screen devices (such as Macs):
            #if os(macOS)
                ZStack{
                    ForEach(visualizationList.indices) {index in
                        if index == visNum{
                            Text("\(visualizationList[index].name)") // the "visualization name" text field at the screen top.
                            .bold()
                            .padding(.top, 5)
                        }
                    }
                }
            #endif
    
            // "visualizationList[settings.visNum].location" is the main "visualization rendering" pane:
            ZStack{
                ForEach(visualizationList.indices) {index in
                    ZStack{
                        if index == visNum{
                            visualizationList[index].location   // This is the main "visualization rendering" pane.
                        }
                    }
                }
            }
            .drawingGroup()                     // improves graphics performance by utilizing off-screen buffers
            .colorScheme(settings.selectedColorScheme)  // sets the visusalization pane's color scheme to either .dark or .light
            .background( (settings.selectedColorScheme == .light) ? Color.white : Color.darkGray )



            // The toolbar at the pane bottom contains buttons and sliders for user interaction:
            // font sizes: largeTitle, title, title2, title3, headline, subheadline, body, callout, caption, caption2, footnote.
            HStack {
            
                VStack {
                    Text(" \( (settings.selectedColorScheme == .dark) ? "Light" : "Dark" ) ")
                        .platformFont()
                        .padding(.bottom, 5)
                        .padding(.leading, 5)

                    Button (action: self.toggleColorScheme) // This function is at the bottom of this ContentView struct.
                    {   Image(systemName: (settings.selectedColorScheme == .dark) ? "heart.text.square" : "heart.text.square.fill" )
                            .font(.system(size: 15) )
                            .padding(.bottom, 10)
                            .padding(.leading, 5)
                    }
                    .keyboardShortcut(KeyEquivalent.upArrow, modifiers: [])
                }
        
        
                VStack {
                    Text(" \( micEnabled ? "Turn Mic Off" : "Turn Mic On" ) ")
                        .platformFont()
                        .padding(.bottom, 5)
                        .padding(.leading, 5)
        
                    Button (action: {
                        // It is crucial that micEnabled and filePlayEnabled are opposite - never both true or both false.
                        micEnabled.toggle()         // This is the only place in the MuVis app that micEnabled is changed.
                        filePlayEnabled.toggle()    // This is the only place in the MuVis app that filePlayEnabled is changed.
                        audioManager.setupAudio()
                    })
                    {   Image(systemName: micEnabled  ? "mic" : "mic.slash" )
                            .foregroundColor(.black)
                            .background( micEnabled ? Color.red : Color.green )
                            .padding(.bottom, 10)
                            .padding(.leading, 5)
                    }
                }
        
        
        
                VStack {
                    Text("Select Song")
                        .platformFont()
                        .disabled(micEnabled)
                        .padding(.bottom, 5)
                    Button (action: {
                        settings.previousAudioURL.stopAccessingSecurityScopedResource()
                        if(filePlayEnabled) {enableSongFileSelection = true}
                    })  {
                    Image(systemName: "music.quarternote.3")
                        .padding(.bottom, 10)
                    }
                    .disabled(micEnabled)   // gray-out "Select Song" button if mic is enabled
                    .keyboardShortcut(KeyEquivalent.downArrow, modifiers: []) // downArrow key toggles "Select Song" button
                    .fileImporter(
                        isPresented: $enableSongFileSelection,
                        allowedContentTypes: [.audio],
                        allowsMultipleSelection: false
                        ) { result in
                        if case .success = result {
                            do {
                                let audioURL: URL = try result.get().first!
                                settings.previousAudioURL = audioURL
                                if audioURL.startAccessingSecurityScopedResource() {
                                    let path: String = audioURL.path
                                    // path = /Users/JohnDoe/Music/Santana/Stormy.m4a
                                    audioManager.selectedSongURL = URL(fileURLWithPath: path)
                                    // URL = file:///Users/JohnDoe/Music/Santana/Stormy.m4a
                                    if(filePlayEnabled) {audioManager.setupAudio()}
                                }
                            } catch {
                                let nsError = error as NSError
                                fatalError("File Import Error \(nsError), \(nsError.userInfo)")
                            }
                        } else {
                                print("File Import Failed")
                        }
                    }
                }

                Spacer()
                
                // This slider allows the user to multiply the developer-selected gain value by between 0 and 2.
                VStack {
                    Text("Visualization Gain")
                        .platformFont()
                    Slider(value: $settings.userGain, in: 0.0 ... 2.0)
                        .font(.footnote)
                        .background(Capsule().stroke(Color.red, lineWidth: 2))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 5)
                        .onChange(of: settings.userGain, perform: {value in
                            settings.userGain = CGFloat(value)
                        })
                }

                Spacer()
                
                // This slider allows the user to specify a slope value between 0 and 0.05
                VStack {
                    Text("Treble Boost")
                        .platformFont()
                    Slider(value: $settings.userSlope, in: 0.0 ... 0.01)
                        .font(.footnote)
                        .background(Capsule().stroke(Color.red, lineWidth: 2))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 5)
                        .onChange(of: settings.userSlope, perform: {value in
                            settings.userSlope = CGFloat(value)
                        })
                }
                
                Spacer()
                
                VStack {
                    Text("Prev Vis")
                        .platformFont()
                        .padding(.bottom, 5)
                    Button (action: {
                        visNum -= 1
                        if(visNum <= -1) {visNum = visualizationList.count - 1}
                    })  {
                        Image(systemName: "chevron.left")
                        .font(.body)
                        .padding(.top, 5)
                        .foregroundColor(.red)
                    }.keyboardShortcut(KeyEquivalent.leftArrow, modifiers: [])
                }

                VStack {
                    Text("Next Vis")
                        .platformFont()
                        .padding(.bottom, 5)
                        .padding(.trailing, 5)
                    Button (action: {
                        visNum += 1
                        if(visNum >= visualizationList.count) {visNum = 0}
                    })  {
                        Image(systemName: "chevron.right")
                        .font(.body)
                        .padding(.top, 5)
                        .padding(.trailing, 5)
                        .foregroundColor(.red)
                    }.keyboardShortcut(KeyEquivalent.rightArrow, modifiers: [])
                }

            }  // end of HStack
       }  // end of VStack
    }  // end of var body: some View
    


    // https://stackoverflow.com/questions/61912363/swiftui-how-to-implement-dark-mode-toggle-and-refresh-all-views
    func toggleColorScheme() {
        settings.selectedColorScheme = (settings.selectedColorScheme == .dark) ? .light : .dark
    }
    
}  // end of ContentView struct



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(AudioManager.audioManager).environmentObject(Settings.settings)
    }
}
