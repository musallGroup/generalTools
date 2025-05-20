function [h, p] = binomCompare(hits1, n1, hits2, n2)
% compare if two binomial distributions are significantly different from each other.
% Taken from here: https://stats.stackexchange.com/questions/113602/test-if-two-binomial-distributions-are-statistically-different-from-each-other

% Proportions
p1 = hits1 / n1;
p2 = hits2 / n2;

% Pooled proportion
p_pool = (hits1 + hits2) / (n1 + n2);

% Standard error
SE = sqrt(p_pool * (1 - p_pool) * (1/n1 + 1/n2));

% z-statistic
z = (p1 - p2) / SE;

% two-tailed p-value
p = erfc(abs(z) / sqrt(2));
h = p < 0.05;