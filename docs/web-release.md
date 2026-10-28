# Publishing the web app

The production web app is hosted at [iebb.github.io/NekokoLPA2](https://iebb.github.io/NekokoLPA2/). The separate `nekokolpa` Cloudflare Pages project is the landing page.

The [Publish web release workflow](../.github/workflows/publish_web.yml) deploys published stable app releases. It checks out the release tag's exact commit, builds with Flutter 3.47.2 and the GitHub Pages base path, verifies `version.json`, and uploads/deploys the static site. It needs only the repository's `GITHUB_TOKEN` and Pages/OIDC permissions; no Cloudflare token, private overlay or signing material is used.

Two automatic events cover the release paths:

- `release: published` handles releases created by a maintainer or a personal access token.
- Successful completion of **Build NekokoLPA2** on `release` covers releases created with `GITHUB_TOKEN`, which do not trigger a second release-event workflow. The completed build and release tag must identify the same commit.

Automatic runs deploy only the latest stable release. Delayed old events, drafts, prereleases and builds from forks cannot replace production. A manual run can select an older published stable tag for an intentional rollback.

To deploy or retry a release:

```sh
gh workflow run publish_web.yml --repo iebb/NekokoLPA2 --ref master \
  -f 'release_tag=v2.4.0+600'
```

Leaving `release_tag` empty selects the latest stable release. The Actions run records the Pages deployment URL. The app's `version.json` exposes the deployed version/build for verification.

The repository's Pages source must be **GitHub Actions**. To use `web.lpa.ee`, configure that custom domain in GitHub Pages and point its DNS at `iebb.github.io`; the workflow automatically uses the resulting root base path on its next deployment. DNS must be changed in the account that owns `lpa.ee`. The legacy local publisher's `weblpa` Cloudflare target was not present in the connected accounts during the 2026-10-28 investigation.
