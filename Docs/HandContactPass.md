# Held-item contact pass — 5 November 2026

The flashlight and candy now remain fixed inside Luke's palm while the wrist
follows the pose. Previously the flashlight rotated independently through his
fingers, and the candy's model root sat at the wrist while the fingers closed on
empty space. The candy target also used a head-joint offset below the visible lip
line; it now uses an anatomical target independent of camera pitch.

The actual rig's native close-ups show the closed flashlight grip through level
and upward aim, the wrapper between the fingers, and the exposed candy reaching
the lip line. `Evidence/hand-contact-final.json` identifies all six captures.
The contact regression passed 13/13, equipment 53/53, and native mouse-driven
knife checks 16/16. The measured bite-tip gap was 7.85 mm in the test pose. These
are authored skeletal poses, not newly acquired motion-capture animations.

Knife behavior is unchanged: four base damage, impact threshold 0.24 seconds,
0.68-second action and 0.75-second cooldown. The native attack crossed the impact
threshold at the 0.25-second physics boundary, with no local grip drift. Candy
still heals 30 at 0.78 seconds within its 1.16-second action. Battery, bandage and
flare integration passed 41/41 after the contact changes; delayed action checks
passed 24/24.

A separate hair-only material comparison was rejected. Removing specular and
trying alpha-to-coverage changed pale card edges into dark seams without fixing
the broad cards or patchy source texture. The original hair materials, texture,
FBX and provenance remain intact. The source FBX contains lowercase `textures`
references, which produce editor-import case warnings on Windows; the playable
Luke scene uses the correct `Textures` paths. No cross-platform FBX portability
claim is made. `Evidence/hair-material-audit.md` records that bounded review.
