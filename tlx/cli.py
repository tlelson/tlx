import shutil
from typing import Iterable, List, Tuple


def _which_grouped(names: Iterable[str]) -> Tuple[List[str], List[str]]:
    found: List[str] = []
    missing: List[str] = []
    for n in names:
        if shutil.which(n):
            found.append(n)
        else:
            missing.append(n)
    return found, missing


def _scripts_from_entry_points() -> List[str]:
    """Return installed console script names for the 'tlx' distribution."""
    try:
        import importlib.metadata as md  # Python 3.8+
    except Exception:
        try:
            import importlib_metadata as md  # type: ignore
        except Exception:
            return []

    try:
        dist = md.distribution("tlx")
    except Exception:
        return []

    names: List[str] = []
    for ep in getattr(dist, "entry_points", []) or []:
        if getattr(ep, "group", "") == "console_scripts":
            name = getattr(ep, "name", "")
            if name:
                names.append(name)
    return sorted(set(names))


def main() -> None:
    """List tools made available on PATH by the tlx package.

    Uses installed entry points for the 'tlx' distribution for reliability
    when pip-installed.
    """
    names = _scripts_from_entry_points()

    # Exclude self from the listing for clarity
    names = [n for n in names if n != "tlx"]

    found, missing = _which_grouped(names)

    if found:
        print("Available tools:")
        for name in sorted(found):
            path = shutil.which(name) or ""
            print(f"  - {name} ({path})")

    if missing:
        print("\nNot on PATH (install/activate env to use):")
        for name in sorted(missing):
            print(f"  - {name}")


if __name__ == "__main__":
    main()
