function [DataOut, mask] = arrayMask(DataIn, mask, mode)
% arrayMask - compress/restore image stacks using an inclusion mask.
%
% Wrapper around arrayShrink with inverted mask convention:
%   mask = true  -> pixel is KEPT (e.g. inside brain)
%   mask = false -> pixel is excluded (e.g. outside brain)
%
% This is the opposite of arrayShrink, where mask=true means EXCLUDED.
% All other behaviour (merge/split, NaN fill, datatype handling) is
% identical to arrayShrink.
%
% Usage:
%   flat    = arrayMask(imageStack, brainMask, 'merge')
%   imgBack = arrayMask(flat,       brainMask, 'split')
%
% INPUTS
%   DataIn : image stack [X x Y x ...] for 'merge', or flat matrix for 'split'
%   mask   : logical [X x Y], true = keep
%   mode   : 'merge' (default) or 'split'
%
% OUTPUTS
%   DataOut : compressed flat matrix ('merge') or restored image stack ('split')
%             with NaN at excluded pixels
%   mask    : returned unchanged (inclusion convention preserved)

if ~exist('mode', 'var'), mode = 'merge'; end

[DataOut, ~] = arrayShrink(DataIn, ~mask, mode);
