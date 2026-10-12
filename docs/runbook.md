# Runbook

What an operator does: how the system is brought up, what record that
leaves, and what to do when something is lost, stolen or expires. The
companion to [threat-model.md](threat-model.md), which says what an
attacker gets; this says what an operator does about it.

## 1. How to read this

<!-- Audiences mapped to sections, so the person opening this during an
incident reads one section:
- First-time setup: §2.
- Something was lost, destroyed or is suspected compromised: §4.
- Procedures designed but not yet run: §5, labelled documented-design. -->

Nothing here writes a secret to a log line or a plaintext file.

## 2. <Procedure>

### 2.1 Who, and with what access

<!-- Roles, credentials (referenced by environment-variable name), and
what must be decided BEFORE starting, with the irreversible choices
called out. -->

### 2.2 Running it

```sh
# exact commands
```

### 2.3 What comes out, and what does not

<!-- Every artifact produced, where it goes, which are public, and what is
deliberately never produced. -->

## 3. Records

<!-- Any manifest or log a procedure leaves, its fields, and what is
deferred. -->

## 4. Recovery, by tier

### 4.1 <The routine case>
### 4.2 <The exceptional case>
### 4.3 <Losing everything>

<!-- For each: detection, the steps, the cost, and what cannot be
recovered. -->

## 5. Documented-design

<!-- Procedures designed and not yet run. Each is labelled
**documented-design** until a run is recorded against it, with its date. -->

## 6. Cross-references

- [architecture.md](architecture.md)
- [threat-model.md](threat-model.md)
