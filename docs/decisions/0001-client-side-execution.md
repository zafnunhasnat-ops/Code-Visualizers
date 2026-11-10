# ADR 0001: Execute user code in the browser

**Status:** Accepted

## Context
The product visualizes code execution and must be free to run. Executing arbitrary code on a server requires sandboxing (containers, resource limits) and costs money per run, with abuse risk.

## Decision
Run Python in the user's browser via Pyodide (WebAssembly) inside a Web Worker. The backend only stores shared snippets and relays collaboration messages.

## Consequences
- No server-side code execution: removes the main security and cost risk
- UI stays responsive because execution is off the main thread
- Initial Pyodide download adds load time (mitigate with a loading state and caching)
- Languages that cannot run in the browser (e.g. Java) are out of scope for launch

## Alternatives considered
- Docker sandbox per run: flexible, but costly and a large attack surface
- Third-party execution API: fast to build, but adds cost, rate limits and a dependency
