function plotRowsWithColormap(A, colormapName, xAxis, ax)
    % plotRowsWithColormap Plots each row of matrix A with colors from a specified colormap.
    %
    % Usage:
    %   plotRowsWithColormap(A)                   % Uses the default 'parula' colormap
    %   plotRowsWithColormap(A, colormapName)     % Uses the specified colormap
    %
    % Inputs:
    %   A               - Matrix where each row will be plotted with a unique color.
    %   colormapName    - (Optional) Name of the colormap to use (e.g., 'jet', 'hot', 'cool').
    %                      Default is 'parula'.
    %   ax              - (Optional) Axis to which the plot should be added. Will open a new figure otherwhise.
    %   xAxis           - (Optional) Values for the x-axis to plot the data against
    
    % check if axis handle is provided
    if ~exist('ax', 'var') || isempty(ax)
        figure;
    end
        
    % Set default colormap to 'parula' if not provided
    if ~exist('colormapName', 'var') || isempty(colormapName)
        colormapName = 'parula';
    end

    % Get the number of rows
    [numRows, numCols] = size(A);

    % check if xaxis values are provided
    if ~exist('xAxis', 'var') || isempty(xAxis)
        xAxis = 1 : numCols;
    end
    
    % Generate the colors using the specified colormap
    colors = feval(colormapName, numRows);

    % Plot each row with the corresponding color
    hold on;
    for i = 1:numRows
        plot(xAxis, A(i, :), 'Color', colors(i, :), 'LineWidth', 1.5);
    end
    hold off;

    % Add labels and title
    xlabel('Column Index');
    ylabel('Row Value');
    title(['Rows of Matrix with ', colormapName, ' Colormap']);

    % Optional: add a colorbar for reference
%     colormap(colors);
%     colorbar('Ticks', linspace(0, 1, numRows), 'TickLabels', 1:numRows);
end
