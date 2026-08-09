# create-feature-workspace
A script (with Unix/Windows variants) for creating feature workspaces (similarly to Cursor workspaces but tool-agnostic)

## How to Use Them:

### Unix Operating Systems

```bash
./install-create-feature-workspace.sh

create-feature-workspace \
  --feature-name feature-x \
  --config-file ./repos.ini \
  --workspaces-root ~/workspaces
```

If you prefer not to install a symlink, you can also run the script directly:

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

## To Use It From Anywhere - Add Its Folder to the PATH Environment Variable:

```bash
export PATH=/your/place/to/directory_of_script:$PATH
```

## Workspace metadata files

Each workspace contains two hidden metadata files:

- `.create-feature-workspace.desired.ini` is the desired workspace definition. Edit this file to add, remove, or change entries, then run `sync`.
- `.create-feature-workspace.provisioned.ini` records the entries the tool successfully created. It is managed by the tool and should not be edited.

They may look similar immediately after creation because the workspace matches its desired definition. They can differ while changes are being reconciled, and the provisioned record lets the tool distinguish entries it owns from unrelated files in the workspace.

Copyrighy © 2026 Commit AI. All rights reserved.
