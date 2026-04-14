function nBarweb(cData, cError, cColor, cPoints, cSig)
% nBarweb - grouped bar plot with error bars and optional individual data points
%
% INPUTS
%   cData   : [ngroups x nbars] matrix of bar heights (means)
%   cError  : [ngroups x nbars] matrix of error values (e.g. SEM). Use [] to skip.
%   cColor  : bar color(s). Any of:
%               [1 x 3]         single RGB triplet applied to all bars
%               [nbars x 3]     one color per bar series (columns of cData)
%               [ngroups x 3]   one color per group (rows of cData); only
%                               supported when nbars == 1
%   cPoints : (optional) [ngroups x nbars x nPoints] individual data points,
%             plotted as filled circles with horizontal jitter.
%   cSig    : (optional) logical [ngroups x 1], true for groups with a
%             significant difference. An asterisk is drawn above those groups.

if ~exist('cError',  'var'), cError  = []; end
if ~exist('cColor',  'var') || isempty(cColor), cColor = [0 0.4470 0.7410]; end
if ~exist('cPoints', 'var'), cPoints = []; end
if ~exist('cSig',    'var'), cSig    = []; end

[ngroups, nbars] = size(cData);

% detect per-group coloring: [ngroups x 3] with nbars == 1 and ngroups > 1
perGroupColor = (size(cColor,1) == ngroups) && (size(cColor,2) == 3) && ...
                (nbars == 1) && (ngroups > 1);

% expand single [1x3] color to [nbars x 3]
if isvector(cColor) && numel(cColor) == 3
    cColor = repmat(cColor(:)', nbars, 1);
    perGroupColor = false;
end

% compute grouped bar x-positions
groupwidth = min(0.8, nbars / (nbars + 1.5));
xPos = nan(ngroups, nbars);
for i = 1:nbars
    xPos(:,i) = (1:ngroups)' - groupwidth/2 + (2*i-1) * groupwidth / (2*nbars);
end

wasHeld = ishold;
if ~wasHeld, hold on; end

% draw bars
hBar = bar(cData);
if perGroupColor
    hBar(1).FaceColor = 'flat';
    hBar(1).CData     = cColor;
    hBar(1).FaceAlpha = 0.6;
    hBar(1).EdgeColor = 'none';
else
    for i = 1:nbars
        hBar(i).FaceColor = cColor(i,:);
        hBar(i).FaceAlpha = 0.6;
        hBar(i).EdgeColor = 'none';
    end
end

% draw error bars
if ~isempty(cError)
    for i = 1:nbars
        errorbar(xPos(:,i), cData(:,i), cError(:,i), 'k', ...
            'LineStyle', 'none', 'LineWidth', 1);
    end
end

% draw individual data points with horizontal jitter
if ~isempty(cPoints)
    nPoints  = size(cPoints, 3);
    jitWidth = groupwidth / nbars * 0.4;
    jit      = linspace(-jitWidth, jitWidth, max(nPoints, 2));
    if nPoints == 1, jit = 0; end
    for i = 1:nbars
        for iGrp = 1:ngroups
            if perGroupColor
                ptColor = cColor(iGrp,:);
            else
                ptColor = cColor(i,:);
            end
            yvals = squeeze(cPoints(iGrp, i, :));
            ok    = ~isnan(yvals);
            if any(ok)
                plot(xPos(iGrp,i) + jit(ok), yvals(ok)', 'o', ...
                    'Color',           ptColor, ...
                    'MarkerFaceColor', ptColor, ...
                    'MarkerSize',      4, ...
                    'LineStyle',       'none', ...
                    'HandleVisibility','off');
            end
        end
    end
end

% draw significance markers
if ~isempty(cSig)
    cSig = logical(cSig(:));
    if ~isempty(cError)
        yTops = max(cData + abs(cError), [], 2);
    else
        yTops = max(cData, [], 2);
    end
    yRange = max(yTops) - min(yTops);
    if yRange == 0, yRange = max(abs(yTops)); end
    for iGrp = 1:ngroups
        if cSig(iGrp)
            text(double(iGrp), double(yTops(iGrp) + 0.05 * yRange), '*', ...
                'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');
        end
    end
end

if ~wasHeld, hold off; end

end
