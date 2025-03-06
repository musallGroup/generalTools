function [fullMat, eventIdx] = makeDesignMatrix_noTrials(events, eventType, regLabels, opts)
% function to generate design matrix from a column matrix with binary
% events. eventType defines the type of design matrix that is generated.
% (1 = fullTrial, 2 = post-event, 3 = peri-event)

fullMat = cell(1,length(eventType));
eventIdx = cell(1,length(eventType));
nrTimes = size(events,1);
nrRegs = length(eventType);

% loop over regressor variables
for iRegs = 1 : nrRegs
    
    % determine index for current event type
    if eventType(iRegs) == 1
        kernelIdx = -opts.preTrig : opts.postTrig; %index for whole trial
    elseif eventType(iRegs) == 2
        kernelIdx = 0 : opts.sPostTime; %index for design matrix to cover post event activity
    elseif eventType(iRegs) == 3
        kernelIdx = -opts.mPreTime : opts.mPostTime; %index for design matrix to cover pre- and post event activity
    else
        error('Unknown event type. Must be a value between 1 and 3.')
    end
    
    % build design matrix
    nrCols = length(kernelIdx);
    trace = logical(events(:,iRegs));
    cIdx = bsxfun(@plus,find(trace),kernelIdx);
    fullMat{iRegs} = false(nrTimes, nrCols);
    for iCols = 1 : nrCols
        useIdx = cIdx(:,iCols);
        useIdx = useIdx(useIdx > 0 & useIdx <= nrTimes); %make sure index is within range of the recording
        fullMat{iRegs}(useIdx, iCols) = true;
    end
    
    cIdx = sum(fullMat{iRegs},1) > 0; %don't use empty regressors
    if sum(~cIdx) > 0
        warning('Removed %i empty regressors from design matrix of regressor %s.\n', sum(~cIdx), regLabels{iRegs})
    end
    fullMat{iRegs} = fullMat{iRegs}(:,cIdx);
    eventIdx{iRegs} = repmat(iRegs, sum(cIdx),1); %keep index on how many regressor were created
end

fullMat = cat(2,fullMat{:}); %combine all regressors into larger matrix
eventIdx = cat(1,eventIdx{:}); %combine index so we need what is what

end