# Development Workflow Guidelines

## Branch Naming Conventions

- Feature branches: `feature/feature-name`
- Bug fixes: `fix/bug-description`
- Release branches: `release/v1.x.x`

## Pull Request Process

1. Create a branch from `main` (or relevant parent branch)
2. Develop and test your changes locally
3. Commit with descriptive messages
4. Push your branch to GitHub
5. Create a Pull Request (PR) to merge into `main`
6. Ensure all tests pass
7. Request review from teammates
8. Address any review comments
9. Merge only after approval

## Commit Message Guidelines

- Use present tense ("Add feature" not "Added feature")
- First line is a summary (50 chars or less)
- Optionally followed by blank line and detailed description
- Reference issues by number: "Fix #123"

## Code Review Checklist

- Does the code work as expected?
- Is the code easy to understand?
- Is the code consistent with our style?
- Are there appropriate tests?
- Is documentation updated?