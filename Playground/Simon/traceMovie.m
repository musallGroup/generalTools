function traceMovie(dataIn, xRange, saveFile, optsIn)

opts.fps = 60;
opts.sRate = 20000;
opts.yRange = [min(dataIn)-abs(prctile(mat2gray(dataIn),5)), max(dataIn)+abs(prctile(mat2gray(dataIn),5))];
opts.reverseColor = true;
opts.showFrame = round(length(xRange) / opts.sRate / 2);
opts.showRatio = 0.7;
opts.yLabel = 'y-axis';
opts.stimEvents = {};

%% update opts if different options were given as an input to the function
% Ensure both opts and optsIn are structures
if exist('optsIn' , 'var')
    if isstruct(opts) && isstruct(optsIn)
        % Get the field names of both structures
        fieldsOpts = fieldnames(opts);
        fieldsOptsIn = fieldnames(optsIn);
        
        % Find the common fields
        commonFields = intersect(fieldsOpts, fieldsOptsIn);
        
        % Copy the values from optsIn to opts for the common fields
        for i = 1:length(commonFields)
            opts.(commonFields{i}) = optsIn.(commonFields{i});
        end
    else
        error('Both opts and optsIn must be structures.');
    end
end

%% initiate figure and open videowriter
maxRange = round(opts.showFrame * opts.sRate * opts.showRatio); %max number of data points to be shown
stepSize = round(1 / opts.fps * opts.sRate);

v = VideoWriter(saveFile);
v.FrameRate = opts.fps;
v.Quality = 100; %this can make the files a lot larger as the 75 default
open(v);

h = figure;
nhline(0, '--');
plot(xRange, dataIn);
xlim([xRange(1), xRange(maxRange) + opts.showFrame])
ylim(opts.yRange);
ax = gca;
ax.FontSize = 20;
title('Resize window to get best aspect ratio and hit any button to continue');
pause;

%% run loop
hYLabel = ylabel(opts.yLabel);
labelPosition = get(hYLabel, 'Position'); % Get current position
labelPosition(1) = labelPosition(1) - 0.2; % Move the label 0.2 units to the left
labelOffset = labelPosition(1) - xRange(1); %this is how far away the label should be from the axis edge

Cnt = 0;
while Cnt + stepSize < length(dataIn)
    Cnt = Cnt + stepSize;
    
    if Cnt < maxRange
        cIdx = 1:Cnt;
    else
        cIdx = Cnt-maxRange:Cnt;
    end
    
    cla;
    hold on;
    for x = 1 : length(opts.stimEvents{1})
        if any(xRange(cIdx) > opts.stimEvents{1}(x)) || any(xRange(cIdx) > opts.stimEvents{2}(x))
            recWidth = min([opts.stimEvents{2}(x) - opts.stimEvents{1}(x), max(xRange(cIdx))-opts.stimEvents{1}(x)]);
            cRec = rectangle('Position', [opts.stimEvents{1}(x), opts.yRange(1), recWidth, diff(opts.yRange)]);
            cRec.FaceColor = [0 0.5 1 0.25];
            cRec.EdgeColor = 'none';
        end
    end
    
    nhline(0, '--');
    plot(xRange(cIdx), dataIn(cIdx), 'k');
    plot(xRange(cIdx(end)), dataIn(cIdx(end)), 'o', 'MarkerSize', 5, 'MarkerFaceColor', 'k')
    xlim([xRange(cIdx(1)), xRange(cIdx(1)) + opts.showFrame])
    ylim(opts.yRange);
    ax = gca;
    ax.TickDir = 'out';
    
    if opts.reverseColor
        reverseAxisColor;
        useColor = 'w';
        ax.XColor = 'k';
    else
        useColor = 'k';
        ax.XColor = 'w';
    end
    
    ylabel(opts.yLabel, 'Color', useColor);
    labelPosition(1) = labelOffset + xRange(cIdx(1)); %this is how far away the label should be from the axis edge
    hYLabel = ylabel(opts.yLabel);
    hYLabel.Position = labelPosition;
    
    ax.FontSize = 20;
    ax.TickDir = 'out';
    set(gca,'box','off')
    cText = text(ax.XLim(2) - opts.showFrame/10, ax.YLim(1) + diff(ax.XLim)/10, sprintf('%.2f s',max(xRange(cIdx))));
    cText.Color = 'w';
    cText.FontSize = 20;
    
    % Write the frame to the video file
    frame = getframe(h);
    writeVideo(v, frame);
    
    drawnow;
end
close(v);
close(h);