function [ciLowerBound, ciUpperBound] = getConfidenceIntervals(data)
% function to compute 95% confidence intervals via bootstrapping

% Number of bootstrap samples
nBootstraps = 1000;
bootstrapMedians = zeros(nBootstraps, 1); % Preallocate array for medians

% Bootstrapping process
for i = 1:nBootstraps
    % Resample with replacement
    bootstrapSample = datasample(data, length(data), 'Replace', true);
    
    % Calculate median for this bootstrap sample
    bootstrapMedians(i) = median(bootstrapSample);
end

% Step to calculate confidence interval using percentiles
confidenceLevel = 0.95; % Confidence level (95%)
lowerPercentile = (1 - confidenceLevel) / 2 * 100; % Lower percentile
upperPercentile = (1 + confidenceLevel) / 2 * 100; % Upper percentile

% Compute lower and upper bounds of CI from bootstrap medians
ciLowerBound = prctile(bootstrapMedians, lowerPercentile);
ciUpperBound = prctile(bootstrapMedians, upperPercentile);

% % Display results
% fprintf('Bootstrap Median: %.2f\n', median(bootstrapMedians));
% fprintf('Confidence Interval (%.0f%%): [%.2f, %.2f]\n', ...
%         confidenceLevel*100, ciLowerBound, ciUpperBound);