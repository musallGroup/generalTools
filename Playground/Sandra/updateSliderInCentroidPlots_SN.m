function updateSliderInCentroidPlots_SN(src, event, hText, corr_mat_plot, connections, centroids, line_strengths, thickness, color_list, transparency)
    frameIdx = round(get(src, 'Value')); % Get slider value
    set(hText, 'String', sprintf(['time ' num2str(frameIdx)])); % Update text
    % set(hText, 'String', sprintf(['time ' num2str(opts.tC(frameIdx))])); % Update text
    
    set(corr_mat_plot, 'CData', centroids{frameIdx});

    n_components = size(centroids{1}, 1);
    
    %set diagnotal values
    diag_indices = sub2ind([n_components, n_components], 1:n_components, 1:n_components);
    useIdx = ~cellfun(@isempty, (connections(diag_indices)));
    cColor = reshape(color_list(:,:,frameIdx,1:3), n_components^2, []);
    cThick = thickness(:, :, frameIdx);
    cTrans = transparency(:, :, frameIdx);
    set(cat(1,connections{diag_indices(useIdx)}), {'SizeData', 'CData', 'MarkerFaceAlpha'}, [num2cell(line_strengths(1) * cThick(diag_indices(useIdx))'), num2cell(cColor(diag_indices(useIdx), :),2), num2cell(cTrans(diag_indices(useIdx))')]);
    
    % set non-diagonal values
    all_indices = 1:n_components^2;
    non_diag_indices = setdiff(all_indices, diag_indices);
    useIdx = ~cellfun(@isempty, (connections(non_diag_indices)));
    cColor = reshape(color_list(:,:,frameIdx,1:4), n_components^2, []);
    set(cat(1,connections{non_diag_indices(useIdx)}), {'LineWidth', 'Color'}, [num2cell(line_strengths(2) * cThick(non_diag_indices(useIdx))'), num2cell(cColor(non_diag_indices(useIdx), :),2)]);

end

