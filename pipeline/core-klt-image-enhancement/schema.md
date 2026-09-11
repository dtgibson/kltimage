# Schema — Core RGB Enhancement Workflow

## Path

Frontend Only — No data layer changes required

## Confirmation

The PRD requires local image import, in-memory processing, comparison, and file export. It creates no database records, stored relationships, migrations, or remote data.

## Existing Data Used by This Feature

### Source Image

- Data used: decoded RGB channels, pixel dimensions, orientation, color profile, and optional alpha channel.
- How used: RGB pixels supply the covariance calculation; dimensions, orientation, profile, and alpha govern display and export.
- Lifetime: retained only while the image is open.

### Enhanced Image

- Data used: transformed RGB pixels plus the source dimensions, orientation, profile, and alpha channel.
- How used: displayed beside the original and written only when the user exports it.
- Lifetime: held in memory until replaced or the app closes.

### External Services

None. Processing is local and no API endpoints are required.

## No Data Layer Work Required

The Engineer can proceed directly to native application and image-processing implementation. No database, persistent model, backend, or migration is needed.
