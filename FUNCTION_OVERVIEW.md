# generalTools Function Overview

**Last updated:** 2026-05-25  
**Total functions:** 246+ (excluding libraries)

This is the central reference for functions available in the generalTools repository. Use Ctrl+F to search for specific functionality. When implementing new features, check here first to avoid re-inventing existing solutions.

---

## Array & Matrix Operations

| Function | Location | Description |
|----------|----------|-------------|
| `arrayCorr` | root | Compute correlation coefficient between two matrices (rows) |
| `arrayCrop` | root | Apply a mask to an image or stack of images |
| `arrayFilter` | root | Apply gaussian or box filter to array |
| `arrayIndex` | root | Index from any dimension using specified indices |
| `arrayMask` | root | Compress/restore image stacks using an inclusion/exclusion mask |
| `arrayOutline` | root | Get area outlines from a binary map (Allen atlas convention) |
| `arrayPlot` | root | Plot all columns of data matrix as individual lines plus mean |
| `arrayResamp` | root | Change sampling rate using resample command |
| `arrayResize` | root | Downsample image stack based on averaging through symmetric box filter |
| `arrayShrink` | root | Merge first two dimensions of matrix and remove pixels outside brain |
| `combvec` | root | Create all combinations of vectors |
| `insertColumns` | root | Insert columns filled with specified value at given locations |
| `maxnorm` | root | Normalize content of array between 0 and 1 |
| `removeOutline` | root | Crop outer edge of image created by outlineAndSmooth |
| `vec` | Playground/Gerion | Reduce dimensions of data to 1D |

---

## Signal Processing & Filtering

| Function | Location | Description |
|----------|----------|-------------|
| `applyCorrection` | root | Apply drift correction to time series data |
| `makeCorrection` | root | Compute clock drift correction using trigger-based alignment |
| `lowpassData` | root | Apply lowpass filter to imaging data |
| `simpleNotch` | root | Apply notch filter at specified frequency |
| `exponentialFilter` | root | Generate 1D exponential filter kernel with decay time |
| `runMean` | root | Compute running average (handles NaN values) |
| `runMeanWeight` | Playground/Gerion | Running average with sample weighting |
| `removeMedian` | root | Remove median across segments of data |
| `detrendTrace` | Playground/Simon | Remove slow trends from data trace |
| `smooth2a` | root | Smooth 2D array data (ignores NaN) |
| `smoothCol` | root | Smooth columns of data matrix |
| `smoothImg` | root | Apply gaussian or box filter to 2D image |
| `outlineAndSmooth` | root | Outline image and smooth results |

---

## Plotting & Visualization

| Function | Location | Description |
|----------|----------|-------------|
| `errorshade` | root | Plot line with error shading (upper/lower bounds) |
| `stdshade` | root | Plot line with standard deviation shading |
| `betterFigure` | root | Improve data visualization in current axis |
| `niceFigure` | root | Improve data visualization in current axis |
| `nBarweb` | root | Grouped bar plot with error bars and optional individual points |
| `raincloud_plot` | root | Create raincloud plots (distribution + scatter) |
| `regressorBoxPlot` | root | Box plot for categorical data with optional individual points |
| `mysigstar` | root | Add significance stars/brackets to plots |
| `compareMovie` | root | Visualize 3D data stack interactively |
| `imageScale` | root | Plot image with NaNs as transparent |
| `nvline` | root | Vertical line(s) at specified x positions |
| `nhline` | root | Horizontal line(s) at specified y positions |
| `freezeColors` | root | Lock colors of plot (allows multiple colormaps per figure) |
| `unfreezeColors` | root | Restore colors of plot to original indexed color |
| `figToPDF` | root | Save figure as PDF (vector, via print/painters) and PNG (600 dpi) on A4 |
| `plotRowsWithColormap` | Playground/Simon | Plot each row of matrix with colors from colormap |
| `plot_with_error_shading_GN` | Playground/Gerion | Plot average trace with error shading |
| `reverseAxisColor` | Playground/Simon | Switch colors from black-on-white to white-on-black |

---

## Image Processing

| Function | Location | Description |
|----------|----------|-------------|
| `createCircle` | root | Create logical image of circle with specified diameter and center |
| `smoothImg` | root | Apply gaussian or box filter to 2D image |
| `parseTifHeader` | root | Parse TIFF header metadata |
| `readTIFFstack` | root | Load multi-frame TIFF stacks |
| `parseScanimageMeta` | root | Decode ScanImage metadata from TIF files |
| `fwhm` | root | Compute full-width at half-maximum |
| `svdFrameReconstruct` | root | Reconstruct frames from SVD components |

---

## Data Analysis & Statistics

| Function | Location | Description |
|----------|----------|-------------|
| `LME_compare` | root | Compare two variables using mixed-effects model, controlling for random effects |
| `LME_compareMulti` | root | Compare measurements across conditions using mixed-effects model |
| `LME_compare_2vars` | root | Compare role of two variables while controlling for random effects |
| `colAUC` | root | Calculate Area Under ROC curve for vector or matrix columns |
| `computeROC` | root | Compute ROC curve (AUC, d', hit rate, false alarm rate) |
| `binomCompare` | root | Test if two binomial distributions differ significantly |
| `myBinomTest` | root | Binomial test (simple/two-sided) |
| `avrRank` | root | Compute sample ranks with tie handling |
| `fdrCorrect` | root | Benjamini-Hochberg false discovery rate correction |
| `gT_ridgeMML` | root | Ridge regression with maximum marginal likelihood |
| `salt` | root | Stimulus-associated spike latency test |
| `selectBehaviorTrials` | root | Select subset of trials based on conditions |
| `Behavior_wilsonError` | root | Wilson score confidence intervals for binomial proportions |
| `BinoPlot` | root | Plot binomial data with optional linear/sigmoid fitting |
| `getConfidenceIntervals` | Playground/Simon | Compute 95% confidence intervals via bootstrapping |
| `compute95CI` | Playground/Gerion | Infer dimension and compute 95% CI |

### NaN Handling (MATLAB 2025+ compatibility wrappers)

| Function | Location | Description |
|----------|----------|-------------|
| `nanmean` | root | Mean ignoring NaN values (wraps `mean(..., 'omitnan')`) |
| `nanmedian` | root | Median ignoring NaN values (wraps `median(..., 'omitnan')`) |
| `nanstd` | root | Standard deviation ignoring NaN values (wraps `std(..., 'omitnan')`) |
| `nansum` | root | Sum ignoring NaN values (wraps `sum(..., 'omitnan')`) |
| `nanmin` | root | Minimum ignoring NaN values (wraps `min(..., 'omitnan')`) |
| `nanmax` | root | Maximum ignoring NaN values (wraps `max(..., 'omitnan')`) |

---

## Behavior Analysis & Bpod Data

| Function | Location | Description |
|----------|----------|-------------|
| `getBpodTriggers` | root | Extract trial triggers from digital line recorded from Bpod |
| `getBpodTriggers_Neurophotometrics` | root | Extract trial triggers for Neurophotometrics recordings |
| `getMultiSessionBpodTriggers` | Playground/Simon | Extract triggers across multiple sessions |
| `getBpodTriggers_MC` | Playground/Mattia | Extract trial triggers (Mattia's version) |
| `Behavior_vidResamp` | root | Adjust single-trial video data to target framerate |
| `appendBehavior` | root | Collect data from behavioral files into unified array |
| `checkBpodModulePort` | root | Find Bpod modules and check ports |
| `findBhvFile` | root | Find behavioral files from Bpod system |
| `findBhvFile_MC` | Playground/Mattia | Find behavioral files (Mattia's version) |
| `cleanTriggers` | Playground/Mattia | Validate and clean trial triggers |
| `selectBehaviorTrials` | root | Select subset of trials based on conditions |
| `bhvVideoToServer` | root | Move behavioral video data from local PC to server |
| `bhvVideoToHDD` | root | Move behavioral video data from local PC to HDD |
| `bhvVideoToTape` | root | Move behavioral video data to tape drive |
| `bpod_checkSessions` | bpod/ | Check behavioral data and collect across sessions |
| `bpod_createTrainingOverview` | bpod/ | Set up basic variables and collect behavior overview |

---

## File I/O & Data Management

| Function | Location | Description |
|----------|----------|-------------|
| `checkServerFile` | root | Check for file locally or on server, copy if needed |
| `checkServerDataConsistency_SM` | Playground/Simon | Verify behavioral data consistency across storage |
| `makeLocal` | root | Load file from server and create local copy if needed |
| `avoidOverwrite` | root | Check if file exists and create new filename if necessary |
| `saveMatToAvi` | root | Convert 3D matrix to short movie sequence (AVI) |
| `readTIFFstack` | root | Load multi-frame TIFF stacks |
| `compareFileHeadAndTail` | root | Compare first and last N bytes of two files |
| `removeDrivesFromHistory` | root | Remove local drive paths from history/cache |
| `TwoPhotonToServer` | root | Move imaging data from local PC to server or external drive |
| `twoPhotonToTape` | root | Move imaging data to tape drive |
| `ephysToTape` | root | Move ephys data to tape drive folder |
| `compressTIFwith7zip` | root | Compress TIF file and verify archive integrity |
| `decompressEphysInFolder` | root | Decompress ephys data in .cbin format |
| `unzip7z` | root | Unzip 7z archives |
| `convertMJ2` | root | Convert MJ2 files to MP4 |
| `GetGoogleSpreadsheet` | root | Download Google Spreadsheet as CSV into MATLAB cell array |
| `getRecordingsFromGooglesheet` | root | Select specific recordings from Google Sheet |
| `loadSessionData` | Playground/Mattia | Load behavioral session data |
| `loadVideoData` | Playground/Mattia | Load video data from session |

---

## Spike & Ephys Data

| Function | Location | Description |
|----------|----------|-------------|
| `parseSpikeGLXgalvo` | root | Parse galvo position data from SpikeGLX |
| `gt_readSpikeGLXmeta` | root | Read SpikeGLX metadata file |
| `readNPXmeta` | root | Read Neuropixel metadata file |
| `readClusterGroupsTSV` | root | Read Kilosort cluster group assignments |
| `prune_units` | Playground/Mattia | Keep only units/spikes/clusters meeting quality criteria |
| `add_decoder_output` | Playground/Mattia | Add Anoushka's decoder output to RecSummary |

---

## Barcode & Encoding

| Function | Location | Description |
|----------|----------|-------------|
| `encode2of5` | root | Encode modified 2-of-5 barcode |
| `decode2of5` | root | Decode 2-of-5 barcode |
| `voltageToBarcode` | root | Convert voltage trace to barcode sequence |
| `segmentVoltageAndReadBarcodes` | root | Segment voltage and read barcode sequence |

---

## Time & Alignment

| Function | Location | Description |
|----------|----------|-------------|
| `digitalToTimestamp` | root | Convert binary data to timestamps |
| `makeDesignMatrix` | root | Generate design matrix from binary column (trial onsets) |
| `makeDesignMatrix_noTrials` | root | Generate design matrix without trial-based structure |
| `findMinDiffs` | root | Find minimum differences between two vectors |
| `totalMinDiffs` | root | Remove worst N differences (keep best matches) |

---

## Colormaps

| Function | Location | Description |
|----------|----------|-------------|
| `colormap_blueblackred` | root | Blue-black-red diverging colormap (preferred for diverging data) |
| `inferno` | root | Viridis-style colormap (dark to yellow) |
| `magma` | root | Viridis-style colormap (dark to bright) |
| `plasma` | root | Viridis-style colormap (purple to yellow) |
| `viridis` | root | Viridis colormap (blue to yellow, perceptually uniform) |
| `PRGn` | root | Purple-green diverging colormap |
| `PiYG` | root | Pink-yellow-green diverging colormap |
| `RdBu` | root | Red-blue diverging colormap |
| `bluewhitered` | root | Blue-white-red colormap |
| `berlin` | root | Cool/warm colormap |
| `managua` | root | Colormap |
| `vanimo` | root | Colormap |

---

## Utility Functions

| Function | Location | Description |
|----------|----------|-------------|
| `keep` | root | Clear workspace variables except specified ones |
| `cprintf` | root | Display styled formatted text in command window |
| `natsort` | root | Natural-order (alphanumeric) sort of text array |
| `natsortfiles` | root | Natural-order sort of filenames/foldernames |
| `makeLogical` | root | Create logical vector from index array |
| `fastDec2bin` | root | Fast decimal to binary conversion |
| `exponentialFit` | Playground/Simon | Fit data with exponential function (A, tau) |
| `gamma_distribution` | Playground/Simon | Define shape/scale parameters of gamma distribution |
| `loopReporter` | Playground/Simon | Report progress in for loop |
| `rescaleMatrix` | Playground/Simon | Rescale 2D/3D matrix to new dimensions |
| `txt2pdf` | root | Convert .txt to multi-page A4 PDF |
| `copyCommonFields` | root | Copy matching fields from one struct to another |
| `getAllenAreas` | root | Isolate individual areas from Allen atlas |
| `checkStimData` | root | Resolve unique combinations of stimulus conditions |
| `fig_size` | Playground/Gerion | Adjust figure size |
| `get_significance_str` | Playground/Gerion | Generate significance string from p-value |
| `make_dir` | Playground/Gerion | Create directory if doesn't exist |
| `mergeStructs` | Playground/Gerion | Merge two structs (second overwrites first) |
| `abs_paths` | Playground/Gerion | Get absolute file paths in directory |
| `abs_paths_str` | Playground/Gerion | Get absolute paths as string array |
| `weighted_std_multi_dim` | Playground/Gerion | Weighted standard deviation across dimensions |
| `vec` | Playground/Gerion | Flatten array to 1D |
| `compareFolders` | Playground/Simon | Compare contents of two folders |
| `traceMovie` | Playground/Simon | Create movie of trace updates |
| `updateFrame` | Playground/Simon | Update frame in visualization |
| `makeMovieFromBinary` | Playground/Simon | Create movie from binary file |
| `restoreAviFromTapeTransfer` | Playground/Simon | Restore AVI from tape transfer |
| `plotCabinetDatalog` | Playground/Simon | Read daily CSV logs and plot monthly summaries |

---

## Playground Scripts (Author-Specific)

### Irene's Atlas & Histology Tools
- `AtlasTransformBrowser_IL` — Browse Allen atlas with histology alignment
- `HistologyBrowser_IL` — Interactive histology image viewer with contrast controls
- `LoadAverageBrainSlices_anterogradeALM_IL` — Load average brain slices for anterograde tracing
- `Navigate_Atlas_and_Register_Slices_IL` — Navigation tool for atlas and registration
- `NeuronDistributionALM` — Analyze neuron distribution in ALM
- `NeuronOverlapALM` — Analyze neuronal overlap across regions
- `NeuronOverlapALM_Depth` — Analyze neuronal overlap with depth information
- `PlotMasksOutlines` — Visualize masks and outlines on images
- `Process_Histology_IL` — Batch process histology images
- `ProcessAlignedData_IL` — Process aligned imaging data
- `ProcessAlignedData_ForPlots_IL` — Process aligned data for figure generation
- `ProcessAlignedDataIpsiContra_IL` — Analyze ipsilateral/contralateral data
- `SliceFlipper_IL` — Crop, sharpen, and flip slice images

### Mattia's Behavior & Decoding
- `add_decoder_output` — Add decoder output to RecSummary files
- `cleanTriggers` — Validate and clean trial triggers
- `findBhvFile_MC` — Find behavioral files from Bpod
- `find_dir` — Find animal/session directories
- `getBpodTriggers_MC` — Extract trial triggers
- `loadSessionData` — Load behavioral session data
- `loadVideoData` — Load video data from session
- `prune_units` — Filter units by quality criteria

### Sacha & Severin's Atlas Tools
- `AtlasTransformBrowser_SAR` / `_SG` — Browse Allen atlas
- `Navigate_Atlas_and_Register_Slices_SAR` / `_SG` — Atlas navigation and registration
- `ProcessAlignedData_SAR` / `_SG` — Process aligned imaging data
- `Process_Histology_SAR` / `_SG` — Batch histology processing
- `makeTif_SG` — Create TIFF from processed data
- `setup_utils` — Utility setup functions
- `table_matlab_to_excel` — Convert MATLAB table to Excel

### Sandra's Interactive Plotting
- `updateSliderInAllAnimalPlots_SN` — Update slider across all animal plots
- `updateSliderInBrainPlots_SN` — Update brain connectivity visualization
- `updateSliderInCentroidPlots_SN` — Update centroid plots
- `updateSliderInCorrMatrixPlots_SN` — Update correlation matrix plots
- `updateSliderInJointPlots_SN` — Update joint plots
- `updateSliderInStablePlots_SN` — Update stability plots

### Simon's Analysis & Utilities
- `checkServerDataConsistency_SM` — Verify data consistency
- `compareFolders` — Compare folder contents
- `detrendTrace` — Remove slow trends from traces
- `exponentialFit` — Fit exponential functions
- `gamma_distribution` — Define gamma distributions
- `getConfidenceIntervals` — Bootstrap confidence intervals
- `getMultiSessionBpodTriggers` — Extract multi-session triggers
- `loopReporter` — Report loop progress
- `makeMovieFromBinary` — Create movies from binary files
- `moveSourcefileToLocal` — Move files to local storage
- `plotCabinetDatalog` — Plot Cabinet datalogging
- `plotRowsWithColormap` — Plot rows with colormap coloring
- `readTIFFstack` — Load TIFF stacks
- `rescaleMatrix` — Rescale matrices
- `restoreAviFromTapeTransfer` — Restore transferred AVI files
- `reverseAxisColor` — Invert plot colors
- `runSuite2pScript_SM` — Batch Suite2p processing
- `traceMovie` — Visualize trace updates

### Gerion's Statistical & Utility Functions
- `alignAllenTransIm_GN` — Align image to Allen atlas
- `compute95CI` — Compute 95% confidence intervals
- `fig_size` — Set figure size
- `get_significance_str` — Generate significance strings
- `make_dir` — Create directories
- `mergeStructs` — Merge struct arrays
- `plot_with_error_shading_GN` — Plot with error shading
- `runMeanWeight` — Weighted running average
- `test_binomial_difference` — Statistical test for binomial distributions
- `vec` — Flatten arrays
- `weighted_std_multi_dim` — Weighted standard deviation
- `LME_compare_GN` — Mixed-effects model comparison

### Elisabeta's Analysis
- `colAUC_EB` — Area under ROC curve variant

---

## Libraries & Packages

| Library | Location | Description |
|---------|----------|-------------|
| **ScanImageTiffReader** | +ScanImageTiffReader/ | MATLAB package for reading TIFF/BigTIFF files from ScanImage recordings |
| **NPY-MATLAB** | npy-matlab/ | NumPy .npy format I/O for MATLAB |
| **EasyH5** | easyH5/ | Simplified HDF5 file handling |
| **ViolinPlot** | violinPlot/ | Violin plot visualization toolbox |
| **Colormaps** | colormaps/ | Perceptually uniform colormaps (viridis, inferno, etc.) |

---

## How to Use This Reference

1. **Search by function name:** Use Ctrl+F to find specific functions
2. **Search by category:** Look for relevant section (plotting, signal processing, etc.)
3. **Check before implementing:** When solving a problem, search here first to avoid duplicating existing code
4. **Ask Claude about contents:** Reference the overview when asking if generalTools has a function for something

**For new lab members:** This is your go-to reference for general-purpose tools already available. Exploring these functions can speed up your analysis pipelines considerably.

