
% get brain files
localSavePath = 'E:\Histology_AnterogradeALM';
brainFiles = dir([localSavePath filesep '**' filesep 'avgSliceData.mat']);
% brainFiles.folder %not using this right now but can inform which brain is which

stepSize = 20; %stepSize to register bins from individual brains
minAreaSizeforPlot = 100; %dont show areas below this size in pixels

%% load atlas data
Atlas_folder = 'E:\Histology_Test\'; %path to saved AtlasData
Atlas_file_name = 'AtlasData';
full_path_atlas = fullfile(Atlas_folder, Atlas_file_name + ".mat");
AtlasData = load(full_path_atlas);
av = AtlasData.allData.av;
st = AtlasData.allData.st;
tv = AtlasData.allData.tv;
brainSteps = 1: stepSize : size(av,1);

%% run over all brains and average them together for each allen bin (defined
%by sliceSteps)
allBrainSlices = cell(1, length(brainSteps));
allBrainCnt = zeros(1, length(brainSteps));
for iBrains = 1 : length(brainFiles)
    
    cFile = fullfile(brainFiles(iBrains).folder, brainFiles(iBrains).name);
    load(cFile, 'avgSliceData', 'sliceSteps');
    
    for iSteps = 1 : length(brainSteps)
        
        if iSteps == length(brainSteps)
            useIdx = sliceSteps >= brainSteps(iSteps);
        else
            useIdx = sliceSteps >= brainSteps(iSteps) & sliceSteps <= brainSteps(iSteps+1);
        end
        
        % further combine slices from current brain that fit into requested bin
        cData = cat(4, avgSliceData{useIdx});
        
        % if there is data add to average
        if ~isempty(cData)
            
            %combine slices and subtract background
            cData = nanmean(cData,4);
            cData = uint8(cData - cData(:,:,3));
            
            allBrainCnt(iSteps) = allBrainCnt(iSteps) + 1;
            allBrainSlices{iSteps} = runMean(allBrainSlices{iSteps}, ...
                cData, allBrainCnt(iSteps));
            
        end
    end
end


%% Visualize the result for all brains
h = figure('renderer', 'painters');
[a,~] = cellfun(@size, allBrainSlices);
useRange = a~= 0;
brainsPerRow = 12; %how many brains to show per row
t = tiledlayout(ceil(sum(useRange)/brainsPerRow),brainsPerRow);
t.TileSpacing = 'compact'; % 'compact' or 'none'
t.Padding = 'compact'; % 'compact' or 'none'

showOnlyLeftHS = true; %flag to only show the left HS
for iSteps = find(useRange)
    nexttile
    
    % show mean for current bin
    cData = mat2gray(rgb2gray(allBrainSlices{iSteps}));
    if showOnlyLeftHS
        cData = cData(:, 1 : round(size(cData,2)/2));
    end
    imshow(cData);
    caxis([0 0.2]);
    title(brainSteps(iSteps));
    colormap(magma(256));
    hold on;
    
    % show area outliens
    concatenatedTable = [];
    current_slice = brainSteps(iSteps) + round(stepSize / 2);
    RegionsID = (unique(av(current_slice,:,:)));
    for cID = 1: length(RegionsID)
        locID = squeeze(av(current_slice,:,:)) == RegionsID(cID); %get mask for current area
        locID = locID(1:size(cData,1), 1:size(cData,2));
        
        % show area outlines on fluorescent image
%         a = bwboundaries(locID); %outline of selected area
        a = outlineAndSmooth(locID);
        for x = 1 : length(a)
            if size(a{x},1) > minAreaSizeforPlot
                plot(smooth(a{x}(:,2),10),smooth(a{x}(:,1),10),'w', 'linewidth', 0.01)
            end
        end
    end
    drawnow;
end


%% keep going through the slices on button press
figure
for iSteps = 1 : length(brainSteps)
    
    if ~isempty(allBrainSlices{iSteps})
        
        % show mean for current bin
        imshow(mat2gray(rgb2gray(allBrainSlices{iSteps})));
        caxis([0 0.2]);
        title(iSteps);
        colormap(magma(256));
        hold on;
        
        % show area outliens
        concatenatedTable = [];
        current_slice = brainSteps(iSteps) + round(stepSize / 2);
        RegionsID = (unique(av(current_slice,:,:)));
        for cID = 1: length(RegionsID)
            locID = squeeze(av(current_slice,:,:)) == RegionsID(cID); %get mask for current area
         
            % show area outlines on fluorescent image
            a = bwboundaries(locID); %outline of selected area
            for x = 1 : length(a)
                if size(a{x},1) > minAreaSizeforPlot
                    plot(smooth(a{x}(:,2),10),smooth(a{x}(:,1),10),'w', 'linewidth', 0.1)
                end
            end
        end
        
        pause;
    end
end

%% Visualize the result for one brain
figure;
iBrains = 4; %brain of interest
cFile = fullfile(brainFiles(iBrains).folder, brainFiles(iBrains).name);
load(cFile, 'avgSliceData', 'sliceSteps');
for iSteps = 1 : length(sliceSteps)
    
    if ~isempty(avgSliceData{iSteps})
        
        % show mean for current bin
        cData = uint8(avgSliceData{iSteps} - avgSliceData{iSteps}(:,:,3));
        imshow(mat2gray(rgb2gray(cData)));
        caxis([0 0.2]);
        title(iSteps);
        colormap(magma(256));
        hold on;
        
%         % show area outliens
%         concatenatedTable = [];
%         current_slice = sliceSteps(iSteps) + round(stepSize / 2);
%         RegionsID = (unique(av(current_slice,:,:)));
%         for cID = 1: length(RegionsID)
%             locID = squeeze(av(current_slice,:,:)) == RegionsID(cID); %get mask for current area
%          
%             % show area outlines on fluorescent image
%             a = bwboundaries(locID); %outline of selected area
%             for x = 1 : length(a)
%                 if size(a{x},1) > minAreaSizeforPlot
%                     plot(smooth(a{x}(:,2),10),smooth(a{x}(:,1),10),'w', 'linewidth', 0.1)
%                 end
%             end
%         end
%         
        pause;
    end
end




