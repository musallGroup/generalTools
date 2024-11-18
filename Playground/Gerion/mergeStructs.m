function a = mergeStructs(a, b)
% NOTE: If the same field is found in both a and b, the value of b is used!
% Example line: 
%     a = mergeStructs(struct("a", 1, "b", 2, "c", 3), struct("b", 4, "c", 5, "d", 6))


duplicate_fieldNames = intersect(fieldnames(a), fieldnames(b));

% remove fields also contained in b
if ~isempty(duplicate_fieldNames)
    for fieldName = squeeze(duplicate_fieldNames)'
        warning("Overwriting field: struct_1." + fieldName{1} + ": " + a.(fieldName{1}) + " with: struct_2." + ...
                fieldName{1} + ": " + b.(fieldName{1}));
        a = rmfield(a, fieldName{1});
    end
end

% concatenate fields from b to a
a = cell2struct([struct2cell(a); struct2cell(b)], ...
                [fieldnames(a); fieldnames(b)]);
end
