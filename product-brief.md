# Product Brief — KLT Image

## What This Is

KLT Image is a Mac app that applies decorrelation stretch to photographs using the Karhunen–Loève transform. It reveals subtle color differences while mapping the transformed colors back toward the original image.

## The Problem

Small but meaningful color variations can be difficult to see in ordinary photographs, especially when lighting, backgrounds, and correlated color channels dominate the image. Existing tools can expose these differences, but often require a larger scientific imaging environment or specialized knowledge.

## Who It’s For

The primary user is a researcher, naturalist, photographer, or technically curious image analyst who already understands the basic purpose of PCA or decorrelation stretch. The app should explain its controls clearly without hiding the underlying technique.

The initial use case is examining bird feathers and whole-bird photographs for subtle patterns that are not readily visible.

## Why It Should Exist

KLT Image makes decorrelation stretch available through a focused, native Mac workflow. It combines whole-image processing with region-based statistical sampling, which helps prevent an unrelated background from determining the enhancement.

Unlike tools centered on dramatic false-color results, KLT Image initially emphasizes useful visual comparison and an output that remains interpretable alongside the source.

## What Success Looks Like

A user can open a photograph, choose how the transform is calculated, and immediately compare the original with the enhanced result. They can use either the whole image or a selected region to calculate the color statistics, then export the enhanced image at full resolution.

The output makes subtle feather colors easier to distinguish without obscuring how they relate to the original photograph.

## Founding Decisions

- Native Mac app.
- Visual exploration comes first; quantitative analysis follows later.
- Side-by-side comparison of the original and enhanced image.
- Full-resolution image export.
- Covariance and correlation matrix modes.
- Whole-image or selected-region statistical sampling.
- The calculated transform applies to the full image.
- RGB and Lab color spaces in v1, with RGB as the default.
- Brief, accessible explanations for users who already have some technical understanding.
- DStretch informs the technique, but KLT Image remains a focused standalone tool.

## Out of Scope

- Scientific claims about what an enhancement proves.
- Quantitative measurements, reports, or exported transformation data.
- Custom color spaces.
- Saved or reusable transformation matrices.
- Batch processing.
- Automated feather or bird segmentation.
- Hue isolation and other unrelated enhancement methods.
