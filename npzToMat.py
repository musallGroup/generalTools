# -*- coding: utf-8 -*-
"""
Created on Tue Jul  2 11:30:19 2024

@author: musall
"""
# function to convert all npz files in a target folder to .mat files
# Example usage:
# targPath = r'\\Naskampa\lts\invivo_ephys\PNPdata\Open Ephys\2023-10-16_15-46-26\spikeinterface\Record Node 103\experiment1\mountainsort5_LK\sorter_output'
# convert_npz_to_mat(targPath)

from scipy.io import savemat
import numpy as np
import glob
import os

def convert_npz_to_mat(targPath):
    # Ensure the path ends with a separator to properly list files
    if not targPath.endswith(os.path.sep):
        targPath += os.path.sep
        
    # Use raw string to ensure the path is interpreted correctly
    npzFiles = glob.glob(rf"{targPath}*.npz")
    
    if not npzFiles:
        print(f"No .npz files found in the directory: {targPath}")
        return
    
    for f in npzFiles:
        fm = os.path.splitext(f)[0] + '.mat'
        d = np.load(f)
        savemat(fm, d)
        print('Generated', fm, 'from', f)