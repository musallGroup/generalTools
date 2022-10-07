function [h, Z, p] = test_binomial_difference(p1, p2, n1, n2, alpha, side)
    % side: 'two' for both tails otherwise one sided.
    
    if ~exist('alpha', 'var'); alpha = 0.05; end
    if ~exist('side', 'var'); side = 'two'; end
    
    if isnan(p1) || isnan(p2) || (n1 < 1) || (n2 < 1)
        h = nan; Z = nan; p = nan;
        return
    end
    
    p_hat = (n1*p1 + n2*p2) / (n1+n2);
    Z = (p1-p2) / sqrt(p_hat * (1 - p_hat) * ((1 / n1) + (1 / n2)));

    if strcmp(side, 'two')
        % the (1-normcdf(Z)) if cause matlab apparently returns the percentile
        % instead of the p-value
        p = (1 - normcdf(abs(Z))) ./ 2;  % two-sided
    elseif strcmp(side, 'left')
        p = normcdf(abs(Z));  % one-sided
    elseif strcmp(side, 'right')
        p = 1 - normcdf(abs(Z));  % one-sided
    else
        error('Unclear tail!');
    end
    h = p < alpha;
end
