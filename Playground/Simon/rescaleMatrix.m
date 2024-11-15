function A_rescaled = rescaleMatrix(A, newRows, method)
    % rescaleMatrix Rescales a matrix A to have newRows rows with specified interpolation.
    %
    % Usage:
    %   A_rescaled = rescaleMatrix(A, newRows)
    %   A_rescaled = rescaleMatrix(A, newRows, method)
    %
    % Inputs:
    %   A        - The original matrix to be rescaled.
    %   newRows  - The desired number of rows in the rescaled matrix.
    %   method   - (Optional) Interpolation method, e.g., 'linear', 'spline', 'pchip', etc.
    %              Default is 'linear'.
    %
    % Output:
    %   A_rescaled - The rescaled matrix with size [newRows, cols].

    % Set default method to 'linear' if not provided
    if ~exist('method', 'var') || isempty(method)
        method = 'linear';
    end

    % Get the original size of the matrix
    [oldRows, cols] = size(A);

    % Create an index for the original and new row positions
    originalRowIndices = linspace(1, oldRows, oldRows);
    newRowIndices = linspace(1, oldRows, newRows);

    % Initialize the new matrix with the desired size
    A_rescaled = zeros(newRows, cols);

    % Interpolate each column individually using the specified method
    for c = 1:cols
        A_rescaled(:, c) = interp1(originalRowIndices, A(:, c), newRowIndices, method);
    end
end
