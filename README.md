# Heroku Playwright Python Browser Buildpack

A small classic Heroku buildpack that installs Playwright browser binaries **and the native Ubuntu libraries Chromium needs** for Python apps after the official `heroku/python` buildpack has installed your dependencies.

This is intended for Flask/FastAPI/Django apps that use Python Playwright at runtime, for example:

```python
browser = playwright.chromium.launch(headless=True)
```

Without this buildpack, Heroku can install the `playwright` Python package but still fail at runtime with either:

```text
BrowserType.launch: Executable doesn't exist at /app/.cache/ms-playwright/...
Please run: playwright install
```

or:

```text
error while loading shared libraries: libatk-1.0.so.0: cannot open shared object file
```

Because apparently installing the package, installing the browser, and installing the browser's native libraries are three separate ceremonies. Naturally.

## Buildpack order

Add this buildpack **after** `heroku/python` so the `playwright` Python package and CLI already exist:

```bash
heroku buildpacks:clear --app <app-name>
heroku buildpacks:add heroku/python --app <app-name>
heroku buildpacks:add https://github.com/Skulldorom/heroku-playwright-python-browser-buildpack --app <app-name>
```

Expected order:

```text
1. heroku/python
2. https://github.com/Skulldorom/heroku-playwright-python-browser-buildpack
```

You should not need Heroku's Chrome for Testing buildpack for the default path. This buildpack installs Playwright's own browser binaries and the native libraries needed to launch them.

## What it installs

By default the buildpack installs:

- Playwright's `chromium-headless-shell` browser into `.cache/ms-playwright`
- Chromium native Ubuntu packages into `.apt`
- runtime profile exports for:
  - `PLAYWRIGHT_BROWSERS_PATH=/app/.cache/ms-playwright`
  - `PLAYWRIGHT_SKIP_BROWSER_GC=1`
  - `LD_LIBRARY_PATH` pointing at `/app/.apt/...`

The native package list targets Heroku-26. It includes the packages Playwright maps for Chromium, including `libatk`, `libatk-bridge`, `libasound`, `libnss3`, `libgbm1`, and the other tiny shared-library goblins Chromium demands. Integration tests run against the supported stack on every push to `main`.

## Configuration

Optional Heroku config vars:

| Variable | Default | Description |
| --- | --- | --- |
| `PLAYWRIGHT_BUILDPACK_BROWSERS` | `chromium-headless-shell` | Browser list passed to `python -m playwright install`. The default matches Playwright's default `headless=True` launch path. Use `chromium` if your app needs the full browser. |
| `PLAYWRIGHT_INSTALL_OPTIONS` | empty | Extra install flags. Usually leave empty with the default browser. |
| `PLAYWRIGHT_BROWSERS_PATH` | `/app/.cache/ms-playwright` at runtime | Runtime browser path. During build, relative paths are installed under Heroku's slug build dir and exported as `/app/<path>` for dynos. |
| `PLAYWRIGHT_INSTALL_NATIVE_DEPS` | `true` | Installs Chromium native Ubuntu packages into `.apt`. Set to `false` only if another buildpack already provides them. |
| `PLAYWRIGHT_NATIVE_DEPS_PACKAGES` | stack-aware Chromium list | Override native packages entirely. Space-separated package names. |
| `PLAYWRIGHT_SKIP_BROWSER_GC` | `1` | Prevent Playwright from garbage-collecting browser binaries installed by the buildpack. |

Example:

```bash
heroku config:set PLAYWRIGHT_BUILDPACK_BROWSERS=chromium-headless-shell --app <app-name>
heroku config:set PLAYWRIGHT_BROWSERS_PATH=/app/.cache/ms-playwright --app <app-name>
heroku config:set PLAYWRIGHT_INSTALL_NATIVE_DEPS=true --app <app-name>
```

## Verify after deploy

Trigger a fresh rebuild/redeploy after changing buildpacks or config vars. Existing slugs do not magically mutate; Heroku is annoying, not telepathic.

```bash
heroku run 'echo $PLAYWRIGHT_BROWSERS_PATH && echo $LD_LIBRARY_PATH && python -m playwright install --list' --app <app-name>
heroku logs --tail --app <app-name>
```

The runtime browser path should be:

```text
/app/.cache/ms-playwright
```

If you still see shared-library errors, check the Heroku stack and set a manual package override with `PLAYWRIGHT_NATIVE_DEPS_PACKAGES`.

## Packaging a tarball

From the repo root:

```bash
tar --exclude .git -czf heroku-playwright-python-browser-buildpack.tgz .
```

Then upload/use the `.tgz` wherever you maintain custom buildpacks.

## Releases

Every push to `main` runs the buildpack test workflow. After that workflow passes its
stubbed test suite and real browser launch on Heroku-26, its exact tested commit is
published as a GitHub release with automatically generated notes and a `buildpack.tgz`
archive. A failed or cancelled test workflow does not start the release job. Successful
automatic releases increment the latest semantic version's patch component; the first
release is `v0.0.1`. Releases are serialized so concurrent pushes cannot select the
same version. The browser integration also runs for pull requests, so compatibility
failures are caught before changes reach `main`.

To create a release manually, open **Actions → Release → Run workflow**, select the
commit or branch to release, and choose a `major`, `minor`, or `patch` increment. The
workflow calculates the next version from the latest version tag, tests the selected
commit, creates the tag at that exact commit, and then publishes the release. The
automatic and manual paths use the same test gates.

## Dependency maintenance

Dependabot checks the GitHub Actions used by this repository every week. Dependabot
alerts and Dependabot security updates are also enabled in the repository security
settings. Pull requests created by Dependabot run the same buildpack smoke workflow
as other pull requests.

The Ubuntu packages installed by `bin/install-native-deps` are resolved directly
through APT rather than declared in a dependency manifest supported by Dependabot.
Dependabot therefore cannot propose updates for those packages. The stack integration
tests are the control for detecting package availability or compatibility changes on
the supported Heroku stack.

## License

MIT
