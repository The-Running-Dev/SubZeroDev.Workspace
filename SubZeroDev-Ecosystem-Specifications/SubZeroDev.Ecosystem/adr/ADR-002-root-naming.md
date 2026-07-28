# ADR-002: Keep `SubZeroDev` as the Root Namespace

## Status

Accepted

## Context

`SubZeroDev.Platform` and `SubZeroDev.Automator` were provisional names. The question was whether to
settle them before packages publish, because a package identifier is effectively permanent once
consumers depend on it — a rename means deprecating the old identifiers, republishing, and breaking
everyone who did not follow.

Two objections were worth taking seriously.

**"Platform" is a category, not a name.** It describes what the thing is rather than identifying it,
and in conversation "the platform" becomes ambiguous the moment a second thing could be called one.
Projects that name their framework `Platform`, `Core`, or `Common` tend to regret it later.

**`SubZeroDev.Platform.Abstractions` is verbose.** Four segments before anything meaningful.

## Decision

**Keep `SubZeroDev` as the root, and `SubZeroDev.Platform` and `SubZeroDev.Automator` as the product
namespaces.**

The objections are real but the alternatives are not better:

- Every replacement for "Platform" — Foundation, Framework, Kernel, Base — is equally a category
  word, and each is more surprising to a reader.
- `Company.Product.Component` is the .NET convention, so verbosity here reads as ordinary rather than
  as a decision. `Microsoft.Extensions.DependencyInjection` is longer.
- The brand already exists across GitHub repositories, the container registry namespace, and the npm
  scope. Splitting the .NET namespace from the brand costs recognition and gains nothing.

The ambiguity objection is answered by usage rather than by naming: "Platform" is unqualified only
inside its own repository, and everywhere else it appears with its root.

### Reserve the identifiers now

The expensive part of naming is not the choice, it is discovering later that someone else took the
identifier. Before first publish:

| Registry           | Action                                                          |
| ------------------ | --------------------------------------------------------------- |
| NuGet              | Reserve the `SubZeroDev.*` ID prefix against the verified owner |
| npm                | Confirm the `@subzerodev` scope is held                         |
| Container registry | Confirm the `subzerodev-*` image namespace is held              |
| PowerShell Gallery | Reserve the `SubZeroDev.*` module prefix                        |

Prefix reservation is free and prevents both squatting and honest collisions. It is worth doing
before the first package rather than after the first conflict.

### The naming rules that follow

Already stated in the plugin contract and repeated here as the general form:

| Surface                    | Form                                                       |
| -------------------------- | ---------------------------------------------------------- |
| .NET namespace and package | `SubZeroDev.<Product>.<Component>`                         |
| Plugin ID                  | `subzerodev.<name>`                                        |
| CLI binary                 | `subzerodev-<name>`, alias `sz-<name>`                     |
| Container image            | `<registry>/subzerodev-<name>`                             |
| npm package                | `@subzerodev/<name>`                                       |
| PowerShell module          | `SubZeroDev.<Product>.PowerShell`, cmdlet noun prefix `Sz` |

## Consequences

- The _root_ and the _forms_ are settled, so packages can publish without a rename hanging over the
  namespace. **Individual plugin names are not** — this ADR fixes `subzerodev.<name>` as the shape and
  says nothing about how `<name>` is chosen, and in practice the plugins mix provider names, domain
  objects, activities, and compounds. That gap is question 0 in `19-open-questions.md`, and the
  reservation argument below applies to it with the same force.
- Prefix reservation becomes a prerequisite of the first release rather than an afterthought.
- `SubZeroDev.Platform` keeps a category word as a product name. Accepted: the cost is occasional
  conversational ambiguity, against the cost of a rename after publication.
- The `Sz` cmdlet prefix and the `sz-` CLI alias give the terseness the long form lacks, at the two
  places where people actually type.

## Alternatives considered

**A shorter root such as `SubZero`.** Fewer characters, and it reads well. Rejected: it is a different
brand from the one that already exists across every other surface, and a one-word difference between
namespace and brand is the kind of inconsistency people trip over indefinitely.

**Renaming `Platform` to something specific.** Would answer the category-word objection. Rejected: no
candidate was clearly better, and a name chosen mainly to avoid a mild objection tends to acquire its
own.

**Deferring until first publish.** Rejected: publication is exactly when the decision becomes
expensive, so deferring moves it to the worst possible moment.
