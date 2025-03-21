% directory of processed image
serverPath = '\\fileserver2\All Groups\transfer\for Irene\TripleRetro-Exports\3C-RGB_flat\';
SavePath = 'E:\Histology_NeuronDistributionALM\';
slicePath = '*\Green\*.mat';
conversionFactor = 0.5681821; % conversion factor um/pixel

allSlices = dir(fullfile(serverPath, slicePath));  % Get all matching files
allDepths = [];  % Initialize depth variable

for iSlice = 1:length(allSlices)
    
   % Load data
    
   cData = load(strcat(allSlices(iSlice).folder, "\",  allSlices(iSlice).name));
   maskData = cData.masks;
     
   % Calculate Depth
    
   nrCells = max(maskData, [], "all");
   cellDepths = NaN(nrCells, 1);
   
   for iCell = 1:nrCells
    [y,x] = find(maskData == iCell); %find coordinate of pixels belonging to iCell
    cellDepths(iCell) = median(y)*conversionFactor; % calculate the median of the depths
   end    
    
   % Concatenate Depths
    
   allDepths = cat(1,allDepths, cellDepths); 
end

% Save Results
save(fullfile(SavePath, 'greenDepths.mat'), 'allDepths');

%% Plot Histogram of superficial and deep neurons
%Load files
data = load(fullfile(SavePath, 'greenDepths.mat'));
cData = data.allDepths;
%% Plot over depths
clear x label ylabel
% Define the bin edges
bin_edges = 0:100:900;

% Calculate the histogram
counts = histcounts(cData, bin_edges);

% Calculate the percentage distribution
percentages = (counts / sum(counts)) * 100;

% Define the bin centers for plotting
bin_centers = bin_edges(1:end-1) + diff(bin_edges)/2;

% Create the plot
figure;
plot(bin_centers, percentages, '-o', 'LineWidth', 2);
xlabel('Depth um');
ylabel('Fraction of neurons');
title('Striatal Neurons Distribution');
ylim([0 100]);
grid on;

%% Batch run

% Define the datasets and colors for plotting
datasets = {'bluDepths.mat', 'greenDepths.mat', 'redDepths.mat'};
colors = {'b', 'g', 'r'};
bin_edges = 0:100:1000;

% Figure
figure;
hold on;

for i = 1:length(datasets)
    % Load the data
    data = load(fullfile(SavePath, datasets{i}));
    cData = data.allDepths;

    counts = histcounts(cData, bin_edges);
    percentages = (counts / sum(counts)) * 100;
    bin_centers = bin_edges(1:end-1) + diff(bin_edges)/2;

    % Plot the data
    plot(bin_centers, percentages, '-o', 'LineWidth', 2, 'Color', colors{i});
end

% Customize the plot
xlabel('Depth um');
ylabel('Fraction of neurons');
title('Striatal Neurons Distribution');
ylim([0 30]);
grid on;
legend({'Blue Depths', 'Green Depths', 'Red Depths'}, 'Location', 'best');

hold off;

%% Plot Histogram of superficial and deep neurons
%Load files
data = load(fullfile(SavePath, 'greenDepths.mat'));
cData = data.allDepths;
%% Bar Plot superficial vs deep

% Calculate the number of data points in each category
sup = sum(cData < 350);
deep = sum(cData >= 350);

% Calculate the distribution
distribution = [sup/length(cData), deep/length(cData)]*100;

% Create the bar plot
figure;
b = bar(distribution);
xticks([1 2]); % Set the positions of the x-ticks
xticklabels({'Superficial (< 350 um)', 'Deep (> 350 um)'}); % Set the labels for each bar
xlabel('Depth');
ylabel('Fraction of Neurons');
ylim([0 100]);
title('Distribution of Thalamus-Projecting Neurons');
grid on;
b.FaceColor = 'flat';
% b.CData(1,:) = [0.4660 0.6740 0.1880]; % Light green
% b.CData(2,:) = [0.0 0.5 0.0]; % Dark green
% 
% b.CData(1,:) = [1 0.4 0.4]; % Light red
% b.CData(2,:) = [0.545 0.0 0.0]; % Dark red
% 
b.CData(1,:) = [0.679 0.847 0.902]; % Light blue
b.CData(2,:) = [0.0 0.0 0.545]; % Dark blue

