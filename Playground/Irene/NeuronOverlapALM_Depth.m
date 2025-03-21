% directory of processed image
serverPath = '\\Fileserver\Allgemein\transfer\for Irene\TripleRetro-Exports\3C-RGB_flat\Triple*';
SavePath = 'E:\Histology_NeuronDistributionALM\';
slicePath = '*.mat';
conversionFactor = 0.5681821; % conversion factor um/pixel
depthThreshold = 350; % depth threshold in micrometers
allSlices = dir([serverPath]);
nrSlices = length(allSlices);
minCellSize = 50; %min size of each ROI in pixels to be counted
maxCellSize = 300; %max size of each ROI in pixels to be counted
cellOverlapThreshold = 0.3; %amount of overlap to declare 2 cells to be the same

%% Load Data
allData = zeros(2280, 1744, nrSlices, 3); %this is pixels by slices by color channels
for iSlice = 1:nrSlices
    
    redFile = dir([allSlices(iSlice).folder '\' allSlices(iSlice).name '\Red\*.mat']);
    allData(:,:,iSlice, 1) = load(strcat(redFile.folder, '\', redFile.name) ).masks;
    greenFile = dir([allSlices(iSlice).folder '\' allSlices(iSlice).name '\Green\*.mat']);
    allData(:,:,iSlice, 2) = load(strcat(greenFile.folder, '\', greenFile.name) ).masks;
    blueFile = dir([allSlices(iSlice).folder '\' allSlices(iSlice).name '\Blue\*.mat']);
    allData(:,:,iSlice, 3) = load(strcat(blueFile.folder, '\', blueFile.name) ).masks;
      
end

%% find cells for each brain
tic
allColorIdx = cell(1, nrSlices); %color index for all cells from each slice
allCellMasks = cell(1, nrSlices); %binary masks for each cell, color channel, and slice
for iSlice = 1:nrSlices

    % general variables for current slice
    cellCnt = 0; %counter for all cells
    colorIdx = []; %color index for each cell
    cellMasks = []; %mask for each cell
    
    % loop over color channels
    for iColor = 1 : size(allData,4)
        nrCells = unique(allData(:,:,iSlice, iColor))';
        nrCells = nrCells(nrCells > 0); %dont use 0
        
        for iCells = nrCells
            
            cMask = allData(:,:,iSlice, iColor) == iCells; %mask for current cell
            cMask = logical(arrayResize(cMask, 2)); %downsample by 2
            
            % Calculate depth of the current cell (similar to second code)
            [y, x] = find(cMask); %find coordinate of pixels belonging to iCell
            cellDepth = median(y) * conversionFactor; % calculate the median depth
            
            % check if cell counts as a real cell, is within size range, and is deeper than 350 um
            if sum(cMask(:)) > minCellSize && sum(cMask(:)) < maxCellSize && cellDepth >= depthThreshold
                colorIdx = [colorIdx, iColor]; %1 means red, 2 means green, 3 means blue
                if isempty(cellMasks)
                    cellMasks = cMask;
                else
                    cellMasks = cat(3, cellMasks, cMask);
                end
            end
        end
    end
    
    % give some feedback for the current slice
    totalCells = size(cellMasks,3); %total number of neurons in this slice
    fprintf('Found %i cells for slice %i. %i in red, %i in green, %i in blue\n', ...
        totalCells, iSlice, sum(colorIdx ==1), sum(colorIdx == 2), sum(colorIdx == 3));
    
    % check for overlap
    useIdx = true(1, totalCells);
    mergeColorIdx = false(3, totalCells);
    rejIdx = cell(1, totalCells);
    for iCells = 1 : totalCells
        if useIdx(iCells)
            cMask = cellMasks(:,:,iCells); %current cell
            allCellPx = arrayShrink(cellMasks, ~cMask, 'merge'); %find pixels of all cells
            
            cIdx = find(mean(allCellPx) > cellOverlapThreshold); %check for overlap
            
            % keep color identify for the current cell
            mergeColorIdx(colorIdx(cIdx), iCells) = true;
            
            % this is to avoid double-counting multi-color neurons
            cIdx = cIdx(cIdx ~= iCells); %remove the current cell from the index
            
            rejIdx{iCells} = cIdx; %store overlapping cells in array as a control
            useIdx(cIdx) = false; %cells that are accounted for can be removed from useIdx
        end
    end
    nrRealCells = sum(useIdx); %number of unique cells
    
    % isolate real neurons for the current slice
    allColorIdx{iSlice} = mergeColorIdx(:, useIdx);
    
    % get masks for cells as output
    trueCellMasks = false([size(cMask), nrRealCells, 3]);
    cellIdx = find(useIdx);
    for iCell = 1 : nrRealCells
        currCell = cellIdx(iCell); %current cell
        cCells = [currCell, rejIdx{cellIdx(iCell)}]; %current cell and overlapping cells
    
        currMasks = cellMasks(:,:,cCells);
        trueCellMasks(:,:, iCell, colorIdx(cCells)) = currMasks; %put into new array
    end
    allCellMasks{iSlice} = trueCellMasks; %keep this for verification
        
    fprintf('Found %i UNIQUE cells for slice %i. %i in red, %i in green, %i in blue\n', ...
        nrRealCells, iSlice, sum(mergeColorIdx(1,:)), sum(mergeColorIdx(2,:)), sum(mergeColorIdx(3,:)));
    toc;
end 
    
%% compute ratios
crossColorIdx = logical(cat(2, allColorIdx{:})); %merge data from all slices

%all indices for computing ratios
redGreenCellIdx = crossColorIdx(1,:) & crossColorIdx(2,:) & ~crossColorIdx(3,:);
redBlueCellIdx = crossColorIdx(1,:) & ~crossColorIdx(2,:) & crossColorIdx(3,:);
redBlueGreenCellIdx = crossColorIdx(1,:) & crossColorIdx(2,:) & crossColorIdx(3,:);
blueGreenCellIdx = ~crossColorIdx(1,:) & crossColorIdx(2,:) & crossColorIdx(3,:);
onlyGreenIdx = ~crossColorIdx(1,:) & crossColorIdx(2,:) & ~crossColorIdx(3,:);
onlyRedIdx = crossColorIdx(1,:) & ~crossColorIdx(2,:) & ~crossColorIdx(3,:);
onlyBlueIdx = ~crossColorIdx(1,:) & ~crossColorIdx(2,:) & crossColorIdx(3,:);

% green vs rest

allGreen = crossColorIdx(2,:);
onlyGreenRatio_g = sum(onlyGreenIdx)/sum(allGreen);
redGreenRatio_g = sum(redGreenCellIdx)/sum(allGreen);
blueGreenRatio_g = sum(blueGreenCellIdx)/sum(allGreen);
redBlueGreenCellRatio_g = sum(redBlueGreenCellIdx)/sum(allGreen);

% red vs rest

allRed = crossColorIdx(1,:);
onlyRedRatio_r = sum(onlyRedIdx)/sum(allRed);
redGreenRatio_r = sum(redGreenCellIdx)/sum(allRed);
blueRedRatio_r = sum(redBlueCellIdx)/sum(allRed);
redBlueGreenCellRatio_r = sum(redBlueGreenCellIdx)/sum(allRed);

% blue vs rest

allBlue = crossColorIdx(3,:);
onlyBlueRatio_b = sum(onlyBlueIdx)/sum(allBlue);
blueGreenRatio_b = sum(blueGreenCellIdx)/sum(allBlue);
blueRedRatio_b = sum(redBlueCellIdx)/sum(allBlue);
redBlueGreenCellRatio_b = sum(redBlueGreenCellIdx)/sum(allBlue);


% Make Pie Charts with results for green
greenPieValues = [onlyGreenRatio_g, redGreenRatio_g, blueGreenRatio_g, redBlueGreenCellRatio_g];
labels = {'Only Green', 'Green and Red', 'Green and Blue', 'Green, Red and Blue'};
figure;
pie(greenPieValues, labels);
title('Distribution of Green Neurons by Color Overlap');

% Make Pie Charts with results for Red
redPieValues = [onlyRedRatio_r, redGreenRatio_r, blueRedRatio_r, redBlueGreenCellRatio_r];
labels = {'Only Red', 'Red and Green', 'Red and Blue', 'Red, Blue and Green'};
figure;
pie(redPieValues, labels);
title('Distribution of Red Neurons by Color Overlap');

% Correct the blue pie chart plotting
bluePieValues = [onlyBlueRatio_b, blueGreenRatio_b, blueRedRatio_b, redBlueGreenCellRatio_b];
labels = {'Only Blue', 'Blue and Green', 'Blue and Red', 'Blue, Red and Green'};
figure;
pie(bluePieValues, labels);
title('Distribution of Blue Neurons by Color Overlap');
%% Pie charts with values

greenPieValues = greenPieValues / sum(greenPieValues);
redPieValues = redPieValues / sum(redPieValues);
bluePieValues = bluePieValues / sum(bluePieValues);

% Make Pie Charts with results for green
figure;
pie(greenPieValues);
legend(labels, 'Location', 'eastoutside');
title('Distribution of Green Neurons by Color Overlap');

% Make Pie Charts with results for Red
figure;
pie(redPieValues);
legend(labels, 'Location', 'eastoutside');
title('Distribution of Red Neurons by Color Overlap');

% Make Pie Charts with results for Blue
figure;
pie(bluePieValues);
legend(labels, 'Location', 'eastoutside');
title('Distribution of Blue Neurons by Color Overlap');
