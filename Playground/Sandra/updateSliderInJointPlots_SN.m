function updateSliderInJointPlots_SN(src, event, hText, corr_mat_plot, connections, diffusion_plot, timer_plot, perf_ax, iSeg, CC_sorted, diffmap, speed, angles, region_per_component, line_strengths, thickness, color_list, transparency, opts)
    frameIdx = round(get(src, 'Value')); % Get slider value
    set(hText, 'String', sprintf(['time ' num2str(frameIdx)])); % Update text
    % set(hText, 'String', sprintf(['time ' num2str(opts.tC(frameIdx))])); % Update text
    
    set(corr_mat_plot, 'CData', CC_sorted(:, :, iSeg, frameIdx));

    n_components = size(CC_sorted, 1);
    
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

%     for i_reg = 1:n_components
%         for j_reg = 1:n_components
%             if i_reg == j_reg && region_per_component{i_reg} > 1
%                 set(connections{i_reg, j_reg}, 'SizeData', line_strengths(1) * thickness(i_reg, j_reg, frameIdx), 'CData', reshape(color_list(i_reg, j_reg, frameIdx, 1:3), [1, 3]), 'MarkerFaceAlpha', transparency(i_reg, j_reg, frameIdx));
%             elseif region_per_component{i_reg} > 1 && region_per_component{j_reg} > 1
%                 set(connections{i_reg, j_reg}, 'LineWidth', line_strengths(2) * thickness(i_reg, j_reg, frameIdx), 'Color', reshape(color_list(i_reg, j_reg, frameIdx, :), [1, 4]));
%             end
%         end
%     end

    set(diffusion_plot, 'XData', diffmap(1, frameIdx, iSeg), 'YData', diffmap(2,frameIdx,iSeg), 'ZData', diffmap(3,frameIdx,iSeg));

    set(timer_plot{1}, 'XData', frameIdx, 'YData', opts.Corr_strength{iSeg}(frameIdx));
    set(timer_plot{2}, 'XData', frameIdx, 'YData', opts.perfC(frameIdx));
    % set(timer_plot{1}, 'XData', opts.tC(frameIdx), 'YData', opts.Corr_strength{iSeg}(frameIdx));
    % set(timer_plot{2}, 'XData', opts.tC(frameIdx), 'YData', opts.perfC(frameIdx));
    if frameIdx < length(opts.tC) - opts.diff_lag
        set(timer_plot{3}, 'XData', frameIdx, 'YData', speed(frameIdx));
        set(timer_plot{4}, 'XData', frameIdx, 'YData', angles(frameIdx));
        % set(timer_plot{3}, 'XData', opts.tC(frameIdx), 'YData', speed(frameIdx));
        % set(timer_plot{4}, 'XData', opts.tC(frameIdx), 'YData', angles(frameIdx));
    else
        set(timer_plot{3}, 'XData', length(opts.tC) - opts.diff_lag, 'YData', speed(end));
        set(timer_plot{4}, 'XData', length(opts.tC) - opts.diff_lag - 1, 'YData', angles(end));
        % set(timer_plot{3}, 'XData', opts.tC(end - opts.diff_lag), 'YData', speed(end));
        % set(timer_plot{4}, 'XData', opts.tC(end - opts.diff_lag - 1), 'YData', angles(end));
    end
end

