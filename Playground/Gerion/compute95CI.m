function CI = compute95CI(x, dim)
% try to infere across which dimension to compute the CI
if ~exist("dim", "var")
    tempShape = size(x);
    if length(tempShape) > 2
        error("Unclear Dimension!")
    end
    
    if (tempShape(1) > 1) && (tempShape(2) == 1)  % tempShape(1) > tempShape(2)
        dim = 1;
    elseif (tempShape(1) == 1) && (tempShape(2) > 1)  % tempShape(1) < tempShape(2)
        dim = 2;
    else
        error("Unclear Dimension!")
    end
end

SEM = nanstd(x, [], dim) ./ sqrt(size(x, dim));  % Standard Error
ts = tinv([0.025  0.975], size(x, dim) - 1);  % T-Score
% CI = mean(x) + ts*SEM;
CI = ts(2) .* SEM;
end
