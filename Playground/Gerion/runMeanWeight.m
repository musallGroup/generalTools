function [currAvg, new_k] = runMeanWeight(currAvg, newData, k, new_k)
% function for running average, but allowing to assign weight to the samples
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

% Match the shape of currAvg
if k > 0 && ~isempty(currAvg)
    newData = reshape(newData, size(currAvg));
end

if isempty(k) && isempty(currAvg)
    % for the first value, simplifies use by passing empty array: []
    k = zeros(size(new_k));
    currAvg = zeros(size(newData));
end

% make sure k and new_k are integers and then double() for divisions, 
% not sure if Matlab cased about that
k = double(round(k));
new_k = double(round(new_k));

if k < 0
    error('k must be >= 0 !')
end

if new_k < 0
    error(sprintf('new_k must be >= 0. \nIn case of no/invalid sample, simply pass k==0 \nAlternative: you can also pass newData as all NaNs. \nIn both cases the newData will be ignored!'))
end

if k == 0
    currAvg = newData; %new average
elseif new_k > 0
    % In case I have new entries with NaNs I want to ignore them and only
    % update valid values
    cIdx = ~isnan(currAvg(:)) & ~isnan(newData(:));  % only non-NaN entries
    
    % compute the weight average
    currAvg(cIdx) = (currAvg(cIdx) .* k + newData(cIdx) .* new_k) ./ (k + new_k);  % running average
    
    % In case I have new data, where I previously only had NaNs overwrite
    % these with the new data
    cIdx = isnan(currAvg(:)) & ~isnan(newData(:));  % new data is non-NaN
    currAvg(cIdx) = newData(cIdx);  % add new data to average
end


%% Update the counter of how many samples went into the new average to be 
%  carried over to the next iteration/sample on the outside.
new_k = new_k + k;

end



