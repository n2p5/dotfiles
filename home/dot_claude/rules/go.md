---
paths:
  - "**/*.go"
---

# Go

- Standard library first; justify every new dependency. A little copying beats a little dependency.
- Small interfaces. Accept interfaces, return structs. Make the zero value useful.
- Errors are values: wrap with `%w` and context, never swallow them. Don't panic in library code.
- Table-driven tests.
- Comments follow godoc conventions in the style of the Go standard library: complete sentences that begin with the name of the identifier they document.
- Comments are living documentation of the code and its expected behavior. They are never narrative and never reference fixes or past changes. Don't narrate implementation inline.
