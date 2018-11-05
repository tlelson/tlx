# Contributing

## Install

```bash
pip install -r test_requirements.txt
pip install -e .
```

## Before committing:

The build will fail if tests or linting fail.  The build also runs on PR's.  Please do the following before committing.

Tests:
```
pytest
```

Lint
```
flake8 --ignore=E501
```
