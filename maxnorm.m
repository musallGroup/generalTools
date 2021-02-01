function a = maxnorm(a,dim)
%normalize content of A between 0 and 1. If dim is given, operation is done
%over this dimension instead of all values in input a.

if ~exist('dim','var')
    dim = []; %normalize all entries similarly
end

if length(unique(a)) > 1
    if isempty(dim)
        a = a - min(a(:));
        a = a ./ max(a(:));
    else
        a = a - min(a, [], dim);
        a = a ./ max(a, [], dim);
    end
end