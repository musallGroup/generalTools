%% Code to plot the outline of masks

%Load data
mainImage = imread('\\Fileserver\Allgemein\transfer\for Irene\TripleRetro-Exports\3C-RGB_flat\TripleRetro01-021-3C-tdTom_GCaMP_iGECI-RGB_flat-full_res\TripleRetro01-021-3C-tdTom_GCaMP_iGECI-RGB_flat-full_res_Cropped.tif');
masks = load('\\Fileserver\Allgemein\transfer\for Irene\TripleRetro-Exports\3C-RGB_flat\TripleRetro01-021-3C-tdTom_GCaMP_iGECI-RGB_flat-full_res\Green\TripleRetro01-021-3C-tdTom_GCaMP_iGECI-RGB_flat-full_res_Cropped_seg.mat').masks;
conversionFactor = 0.5681;

%Create grayscale version of original figure
figure;
mainImage = im2gray(mainImage);
mainImage = imadjust(mainImage);
imshow(mainImage); hold on;
% imshow(f1);

%Plot masks overlat on original figure for each channel

for iCell = 1:max(masks,[],'all')
    
     [y,x] = find(masks==iCell);

     contour = bwtraceboundary(masks~=0, [y(1) x(1)], "s");

     hold on;

     c=plot(contour(:,2), contour(:,1),'color', [0 0.8 1], 'LineWidth', 1);

end


for iCell = 1:max(masks,[],'all')
    
     [y,x] = find(masks==iCell);

     contour = bwtraceboundary(masks~=0, [y(1) x(1)], "s");

     hold on;

     c=plot(contour(:,2), contour(:,1),'r', 'LineWidth', 1);
     

end

for iCell = 1:max(masks,[],'all')
    
     [y,x] = find(masks==iCell);

     contour = bwtraceboundary(masks~=0, [y(1) x(1)], "s");

     hold on;

     c=plot(contour(:,2), contour(:,1),'g', 'LineWidth', 1);
     

end

hold on;

yline(200/conversionFactor, 'w--', 'LineWidth', 4);
hold on;
yline(400/conversionFactor, 'w--', 'LineWidth', 4);
hold on;
yline(600/conversionFactor, 'w--', 'LineWidth', 4);
hold on;
yline(800/conversionFactor, 'w--', 'LineWidth', 4);
hold on;
yline(1000/conversionFactor, 'w--', 'LineWidth', 4);