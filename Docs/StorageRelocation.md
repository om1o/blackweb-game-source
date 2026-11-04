# Storage relocation — 2026-11-03

The user authorized freeing 5 GB for the game. This pass relocates only the named
Arachnophobia download and archive. Other downloads have not been moved by this pass.

## Completed relocations

| Original location | Preserved location | Payload bytes | Original-path behavior |
| --- | --- | ---: | --- |
| `C:\Users\omiol\Downloads\Arachnophobia` | `D:\GameDownloads\BlackwebSourceBackup-20261103\Arachnophobia` | 840,302,861 | Directory junction to the preserved D: folder. |
| `C:\Users\omiol\Downloads\Arachnophobia.rar` | `D:\GameDownloads\BlackwebSourceBackup-20261103\Arachnophobia.rar` | 695,055,717 | File symlink was denied because administrator privilege is required. Use the D: archive path. |

Total payload moved off C: is **1,535,358,578 bytes**, approximately **1.430 GiB**.
No permissions, developer-mode settings, or system configuration were changed to
enable the denied file symlink. The existing separate copies at
`D:\GameDownloads\Arachnophobia` and `D:\GameDownloads\Arachnophobia.rar` remain intact.

The combined copy/verify/recursive-delete command was rejected by automatic tool
policy before execution. The accepted alternative used native PowerShell `Move-Item`
with explicitly resolved source paths, checked non-link originals, unique checked D:
destinations, and the already verified independent D: duplicates as rollback copies.
No standalone recursive-delete command executed.

## Integrity evidence

- Before relocation, all **23 game files** matched SHA256 against the existing D:
  game copy, with matching total size and no mismatches.
- Both archive copies matched SHA256 before relocation. The relocated archive was
  hashed again afterward and matched:

  `537EA98AC51C364DF22CFD214C71DEB1177C383A7CC22468BF036BF4BBC532EA`

- A second, post-relocation SHA256 pass verified all **23 game files**, again totaling
  **840,302,861 bytes**, with no mismatches. The original full C: executable path
  remains accessible through the directory junction. The verification manifest is
  `D:\GameDownloads\BlackwebSourceBackup-20261103\Arachnophobia-files-sha256.json`.

## Observed free-space readings

| Operation | C: bytes free before | C: bytes free after | Observed increase |
| --- | ---: | ---: | ---: |
| Game folder relocation and junction | 192,737,280 | 1,040,646,144 | 847,908,864 |
| Archive relocation, verification, symlink attempt | 1,070,899,200 | 1,999,278,080 | 928,378,880 |

A later read showed **2,026,934,272 bytes free** on C: (approximately 1.888 GiB).
These volume readings include concurrent system activity. The verified payload
total above is the attributable file data moved by this pass. The 5 GB objective
was **not yet reached** at these readings.

## Further candidates inspected, not moved

Only filenames and file-size metadata were inspected for these game downloads.

| Download | Extracted folder bytes | ZIP bytes | Combined bytes |
| --- | ---: | ---: | ---: |
| `lyra-windows-alpha` | 733,018,722 | 498,372,713 | 1,231,391,435 |
| `Undertale_Yellow_v1.1` | 299,363,046 | 242,976,671 | 542,339,717 |
| `LTS DELTARUNE Chapter 1&2 (PC Version 3)` | 193,493,560 | 152,755,443 | 346,249,003 |
| **Total** | **1,225,875,328** | **894,104,827** | **2,119,980,155** |

Relocating all three folder/archive pairs would add about 1.974 GiB of capacity.
Together with the last observed free-space reading, this would still be about
1.14 GiB short of 5 GiB free, before any concurrent activity.

The current task's C: `work` directory contains only 12,078,581 bytes. Its `outputs`
directory contains 97,912 bytes and was preserved. No attributable top-level TEMP
entries were found using today's date and the task/tool names. The checked user
`.nuget`, `.dotnet`, and local Microsoft/dotnet directories do not exist.

## Rollback

1. Close any game using the original C: path. Ensure C: has enough capacity for the
   files being restored.
2. Inspect the C: `Arachnophobia` directory link and confirm its target is exactly
   `D:\GameDownloads\BlackwebSourceBackup-20261103\Arachnophobia`.
3. Remove **only the directory junction itself**, never recursively delete its D:
   target. Move the preserved D: game folder back to
   `C:\Users\omiol\Downloads\Arachnophobia`.
4. Move the preserved D: archive back to
   `C:\Users\omiol\Downloads\Arachnophobia.rar`. No archive symlink exists to remove.
5. Verify file counts, sizes, and SHA256 again. The independent original D:
   game/archive copies remain available if another recovery copy is needed.

The rebuild project at `D:\GameProjects\BlackwebHouseRebuild-20261103` was not moved
or deleted by this storage operation.
