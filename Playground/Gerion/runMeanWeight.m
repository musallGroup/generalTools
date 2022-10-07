function [currAvg, new_k] = runMeanWeight(currAvg, newData, k, new_k)
% function for running average, but allowing to asign weight to the samples
% Ignores NaN entries (similar to 'nanmean')
% 
% e.g.: when combining sessions-wise averages, I want to weight the
% newData, by how many trials went into this average compared to the 
% samples the went into currAvg.
% The equivalent would be to accumulate all the raw trials over
% sessions and then make a single nanmean() over those in the end.
% 
% currAvg:      current running average
% newData:      new data that should be added
% k (int):      number of samples (e.g. trials) in current average
% new_k (int):  number of samples (e.g. trials) in new data

if isempty(k) && isempty(currAvg)
    % for the first value, simplifies use by passing empty array: []
    k = zeros(size(new_k));
    currAvg = zeros(size(newData));
end

k = round(k);          % make sure k is an integer
new_k = round(new_k);  % make sure new_k is an integer

if k < 0
    error('k must be >= 0 !')
end

if new_k < 0
    error(sprintf('new_k must be >= 0. \nIn case of no/invalid sample, simply pass k==0 \nAlternative: you can also pass newData as all NaNs. \nIn both cases the newData will be ignored!'))
end

if k == 0
    currAvg = newData; %new average
elseif new_k > 0
    ratio = double(new_k) ./ double(k);  % not sure if matlab cares about this

    cIdx = ~isnan(currAvg(:)) & ~isnan(newData(:)); %only non-NaN entries
%     currAvg(cIdx) = currAvg(cIdx) .* (1. - ratio) + newData(cIdx) .* ratio; %running average
    currAvg(cIdx) = currAvg(cIdx) + (newData(cIdx) - currAvg(cIdx)) .* ratio; %running average
    
    cIdx = isnan(currAvg(:)) & ~isnan(newData(:)); %new data is non-NaN
    currAvg(cIdx) = newData(cIdx); %add new data to average
end

%% This is new: check if that causes issues. 
% Before I updated the trial counters outside of this function, but I hope
% that the previous functionality is identical and this only takes effect
% if you try to use the second output.
new_k = new_k + k;

end



