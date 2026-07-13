# create-feature-workspace
A script (with Unix/Windows variants) for creating feature workspaces (similarly to Cursor workspaces but tool-agnostic)

## How to Use Them:

### Unix Operating Systems

```bash
./create-feature-workspace.sh \
  --feature-name feature-x \
  --config-file ./repos.ini \
  --workspaces-root ~/workspaces
```

### Windows Operating Systems (PowerShell)

```powershell
.\create-feature-workspace.ps1 `
  -FeatureName feature-x `
  -ConfigFile .\repos.ini `
  -WorkspacesRoot ~/workspaces
```

## To Use It From Anywhere - Add It to the PATH Environment Variable:

```bash
export PATH=/your/place/to/directory_of_script:$PATH
```
