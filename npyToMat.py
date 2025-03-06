# -*- coding: utf-8 -*-
"""
Created on Tue Jul  2 11:44:45 2024

@author: musall
"""
# function to convert all npy files in a target folder to .mat files
# Example usage:
# targPath = r'\\Naskampa\lts\invivo_ephys\PNPdata\Open Ephys\2023-10-16_15-46-26\spikeinterface\Record Node 103\experiment1\mountainsort5_LK\sorter_output'
# convert_npz_to_mat(targPath)
#
# to convert a single npy file you can use:
# npyFilePath = r'\\Naskampa\lts\invivo_ephys\PNPdata\Open Ephys\2023-10-16_15-46-26\spikeinterface\Record Node 103\experiment1\kilosort_2_5\sorter_output\spikes.npy'
# convert_single_npy_to_mat(npyFilePath)


from scipy.io import savemat
import numpy as np
import glob
import os

def convert_single_npy_to_mat(npyFilePath):
    print('===================')
    print(npyFilePath)
    if not os.path.isfile(npyFilePath):
        print(f"The file {npyFilePath} does not exist.")
        print('===================')
        return
    
    fm = os.path.splitext(npyFilePath)[0] + '.mat'
    d = np.load(npyFilePath, allow_pickle=True)

    if isinstance(d, np.ndarray) and d.dtype.names is not None:
        # If the array has fields (is a structured array)
        mat_dict = {name: d[name] for name in d.dtype.names}
        savemat(fm, mat_dict)
        print('Generated', fm, 'from', npyFilePath)
    else:
        print('The npy file does not contain a structured numpy array. Please check the file format.')
        
    print('===================')
    
    

def convert_npy_to_mat(targPath):
    if not targPath.endswith(os.path.sep):
        targPath += os.path.sep
        
    npyFiles = glob.glob(rf"{targPath}*.npy")
    
    if not npyFiles:
        print(f"No .npy files found in the directory: {targPath}")
        return
    
    for f in npyFiles:
        convert_single_npy_to_mat(f)
