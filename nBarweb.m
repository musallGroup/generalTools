function nBarweb(cData, cError, cColor, cPoints, cSig)
% nBarweb - grouped bar plot with error bars and optional individual data points
%
% INPUTS
%   cData   : [ngroups x nbars] matrix of bar heights (means)
%   cError  : [ngroups x nbars] matrix of error values (e.g. SEM). Use [] to skip.
%   cColor  : bar color(s). Either a single [1x3] RGB triplet or an
%             [nbars x 3] matrix with one color per bar.
%   cPoints : (optional) [ngroups x nbars x nPoints] individual data points,
%             plotted as filled circles at the correct grouped bar positions.
%   cSig    : (optional) logical [ngroups x 1], true for groups with a
%             significant difference. An asterisk is drawn above those groups.

if ~exist('cError',  'var'), cError  = []; end
if ~exist('cColor',  'var') || isempty(cColor), cColor = [0 0.4470 0.7410]; end
if ~exist('cPoints', 'var'), cPoints = []; end
if ~exist('cSig',    'var'), cSig    = []; end

[ngroups, nbars] = size(cData);

% expand single color to [nbars x 3]
if isvector(cColor) && numel(cColor) == 3
    cColor = repmat(cColor(:)', nbars, 1);
end

% compute grouped bar x-positions (same formula used for both error bars and points)
groupwidth = min(0.8, nbars / (nbars + 1.5));
xPos = nan(ngroups, nbars);
for i = 1:nbars
    xPos(:,i) = (1:ngroups)' - groupwidth/2 + (2*i-1) * groupwidth / (2*nbars);
end

wasHeld = ishold;
if ~wasHeld, hold on; end

% draw bars with per-bar colors
hBar = bar(cData);
for i = 1:nbars
    hBar(i).FaceColor = cColor(i,:);
    hBar(i).FaceAlpha = 0.6;
end

% draw error bars
if ~isempty(cError)
    for i = 1:nbars
        errorbar(xPos(:,i), cData(:,i), cError(:,i), 'k', ...
            'LineStyle', 'none', 'LineWidth', 1);
    end
end

% draw individual data points as filled circles
if ~isempty(cPoints)
    nPoints = size(cPoints, 3);
    for i = 1:nbars
        for iPt = 1:nPoints
            plot(xPos(:,i), cPoints(:,i,iPt), 'o', ...
                'Color',           cColor(i,:), ...
                'MarkerFaceColor', cColor(i,:), ...
                'MarkerSize',      4);
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
