#Requires -Version 5.1
<#
.SYNOPSIS
Generate Python project starter files (requirements.txt, setup.py, etc.)

.DESCRIPTION
Creates language-specific starter files for a Python project.
Called automatically by setup-project.ps1 if setup-starter-python.ps1 exists.

.PARAMETER ProjectPath
Project root directory.

.PARAMETER ProjectName
Project display name (used in setup.py).
#>

param(
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$ProjectName
)

. (Join-Path $PSScriptRoot '../../modules/Common.ps1')

Write-Step "Setting up Python starter files"

$projectNameSnake = ($ProjectName -replace '[^a-zA-Z0-9]', '_').ToLower()

# ============================================================================
# requirements.txt
# ============================================================================

$requirementsContent = @"
# Production dependencies
# Add packages here as: package-name==version

# Development dependencies (optional)
# Run: pip install -r requirements-dev.txt
"@

Set-Content -Path (Join-Path $ProjectPath 'requirements.txt') -Value $requirementsContent
Write-Success "Generated requirements.txt"

# ============================================================================
# requirements-dev.txt
# ============================================================================

$requirementsDevContent = @"
# Development and testing dependencies
-r requirements.txt

pytest==7.4.0
pytest-cov==4.1.0
black==23.7.0
pylint==2.17.5
mypy==1.4.1
flake8==6.0.0
"@

Set-Content -Path (Join-Path $ProjectPath 'requirements-dev.txt') -Value $requirementsDevContent
Write-Success "Generated requirements-dev.txt"

# ============================================================================
# setup.py
# ============================================================================

$setupContent = @"
from setuptools import setup, find_packages

with open('README.md', 'r', encoding='utf-8') as f:
    long_description = f.read()

setup(
    name='$projectNameSnake',
    version='0.1.0',
    description='$ProjectName',
    long_description=long_description,
    long_description_content_type='text/markdown',
    author='Your Name',
    author_email='your.email@example.com',
    url='https://github.com/yourusername/$projectNameSnake',
    packages=find_packages(where='src'),
    package_dir={'': 'src'},
    python_requires='>=3.8',
    install_requires=[],
    extras_require={
        'dev': [
            'pytest',
            'pytest-cov',
            'black',
            'pylint',
            'mypy',
            'flake8',
        ],
    },
    classifiers=[
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3.10',
        'Programming Language :: Python :: 3.11',
    ],
)
"@

Set-Content -Path (Join-Path $ProjectPath 'setup.py') -Value $setupContent
Write-Success "Generated setup.py"

# ============================================================================
# pyproject.toml
# ============================================================================

$pyprojectContent = @"
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "$projectNameSnake"
version = "0.1.0"
description = "$ProjectName"
requires-python = ">=3.8"
authors = [
    {name = "Your Name", email = "your.email@example.com"},
]

[tool.black]
line-length = 100
target-version = ['py38', 'py39', 'py310', 'py311']

[tool.pylint]
max-line-length = 100
disable = []

[tool.mypy]
python_version = "3.8"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = false
"@

Set-Content -Path (Join-Path $ProjectPath 'pyproject.toml') -Value $pyprojectContent
Write-Success "Generated pyproject.toml"

# ============================================================================
# pytest.ini
# ============================================================================

$pytestContent = @"
[pytest]
testpaths = ["tests"]
python_files = ["test_*.py", "*_test.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
addopts = --verbose --cov=src --cov-report=term-missing
"@

Set-Content -Path (Join-Path $ProjectPath 'pytest.ini') -Value $pytestContent
Write-Success "Generated pytest.ini"

# ============================================================================
# .flake8
# ============================================================================

$flakeContent = @"
[flake8]
max-line-length = 100
extend-ignore = E203, W503
exclude = .venv,venv,build,dist,.git
"@

Set-Content -Path (Join-Path $ProjectPath '.flake8') -Value $flakeContent
Write-Success "Generated .flake8"

# ============================================================================
# src/__init__.py
# ============================================================================

$initContent = @"
"""
$ProjectName package
"""

__version__ = "0.1.0"
"@

$srcDir = Join-Path $ProjectPath 'src'
$null = New-Item -ItemType Directory -Path $srcDir -Force -ErrorAction SilentlyContinue
Set-Content -Path (Join-Path $srcDir '__init__.py') -Value $initContent
Write-Success "Generated src/__init__.py"

# ============================================================================
# src/main.py (stub)
# ============================================================================

$mainContent = @"
"""
Main application entry point
"""


def main():
    print("Welcome to $ProjectName")
    # Add your application code here


if __name__ == "__main__":
    main()
"@

Set-Content -Path (Join-Path $srcDir 'main.py') -Value $mainContent
Write-Success "Generated src/main.py"

# ============================================================================
# tests/__init__.py
# ============================================================================

Set-Content -Path (Join-Path $ProjectPath 'tests/__init__.py') -Value ''
Write-Success "Generated tests/__init__.py"

# ============================================================================
# tests/test_main.py (stub)
# ============================================================================

$testContent = @"
"""
Example test file
"""

import pytest


def test_example():
    """Example test"""
    assert True
"@

Set-Content -Path (Join-Path $ProjectPath 'tests/test_main.py') -Value $testContent
Write-Success "Generated tests/test_main.py"

Write-Success "Python starter setup complete"
