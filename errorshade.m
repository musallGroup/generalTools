function [lineOut, fillOut] = errorshade(xVals, dataIn, dataUpper, dataLower, plotColor, plotAlpha, smth)
% usage: [lineOut, fillOut] = errorshade(xVals, dataIn, dataUpper, dataLower, plotColor, plotAlpha, smth)


if exist('plotColor','var') == 0 || isempty(plotColor)
    plotColor = 'r'; 
end

if exist('xVals','var') == 0 || isempty(xVals)
    xVals = 1 : length(dataIn);
end

if exist('smth','var'); if isempty(smth); smth=1; end
else 
    smth=1; %no smoothing by default
end  

if ~exist('plotAlpha','var') || isempty(plotAlpha)
    plotAlpha = 1;
end

% do smoothing if requested
if smth > 1
    dataIn = boxFilter(dataIn,smth); %use boxfilter to smooth data
    dataUpper = boxFilter(dataUpper,smth); %use boxfilter to smooth data
    dataLower = boxFilter(dataLower,smth); %use boxfilter to smooth data
end

% check if current axis is on hold
check = false;
if ~ishold
    check=true;
end
hold on;


% make sure we are using column vectors
xVals = xVals(:);
dataIn = dataIn(:);
dataUpper = dataUpper(:);
dataLower = dataLower(:);


if any(isnan(dataIn)) %make multiple patches if there are nans
    nanIdx = find(isnan(dataIn));
    nanIdx = [0; nanIdx(:)]';
    
    for x = 1 : length(nanIdx)
        if x ~= length(nanIdx)
            cIdx = nanIdx(x)+1:nanIdx(x+1)-1; %data for current patch
        else
            cIdx = nanIdx(x)+1:length(dataIn); %data for current patch
        end
        
        if ~isempty(cIdx)
            cX = xVals(cIdx);
            cM = dataIn(cIdx);
            cUp = dataUpper(cIdx);
            cDown = dataLower(cIdx);
            % plot the patch
            fillOut(x) = fill([cX; flipud(cX)],[cM+cUp; flipud(cM-cDown)], plotColor, 'FaceAlpha', plotAlpha, 'linestyle','none');

        end
    end
else
    % plot entire patch
    fillOut = fill([xVals; flipud(xVals)],[dataIn+dataUpper; flipud(dataIn-dataLower)], plotColor, 'FaceAlpha', plotAlpha, 'linestyle','none');
end

% plot the line
if plotAlpha == 1; plotColor = 'k'; end
lineOut = plot(xVals, dataIn, 'color', plotColor, 'linewidth', 1.5); %% change color or linewidth to adjust mean line

% check if hold should be released
if check
    hold off;
end
end

function dataOut = boxFilter(dataIn, fWidth)
% apply 1-D boxcar filter for smoothing

fWidth = fWidth - 1 + mod(fWidth,2); %make sure filter length is odd
dataStart = cumsum(dataIn(1:fWidth-2),2);
dataStart = dataStart(1:2:end) ./ (1:2:(fWidth-2));
dataEnd = cumsum(dataIn(length(dataIn):-1:length(dataIn)-fWidth+3),2);
dataEnd = dataEnd(end:-2:1) ./ (fWidth-2:-2:1);
dataOut = conv(dataIn,ones(fWidth,1)/fWidth,'full');
dataOut = [dataStart;dataOut(fWidth:end-fWidth+1);dataEnd];

end