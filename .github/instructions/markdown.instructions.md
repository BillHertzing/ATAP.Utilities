---
applyTo: "**/*.md"
---

# Copilot instructions for Markdown files

This file is a set of instructions for Copilot to follow when generating or modifying Markdown (.md) files in this repository.

## Goals

Generate production-grade Markdown documentation that adheres to the repository's conventions and standards.

## Coding Rules

- All heading lines should be followed by a blank line.
- Use consistent heading levels to organize content hierarchically.
- Use bullet points or numbered lists for clarity when listing items.
- Ensure proper indentation for nested lists.
- Use fenced code blocks (```language) for code snippets, specifying the language where applicable.
- Avoid trailing whitespace at the end of lines.
- Images have special treatment:
  - Use relative paths for images to ensure portability.
  - Use `![alt text](image_path)` syntax for images.
  - Ensure images are accessible and have descriptive alt text.
- Use descriptive alt text for images.
- Ensure links are valid and descriptive.
- Validate Markdown files using linting tools (e.g., markdownlint) before committing.

## Building markdown documentation images

- always pass the markdown file to the cmdlet `Convert-DiagramsToImages` to convert diagrams to images.

## Continuous Integration

- Ensure all Markdown files pass linting checks in the CI/CD pipeline.
- Update documentation promptly to reflect changes in the repository.
