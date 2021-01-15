function corrMat = arrayCorr(A,B)
%short code to compute the correlation coefficent between to matrices. Rows
%are observations and corrmat is a vector with the correlation coefficient
%between each row in A and B.

cCovV = bsxfun(@minus, A, mean(A,2)) * B' / (size(B, 2) - 1); %get covariance
corrMat = diag(cCovV) ./ (std(A,[],2) .* std(B,[],2)); %divide by standard deviation

end