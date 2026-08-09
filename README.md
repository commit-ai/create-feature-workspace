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

Run the installer once from the directory where you cloned this repo:

```powershell
.\install-create-feature-workspace.ps1
```

This copies the script and creates a `create-feature-workspace.cmd` wrapper in `~\.local\bin` (no Administrator or Developer Mode required). After that you can invoke it from any terminal:

```powershell
create-feature-workspace `
  -FeatureName feature-x `
  -ConfigFile .\repos.ini `
  -WorkspacesRoot ~/workspaces
```

If `~\.local\bin` is not yet in your PATH, the installer will tell you. Add it to your PowerShell profile to persist it across sessions.

If you prefer to skip installation and run the script directly:

```powershell
.\create-feature-workspace.ps1 `
  -FeatureName feature-x `
  -ConfigFile .\repos.ini `
  -WorkspacesRoot ~/workspaces
```

## Workspace Commands

After creating a workspace, run these from inside the workspace directory:

| Command | Unix | PowerShell |
|---------|------|------------|
| Sync desired state | `create-feature-workspace sync` | `create-feature-workspace -Command sync` |
| Add an entry | `create-feature-workspace add --folder-name NAME --folder-path PATH` | `create-feature-workspace -Command add -FolderName NAME -FolderPath PATH` |
| Remove an entry | `create-feature-workspace remove --folder-name NAME` | `create-feature-workspace -Command remove -FolderName NAME` |

## Claude Code Plugin

A Claude Code plugin is available in the `plugins/create-feature-workspace/` directory. It provides four skills:

- **install-create-feature-workspace** — guided installation on Unix and Windows
- **use-create-feature-workspace** — usage reference for all commands and config format
- **add-to-feature-workspace** — step-by-step guidance for adding a new entry
- **remove-from-feature-workspace** — step-by-step guidance for removing an entry

The plugin is registered in `marketplace.json` and can be installed via the Claude Code marketplace.

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
