///  SpectralEnhancer.swift
///  MuVis
///
///  SpectralEnhancer is a normalization method used to enhance the display of spectral lines (usually the harmonics
///  of musical notes) and to reduce the display of noise (usually percussive effects which smear spectral energy
///  over a large range.)  The technique used here is to (1) slide a moving window across the spectrum seeking local peaks
///  above some threshold; (2) replace those peaks with the local mean value; (3) compute a moving average
///  of the resultant reduced-peaks spectrum, and (4) subtract this moving average from the initial spectrum.
///
///  This technique is called "Two-Pass Split-Window (TPSW) Filtering" and is described in the paper "Evaluation of
///  Threshold-Based Algorithms for Detection of Spectral Peaks in Audio" by Leonardo Nunes, Paulo Esquef, and Luiz Biscainho.
///  This paper can be downloaded from: https://www.lncc.br/%7Epesquef/publications/nat_conferences/nunes_aesbr2007.pdf
///
///  The SpectralEnhancer class contains the private method localSum() which creates an output array where each element
///  is the sum of inputArray[k-M] to inputArray[k+M].  It also contains a public method enhance() which uses the
///  localSum() method to perform the TPSW filtering on the desired input array.
///
///  The SpectralEnhancer class contains a public method pickPeaks().  It produces an outputArray[] that contains "true"
///  values only at bins that are larger in value than the three bins on either side.
///
///  author: Keith Bromley (adapted from a previous C++ version written by Bob Dukelow and translated into java by Elliot Ickovich)

import Foundation


class SpectralEnhancer {

    let filterHalfWidth : Int  // filter half-width: number of bins to include in average each side of center
    let gapHalfWidth : Int  // gap half-width; number of bins to skip on either side of center (i.e., skip 2*gapHalfWidth+1 bins)
                                
    // Note that without the gap there are 2*filterHalfWidth+1 bins averaged to get the mean at each point (except near the edges).
    // When the gap is used, there are (2*filterHalfWidth+1) - (2*gapHalfWidth+1) bins in each average.

    var noPeaksArray: [Float] = [Float] (repeating: 0.0, count: binCount)      // intermediate array
    var sum         : [Float] = [Float] (repeating: 0.0, count: binCount)      // local sum vector
    var sumGap      : [Float] = [Float] (repeating: 0.0, count: binCount)      // local sum vector
    var sumCount    : [Int]   = [Int]   (repeating: 0, count: binCount)      // count of values included in each local sum
    var sumGapCount : [Int]   = [Int]   (repeating: 0, count: binCount)      // count of values included in each local sum
    let noiseThreshold : Float // determines which peaks are replaced by the mean during the first pass

    init() {
        filterHalfWidth = 32    // so the total filter width is 65 bins
        gapHalfWidth = 2        // so the total gap width is 5 bins;  (A Hamming FFT window will smear the main peak over about 5 FFT bins.)
        noiseThreshold = 2.0    // determines which peaks are replaced by the mean during the first pass
    }

    internal func localSum( inputArray: [Float], M: Int) -> (sumArray:[Float], countArray:[Int]) {
    
        /*
        inputArray is the input array
        M is the  number of bins to include in sum each side of center
        
        For input array inputArray[] create an output array sumArray[] where each element of the sumArray[k] is the sum
        of inputArray[k-M] to inputArray[k+M].  To perform this computation correctly, we need to account for the "edge
        effects".  That is, the number of elements in the sum is reduced near the edges  (i.e., the out-of-range points
        are treated as zeros).   We will assume that 2*M+1 is smaller than the binCount.
        
        We are essentially convolving the input array with a window whose 2*M+1 elements are all ones.  This window is
        called the "convolution kernel".  The computation involves three cases: (1) the convolution kernel overlaps the
        beginning of the input array, (2) the kernel is completely within the input array, and (3) the kernel overlaps
        the end of the input array.
        */
        
        var first: Int
        var last : Int
        var sumArray    : [Float] = [Float] (repeating: 0.0, count: inputArray.count)   // sumArray is the output sum array
        var countArray  : [Int]   = [Int]   (repeating: 0,   count: inputArray.count)   // countArray is the output array indicating number of input elements summed to form each element of the sumArray
        
        // First do sumArray[0] to get things started
        // sumArray[0] is the sum of the M+1 elements inputArray[0] to inputArray[M]
        sumArray[0] = 0.0
        last = M
        
        for j in 0 ... last {
            sumArray[0] += inputArray[j];
        }
        countArray[0] = last + 1;
        
        // Then just keep adding on to the sum for the next M sumArray elements
        // sumArray[i] is the sum of elements inputArray[i]
        for i in 1 ... last {
            sumArray[i] = sumArray[i - 1] + inputArray[i + M];
            countArray[i] = countArray[i - 1] + 1;
        }

        // Keep subtracting old and adding new values until window reaches other end.
        first = M + 1;
        last = inputArray.count - M - 1;

        for i in first ... last {
            sumArray[i] = sumArray[i - 1] - inputArray[i - 1 - M] + inputArray[i + M];
            countArray[i] = countArray[i - 1];
        }

        // then just subtract old values on the left till the end
        first = inputArray.count - M;
        for i in first ..< inputArray.count {
            sumArray[i] = sumArray[i - 1] - inputArray[i - 1 - M];
            countArray[i] = countArray[i - 1] - 1;
        }
        return (sumArray, countArray)
        
    }  // end of localSum() func



/// The enhance() method performs two-pass split-window filtering on the inputArray[].  The steps include:
///     (1) Calculate a local first-pass mean for each bin using a 65-bin window with a 5-bin gap.
///     (2) Compare each bin value against its respective local first-pass mean. Values above a threshold are replaced by the local first-pass mean.
///     (3) Calculate a local second-pass noise mean estimate for each bin of this smoothed data again using a 65-bin window but this time with no gap.
///     (4) Subtract this noise mean estimate from each original bin value to reduce the noise.

/// @param inputArray
/// @param meanArray
/// @param outputArray
/// @author Keith Bromley (adapted from a previous version written in C++ by Bob Dukelow and translated into java by Elliot Ickovich)
    
    public func findMean(inputArray: [Float]) ->  ([Float]) {
        // In the first pass the input array is filtered through a split window.
        // We do this in three steps: first sum over the total window, then sum over the gap,
        // and then subtract the gap sum from the total-window sum.

        // local sum with no gap:
        // sliding window (width = 2*filterHalfWidth+1) summation of the inputArray
        sum = localSum(inputArray: inputArray, M: filterHalfWidth).sumArray
        sumCount = localSum(inputArray: inputArray, M: filterHalfWidth).countArray
        
        // local sum of the gap:
        // sliding window (width = 2*gapHalfWidth+1) summation of the inputArray
        sumGap = localSum(inputArray: inputArray, M: gapHalfWidth).sumArray
        sumGapCount = localSum(inputArray: inputArray, M: gapHalfWidth).countArray
        
        var mean : Float = 0.0
        
        // Compute the noPeaksArray[] by replacing peaks of the inputArray[] with the local mean.
        for i in 0 ..< inputArray.count {
            mean = (sum[i] - sumGap[i]) / Float(sumCount[i] - sumGapCount[i])
            if (inputArray[i] > noiseThreshold * mean) {
                noPeaksArray[i] = mean
            } else {
                noPeaksArray[i] = inputArray[i]
            }
        }
        // The noPeaksArray[] is the same as the inputArray[] but is free of prominent peaks.

        // In the second pass, we perform further smoothing on this noPeaksArray[] by applying a conventional
        // moving summation filter to determine sum[] an array of local sums.
        sum = localSum(inputArray: noPeaksArray, M: filterHalfWidth).sumArray
        sumCount = localSum(inputArray: noPeaksArray, M: filterHalfWidth).countArray

        var meanArray: [Float] = [Float] (repeating: 0.0, count: inputArray.count)

        // Now subtract this local mean from the original inputArray
        for i in 0 ..< inputArray.count {
            mean = sum[i] / Float(sumCount[i])
            meanArray[i] = mean
        }
        return (meanArray)
        // We have now reduced the noise floor and hopefully improved the visibility of the harmonic peaks above it.

    }  // end of the findMean() func
    
    

    /*
     Here is a second version of the enhance() method that does not output the meanArray.
     This is useful where the visualization does not need the meanArray.
     */
    public func enhance(inputArray: [Float]) -> ([Float]) {
        // In the first pass the input array is filtered through a split window.
        // We do this in three steps: first sum over the total window, then sum over the gap,
        // and then subtract the gap sum from the total-window sum.

        // local sum with no gap:
        // sliding window (width = 2*filterHalfWidth+1) summation of the inputArray
        sum = localSum(inputArray: inputArray, M: filterHalfWidth).sumArray
        sumCount = localSum(inputArray: inputArray, M: filterHalfWidth).countArray

        // local sum of the gap:
        // sliding window (width = 2*gapHalfWidth+1) summation of the inputArray
        sumGap = localSum(inputArray: inputArray, M: gapHalfWidth).sumArray
        sumGapCount = localSum(inputArray: inputArray, M: gapHalfWidth).countArray

        var mean : Float = 0.0
        
        // Compute the noPeaksArray[] by replacing peaks of the inputArray[] with the local mean.
        for i in 0 ..< inputArray.count {
            mean = (sum[i] - sumGap[i]) / Float(sumCount[i] - sumGapCount[i])
            if (inputArray[i] > noiseThreshold * mean) {
                noPeaksArray[i] = mean
            } else {
                noPeaksArray[i] = inputArray[i]
            }
        }
        // The noPeaksArray[] is the same as the inputArray[] but is free of prominent peaks.

        // In the second pass, we perform further smoothing on this noPeaksArray[] by applying a conventional
        // moving summation filter to determine sum[] an array of local sums.
        sum = localSum(inputArray: noPeaksArray, M: filterHalfWidth).sumArray
        sumCount = localSum(inputArray: noPeaksArray, M: filterHalfWidth).countArray

        var outputArray  : [Float] = [Float] (repeating: 0.0, count: inputArray.count)
        
        // Now subtract this local mean from the original inputArray
        for i in 0 ..< inputArray.count {
            mean = sum[i] / Float(sumCount[i])
            outputArray[i] = inputArray[i] - mean
            if (outputArray[i] < 0.0) { outputArray[i] = 0.0 }
        }
        return (outputArray)
        // We have now reduced the noise floor and hopefully improved the visibility of the harmonic peaks above it.

    }  // end of the enhance() func



    /*
    The outputArray[] computed by the pickPeaks() method contains "true" values only at bins that are larger in value
    than the three bins on either side.
    */
    public func pickPeaks(inputArray: [Float], peakThreshold: Float) -> ([Bool]) {

        var outputArray: [Bool] = [Bool] (repeating: false, count: inputArray.count)  // Initialize the outputArray to all false.

        for bin in 3 ..< inputArray.count - 3 {
            let tempFloat: Float = inputArray[bin];
            if ((tempFloat > peakThreshold) &&
                    (tempFloat > inputArray[bin - 3]) &&
                    (tempFloat > inputArray[bin - 2]) &&
                    (tempFloat > inputArray[bin - 1]) &&
                    (tempFloat > inputArray[bin + 1]) &&
                    (tempFloat > inputArray[bin + 2]) &&
                    (tempFloat > inputArray[bin + 3])) {
                outputArray[bin] = true;
            } else {
                outputArray[bin] = false;
            }
        }
        return (outputArray)

    }  // end of the pickPeaks() method

}  // end of SpectralEnhancer class
