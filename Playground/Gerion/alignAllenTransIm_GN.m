function im = alignAllenTransIm_GN(im, transParams, targSize)
% im = alignAllenTransIm(im, transParams)
% 
% Take a brain image and rotate, scale, and translate it according to the
% parameters in transParams (produced by alignBrainToAllen GUI). im may be
% an image stack. Note that due to the behavior of imrotate, NaNs may not
% propagate identically if an image stack is used vs. calling this function
% on individual images.
% 
% Pixels where the value is not defined (due to rotation) are set to NaN.
% This behavior is different from imrotate.

if ~exist('targSize', 'var') || isempty(targSize)
    targSize = [540, 586];  % standard size of allen brain map
end

% offset = 10;  % previously used 10, shouldn't matter much
offset = 5E1;
[h, w, d] = size(im);

% Set pixels off from zero
theMin = min(im(:));
im = im - theMin + offset;

% Rotate
im = imrotate(im, transParams.angleD, 'bilinear');

% Scale
if transParams.scaleConst ~= 1
  im = imresize(im, transParams.scaleConst);
end

% Trim result (rotate expands it)
[rH, rW, rD] = size(im);

% Set NaNs to 0, because imtranslate can't handle them
nans = isnan(im);
if any(nans(:))
  im(nans) = 0;
end

% Translate
im = imtranslate(im, transParams.tC');

% Detect missing pixels due to rotation, set to NaN
im(im <= 0.9999 * offset) = NaN;

% Restore offset
im = im + theMin - offset;

% Trim result (rotate expands it)
[rH, rW, rD] = size(im);
trimH = floor((rH - h) / 2);
trimW = floor((rW - w) / 2);

if transParams.scaleConst < 1
    if trimH < 0
        temp_img = NaN(h, size(im, 2), d, class(im));
        temp_img(abs(trimH) + (1:size(im, 1)), :, :) = im;
        im = temp_img;
    else
        im = im(trimH + (1:h), :, :);
    end

    if trimW < 0
        temp_img = NaN(size(im, 1), w, d, class(im));
        temp_img(:, abs(trimW) + (1:size(im, 2)), :) = im;
        im = temp_img;
    else
        im = im(:, trimW + (1:w), :);
    end
else
    im = im(trimH + (1:h), trimW + (1:w), :);
end

try
    im = im(1:540, 1:targSize(2), :);
catch; end


% The rotation/interpolation creates artifacts at the edges. This removes 
% just one pixel to fix this.
try
    addpath('\\NASKAMPA\LTS2\Analysis_software_shapred_between_PCs\universal_functions');
    im = remove_edge_pixels(im, 2);
catch; end

