function betterFigure(ax)
% code to improvide data visualization in current axis.

if nargin == 0
    ax = gca;
end

%axis properties
try
    ax.Parent.Renderer = 'painters';
    ax.LineWidth = 2;
end
ax.FontSize = 14;

% children properties
for x = 1 : length(ax.Children)
    if contains(class(ax.Children(x)),'ErrorBar')
            ax.Children(x).LineWidth = 4;
            ax.Children(x).MarkerSize = 10;
            ax.Children(x).MarkerFaceColor = 'w';
    elseif strcmp(ax.Children(x).Tag,'boxplot')
        for y = 1 : length(ax.Children(x).Children)
            ax.Children(x).Children(y).LineWidth = 2;
        end
    else
        try
            ax.Children(x).LineWidth = 2;
        end
    end
end

%check for hidden lines
oChild = findall(ax,'Type','line');
for x = 1 : length(oChild)
    oChild(x).LineWidth = 2;
end