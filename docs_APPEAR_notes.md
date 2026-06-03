# APPEAR Notes

The local test run used APPEAR with small compatibility fixes for this dataset
and MATLAB setup:

- load BrainVision `SyncStatus / Sync On` markers as scanner timing anchors;
- keep channels 1:32 for the first-pass workflow, with channel 32 treated as ECG;
- repair non-finite samples before ICA;
- guard ECG channel-location deletion;
- use a configurable `slice_per_TR`, currently set to `37` pending fMRI metadata verification.

These changes are represented by the wrapper/helper scripts in `src/` and
`src/funcs/`. If vanilla APPEAR fails in your MATLAB version, inspect the local
APPEAR compatibility issue before treating it as a data problem.
