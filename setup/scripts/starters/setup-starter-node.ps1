#Requires -Version 5.1
<#
.SYNOPSIS
Generate Node.js project starter files (package.json, .eslintrc, etc.)

.DESCRIPTION
Creates language-specific starter files for a Node.js project.
Called automatically by setup-project.ps1 if setup-starter-node.ps1 exists.

.PARAMETER ProjectPath
Project root directory.

.PARAMETER ProjectName
Project display name (used in package.json).
#>

param(
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][string]$ProjectName
)

. (Join-Path $PSScriptRoot '..\..\modules\Common.ps1')

Write-Step "Setting up Node.js starter files"

$projectNameKebab = ($ProjectName -replace '[^a-zA-Z0-9]', '-').ToLower()

# ============================================================================
# package.json
# ============================================================================

$packageJson = @{
    name        = $projectNameKebab
    version     = "0.1.0"
    description = $ProjectName
    main        = "src/index.js"
    type        = "module"
    scripts     = @{
        build = "tsc"
        test  = "jest"
        lint  = "eslint src/ --fix"
        start = "node src/index.js"
        dev   = "nodemon src/index.js"
    }
    keywords    = @("project", "typescript")
    author      = ""
    license     = "MIT"
    dependencies = @{
        # Add production dependencies here
    }
    devDependencies = @{
        "@types/node" = "^20.0.0"
        "typescript"  = "^5.0.0"
        "eslint"      = "^8.0.0"
        "prettier"    = "^3.0.0"
        "jest"        = "^29.0.0"
    }
} | ConvertTo-Json -Depth 10

Set-Content -Path (Join-Path $ProjectPath 'package.json') -Value $packageJson
Write-Success "Generated package.json"

# ============================================================================
# tsconfig.json
# ============================================================================

$tsconfigContent = @"
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "declaration": true,
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "noImplicitAny": true,
    "moduleResolution": "node"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
"@

Set-Content -Path (Join-Path $ProjectPath 'tsconfig.json') -Value $tsconfigContent
Write-Success "Generated tsconfig.json"

# ============================================================================
# .eslintrc.json
# ============================================================================

$eslintContent = @"
{
  "env": {
    "node": true,
    "es2020": true
  },
  "extends": ["eslint:recommended"],
  "parserOptions": {
    "ecmaVersion": 2020,
    "sourceType": "module"
  },
  "rules": {
    "indent": ["error", 2],
    "linebreak-style": ["error", "unix"],
    "quotes": ["error", "single"],
    "semi": ["error", "always"],
    "no-unused-vars": ["warn"]
  }
}
"@

Set-Content -Path (Join-Path $ProjectPath '.eslintrc.json') -Value $eslintContent
Write-Success "Generated .eslintrc.json"

# ============================================================================
# jest.config.js
# ============================================================================

$jestContent = @"
export default {
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.js', '**/?(*.)+(spec|test).js'],
  collectCoverageFrom: ['src/**/*.js'],
  coveragePathIgnorePatterns: ['/node_modules/'],
};
"@

Set-Content -Path (Join-Path $ProjectPath 'jest.config.js') -Value $jestContent
Write-Success "Generated jest.config.js"

# ============================================================================
# .prettierrc.json
# ============================================================================

$prettierContent = @"
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2
}
"@

Set-Content -Path (Join-Path $ProjectPath '.prettierrc.json') -Value $prettierContent
Write-Success "Generated .prettierrc.json"

# ============================================================================
# src/index.js (stub)
# ============================================================================

$indexContent = @"
/**
 * Main application entry point
 */

console.log('Welcome to $ProjectName');

// Add your application code here
"@

Set-Content -Path (Join-Path $ProjectPath 'src/index.js') -Value $indexContent
Write-Success "Generated src/index.js"

# ============================================================================
# src/__tests__/index.test.js (stub)
# ============================================================================

$testContent = @"
/**
 * Example test file
 */

describe('Application', () => {
  test('should exist', () => {
    expect(true).toBe(true);
  });
});
"@

Set-Content -Path (Join-Path $ProjectPath 'tests/index.test.js') -Value $testContent
Write-Success "Generated tests/index.test.js"

Write-Success "Node.js starter setup complete"
