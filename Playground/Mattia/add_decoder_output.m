function recSummary_decoder = add_decoder_output(dir_animal, recSummary)
% ugly function to add Anoushka's decoder output to a copy 
% of Alice's RecSummary files
recSummary_decoder = recSummary;
parts = strsplit(dir_animal, '\');
% check if there is an Imec0 probe in the recSummary file
% then add the decoder/thresholding label to that file
if sum(contains(fieldnames(recSummary), 'Imec0')) > 0
    try
        table = readtable([dir_animal, filesep, parts{end}, ...
            '_imec0\pipeline_output\processed\' ...
            'decoder_output_dataframe_for_mattia.csv']);
    catch
        dir_animal = strrep(dir_animal, 'g0', 'g1');
        part2add = strrep(parts{end}, 'g0', 'g1');
        table = readtable([dir_animal, filesep, part2add, ...
            '_imec0\pipeline_output\processed\' ...
            'decoder_output_dataframe_for_mattia.csv']);
    end
    recSummary_decoder.cluImec0 = table.Unnamed_0;
    recSummary_decoder.decoderImec0 = strcmp(table.decoder_label, 'sua');
    recSummary_decoder.thresholdImec0 = strcmp(table.thresholding, 'sua');
end

% check if there is an Imec1 probe in the recSummary file
% then add the decoder/thresholding label to that file

if sum(contains(fieldnames(recSummary), 'Imec1')) > 0
    try
        table = readtable([dir_animal, filesep, parts{end}, ...
            '_imec1\pipeline_output\processed\' ...
            'decoder_output_dataframe_for_mattia.csv']);
    catch
        dir_animal = strrep(dir_animal, 'g0', 'g1');
        part2add = strrep(parts{end}, 'g0', 'g1');
        table = readtable([dir_animal, filesep, part2add, ...
            '_imec1\pipeline_output\processed\' ...
            'decoder_output_dataframe_for_mattia.csv']);
    end
    recSummary_decoder.cluImec1 = table.Unnamed_0;
    recSummary_decoder.decoderImec1 = strcmp(table.decoder_label, 'sua');
    recSummary_decoder.thresholdImec1 = strcmp(table.thresholding, 'sua');
end

end