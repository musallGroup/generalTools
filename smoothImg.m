function DataOut = smoothImg(DataIn,type,fLength,sigma)
% Apply either gaussian or box filter to a 2D image. 
% Usage: DataOut = smoothImg(DataIn,type,fLength,sigma)
% Input:    DataIn = 2D matrix on which the filter should be applied
%           type: type of filter. 1 for gaussian, 2 for box filter
%           fLength = filter length.
%           sigma = sigma of the gaussian kernel. Standard is 1.76 for a single standard deviation.
% Output:   DataOut = filtered version of DataIn.

if ~exist('type','var') || isempty(type) || strcmpi(type,'gaussian')
    type = 1; %use gaussian filter by default
elseif strcmpi(type,'box')
    type = 2; %use box
end

if ~exist('fLength','var') || isempty(fLength)
    fLength = 3;
end

if ~exist('sigma','var') || isempty(sigma)
    sigma = 1.76;
end

if fLength > 1
    if type == 1
        [x,y]=meshgrid(-fLength:fLength,-fLength:fLength); % create gaussian filter based on flength and sigma
        Kernel= exp(-(x.^2+y.^2)/(2*sigma*sigma))/(2*pi*sigma*sigma);
    elseif type == 2
        Kernel = ones(fLength,fLength); % Create box filter based on flength
        Kernel = Kernel ./ fLength^2;
    end
    DataOut = conv2(double(DataIn), Kernel, 'same'); %convolve original matrix with filter
else
    DataOut = DataIn; %don't apply filter if fLength is equal or lower then 1
end
% DataOut = padarray(double(DataOut),[1 1],NaN,'both'); %add NaNs to image to see its edge against zero-padded background when rotating.