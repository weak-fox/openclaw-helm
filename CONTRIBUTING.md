# Contributing

Thanks for your interest in contributing.

## Development setup
- Install Helm v3.
- Clone the repo and run checks:
  - `helm lint charts/openclaw`
  - `helm template openclaw charts/openclaw >/tmp/openclaw-rendered.yaml`

## Change guidelines
- Keep chart changes focused and minimal.
- Update docs when values or behavior change.
- For provider-related updates, add or update examples under:
  - `charts/openclaw/examples/providers/`

## Commit and PR
- Use clear commit messages.
- Open a PR with:
  - what changed
  - why it changed
  - how it was tested

## Release notes
- Chart publishing is handled by GitHub Actions.
- Bump `charts/openclaw/Chart.yaml` version when publishing a new chart release.
