function cLine = arrayPlot(amatrix,varargin)
% plot all columns of a data matrix as individual lines and add the mean
% over columns as a single thick line. aside of the data matrix, additional
% inputs that are compatible with the 'plot' command can be provided.
% usage: cLine = arrayPlot(amatrix,varargin)

% plot individual columns
cLine = plot(amatrix, varargin{:});

% check if hold is already on
a = gca;
if ishold(a)
    checker = true;
else
    hold(a,'on'); checker = false;
end

% get color and linewidth
cLineWidth = cLine(1).LineWidth;
cColor = cLine(1).Color + 0.75;
cColor(cColor >  1) = 1;
for x = 1 : length(cLine)
    cLine(x).Color = cColor;
end

% show mean over all columns
cLine = plot(nanmean(amatrix,2), varargin{:}, 'linewidth', cLineWidth * 4);
  
if ~checker
    hold(a,'off');
end


