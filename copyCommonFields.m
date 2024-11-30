function opts2 = copyCommonFields(opts1, opts2)
% function to compare two input structure and copy the content from opts1
% to opts2 where entries intersect.

% Get the field names of both structs
fields1 = fieldnames(opts1);
fields2 = fieldnames(opts2);

% Find the common fields between opts1 and opts2
commonFields = intersect(fields1, fields2);

% Copy values from opts1 to opts2 for the common fields
for i = 1:length(commonFields)
    field = commonFields{i};
    opts2.(field) = opts1.(field);
end
end
