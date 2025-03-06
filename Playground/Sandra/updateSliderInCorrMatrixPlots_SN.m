function updateSliderInCorrMatrixPlots_SN(src, event, hText, images, CC, CC_sorted, opts, cluster_ver)
    frameIdx = round(get(src, 'Value')); % Get slider value
    set(hText, 'String', sprintf(['time ' num2str(opts.tC(frameIdx))])); % Update text
    
    for i = 1:length(opts.plot_segments)
        iSeg = opts.plot_segments(i);
        set(images{i}, 'XData', opts.tC(frameIdx), 'Ydata', opts.Corr_strength{iSeg}(frameIdx)); % Update image
        set(images{i+length(opts.plot_segments)}, 'CData', CC(:, :, iSeg, frameIdx)); % Update image
        if ~strcmp(cluster_ver, "")
            set(images{i+2*length(opts.plot_segments)}, 'CData', CC_sorted(:, :, iSeg, frameIdx)); % Update image
        end
    end
end