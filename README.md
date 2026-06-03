# EEGERP_test

First-pass EEG-fMRI EEG cleaning and synthetic-timeline ERP exploration in MATLAB.

This repository contains wrapper scripts used to:

1. load BrainVision EEG recorded during fMRI,
2. run APPEAR-based MRI/BCG artifact cleaning,
3. generate QC summaries,
4. inject a hard-coded experimental timeline when stimulus triggers are missing,
5. compute a first-pass video-onset ERP.

Raw EEG/fMRI data and generated outputs are intentionally ignored by git.

## Project Layout

```text
EEGERP_test/
  data/
    subject1/
      20260126_sub1_run1.vhdr
      20260126_sub1_run1.vmrk
      20260126_sub1_run1.eeg
  external/
    appear/
  outputs/
  src/
```

## Dependencies

- MATLAB
- Signal Processing Toolbox
- APPEAR: <https://github.com/obada-alzoubi/appear>
- EEGLAB / fMRIB plugins bundled with APPEAR

Put APPEAR in:

```text
external/appear/
```

## Configure Paths And Parameters

Edit:

```text
src/project_config.m
```

Important fields:

```matlab
cfg.subject_id = 'subject1';
cfg.run_id = 'subject1_run1';
cfg.eeg_file_stem = '20260126_sub1_run1';
cfg.first_video_onset_sec = 8.004;
cfg.TR = 2;
cfg.slice_per_TR = 37; % verify from fMRI metadata
```

The synthetic ERP timeline assumes:

```text
8 s blank + 48 * (3 s video + 3 s blank) + 4 s blank = 300 s
```

## Recommended Run Order

In MATLAB:

```matlab
cd('<path-to-EEGERP_test>/src')

run('check_APPEAR_requirements.m')
run('run_subject1_APPEAR.m')
run('qc_subject1_APPEAR.m')
run('check_ERP_readiness_subject1.m')
run('inject_hard_timeline_subject1.m')
run('run_subject1_ERP_from_hardtimeline.m')
```

Optional N400-window visualization:

```matlab
run('plot_subject1_N400_check.m')
```

## Outputs

Main outputs are written under:

```text
outputs/subject1_run1_APPEAR/
```

Useful subfolders:

```text
QC/
ERP_check/
hard_timeline/
ERP_attempt_v3/
```

## Current Interpretation

The synthetic ERP is for exploratory QC only. It is useful for checking whether
video-onset-locked averaging produces microvolt-scale activity, but it should not
be interpreted as a final cognitive ERP result unless the hard timeline is
validated against real stimulus timing and condition labels.
