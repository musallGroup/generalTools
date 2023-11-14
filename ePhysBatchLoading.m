recList = {
    
%   
%    'Y:\invivo_ephys\Neuropixels\PV2730_20230818\PV2730_20230818_g0\PV2730_20230818_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
%     'Y:\invivo_ephys\Neuropixels\PV2730_20230817\PV2730_20230817_g0\PV2730_20230817_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
%     'Y:\invivo_ephys\Neuropixels\PV2730_20230816\PV2730_20230816_g0\PV2730_20230816_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
%     'Y:\invivo_ephys\Neuropixels\PV2730_20230815\PV2730_20230815_g0\PV2730_20230815_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
%     %
%     'Y:\invivo_ephys\Neuropixels\PV2728_20230818\PV2728_20230818_g0\PV2728_20230818_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
%      'Y:\invivo_ephys\Neuropixels\PV2728_20230817\PV2728_20230817_g0\PV2728_20230817_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
%     'Y:\invivo_ephys\Neuropixels\PV2728_20230816\PV2728_20230816_g0\PV2728_20230816_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
%     'Y:\invivo_ephys\Neuropixels\PV2728_20230815\PV2728_20230815_g0\PV2728_20230815_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
%     'Y:\invivo_ephys\Neuropixels\PV2728_20230814\PV2728_20230814_g0\PV2728_20230814_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
%     
    'X:\invivo_ephys\Neuropixels\PV2729_20230825\PV2729_20230825_g0\PV2729_20230825_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
    'Y:\invivo_ephys\Neuropixels\PV2729_20230823\PV2729_20230823_g0\PV2729_20230823_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
    
    
    'Y:\invivo_ephys\Neuropixels\PV2731_20230825\PV2731_20230825_g0\PV2731_20230825_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
    'Y:\invivo_ephys\Neuropixels\PV2731_20230824\PV2731_20230824_g0\PV2731_20230824_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
    'Y:\invivo_ephys\Neuropixels\PV2731_20230823\PV2731_20230823_g0\PV2731_20230823_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
    
    
    'Y:\invivo_ephys\Neuropixels\2662_20230601\2662_20230601_g0\2662_20230601_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
    'Y:\invivo_ephys\Neuropixels\2662_20230531\2662_20230531_g0\2662_20230531_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
    'Y:\invivo_ephys\Neuropixels\2662_20230530\2662_20230530_g0\2662_20230530_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
    'Y:\invivo_ephys\Neuropixels\2662_20230529\2662_20230529_g0\2662_20230529_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
    
    'Y:\invivo_ephys\Neuropixels\2661_20230601\2661_20230601_g0\2661_20230601_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
    'Y:\invivo_ephys\Neuropixels\2661_20230531\2661_20230531_g0\2661_20230531_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
    'Y:\invivo_ephys\Neuropixels\2661_20230530\2661_20230530_g0\2661_20230530_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
    'Y:\invivo_ephys\Neuropixels\2661_20230529\2661_20230529_g0\2661_20230529_g0_imec1\spikeinterface_KS2_5_output\sorter_output'
    

    };


 %% 
 clear params
for i= 1 : size(recList,1) 
%%
    myKsDir = recList{i,:};
    params.localPath = 'E:\ephys\Neuropixels';
    params.loadRaw = true;

    %% params.excludeNoise == false if classifier output is not created 

    params.excludeNoise = false;
%     params.loadRaw = false; %if not needed to load from raw data should be declared as false, it saves time


    %% load spike data

    [sp,trigDat, params] = pC_loadKSdir(myKsDir, params);
    
end
