function image_data = readTIFFstack(filePath, fileName, nrFrames, verbose)
% function to load multi-frame tiff stacks
% image_data is a 3D array with x-y-frames.
% filename is the file name, filePath is the path.
%
% nrFrames is optional and allows to load a limited number of frames.
% verbose is optional and will create a figure of the firt frame in the
% file and also generate some status update as the file is loaded.

% Load the multi-image TIFF file
% filePath = 'X:\twoP\Plex52\200326'; %path to your data file
% fileName = '200326_001_013.tif'; % Replace with your file name

if ~exist('verbose', 'var') || isempty(verbose)
    verbose = true; %give some progress update
end

cFile = fullfile(filePath,fileName); %combine path and filename
imageInfo = imfinfo(cFile);
testImage = imread(cFile, 1);

% Display first image
if verbose
    figure;
    imshow(testImage);
    title('first frame');
end

%use all frames if not specified as input
if ~exist('nrFrames', 'var') || isempty(nrFrames)
    nrFrames = length(imageInfo); 
end

try
    t = Tiff(cFile,'r'); %check if tiff object can be created
    useTiffobj = true;
catch
    useTiffobj = false;
end

% Read in each image until there are no more left
image_data = zeros(numel(testImage), nrFrames, class(testImage)); % Create an array with zeros to store image data

for k = 1 : nrFrames
    if useTiffobj
        t.setDirectory(k);
        cImg = t.read();
        image_data(:,k) = cImg(:);
    else
        cImg = imread(cFile, k);
        image_data(:,k) = cImg(:);
    end
    
    if verbose && mod(k,100) == 0
        fprintf(1, '  image %d\n', k);
    end
end

image_data = reshape(image_data, [size(testImage), nrFrames]);

