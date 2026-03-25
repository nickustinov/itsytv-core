## Logging

- All logging uses `CoreLog` (wrapper around `os.log` Logger)
- `ItsytvCoreLog.verbose` controls info/debug output (off by default)
- Errors and warnings always log
- Consumer apps enable verbose logging with `ItsytvCoreLog.verbose = true`
