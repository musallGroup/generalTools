function figToPDF(hFig, outPath, varargin)
% figToPDF  Save a figure as a PDF (vector) and PNG (600 dpi) on A4 paper.
%
%   figToPDF(hFig, outPath)
%   figToPDF(hFig, outPath, 'landscape')
%
% Saves hFig to outPath as both a PDF (painters renderer, vector graphics,
% editable in Illustrator/Inkscape) and a 600 dpi PNG.  The .pdf/.png
% extensions are appended automatically; any existing extension in outPath
% is replaced.
%
% Default page size is A4 portrait (21 x 29.7 cm) with 0.5 cm margins.
% Pass 'landscape' as the third argument for A4 landscape (29.7 x 21 cm).
%
% The output directory is created if it does not exist.
% The figure's paper properties are restored after saving.

landscape = any(strcmpi(varargin, 'landscape'));
margin    = 0.5;   % cm

if landscape
    pw = 29.7;  ph = 21;
else
    pw = 21;    ph = 29.7;
end

% save current paper properties
origUnits   = get(hFig, 'PaperUnits');
origSize    = get(hFig, 'PaperSize');
origPos     = get(hFig, 'PaperPosition');
origPosMode = get(hFig, 'PaperPositionMode');

% fit figure within A4 while preserving its screen aspect ratio
figPos   = get(hFig, 'Position');   % [x y w h] in pixels
figAR    = figPos(3) / figPos(4);   % width / height

maxW = pw - 2*margin;
maxH = ph - 2*margin;

if figAR >= maxW / maxH
    % figure is wider relative to the page: constrain by width
    printW = maxW;
    printH = maxW / figAR;
else
    % figure is taller relative to the page: constrain by height
    printH = maxH;
    printW = maxH * figAR;
end

% centre on page
xOff = margin + (maxW - printW) / 2;
yOff = margin + (maxH - printH) / 2;

set(hFig, 'PaperUnits',        'centimeters');
set(hFig, 'PaperSize',         [pw, ph]);
set(hFig, 'PaperPosition',     [xOff, yOff, printW, printH]);
set(hFig, 'PaperPositionMode', 'manual');

% resolve path and ensure .pdf extension
[fdir, fname, ~] = fileparts(outPath);
if isempty(fdir)
    fdir = pwd;
end
outFile = fullfile(fdir, [fname '.pdf']);

% create directory if needed
if ~isfolder(fdir)
    mkdir(fdir);
end

print(hFig, outFile, '-dpdf', '-painters');
fprintf('Figure saved: %s\n', outFile);

% high-resolution PNG (600 dpi, opengl renderer for raster fidelity)
pngFile = fullfile(fdir, [fname '.png']);
print(hFig, pngFile, '-dpng', '-r600');
fprintf('Figure saved: %s\n', pngFile);

% restore original paper properties
set(hFig, 'PaperUnits',        origUnits);
set(hFig, 'PaperSize',         origSize);
set(hFig, 'PaperPosition',     origPos);
set(hFig, 'PaperPositionMode', origPosMode);
