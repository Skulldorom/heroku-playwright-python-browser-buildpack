# Heroku Playwright Python Browser Buildpack

A small classic Heroku buildpack that installs Playwright browser binaries for Python apps after the official `heroku/python` buildpack has installed your dependencies.

This is intended for Flask/FastAPI/Django apps that use Python Playwright at runtime, for example:

```python
browser = playwright.chromium.launch(headless=True)
```

Without this buildpack, Heroku can install the `playwright` Python package but still fail at runtime with:

```text
BrowserType.launch: Executable doesn't exist at /app/.cache/ms-playwright/...
Please run: playwright install
```

Because apparently installing the package and installing the browser are two different ceremonies. Naturally.

## Buildpack order

Add this buildpack **after** `heroku/python` so the `playwright` Python package and CLI already exist:

```bash
heroku buildpacks:add heroku/python --app <app-name>
heroku buildpacks:add https://github.com/Technology-Today-Ltd/heroku-playwright-python-browser-buildpack --app <app-name>
```

Expected order:

```text
1. heroku/python
2. https://github.com/Technology-Today-Ltd/heroku-playwright-python-browser-buildpack
```

If you also use Heroku's Chrome for Testing buildpack, it is separate and not required for this buildpack's default path. This buildpack installs Playwright's own browser binaries into the slug.

## Configuration

Optional Heroku config vars:

| Variable | Default | Description |
| --- | --- | --- |
| `PLAYWRIGHT_BUILDPACK_BROWSERS` | `chromium-headless-shell` | Browser list passed to `python -m playwright install`. The default matches Playwright's default `headless=True` launch path. Use `chromium` if your app needs the full browser. |
| `PLAYWRIGHT_INSTALL_OPTIONS` | empty | Extra install flags. Usually leave empty with the default browser. |
| `PLAYWRIGHT_BROWSERS_PATH` | `/app/.cache/ms-playwright` at runtime | Runtime browser path. During build, relative paths are installed under Heroku's slug build dir and exported as `/app/<path>` for dynos. |
| `PLAYWRIGHT_SKIP_BROWSER_GC` | `1` | Prevent Playwright from garbage-collecting browser binaries installed by the buildpack. |

Example:

```bash
heroku config:set PLAYWRIGHT_BUILDPACK_BROWSERS=chromium-headless-shell --app <app-name>
heroku config:set PLAYWRIGHT_BROWSERS_PATH=/app/.cache/ms-playwright --app <app-name>
```

Verify after deploy:

```bash
heroku run 'python -m playwright install --list' --app technology-today-portal-flask
heroku logs --tail --app technology-today-portal-flask
```

## Packaging a tarball

From the repo root:

```bash
tar --exclude .git -czf heroku-playwright-python-browser-buildpack.tgz .
```

Then upload/use the `.tgz` wherever you maintain custom buildpacks.

## License

MIT
