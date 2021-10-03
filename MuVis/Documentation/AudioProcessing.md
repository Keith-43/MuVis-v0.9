
#  MuVis - an Audio Visualizer app for Music
#  MuVis Audio Processing Guide
by Keith Bromley, San Diego, CA, USA &nbsp; &nbsp; kbromley@me.com

###  **Brief History of MuVis**

I have been experimenting with music visualization as a hobby on-and-off for over twenty years.  Since 2014, I have developed visualizations using java for the Polaris audio player project ( [www.logicbind.io/polaris](www.logicbind.io/polaris) ) led by Besmir Beqiri.

I have been developing the MuVis app since early 2020.  It was my first learning experience with Xcode, Swift, and SwiftUI.  A central part of the app is the capture and processing of "live" audio data using Apple's AVAudioEngine API.  This Audio Processing Guide delves into some of the issues faced and choices made during this development.

### **MuVis Audio Processing**

A standard sampling rate for audio signals is 44,100 samples per second.  With this sampling rate, the highest frequency that the signal can contain is 22,050 Hz.  We will use the Fast Fourier Transform (FFT) to convert the audio samples into audio frequencies.  That is, the FFT converts an array

	sampleValues[sampleNum] of length sampleCount
    
into an array

	binValues[binNum] of length binCount.

For the FFT, we observe that

	sampleCount = 2 * binCount
    
and the spacing between frequency bins is

	binFreqWidth = 22,050 / binCount.

Let us estimate what value for binCount we will need:  (1) Divide the total frequency range (0 Hz to 22,050 Hz) into octaves.  (2) In the lowest octave of interest, we would like to have at least 12 bins in order to differentiate the frequencies of the 12 musical notes in that octave.  (3)  Double the number 12 for each of the higher octaves.  (4) Sum the binsPerOctave over all octaves to get the total binCount we desire. (5) Since binCount must be a two-to-the-power-of-N type of number, choose binCount = 8,192 as the total actual value we should use.

                                        Desired		Actual
	Octave		Range				binsPerOctave binsPerOctave

	Top-8		43 Hz		to 86 Hz		12		16
	Top-7		86 Hz		to 172 Hz		24		32
	Top-6		172 Hz		to 344 Hz		48		64
	Top-5		344 Hz		to 689 Hz		96		128
	Top-4		689 Hz		to 1,378 Hz		192		256
	Top-3		1,378 Hz	to 2,756 Hz		384		512
	Top-2		2,756 Hz	to 5,512 Hz		768		1,024
	Top-1		5,512 Hz	to 11,025 Hz	        1,536	        2,048
	Top		11,025 Hz	to 22,050 Hz		3,072		4,096
                                		Total:		6,132		8,192 = binCount <- This implies using FFTs of length 16,384.

Let us stop here and make an important observation (and an important simplification):  In my years of developing music visualization techniques, I have observed that very little of interest occurs above the frequency 5,512 Hz.  There is very little energy above that frequency and whatever there is hardly shows up on a visualization.  We can truncate the frequency range to 0 Hz through 5,512 Hz and still see musically-meaningful and aesthetically-pleasing visualizations.  (Note that these comments do not apply to listening to the music - only to visualizing the music.)

This frequency truncation implies ignoring the binValues for three-quarters of the bins in the above chart.  So, let's not compute them in the first place.  Let's down-sample the original audio signal from 44,100 to 11,025 samples per second, and re-do the above discussion.

											Actual
	Octave		Range					binsPerOctave

	Top-6		43 Hz		to 86 Hz		16
	Top-5		86 Hz		to 172 Hz		32
	Top-4		172 Hz		to 344 Hz		64
	Top-3		344 Hz		to 689 Hz		128
	Top-2		689 Hz		to 1,378 Hz		256
	Top-1		1,378 Hz	to 2,756 Hz		512
	Top		    2,756 Hz	to 5,512 Hz		1,024
                                    			Total:	2,048 = binCount    <- This implies using FFTs of length 4,096.

This simplification greatly reduces the computation load and the array sizes.  We will use:

    sampleRate = 11,025	  sampleCount = 4,096    binCount = 2,048    binFreqWidth = (11,025/2)/2,048 = 2.69 Hz

### **Using the AVAudioEngine API**

The AVAudioEngine API allows the developer to set up a sequence of "nodes" to process the audio signal.  If the variable micEnabled is true then the sequence of nodes processes audio data from the microphone.  The sequence comprises the following node architecture:


	microphone -------> micMixer ------> mixer -------> mixer2 -------> main -------> (to speakers)
						node             node      |    node            mixer
                                     			   |                    node
                                     			   v
                                 				sampling tap
  
The micMixer node amplifies the audio signal from the device's microphone input.
The mixer node is used to convert the input audio stream to monophonic and to lower the sampling rate to 11025 sps.  The mixer2 node sets the volume to zero (after the sampling tap) to prevent the speaker output from feeding back into the microphone input.
The mainMixerNode is implemented automatically by the AVAudioEngine and links to the audio output (speakers).

If the variable filePlayEnabled is true then the sequence of nodes processes audio data from song files selected from the device's file structure.  The sequence comprises the following node architecture:

	(file) -------> player --------> mixer --------> delay -------> main  -------> (to speakers)
             		node             node      |     node           mixer
                                   			   |                    node
                                			   v
                             				sampling tap

The player node plays the audio stream from the desired music file.
The mixer node is used to convert the input audio stream to monophonic and to lower the sampling rate to 11025 sps.
The delay node is used to introduce a delay into the audio stream (after our sampling tap) to synchronize the audio output with the on-screen rendered visualizations.  It compensates for the latency of the sampling process and graphics rendering.  The mainMixerNode is implemented automatically by the AVAudioEngine and links to the audio output (speakers).

Now, here comes the bad news: Using an audio sampleRate of 11,025 samples-per-second, the finest-granularity that AVAudioEngine can deliver is 1,102 samples every 0.1 seconds.   (This is an average value.  The actual period varies as the device's operating-system scheduler interleaves tasks to the CPUs.)  This produces a display frame rate of only 10 frames per second which is painfully slow.

These 1,102 audio samples are appended to the previous samples already stored in the "rawAudioData" circular buffer - overwriting the oldest 1,102 samples.  After each block of 1,102 samples are appended,  we copy the most-recent 4,096 samples into the sampleValues[] array.  We then append the subsequent block of 1,102 samples and copy the most-recent 4,096 samples again.  This process continues as each new block of 1,102 "live" audio samples is appended to the contents of the rawAudioData buffer.  Using the above numbers, the sampleValues[] array is updated every 0.1 seconds (on average) and each window of 4,096 sampleValues has a (4096 - 1102) / 4096 = 73% overlap with the previous window.

Now let's look at the sequence of operations designed to provide frequency data.  The 4096-element sampleValues[] array is then multiplied by a 4096-element Hann window and processed by an FFT operation - producing a new 2048-element binValues[] array every 0.1 seconds.  At this point, let me rename the binValues[] array to the spectrum[] array.

This spectrum[] array is published as an ObservableObject in our Swift code and is passed along to our various visualizations for rendering.  The rendering frame rate will be 10 frames per second (on average).

### **MuVis Music Processing**

The main purpose of the MuVis app is to visualize music.  Hence we need to interpolate the linear-frequency spectrum provided by the FFT into musical note values - an exponential relationship.  Here's the algorithm and pseudo-code that I use:
    
As we discussed above, the FFT provides us with a spectrum of rms amplitudes over a range of frequency indices.  In my notation, I have an array spectrum[binNum] where binNum is the integer sequence 0, 1, 2, 3, ..< binCount.  That is: the array spectrum[] is linear with a constant frequency interval.  Think of this as plotted in a 2D graph with the values of spectrum[binNum] depicted on the vertical axis and the binNum indices as the horizontal axis.  In reality, the horizontal axis is actually a discrete sampling of a smooth continuum of frequencies where

        frequency = binNum * binWidth					Equation 1

and where

		fftLength = 4,096
		binCount = fftLength / 2 = 2,048
		binFreqWidth = (samplingRate/2) / binCount = (11,025/2) / 2,048 = 2.69165 Hz.

My spectrum[binNum] array of values specifies the y-values in our plot only at discrete indices along the x-axis.

So the problem of converting our linear-frequency values into exponential-frequency values boils down to finding the vertical-axis values using a different set of numbers along the horizontal frequency axis.  This "different set of numbers" is based upon a musical context.  For music applications, we recognize that the human ear detects frequencies on an exponential scale. In this application, I want to start counting notes at note = 0 corresponding to the musical note C1 (freqC1 is about 33 Hz) which is 45 semitones below the note A4 (freqA4 is exactly 440 Hz).

The two defining characteristics of musical notes are that (1) there are 12 semitones in an octave (a frequency doubling), and (2) the frequency of each semitone is a constant multiple of the frequency of the preceding one.  Hence, the frequency of each musical semitone is the twelfth-root-of-2 (denoted twelfthRoot2) times the frequency of the next-lower semitone.  Conversely, to get the frequency of a lower semitone, divide the frequency of the next-higher semitone by twelfthRoot2.  Since note C1 is 45 semitones below note A4, I must divide freqA4 by twelfthRoot2 forty-five times to get freqC1.

In Apple's Foundation framework, exponentiation is calculated using the pow(A,B) function where A is the starting value and B is the power to which it is raised. So

	freqC1 = 440.0 * pow(twelfthRoot2, -45.0)

To be more precise, I wish to start my new frequency axis at the frequency which is exactly half-way (exponentially) between note C1 and it's immediately preceding semitone. That is

	leftFreqC1 = freqC1 / TwentyFourthRoot2

We have an audio sampling rate of 11,025 samples per second which means that the highest frequency we can observe is 11,025 / 2 = 5,512.5 Hz.  This implies that the highest musical note that we can reliably observe is E8 (freqE8 is about 5,274 Hz).  If C1 is considered as note = 0 then E8 is note = 88.  Thus we cover a total of 89 notes (just over 7 octaves).

Also, I wish to get finer resolution than just one value per note, so I am going to subdivide each note into 8 points.  Again, this subdivision has to be done exponentially.  Each octave (doubling of frequency) is subdivided into 12 * 8 = 96 points.  Hence the frequency (horizontal axis coordinate) of each point is

	frequency = leftFreqC1 * pow(2.0, point / (12*8))		Equation 2

where point ranges from 0 to 89 * 8 - 1 (that is, from 0 to 711).

This defines the desired sampling of our horizontal frequency axis, so now we need to interpolate the given spectrum(frequency) values into our desired muSpectrum(frequency) values. (Note that I have coined the name muSpectrum for the spectrum sampled at musical frequencies.)

Apple's Accelerate framework contains the vDSP_vqint function for vector quadratic interpolation.  It is called using

	void vDSP_vqint (*A, *B, J, *C, K, N, M) where * denotes "pointer to"

with the parameters:

	A	real input vector 
	B	real input vector: integer parts are indices into A and fractional parts are interpolation constants 
	J	stride for B
	C	real output vector
	K	stride for C 
	N	count for C  
	M 	length of A

The only help that Apple's documentation gives us is: "[This function] generates vector C by interpolating between neighboring values of vector A as controlled by vector B. The integer portion of each element in B is the zero-based index of the first element of a pair of adjacent values in vector A. The value of the corresponding element of C is derived from these two values by quadratic interpolation, using the fractional part of the value in B." 

All that remains now is to massage our horizontal coordinates into the form desired by this vDSP_vqint function.  Our input array spectrum[binNum] and it's integer indices are already in the desired form - wherein the values corresponding to the integer part of the indices is known and correct - namely the spectrum[binNum].  It extends over the range from 0 to 5,512.5 Hz.

However, we need to slightly modify the output coordinates.  We need to adjust the desired resampling coordinates so that they extend over the same range. If we divide both sides of Equation 2 by binFreqWidth, we get

		frequency/binFreqWidth = ( leftFreqC1 * pow(2.0, point / 12*8) ) / binFreqWidth

then these coordinates also cover the range from 0 to 5,512.5 Hz.  So, the given integer parts of the horizontal coordinates are known as spectrum[bin] and the desired output coordinates (covering the same range) will generally fall in the intervals between these integers.

In the context of our problem, the parameters become:

	A	input array = spectrum[binNum]
	B	&outputIndices = ( leftFreqC1 * pow(2.0, point / 12*8) ) / binFreqWidth
	J	vDSP_Stride(1)
	C	&muSpectrum[point]
	K	vDSP_Stride(1)
	N  	vDSP_Length(89 * 8)  	// The muSpectrum array has length totalPointCount = 89 * 8 = 712.
	M	vDSP_Length(binCount)	// The input spectrum array has length binCount = 2,048.

Apple provides a helpful tutorial on linear interpolation at
    [developer.apple.com/documentation/accelerate/use_linear_interpolation_to_construct_new_data_points](https://developer.apple.com/documentation/accelerate/use_linear_interpolation_to_construct_new_data_points)

and discusses Vector-to-Vector Quadratic Interpolation Functions function at
    [developer.apple.com/documentation/accelerate/vdsp/quadratic_interpolation_functions](https://developer.apple.com/documentation/accelerate/vdsp/quadratic_interpolation_functions)

The AudioManager() class uses this function to calculate the muSpectrum[point] array and publishes an updated version of it to our visualizations every frame.

To summarize, every frame, our AudioManager() class publishes the two arrays:

	spectrum[] with 2,048 bin values, and
	muSpectrum[] with 712 point values.

