function dataOut = simpleNotch(dataIn, sRate, f0, BW)
% function to apply a notch filter. sRate is the sampling frequency in Hz.
% f0 is the central frequency to be removed and BW is the filter width.

% Design the notch filter
[b,a] = iirnotch(f0/(sRate/2), BW/(sRate/2), 2);

% Apply the notch filter to your signal
dataOut = filtfilt(double(b), double(a), double(dataIn));
