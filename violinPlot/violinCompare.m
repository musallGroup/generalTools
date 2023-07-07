function [p, h] = violinCompare(dat, groupnames)
% function to compare different groups. Creates a violinplot and returns
% p-Values from a two-sample t-test between each set of values in a given
% set. dat should be a cell array of size nVals x nGroups where nVals are
% different measures from a given group. For each group a subplot with
% violins for different values is shown and p returns the p-value when
% comparing each set of values against one another.

h = figure;
[nVals, nGroups] = size(dat);

for x = 1 : nGroups

    % get values for each group
    try
        gDat = cat(2, dat{:,x})';
    catch
        gDat = cat(1, dat{:,x});
    end
    [a,~] = cellfun(@size,dat(:,x));
    a = cumsum(a);
    a = [0; a];
    cID = zeros(1, a(end));
    for xx = 1 : length(a) - 1
        cID(a(xx)+1 : a(xx+1)) = xx;
    end

    % make violinplots
    subplot(1,nGroups,x); xlim([0 nVals+1]);
    nhline(0, 'k--');
    violinplot(gDat,cID); axis square
    ax = gca; ax.TickLength = [0 0];
    if exist('groupnames','var') && ~isempty(groupnames)
        title(groupnames{x});
    end

    % check for significance across pairs
    p{x} = zeros(1,sum(1:nVals)-nVals);
    Cnt = 0;
    for xx = 1 : nVals
        for yy = xx+1 : nVals
            try
                [~, pOut] = ttest2(dat{xx,x}, dat{yy,x});
                Cnt = Cnt + 1;
                p{x}(Cnt) = pOut;
            end
        end
    end
end