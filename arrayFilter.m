function DataOut = arrayFilter(DataIn,fLength,sigma,filterType,useAbs)
% Apply either gaussian or box filter. 
% Usage: DataOut = arrayFilter(DataIn,fLength,sigma,filterType)
% Input:    DataIn = 2D matrix on which the filter should be applied
%           fLength = filter length.
%           sigma = sigma of the gaussian kernel. Standard is 1.76 for a single standard deviation.
%           filterType: type of filter. 1 for gaussian, 2 for box filter
% Output:   DataOut = filtered version of DataIn.
%
% S Musall, Aachen, 2021

if ~exist('filterType', 'var') || isempty(filterType)
    filterType = 1; %use box filter by default
end

if ~exist('useAbs', 'var') || isempty(useAbs)
    useAbs = false;
end

if fLength > 1
    if filterType == 1
        Kernel = ones(fLength,fLength); % Create box filter based on flength
        Kernel = Kernel ./ fLength^2;
    elseif filterType == 2
        [x,y]=meshgrid(-fLength:fLength,-fLength:fLength); % create gaussian filter based on flength and sigma
        Kernel= exp(-(x.^2+y.^2)/(2*sigma*sigma))/(2*pi*sigma*sigma);
    end
    
    if useAbs
        DataOut = conv2(abs(double(DataIn)), Kernel, 'same');
    else
        DataOut = conv2(double(DataIn), Kernel, 'same');
    end
else
    if useAbs
        DataOut = abs(DataIn); %don't apply filter if fLength is equal or lower then 1
    else
        DataOut = DataIn; %don't apply filter if fLength is equal or lower then 1
    end
end