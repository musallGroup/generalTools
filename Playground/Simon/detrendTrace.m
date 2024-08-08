function dataIn = detrendTrace(dataIn, fLength)
% function to remove slow trends from a data trace. dataIn is the data,
% fLength defines the length of a smoothing filter. Deault if 20% of the
% data length.

dataIn = dataIn(:); %make sure this is a column vector;

if ~exist('fLength', 'var') || isempty(fLength)
    fLength = round(size(dataIn,1) / 5);
end

dataMean = mean(dataIn,1); %keep the mean and put it back in later
dataIn = [repmat(dataMean, fLength, 1); dataIn; repmat(dataMean, fLength, 1)]; %use the mean to pad trace at the beginning and end to avoid filter artifact
dataSmooth = medfilt1(dataIn,fLength);
dataIn = dataIn - dataSmooth;
dataIn = dataIn(fLength+1 : end-fLength,:);

dataIn = dataIn - mean(dataIn,1); %make this zero mean
dataIn = dataIn + dataMean; %then add original mean back