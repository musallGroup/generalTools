function y = gamma_distribution(x, peak, width)

% Define shape and scale parameters of gamma distribution
k = (peak/width)^2;
theta = width^2/peak;

% Compute probability density function of gamma distribution
y = (x.^(k-1) .* exp(-x/theta)) ./ (theta^k * gamma(k));

end
