# fsl_first_subcortical_segmentation

Batch [FSL FIRST](https://fsl.fmrib.ox.ac.uk/fsl/docs/structural/first.html) subcortical segmentation for all `.nii` / `.nii.gz` files in a directory.

## Requirements

- FSL installed

## Usage

```bash
./scripts/batch_run_first_all.sh INPUT_DIR --output-dir DIR --brain-extracted <true|false> [--maxdepth N]
```

- **`INPUT_DIR`**: Folder to search (default: only that folder’s files, not subfolders; use `--maxdepth` to include deeper levels).
- **`--output-dir`**: **Required.** Root directory for all FIRST outputs (created if it does not exist). For each input file, `run_first_all -o` is set to `DIR` plus the path of that file **relative to `INPUT_DIR`**, with `.nii.gz` or `.nii` removed—so subfolders are mirrored under `DIR` and same basenames in different folders do not collide. `run_first_all` still adds suffixes such as `_all_fast_firstseg.nii.gz`, `_all_fast_origsegs.nii.gz`, and `_first.vtk`.
- **`--brain-extracted`**: **Required.** `true` / `1` / `yes` if volumes are already brain-extracted (no skull); the script passes **`-b`** to `run_first_all`. `false` / `0` / `no` for whole-head T1 (no `-b`).

Example (whole-head T1 in `montreal/images`, outputs under `first_out/`):

```bash
./scripts/batch_run_first_all.sh montreal/images --output-dir first_out --brain-extracted false
```

For montreal dataset, the running time is roughly 1h 10min totally for 10 subjects. One sample running time is roughly 7 minutes.

## Registration QC

If `first_flirt` registration is wrong, segmentation will be unreliable even if the command finishes. Registration and mesh outputs live under your `--output-dir` tree; you can `find DIR -name '*_to_std_sub.nii.gz'` and use `slicesdir` with the MNI template as described in the FIRST documentation.
