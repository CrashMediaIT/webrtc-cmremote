# GitHub Repository Settings - Manual Configuration Required

This document outlines the GitHub repository settings that must be configured manually via the GitHub web interface or API by an organization administrator.

These settings are part of Step 1 of [ADR 0001 Fork Instructions](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-spike-fork-instructions.md).

## Repository Settings

### 1. Default Branch

**Setting:** Set `main` as the default branch

**How to configure:**
1. Go to repository Settings → Branches
2. Change default branch to `main` if not already set
3. Click "Update" and confirm

### 2. Repository Description

**Setting:** 
```
CMRemote fork of webrtc-rs/dtls with ring swapped for aws-lc-rs. Tracks ADR 0001 in CMRemote/docs/decisions/0001-webrtc-crypto-provider.md.
```

**How to configure:**
1. Go to repository main page
2. Click the gear icon next to "About"
3. Update the description field
4. Save changes

### 3. Repository Topics

**Setting:** Add the following topics:
- `webrtc`
- `dtls`
- `aws-lc-rs`
- `cmremote`

**How to configure:**
1. Go to repository main page
2. Click the gear icon next to "About"
3. Add topics in the "Topics" field (comma or space separated)
4. Save changes

### 4. Branch Protection Rules for `main`

**Setting:** Configure the following protections on the `main` branch:

#### Required Reviews
- Require pull request reviews before merging
- Required number of approvals: **1**
- Require review from Code Owners: **Enabled**
- Dismiss stale pull request approvals when new commits are pushed: **Enabled**

#### Status Checks
- Require status checks to pass before merging: **Enabled**
- Require branches to be up to date before merging: **Enabled**
- Status checks that are required (configure after CI is set up):
  - All platform build checks (x86_64-pc-windows-msvc, x86_64-unknown-linux-gnu, aarch64-unknown-linux-gnu, x86_64-apple-darwin, aarch64-apple-darwin)
  - Test suite
  - Clippy
  - Format check

#### Additional Protections
- Require conversation resolution before merging: **Enabled** (recommended)
- Do not allow bypassing the above settings: **Enabled**
- Restrict who can dismiss pull request reviews: **Enabled** (maintainers only)
- Restrict who can push to matching branches: **Enabled** (maintainers only)
- Allow force pushes: **Disabled**
- Allow deletions: **Disabled**

**How to configure:**
1. Go to repository Settings → Branches
2. Click "Add rule" under Branch protection rules
3. Enter `main` in the branch name pattern
4. Configure all the settings listed above
5. Save changes

### 4a. Branch Protection Rules for `cmremote/*` Long-Lived Branches

[ADR 0001 Step 10](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-spike-fork-instructions.md) declares the v0.5.4 dtls fork branch and its tag **immutable** so the existing `[patch.crates-io].webrtc-dtls` entry in `agent-rs/Cargo.toml` continues to resolve indefinitely. Step 10 also creates a second long-lived branch (`cmremote/v0.17.0-aws-lc-rs`) for the monorepo fork covering `webrtc/`, `dtls/`, `stun/`, and `turn/`. Both branches need protection rules to back the "immutable" claim.

**Setting:** Add a branch protection rule with the pattern `cmremote/*` (covers both existing and future `cmremote/v<NEW>-aws-lc-rs` branches) configured as follows:

- Require pull request reviews before merging: **Enabled** (1 approval, Code Owners required)
- Require status checks to pass before merging: **Enabled** (same matrix as `main`; for the monorepo branch, the matrix is workspace-scoped per ADR 0001 Step 15)
- Require conversation resolution before merging: **Enabled**
- Restrict who can push to matching branches: **Enabled** (maintainers only)
- Allow force pushes: **Disabled**
- Allow deletions: **Disabled**
- Do not allow bypassing the above settings: **Enabled**

**How to configure:**
1. Go to repository Settings → Branches
2. Click "Add rule" under Branch protection rules
3. Enter `cmremote/*` in the branch name pattern
4. Configure the settings listed above
5. Save changes

**Note:** Until the monorepo fork actually lands (Step 10 onward), only the existing `cmremote/v0.5.4-aws-lc-rs` branch matches this pattern. The pattern is forward-looking by design so no settings change is required when Step 10 creates the second branch.

### 4b. Tag Protection Rules for `v*-cmremote.*`

CMRemote-fork release tags (`v0.5.4-cmremote.1`, future `v0.17.0-cmremote.1`, etc.) are addressed directly by `[patch.crates-io]` entries in `agent-rs/Cargo.toml` and must never be moved or deleted.

**Setting:** Add a tag protection rule with the pattern `v*-cmremote.*`.

**How to configure:**
1. Go to repository Settings → Tags
2. Click "New rule"
3. Enter `v*-cmremote.*` in the pattern field
4. Save changes

This restricts who can create, update, or delete matching tags to repository administrators / maintainers.

### 5. Dependabot Alerts

**Setting:** Enable Dependabot security updates and version updates

**How to configure:**
1. Go to repository Settings → Security & analysis
2. Enable "Dependency graph" (should already be enabled for public repos)
3. Enable "Dependabot alerts"
4. Enable "Dependabot security updates"

**Note:** The `.github/dependabot.yml` file in this repository configures Dependabot to:
- Check for Cargo (Rust) dependency updates weekly
- Check for GitHub Actions updates weekly
- Automatically request reviews from `@CrashMediaIT/cmremote-maintainers`

## Verification Checklist

After manual configuration, verify:

- [ ] Default branch is `main`
- [ ] Repository description includes ADR reference
- [ ] All four topics are added: `webrtc`, `dtls`, `aws-lc-rs`, `cmremote`
- [ ] Branch protection on `main` requires 1 approval
- [ ] Branch protection requires status checks to pass
- [ ] Force pushes are disabled on `main`
- [ ] Branch deletion is disabled on `main`
- [ ] Branch protection rule for `cmremote/*` is configured (covers `cmremote/v0.5.4-aws-lc-rs` and future monorepo branches)
- [ ] Force pushes and deletions are disabled on `cmremote/*` branches
- [ ] Tag protection rule for `v*-cmremote.*` is configured
- [ ] CODEOWNERS file is recognized (test by opening a PR)
- [ ] Dependabot alerts are enabled
- [ ] Dependabot security updates are enabled

## Matching CMRemote Posture

These settings mirror the protection and security posture of the main [CrashMediaIT/CMRemote](https://github.com/CrashMediaIT/CMRemote) repository, ensuring that:

1. All changes are reviewed by qualified maintainers
2. CI must pass before merging
3. The repository is protected against accidental force-pushes or deletions
4. Security vulnerabilities are surfaced on the same cadence as the parent repository

## References

- [ADR 0001 Fork Instructions](https://github.com/CrashMediaIT/CMRemote/blob/master/docs/decisions/0001-spike-fork-instructions.md)
- [GitHub Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [GitHub Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
