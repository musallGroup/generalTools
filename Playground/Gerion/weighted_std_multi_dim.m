function [weighted_std_result, weighted_mean] = weighted_std_multi_dim(data, weights, dim)
% Here I have to assume that both have the same number of dimensions. 
% Weight have to be positive for correct behavior otherwise update how
% n_samples is computed!
if ~exist("dim", "var")
    dim = 1;
end

weighted_mean = nansum(data .* weights, dim) ./ nansum(weights, dim);
n_samples = nansum((weights > 0) & (~isnan(weights)), dim);  % total number of samples
weights_for_division = weights; weights_for_division(isnan(weights_for_division) | (weights_for_division == 0));

weighted_std_result = sqrt(...
    nansum(weights .* power(weighted_mean - data, 2), dim) ...
    ./ (((n_samples-1) ./ n_samples) .* nansum(weights_for_division, dim)));




