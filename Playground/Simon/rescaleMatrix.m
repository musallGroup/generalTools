function A_rescaled = rescaleMatrix(A, newRows, method)
    % rescaleMatrix Rescales a 2D or 3D matrix A to have newRows rows with specified interpolation.
    %
    % Usage:
    %   A_rescaled = rescaleMatrix(A, newRows)
    %   A_rescaled = rescaleMatrix(A, newRows, method)
    %
    % Inputs:
    %   A        - The original 2D or 3D matrix to be rescaled.
    %   newRows  - The desired number of rows in the rescaled matrix.
    %   method   - (Optional) Interpolation method, e.g., 'linear', 'spline', 'pchip', etc.
    %              Default is 'linear'.
    %
    % Output:
    %   A_rescaled - The rescaled matrix. For a 2D input, the output is [newRows, cols].
    %                For a 3D input, the output is [newRows, cols, slices].
    
    % Set default method to 'linear' if not provided
    if ~exist('method', 'var') || isempty(method)
        method = 'linear';
    end

    % Get the size of the input matrix
    [oldRows, cols, slices] = size(A);

    % Create an index for the original and new row positions
    originalRowIndices = linspace(1, oldRows, oldRows);
    newRowIndices = linspace(1, oldRows, newRows);

    % Initialize the rescaled matrix
    A_rescaled = zeros(newRows, cols, slices);

    % Handle 2D case
    if ndims(A) == 2
        for c = 1:cols
            A_rescaled(:, c) = interp1(originalRowIndices, A(:, c), newRowIndices, method);
        end

    % Handle 3D case
    else
        for s = 1:slices
            for c = 1:cols
                A_rescaled(:, c, s) = interp1(originalRowIndices, A(:, c, s), newRowIndices, method);
            end
        end
    end
end

