% directory of processed image
serverPath = '\\Fileserver\Allgemein\transfer\for Irene\TripleRetro-Exports\3C-RGB_flat\';
SavePath = 'E:\Histology_NeuronDistributionALM\';
slicePath = '*\Blue\*.mat';
conversionFactor = 0.5681821; % conversion factor um/pixel

allSlices = dir([serverPath slicePath]);
allDepths = [];

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
save(fullfile(SavePath, 'bluDepths.mat'), 'allDepths');

%% Plot Histogram of superficial and deep neurons
%Load files
data = load(fullfile(SavePath, 'bluDepths.mat'));
cData = data.allDepths;
%% Plot over depths
clear x label ylabel
% Define the bin edges
bin_edges = 0:100:600;

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
title('Neuron Distribution');
ylim([0 100]);
grid on;



%% Bar Plot superficial vs deep

% Calculate the number of data points in each category
sup = sum(cData < 350);
deep = sum(cData >= 350);

% Calculate the distribution
distribution = [sup/length(cData), deep/length(cData)]*100;

% Create the bar plot
figure;
b = bar(distribution);

% Set the x-axis labels
xticks([1 2]); % Set the positions of the x-ticks
xticklabels({'Superficial (< 350 um)', 'Deep (> 350 um)'}); % Set the labels for each bar

% Add titles and labels
xlabel('Depth');
ylabel('Fraction of Neurons');
title('Distribution of Neurons in Different Depth Categories');
grid on;

