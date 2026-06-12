# Failed Design Retrospective

## One-line conclusion

The earlier design failed because it mixed **public deployment packaging** and **private runtime customization** into the same Docker contract.

## What went wrong

1. The image tried to solve too many problems at once:
   - base runtime
   - private addons
   - personal path conventions
   - personal auth defaults
   - device-specific deployment workarounds
2. Documentation drift hid the problem by making the overgrown design look internally consistent.
3. Large, all-in-one changes made it hard to notice that the repository had stopped answering the original question.

## What we keep from the failure

- the need for a reproducible OpenClaw build
- the value of explicit path-mapping documentation
- the importance of local smoke tests before remote rollout
- the lesson that private deployment overlays must not define the public base contract

## Guardrails for the current design

1. Keep the base image generic.
2. Keep addon examples public and synthetic.
3. Keep private runtime details out of the committed deployment contract.
4. Validate the public quickstart locally before layering on any private customization.
