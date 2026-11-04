# Architectural Notes

1. **Intent Locking:**
   - Projects are strictly locked to their native Intent domain.
   - Projects cannot be moved across Intents.
   - Multi-discipline systems are modeled exclusively via parent-child project relationships across Intents.

2. **Profile Migration & Credential Warnings:**
   - When a project is transferred from one Profile to another, the database keys and Profile ID are updated.
   - Updating Git credentials (`user.name`, `user.email`, and SSH identity) must trigger an explicit warning to prevent accidental author attribution mismatches.

3. **Open Question — Credential Handling on Profile Move:**
   - How should local Git credentials (`user.name`, `user.email`), remotes, and SSH keys be handled when a project moves to a new profile?
   - Should it prompt, auto-update, or leave git config untouched?
   - *Status:* Unresolved. Deferred to address in the future.
