function reverseAxisColor
%function to switch colors from black on white to white on black.

% Reverse the colors (white on black)
set(gca, 'Color', 'k'); % Set axes background to black
set(gca, 'XColor', 'w'); % Set x-axis color to white
set(gca, 'YColor', 'w'); % Set y-axis color to white
set(gca, 'GridColor', 'w'); % Set grid color to white (if grid is used)
set(gca, 'MinorGridColor', 'w'); % Set minor grid color to white (if minor grid is used)

% Set figure background color to black
set(gcf, 'Color', 'k');

% Change the plot line color to white
h = findobj(gca, 'Type', 'Line');
set(h, 'Color', 'w', 'MarkerFaceColor', 'w');

% Optionally, set tick labels color to white
set(gca, 'XTickLabel', get(gca, 'XTickLabel'), 'YTickLabel', get(gca, 'YTickLabel'), 'XColor', 'w', 'YColor', 'w');

% % Optionally, adjust the box color if the box is on
if strcmpi(get(gca, 'Box'), 'on')
    set(gca, 'BoxStyle', 'full', 'XColor', 'w', 'YColor', 'w');
end