# Closeout

The new module has no prior source copy or standalone tester to retire. No
temporary server or browser was started. Current sources, Git history, package,
test evidence, generated build files and registry dependencies are retained.
Nothing was moved to Trash; no space-reclamation claim is made.

`manifest.json` records the retention decisions and empty move/restore mapping.
After the local commit, `.validation-cache/source.bundle` contains the full Git
history through delivery HEAD. `.validation-cache/final-receipt.json` records
its verified HEAD and SHA-256, archive hash, final Git state, process check and
filesystem observations. These local backups and generated files are ignored;
the committed manifest cannot contain its own final commit hash.

To inspect or recover the source backup from this directory:

```sh
git bundle verify .validation-cache/source.bundle
git clone .validation-cache/source.bundle <new-recovery-directory>
```

There is no GitHub backup or remote. No old source copy is eligible for removal
on the strength of this local bundle alone. No credentials, global settings,
other projects, shared toolchains or user services were modified by closeout.
