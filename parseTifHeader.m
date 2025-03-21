function dataStruct = parseTifHeader(headerText)
    % Initialize an empty struct to store the values
    dataStruct = struct();
    
    % Define the regular expression for matching key-value pairs
    pattern = '(\w+)\s*=\s*(\S.*?)(?=\w+\s*=|$)';
    
    % Use regular expression to extract the key-value pairs
    tokens = regexp(headerText, pattern, 'tokens');
    
    % Loop through each extracted key-value pair and store in the struct
    for i = 1:length(tokens)
        key = tokens{i}{1};  % Extract the key
        valueStr = tokens{i}{2};  % Extract the value as a string
        
        % Check for specific cases
        if strcmp(key, 'epoch')
            % Convert the epoch string to a numeric array
            value = str2num(valueStr);
        elseif any(strcmp(key, {'auxTrigger0', 'auxTrigger1', 'auxTrigger2', 'auxTrigger3', 'I2CData'}))
            % For the empty arrays or cell arrays, we evaluate the string
            value = eval(valueStr);  % '{}' or '[]' will be converted correctly
        else
            % For numeric values, convert to double
            value = str2double(valueStr);
            
            % If str2double fails (i.e., returns NaN), try to parse as a numeric array
            if isnan(value)
                value = str2num(valueStr);
            end
        end
        
        % Store the value in the struct
        dataStruct.(key) = value;
    end
end
