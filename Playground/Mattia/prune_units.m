function [recSummary_thr, recSummary_dec] = prune_units(recSummary_decoder)
% function that only keeps units/spikes/clusters that have been
% labeled as SUA by Anoushka's decoder or threshold

% start by pruning according to threshold
recSummary_thr = recSummary_decoder;
fields = fieldnames(recSummary_thr);
% imec0
imec0_fields = {fields{contains(fields, 'Imec0') & ...
    contains(fields, 'clusters')}};
if ~ isempty(imec0_fields)
    clu2keep = recSummary_thr.cluImec0(recSummary_thr.thresholdImec0);
    for field = 1 : numel(imec0_fields)
        clu2keep_area = ismember(...
            recSummary_thr.(imec0_fields{field}), clu2keep);
        recSummary_thr.(imec0_fields{field}) = ...
            recSummary_thr.(imec0_fields{field})(clu2keep_area);
    end
end
% imec1
imec1_fields = {fields{contains(fields, 'Imec1') & ...
    contains(fields, 'clusters')}};
if ~ isempty(imec1_fields)
    clu2keep = recSummary_thr.cluImec1(recSummary_thr.thresholdImec1);
    for field = 1 : numel(imec1_fields)
        clu2keep_area = ismember(...
            recSummary_thr.(imec1_fields{field}), clu2keep);
        recSummary_thr.(imec1_fields{field}) = ...
            recSummary_thr.(imec1_fields{field})(clu2keep_area);
    end
end
% then move to decoder
recSummary_dec = recSummary_decoder;
fields = fieldnames(recSummary_dec);
% imec0
imec0_fields = {fields{contains(fields, 'Imec0') & ...
    contains(fields, 'clusters')}};
if ~ isempty(imec0_fields)
    clu2keep = recSummary_dec.cluImec0(recSummary_dec.decoderImec0);
    for field = 1 : numel(imec0_fields)
        clu2keep_area = ismember(...
            recSummary_dec.(imec0_fields{field}), clu2keep);
        recSummary_dec.(imec0_fields{field}) = ...
            recSummary_dec.(imec0_fields{field})(clu2keep_area);
    end
end
% imec1
imec1_fields = {fields{contains(fields, 'Imec1') & ...
    contains(fields, 'clusters')}};
if ~ isempty(imec1_fields)
    clu2keep = recSummary_dec.cluImec1(recSummary_dec.decoderImec1);
    for field = 1 : numel(imec1_fields)
        clu2keep_area = ismember(...
            recSummary_dec.(imec1_fields{field}), clu2keep);
        recSummary_dec.(imec1_fields{field}) = ...
            recSummary_dec.(imec1_fields{field})(clu2keep_area);
    end
end