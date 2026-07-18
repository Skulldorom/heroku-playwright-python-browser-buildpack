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
| `PLAYWRIGHT_BUILDPACK_BROWSERS` | `chromium` | Browser list passed to `python -m playwright install`. Examples: `chromium`, `firefox`, `webkit`, or `chromium firefox`. |
| `PLAYWRIGHT_INSTALL_OPTIONS` | empty | Extra install flags, for example `--only-shell`. |
| `PLAYWRIGHT_BROWSERS_PATH` | `.cache/ms-playwright` | Relative or absolute install path. Relative paths are placed under Heroku's slug build dir. |

Example:

```bash
heroku config:set PLAYWRIGHT_BUILDPACK_BROWSERS=chromium --app <app-name>
heroku config:set PLAYWRIGHT_INSTALL_OPTIONS=--only-shell --app <app-name>
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
