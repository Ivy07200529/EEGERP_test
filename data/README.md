# Data Folder

Place local EEG data here. Raw data are ignored by git.

Expected example layout:

```text
data/
  subject1/
    20260126_sub1_run1.vhdr
    20260126_sub1_run1.vmrk
    20260126_sub1_run1.eeg
```

Update `src/project_config.m` if your subject ID, run ID, or file stem differs.
