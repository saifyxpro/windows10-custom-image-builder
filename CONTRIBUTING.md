# Contributing to Windows 10 Custom Image Builder

We love your input! We want to make contributing to this project as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## We Develop with GitHub

We use GitHub to host code, to track issues and feature requests, as well as accept pull requests.

## We Use [GitHub Flow](https://guides.github.com/introduction/flow/index.html)

Pull requests are the best way to propose changes to the codebase. We actively welcome your pull requests:

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code lints.
6. Issue that pull request!

## Any contributions you make will be under the MIT Software License

In short, when you submit code changes, your submissions are understood to be under the same [MIT License](http://choosealicense.com/licenses/mit/) that covers the project. Feel free to contact the maintainers if that's a concern.

## Report bugs using GitHub's [issues](https://github.com/saifyxpro/windows10-custom-image-builder/issues)

We use GitHub issues to track public bugs. Report a bug by [opening a new issue](https://github.com/saifyxpro/windows10-custom-image-builder/issues/new/choose); it's that easy!

## Write bug reports with detail, background, and sample code

**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

People *love* thorough bug reports. I'm not even kidding.

## Development Setup

1. **Prerequisites:**
   - Windows 10/11 with PowerShell 5.1+
   - Administrator privileges
   - Git for Windows
   - Visual Studio Code (recommended)

2. **Clone and Setup:**
   ```powershell
   git clone https://github.com/saifyxpro/windows10-custom-image-builder.git
   cd windows10-custom-image-builder
   ```

3. **Install Development Dependencies:**
   ```powershell
   # Install PowerShell modules for development
   Install-Module -Name Pester -Force -SkipPublisherCheck
   Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck
   ```

## Code Style and Standards

### PowerShell Scripts

- Use **approved verbs** for function names (Get-*, Set-*, New-*, etc.)
- Use **PascalCase** for function names and variables
- Include **comment-based help** for all functions
- Use **Write-Host** for user-facing output, **Write-Verbose** for debug info
- Include **error handling** with try/catch blocks
- Use **parameter validation** where appropriate

**Example:**
```powershell
<#
.SYNOPSIS
    Downloads and installs QEMU on Windows.

.DESCRIPTION
    This function downloads the latest QEMU version and installs it
    to the default location with PATH configuration.

.PARAMETER InstallPath
    The installation path for QEMU. Defaults to "C:\Program Files\qemu"

.EXAMPLE
    Install-QEMUWindows -InstallPath "C:\Tools\qemu"
#>
function Install-QEMUWindows {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$InstallPath = "C:\Program Files\qemu"
    )
    
    try {
        Write-Host "Installing QEMU..." -ForegroundColor Green
        # Implementation here
    }
    catch {
        Write-Error "Failed to install QEMU: $($_.Exception.Message)"
        throw
    }
}
```

### JSON Configuration Files

- Use **consistent formatting** with 2-space indentation
- Include **comments** where supported
- Validate **JSON syntax** before committing
- Use **meaningful property names**

### Documentation

- Use **Markdown** for all documentation
- Include **code examples** where relevant
- Keep **line lengths** under 100 characters
- Use **proper headings** hierarchy
- Include **badges** for status indicators

## Testing Guidelines

### PowerShell Testing with Pester

Create tests for your PowerShell functions:

```powershell
# tests/Setup-Environment.Tests.ps1
Describe "Setup-Environment" {
    BeforeAll {
        . "$PSScriptRoot\..\scripts\Setup-Environment.ps1"
    }
    
    Context "QEMU Installation" {
        It "Should download QEMU installer" {
            # Test implementation
        }
        
        It "Should add QEMU to PATH" {
            # Test implementation
        }
    }
}
```

### Running Tests

```powershell
# Run all tests
Invoke-Pester

# Run specific test file
Invoke-Pester -Path "tests/Setup-Environment.Tests.ps1"

# Run with code coverage
Invoke-Pester -CodeCoverage "scripts/*.ps1"
```

### Code Quality

```powershell
# Run PSScriptAnalyzer on all scripts
Invoke-ScriptAnalyzer -Path "scripts\" -Recurse

# Fix common issues automatically
Invoke-ScriptAnalyzer -Path "scripts\" -Fix
```

## Pull Request Process

1. **Update Documentation:** Ensure any new features or changes are documented
2. **Test Your Changes:** Run the full test suite and verify functionality
3. **Update CHANGELOG:** Add your changes to the Unreleased section
4. **Code Review:** Address any feedback from maintainers
5. **Merge:** Once approved, your PR will be merged

### Pull Request Template

When creating a PR, please include:

- **Description:** What does this PR do?
- **Type of Change:** Bug fix, new feature, breaking change, documentation update
- **Testing:** How did you test this change?
- **Checklist:** Have you completed all required tasks?

## Feature Requests

We use GitHub issues to track feature requests. When suggesting a new feature:

1. **Check existing issues** to avoid duplicates
2. **Provide context** on why this feature would be useful
3. **Include implementation ideas** if you have them
4. **Consider backwards compatibility**

## Code of Conduct

### Our Pledge

We pledge to make participation in our project a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, sex characteristics, gender identity and expression, level of experience, education, socio-economic status, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

Examples of behavior that contributes to creating a positive environment include:

- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

### Enforcement

Instances of abusive, harassing, or otherwise unacceptable behavior may be reported by contacting the project team. All complaints will be reviewed and investigated and will result in a response that is deemed necessary and appropriate to the circumstances.

## Questions?

Feel free to reach out via:
- GitHub Issues for technical questions
- GitHub Discussions for general discussion
- Email: [saifyxpro@example.com](mailto:saifyxpro@example.com)

## Recognition

Contributors will be recognized in:
- README.md acknowledgments section
- Release notes for significant contributions
- GitHub contributor statistics

Thank you for contributing to making Windows 10 custom image creation better for everyone! 🚀
