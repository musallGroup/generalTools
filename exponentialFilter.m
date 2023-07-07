function kernel = exponentialFilter(decay_time, kernel_length)
% Generate a 1D exponential filter kernel with specified decay time.
% Decay time indicates after how many samples 1/e (37%) of the intial value
% is reached

% Compute the decay factor from the decay time
alpha = exp(-1 / decay_time);

% Compute the length of the kernel
if ~exist('kernel_length','var') || isempty(kernel_length)
    kernel_length = ceil(decay_time * 5);
end

% Generate the kernel values
kernel = zeros(1, kernel_length);
for t = 1:kernel_length
    kernel(t) = alpha^(t-1);
end

% Normalize the kernel to have unit energy
kernel = kernel / sum(kernel);

% Adjust the kernel length if necessary to ensure that it sums to 1
kernel_sum = sum(kernel);
if abs(kernel_sum - 1) > eps
    diff = 1 - kernel_sum;
    kernel(end) = kernel(end) + diff;
end