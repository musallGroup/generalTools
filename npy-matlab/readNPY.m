

function data = readNPY(filename)
% Function to read NPY files into matlab.
% *** Only reads a subset of all possible NPY files, specifically N-D arrays of certain data types.
% See https://github.com/kwikteam/npy-matlab/blob/master/tests/npy.ipynb for
% more.
%

[shape, dataType, fortranOrder, littleEndian, totalHeaderLength, ~, nrVars] = readNPYheader(filename);

if littleEndian
    fid = fopen(filename, 'r', 'l');
else
    fid = fopen(filename, 'r', 'b');
end

try

    [~] = fread(fid, totalHeaderLength, 'uint8');

    % read the data
    data = fread(fid, prod(shape)*nrVars, [dataType '=>' dataType]);
    
    if nrVars > 1
        varIdx = reshape(1 : length(data), nrVars, []);
        varIdx = reshape(varIdx', 1, []);
        data = reshape(data(varIdx), [], nrVars);
    end
    
    if length(shape)>1 && ~fortranOrder
        data = reshape(data, [shape(end:-1:1), nrVars]);
        if nrVars > 1
            data = permute(data, [length(shape):-1:1, length(shape)+1]);
        else
            data = permute(data, length(shape):-1:1);
        end
    elseif length(shape)>1
        data = reshape(data, shape);
    end

    fclose(fid);

catch me
    fclose(fid);
    rethrow(me);
end
