# -*- coding: utf-8 -*-
"""
Created on Sun Aug 11 18:12:46 2024

@author: Anonymous
"""

from pathlib import Path


import numpy as np
from scipy.io import savemat


def convert(p: Path):
    data = np.load(p, allow_pickle=True).item()
    # We only save the masks.
    to_save = {
        "masks": data["masks"]
        }
    savemat(p.with_suffix(".mat"), to_save, appendmat=False)


def main():
    
    root = Path(r"\\Fileserver\Allgemein\transfer\for Irene\TripleRetro-Exports\3C-RGB_flat")
    for path in root.glob("**/*.npy"):
        convert(path)

if __name__ == "__main__":
    main()