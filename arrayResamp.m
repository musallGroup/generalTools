function outX = arrayResamp(X, p , q)
% this uses the resample command to change the sampling rate. 
% Can deal with NaNs in the input matrix.

padSize = 10;
cIdx = find(isnan(X(:,1)))';
cIdx = [0 cIdx];
cIdx = [cIdx size(X,1)+1];

outX = NaN(size(X,1) * ceil(p/q), size(X,2), class(X));
Cnt = 0;
for x = 1 : length(cIdx)-1
    if ~isempty(cIdx(x)+1 : cIdx(x+1)-1)
        
        newX = double(X(cIdx(x)+1 : cIdx(x+1)-1, :));
        newX = [repmat(newX(1,:),padSize,1); newX; repmat(newX(end,:),padSize,1)]; %add some padding on both sides to avoid edge effects when resampling
        newX = resample(newX, p, q);
        a = resample(repmat(newX(1,1),padSize,1), p, q);
        newX = newX(length(a)+1:end-length(a),:); %remove pads.

        outX(Cnt+1 : Cnt + size(newX,1), :) = newX;
        Cnt = Cnt + size(newX,1)+1;
    else
        Cnt = Cnt + 1;
    end
end

outX = outX(1:Cnt, :);