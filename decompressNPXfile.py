import numpy as np
from pathlib import Path
from mtscomp import compress, Reader
import sys

def decompressNPXfile(cFile):

    # cFile = Path(r'\\naskampa\lts\invivo_ephys\Neuropixels\2097_20210323a\2097_20210323a_g0\2097_20210323a_g0_imec0\2097_20210323a_g0_t0.imec0.ap.bin')
    cBinFile = Path(cFile)
    metaFile = cBinFile.with_suffix('.meta')
    binFile = cBinFile.with_suffix('.bin')
    chFile = cBinFile.with_suffix('.ch')
    
    metaInfo = readMeta(metaFile)
    metaInfo['imSampRate']
    
    # code for decompression
    if binFile.exists():
        print("bin file already exists. Aborted decompression of cbin file.")
    else:
        r = Reader()
        r.open(cBinFile, chFile)
        r.tofile(binFile)
        r.close()

# =========================================================
# Parse ini file returning a dictionary whose keys are the metadata
# left-hand-side-tags, and values are string versions of the right-hand-side
# metadata values. We remove any leading '~' characters in the tags to match
# the MATLAB version of readMeta.
#
# The string values are converted to numbers using the "int" and "float"
# fucntions. Note that python 3 has no size limit for integers.

def readMeta(metaPath):
    metaDict = {}
    if metaPath.exists():
        # print("meta file present")
        with metaPath.open() as f:
            mdatList = f.read().splitlines()
            # convert the list entries into key value pairs
            for m in mdatList:
                csList = m.split(sep='=')
                if csList[0][0] == '~':
                    currKey = csList[0][1:len(csList[0])]
                else:
                    currKey = csList[0]
                metaDict.update({currKey: csList[1]})
    else:
        print("no meta file")
        
    return(metaDict)
    
if __name__ == "__main__":
    decompressNPXfile(sys.argv[1])