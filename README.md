# Brain Ventricle Segmentation from MRI

Automatic segmentation of ventricular regions in brain MRI using two fully automatic pipelines: a classical k-means approach and a Mamdani fuzzy inference system.

**Course:** Processing of 2D and 3D Medical Images — Universitat Politècnica de Catalunya (UPC)  
**Academic year:** 2025–2026

---

## Overview

The goal is to segment the ventricular system from paired proton-density (PD) and T2-weighted MR slices (slices 15–21, excluding 16–17). Two independent pipelines are implemented and compared via the Jaccard similarity index against manually annotated ground-truth masks.

---

## Methods

### 1. Classical Pipeline (k-means)

1. **Preprocessing** — contrast stretching with `imadjust`, normalization to uint8, resizing to 512×512
2. **Image fusion** — weighted linear combination of PD and T2 (weights 0.5/0.5)
3. **Segmentation** — k-means clustering with k=4; ventricular cluster selected as the highest-intensity centroid
4. **Morphological refinement** — opening (r=7), erosion (r=3), hole filling, area filtering (threshold: 800 px)
5. **Validation** — Jaccard index against manual ROI masks

### 2. Fuzzy Pipeline (Mamdani FIS)

1. **Preprocessing** — same as classical (T2 only, no fusion required)
2. **Feature extraction** — normalized T2 intensity, Sobel gradient magnitude, inverted normalized distance from center
3. **Mamdani FIS** — 3 inputs × 4/3/3 linguistic terms; 13 IF–THEN rules grouped as: strong, more certainty, medium, negative evidence, safety/mixed
4. **Binary mask** — adaptive alpha-cut at p=86th percentile of foreground pixels (ε=0.16)
5. **Post-processing** — hole filling + area filtering (800 px)
6. **Validation** — Jaccard index

---

## Results

### Classical (k-means)

| Slice | 15 | 18 | 19 | 20 | 21 |
|-------|----|----|----|----|-----|
| Jaccard | — | 0.847 | 0.861 | 0.765 | 0.703 |

### Fuzzy (Mamdani)

| Slice | 15 | 18 | 19 | 20 | 21 |
|-------|----|----|----|----|-----|
| Jaccard | — | 0.821 | 0.851 | 0.789 | 0.823 |

Slice 15 contains no visible ventricles. The fuzzy pipeline shows more consistent performance across slices, particularly for slice 21 where discontinuous ventricular regions are present.

---

## Repository Structure

```
.
├── base_images/               # Original PD and T2 images (slices 15–21)
│   └── mask/                  # Manual ground-truth masks
├── auto_segmentation/         # Classical k-means pipeline
│   ├── final_exam_auto_CARRIERISIMONE.m
│   └── results/               # Per-slice outputs (masks, overlays, Jaccard)
└── fuzzy_segmentation/        # Mamdani FIS pipeline
    ├── create_ventricle_fis.m
    ├── final_exam_fuzzy_CARRIERISIMONE.m
    ├── load_or_generate_masks.m
    ├── segment_ventricles_fuzzy_rules.m
    └── results/               # Per-slice outputs (likelihood maps, masks, overlays)
```

---

## Requirements

- MATLAB R2023a or later
- Image Processing Toolbox
- Fuzzy Logic Toolbox

---

## Usage

**Classical pipeline:**
```matlab
run('auto_segmentation/final_exam_auto_CARRIERISIMONE.m')
```

**Fuzzy pipeline:**
```matlab
run('fuzzy_segmentation/final_exam_fuzzy_CARRIERISIMONE.m')
```

Ground-truth masks for slices other than 18 are generated interactively via `impoly` on first run and saved automatically for subsequent executions.

---

## Dataset

Paired PD and T2-weighted MRI slices (256×256, uint16). Ground-truth ventricular outlines for slice 18 provided; masks for remaining slices defined manually via polygon tool. Images are co-registered — a single mask applies to both modalities.
