# Profile Subsystem

A **Profile** is a high-level identity boundary on a node. It isolates projects, defaults, and credentials by life context (e.g., `personal`, `work`, `consulting`, `lab`).

---

## Architecture & Security
- **View Isolation:** Profiles separate visibility of projects and configs.
- **Storage:** Stored in plain text on the host node. No cryptographic encryption.
- **Credential Injection:** Rogue Core automatically injects the active profile's Git credentials, SSH keys, and environment variables into runtime sessions.

---

## Data Model & Fields
Each profile record (`profile:<profile_id>`) stores:
- `profile_id`: Unique slug identifier (e.g. `personal`, `work`).
- `display_name`: Human-readable label.
- `git_name`: `user.name` for Git commits.
- `git_email`: `user.email` for Git commits.
- `ssh_key_path`: Path to the dedicated SSH key.
- `forge_accounts`: Linked forge details (e.g. GitHub organization, GitLab username).
- `env_vars`: Key-value pairs of profile-scoped environment variables and tokens.
- `password_hash`: Optional password for restricted profile switching.

---

## Root Profile & Profile Switching
- **Root Profile:** An administrative profile with full control over all profiles, settings, and migrations on the local node.
- **Switching Profiles (`rogue su`):**
  - Users switch active profiles using: `rogue su <profile_name>`.
  - If the target profile is password-protected, the CLI prompts for authentication.

---

## Project Migration Across Profiles
- **Database Key Reassignment:** The project lookup key is updated from `p:<old_profile>:<intent>:<project>` to `p:<new_profile>:<intent>:<project>`.
- **Physical Disk:** Source files remain in their original disk directory via `source_pointer`.
- **Credential Warning:** Moving a project issues an explicit warning before modifying local Git configuration (`user.name`, `user.email`, and remotes) to prevent accidental author attribution mismatches.
