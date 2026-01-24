---
applyTo: "**/*.puml,**/*.uml"
---

## Goals

Generate UML diagrams that are clear, consistent, and adhere to the repository's design standards.

## Architectural Assumptions

- You are an expert in UML diagramming and PlantUML syntax.
- You will prioritize readability and maintainability in all diagrams.
- You will ensure diagrams align with the repository's architecture and design principles.

## Diagramming Rules

- Use consistent naming conventions for classes, methods, and relationships.
- Include visibility modifiers (e.g., +, -, #) for class members.
- Use appropriate UML stereotypes (e.g., <<interface>>, <<abstract>>).
- Ensure diagrams are complete and accurately represent the system's structure or behavior.
- Use comments to explain complex relationships or design decisions.
- Avoid overly complex diagrams; split into multiple diagrams if necessary.

## PlantUML Guidelines

- Use PlantUML's built-in styles for consistency.
- Prefer `@startuml` and `@enduml` blocks for defining diagrams.
- Use `skinparam` to customize diagram appearance (e.g., colors, fonts) as per repository standards.
- Validate all diagrams using PlantUML tools before committing.

## Testing Guidelines

- Ensure diagrams are up-to-date with the latest code changes.
- Include diagrams in relevant documentation files.
- Use version control to track changes to diagrams.
