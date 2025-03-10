function updateSliderInJointPlots_SN(src, event, hText, corr_mat_plot, connections, diffusion_plot, timer_plot, perf_ax, iSeg, CC_sorted, diffmap, region_per_component, line_strengths, thickness, color_list, transparency, opts)
    frameIdx = round(get(src, 'Value')); % Get slider value
    set(hText, 'String', sprintf(['time ' num2str(opts.tC(frameIdx))])); % Update text
    
    set(corr_mat_plot, 'CData', CC_sorted(:, :, iSeg, frameIdx));

    n_components = size(CC_sorted, 1);
    for i_reg = 1:n_components
        for j_reg = 1:n_components
            if i_reg == j_reg && region_per_component{i_reg} > 1
                set(connections{i_reg, j_reg}, 'SizeData', line_strengths(1) * thickness(i_reg, j_reg, frameIdx), 'CData', reshape(color_list(i_reg, j_reg, frameIdx, 1:3), [1, 3]), 'MarkerFaceAlpha', transparency(i_reg, j_reg, frameIdx));
            elseif region_per_component{i_reg} > 1 && region_per_component{j_reg} > 1
                set(connections{i_reg, j_reg}, 'LineWidth', line_strengths(2) * thickness(i_reg, j_reg, frameIdx), 'Color', reshape(color_list(i_reg, j_reg, frameIdx, :), [1, 4]));
            end
        end
    end

    set(diffusion_plot, 'XData', diffmap(1, frameIdx, iSeg), 'YData', diffmap(2,frameIdx,iSeg), 'ZData', diffmap(3,frameIdx,iSeg));

    set(timer_plot{1}, 'XData', opts.tC(frameIdx), 'YData', opts.Corr_strength{iSeg}(frameIdx));
    set(timer_plot{2}, 'XData', opts.tC(frameIdx), 'YData', opts.perfC(frameIdx));
end

