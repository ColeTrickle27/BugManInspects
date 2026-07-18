# Graph document schema v2

Schema v2 adds optional text stored directly on generic shapes and preserves
unknown top-level, shape, and annotation properties during load/save cycles.

No destructive migration is required. Version 1 documents and the original
flat graph payload still load through the existing fallbacks. Older rectangle-
based structures remain `GraphShape` records and stay visible and editable;
only newly drawn structures use the point-by-point structure workflow.
