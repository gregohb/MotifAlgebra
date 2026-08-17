# A Motivic Transformation Algebra with a Description-Length Criterion

**Internal working paper, v0.7** — Music Motif project
**Revised 17 August 2026.** Supersedes *The Motivic Transformation Algebra* v0.1.
v0.4 added §11.4 (the tower as a Galois connection), §12.4 (the sweet spot as sophistication,
with the measured order–chaos axis), and predictions 8–9. v0.5 added §11.5 (the arc theorem:
keys as arcs on the circle of fifths, ℤ/12 as the algebraic closure, minimal-arc semantics for
the key-pointing effect) and prediction 10. v0.6 added §11.6 (the ℤ/7 lens: Myhill's property
verified, the three readings of an adjoined accidental, keys as pointed arcs) and
prediction 11. v0.7 adds §11.7 (the classification of spaces: well-formed / asymmetric /
symmetric regimes, Messiaen's modes as the stabilizer column, key-pointing degrading with
symmetry as arithmetic).

---

## How to read this document

This is a working reference, not a submission. Its job is to be the thing the Swift
implementation is checked against, so it labels its own claims:

| tag | meaning |
|---|---|
| **[proved]** | a mathematical statement with a proof given here |
| **[verified]** | checked computationally; the check is named and its result quoted |
| **[measured]** | an empirical result from real music, with the number and the null model |
| **[conjecture]** | believed, stated so it can be attacked; not yet supported |
| **[open]** | a known gap |
| **[retracted]** | something claimed in v0.1 that turned out to be false |

Where a claim is retracted, the retraction stays visible. The point of an internal document is
to remember what was tried and why it failed.

**Provenance.** The ideas are Gregory Moore's, developed across several note sets written at
different times. This document consolidates them, supplies proofs where they were sketched,
prices them under the cost model, and records where they were wrong. Section 14 lists which
claim came from which source.

---

## 1. Position: what is new and what is not

Honesty about this comes first, because the parts that are not new are load-bearing and the
parts that are new are narrow.

**Not new.**

- Group actions on musical objects, and analysis as a network of labelled arrows rather than a
  list of objects. This is Lewin's *Generalized Musical Intervals and Transformations* (1987).
  A Lewin GIS `(S, G, int)` is exactly the frame; the present work differs only in taking `S` to
  be ordered timed motifs and `G` a monoid rather than a group.
- The idea that a piece is one Gestalt under continuous transformation. Réti, *The Thematic
  Process in Music* (1951); Schoenberg's *Grundgestalt* and developing variation.
- Analysis by compression. Meredith's SIA / SIATEC / COSIATEC family represents a score as a
  point set in (time, pitch), finds maximal translatable patterns, and selects the encoding
  shortest in bits.
- Scale-degree versus chromatic space. The tonal-versus-real answer of fugue, four centuries old.
- Self-similar melody, where a line's own intervals generate its larger structure. Nørgård's
  infinity series; L-systems generally.
- The affine group on pitch classes. `Tₙ` and `Mₖ` and their composition are standard in
  pitch-class set theory (Morris, Rahn).

**Plausibly new, in descending order of confidence.**

1. **The closure theorem** (§4). The invertible transformations of a cyclic motif of length `n`
   are exactly `Dₙ × ℤ/2`, order `4n` — the automorphisms of the affine Dynkin diagram `Ãₙ₋₁`
   together with negation. Nothing else invertible exists at that level.
2. **The irreversibility theorem** (§5). The order-preserving stretch maps fixing zero have
   trivial unit group, so every non-trivial "circus mirror" is irreversible by order structure,
   not by rounding accident.
3. **MDL beyond translation** (§9). COSIATEC compresses using translation alone — the trivial
   end of the transformation array. Extending analysis-by-compression to the full affine group
   plus non-invertible warps, with universal codes throughout, is a genuine gap in the
   literature.
4. **The modulation threshold** (§11). A crossover between chromatic embellishment and
   modulation derived from bit costs rather than tuned.
5. **The dominance result** (§13). Contour-sign matching is strictly dominated by exact-interval
   matching with tolerance — higher coverage at roughly eighty times lower false-positive rate.
   This is a criticism of standard practice with numbers behind it.

**Retracted from v0.1.**

- **[retracted]** *"Pitch classes as elements of a finite field; accidentals as field
  extensions; Galois groups of harmonic extensions."* `ℤ/12` is not a field — `4 · 3 = 0` — so
  there is no field to extend and no Galois theory of it. A diatonic set is not a subfield of
  anything: `{C,D,E,F,G,A,B}` is not closed under addition mod 12, since `2 + 11 = 1`. The
  `ℚ(√2)` analogy is rhetorical. What survives is Proposition 3.3 below, which is a stronger
  statement anyway. Genuine field extensions in music live in *tuning* — `ℚ(2^(1/12))` really is
  a degree-12 extension of `ℚ` — and that is a different subject.
- **[retracted]** *"A diatonic sequence up a third is exact and invertible."* True for diatonic
  material, **false** for chromatic material, under the v0.1 representation. See §2 and
  Theorem 6.1.

---

## 2. Representation

### 2.1 Spaces

A **space** `S` is a tonic pitch class `τ ∈ ℤ/12` together with an ascending pattern
`0 = π₀ < π₁ < ⋯ < π_{k−1} < 12`. Write `|S| = k`. The **height** of step index `s ∈ ℤ` is

```
h_S(s) = τ + 12·⌊s/k⌋ + π_{s mod k}
```

Chromatic is not a special case: it is the space with `π = (0,1,…,11)`. Major, minor,
pentatonic, octatonic and Xenakis sieves are the same type with different patterns, so no map
branches on the kind of space.

### 2.2 Spelled pitch

A **pitch** is a pair `p = (s, a) ∈ ℤ × ℤ` — step index and alteration in semitones. Its
sounding height in `S` is `h_S(s) + a`.

This is the decisive representational choice, and it is the one v0.1 got wrong. The pair is
**stored**, never recomputed from a sounding height. `C♯ = (s_C, +1)` and `D♭ = (s_D, −1)` are
distinct objects that sound the same.

This is not an innovation; it is what notation has always done — MusicXML's `step`/`octave`/
`alter`, music21's `Pitch.step`/`.alter`. What is new is noticing that the algebra *breaks*
without it. See Theorem 6.1.

### 2.3 Motifs and phrases

A **note** is `(t, δ, p, ...)` — onset, duration, pitch, plus non-structural tags (velocity,
voice). A **phrase** is a finite multiset of notes under a total order.

**[verified]** The order must be total, down to the last tag. A key that stops at
`(onset, step, alteration, duration)` leaves two notes differing only in voice comparing equal;
since the standard library sort is not guaranteed stable, phrase equality then becomes
nondeterministic. A two-voice unison is exactly that case, and the overlay constructor exists to
produce two-voice unisons. Fixed by extending the key through `voice` and `velocity`.

The **step-interval vector** of a phrase of `n` notes is
`v = (s₂−s₁, …, sₙ−sₙ₋₁) ∈ ℤⁿ⁻¹`. Transposition acts trivially on `v`, so every
transposition-invariant question is a question about `v` alone.

### 2.4 Why chord-space theory does not transfer

The pitch-class-set and voice-leading literature — Forte classes, the orbifold `Tⁿ/Sₙ`, the PLR
group, Tymoczko's voice-leading spaces — answers a *vertical* question: given two simultaneities,
what is the natural map between them? This project asks a *horizontal* question. Three
consequences, all simplifications:

- **The canonicity problem dissolves.** Between two 3-note *sets* there are `3! = 6` bijections
  with no canonical choice; the literature needs the Hungarian algorithm or orbifold geodesics.
  A motif is an ordered sequence in time, so the bijection is given. Time supplies the
  correspondence that chord theory must infer.
- **Forte set classes are the wrong equivalence.** `T/I` classes discard order and register, so
  a motif and its retrograde-inversion collapse together. That is precisely the information to
  be kept: the goal is to *label* the derivation, not quotient it away.
- **Lewin remains the right frame**, at a different level of the hierarchy.

---

## 3. Pitch-class preliminaries

Included for completeness and because it replaces the retracted Galois material. Nothing later
depends on it.

**Proposition 3.1.** `ℤ/12` is a commutative ring, not a field. Its zero divisors are the
non-units. **[proved]** `4 · 3 = 12 = 0` and neither factor is `0`. ∎

**Proposition 3.2.** `(ℤ/12)* = {1, 5, 7, 11} ≅ ℤ/2 × ℤ/2`. **[proved]** These are the residues
coprime to 12; each squares to 1 (`25 = 1`, `49 = 1`, `121 = 1` mod 12), so the group has
exponent 2 and order 4. ∎

Musically these four maps are `M₁` (identity), `M₅` (circle-of-fourths), `M₇`
(circle-of-fifths), and `M₁₁ = I` (inversion).

**Proposition 3.3.** The module automorphisms of `ℤ/12` are exactly multiplication by units, and
adjoining translations gives the affine group

```
AGL(1, ℤ/12) = ℤ/12 ⋊ (ℤ/12)*,   |AGL(1, ℤ/12)| = 12 × 4 = 48,
```

which contains the transposition–inversion dihedral group `D₁₂` of order 24 as an index-2
subgroup. **[proved]** Standard. ∎

**Remark.** `Mₖ` for `k ∉ {1,5,7,11}` is not invertible: `M₂` maps twelve pitch classes onto
six. Those maps are legitimate and interesting but belong in the monoid of §5, not the group.
This is the same non-invertibility phenomenon as the circus mirror, in modular clothing.

---

## 4. The invertible group

### 4.1 The cyclic form

Extend the interval vector to the **cyclic interval vector** `ṽ ∈ ℤⁿ` by appending the wrap
interval `s₁ − sₙ`. Then `Σ ṽᵢ = 0` by telescoping, so cyclic motifs of length `n` live exactly
in the root lattice

```
Aₙ₋₁ = { v ∈ ℤⁿ : Σ vᵢ = 0 }.
```

### 4.2 Action of the classical operations

| operation | action on `ṽ` | order |
|---|---|---|
| transposition `Tₖ` | trivial | — |
| inversion `I` | `ṽ ↦ −ṽ` | 2 |
| retrograde `R` | `ṽ ↦ reverse(−ṽ)` | 2 |
| retrograde-inversion `RI` | `ṽ ↦ reverse(ṽ)` | 2 |
| rotation `σ` | cyclic shift | `n` |

**Corollary 4.1 (a checkable prediction).** `RI` is *pure reversal* in interval space: it
preserves every interval with its sign and only reorders them. `R` and `I` each negate.
**[conjecture]** `RI`-related passages should therefore be perceptually more similar than `R`-
or `I`-related ones. Listener studies broadly bear this out but the prediction has not been
tested here.

### 4.3 The closure theorem

**Theorem 4.2.** Let `σ` be rotation, `ρ` reversal, `ν` negation, acting on `Aₙ₋₁` as above.
Then

```
G_inv = ⟨σ, ρ, ν⟩ ≅ Dₙ × ℤ/2,     |G_inv| = 4n.
```

**[proved]** `σ` has order `n` and `ρ` order 2, and `ρσρ = σ⁻¹`, so `⟨σ, ρ⟩ ≅ Dₙ` of order `2n`.
Both `σ` and `ρ` act by permuting coordinates; `ν` acts by `−1` on the lattice, which for `n ≥ 3`
is not a coordinate permutation, so `ν ∉ ⟨σ, ρ⟩`. Since `ν` commutes with every coordinate
permutation and `ν² = 1`, the product is direct. Hence `|G_inv| = 2n × 2 = 4n`. ∎

`Dₙ` is the automorphism group of the cycle graph on `n` nodes — that is, of the **affine Dynkin
diagram `Ãₙ₋₁`** — and `ν` is the lattice automorphism `−1`. So:

> The entire classical invertible toolkit — transpose, invert, retrograde, rotate — is exactly
> the symmetry group of the affine `Aₙ₋₁` diagram together with negation. **Nothing else
> invertible exists at this level.**

**Corollary 4.3.** For non-cyclic motifs, `σ` is unavailable and `G_inv` collapses to the Klein
four-group `V₄ = {1, I, R, RI}`, order 4.

**Corollary 4.4 (the strategic consequence).** Since the invertible part is this small and this
completely determined, **the interesting content of the theory must live in the non-invertible
part.** This is the single most useful thing Theorem 4.2 tells us, and it sets the agenda for
§5 onward.

---

## 5. The non-invertible monoid

### 5.1 Stretches

Let `Σ ⊂ ℤ` be a finite interval alphabet, say `[−N, N]`. A **stretch** is a map `f : Σ → ℤ`
applied elementwise to `ṽ`, subject to

- `f(0) = 0` — repeated notes stay repeated;
- `f` weakly monotone — contour is preserved.

Uniform stretch is `f(x) = round(cx)`. Non-uniform stretch — the *circus mirror* — is any other
monotone `f`. Under composition these form a monoid `M`.

### 5.2 The irreversibility theorem

**Theorem 5.1.** The group of units of `M` is trivial.

**[proved]** Suppose `f ∈ M` is invertible in `M`, so `f` is a bijection `Σ → Σ` and weakly
monotone. A weakly monotone bijection of a finite totally ordered set is strictly increasing,
and a strictly increasing bijection of a finite totally ordered set is the identity. Hence
`f = id`. ∎

> **Every non-trivial circus mirror is irreversible.** This is not a rounding accident; it is
> forced by the order structure.

The algebra is therefore a monoid, and derivations have a *direction*: they flow from seed to
surface and cannot be run backwards without extra information. That asymmetry is the formal
reason why the generative half of the project is easy and the analytic half is research.

### 5.3 Odd versus asymmetric mirrors

If `f(−x) = −f(x)` then `f` commutes with inversion and reversal, and the structure is a direct
product `M × G_inv`. If `f` is asymmetric — stretching ascending leaps more than descending ones
— commutation fails and the structure is a genuine semidirect product. **[conjecture]** Asymmetry
is musically real, since rising and falling leaps do not behave alike, so the harder case is the
one that will be needed.

### 5.4 A correction: vectors are not the source of irreversibility

**[retracted]** The Group Action notes classify the circus mirrors as non-invertible because
they apply a *vector* of deltas rather than a scalar. That reasoning is wrong: an additive
vector is invertible — subtract it back — and `ℤⁿ` under addition is a group. Changing a major
third to a minor third by moving one note down a semitone is perfectly reversible.

Irreversibility has exactly two sources:

1. **deletion** — the CRISPR mask, which destroys notes;
2. **rounding** — a multiplicative non-uniform map whose output must land on a lattice, so two
   distinct inputs can collapse (Theorem 5.1).

The vector/scalar distinction is real but it is a **cost** distinction, not an invertibility
one, and the cost model handles it correctly and for a better reason: a uniform transposition
costs one parameter, a non-uniform additive vector costs `n`. See §9.4.

---

## 6. The affine form, and what spelling repairs

### 6.1 The four-parameter form

By analogy with `y = C·sin(A(x − B)) + D`, write a transformation of the (time, pitch) plane as

```
m(B, D, A, C) :  (x, y) ↦ (A(x − B), C(y − D))
```

Four parameters: two translations, two scalings. This is the **diagonal affine group**
`AGL(1) × AGL(1)` — the product of two independent one-dimensional affine groups, one per axis.
It is exactly the "pitch maps and time maps commute" factoring, stated as a property of the
group rather than as an implementation convenience.

**Signed scalings absorb two operations.** With `A < 0` meaning retrograde-with-stretch and
`C = −1` meaning inversion, four primitive cases per axis reduce to two:

```
pitch:   translate(k)          scale(f, anchor)
time:    translate(d)          scale(f)
```

**[verified]** This is not tidying. Three consequences:

- **`invert(a)` and `scale(−1, a)` become the same object.** As separate code paths they
  disagreed on 10 of 25 chromatic pitches per two-octave span, because one negated the
  alteration and the other did not. With one case there is one answer.
- **Retrograde-with-augmentation becomes expressible.** Time factor `−2` had no representation
  in the four-case design; it had to be faked as a composition, costing two opcodes and
  distorting the accounting. It is also invertible in its own right: `×(−2)` then `×(−½)` is the
  identity.
- **The alteration must scale with the factor**, not ride along. Only then does `f = −1` send an
  ascending semitone to a descending one — C♯ inverted about C is C♭, which is correct and which
  makes inversion an involution.

Formally, on spelled pitch:

```
step'       = anchor + round( f · (step − anchor) )
alteration' = round( f · alteration )
```

### 6.2 Spelling restores invertibility

**Theorem 6.1.** On spelled pitches `P = ℤ × ℤ`:

1. `translate(k)` is invertible for every `k ∈ ℤ`;
2. `scale(f, a)` is invertible if and only if `|f| = 1`.

By contrast, if a pitch is represented by its sounding height alone and the pair `(step,
alteration)` is recomputed on each application, then diatonic transposition and inversion **fail
to be invertible** on precisely those pitches whose alteration carries them onto another scale
degree.

**[proved]** (1) `translate(k)` acts as `(s, a) ↦ (s + k, a)`, a bijection with inverse
`translate(−k)`. (2) `scale(f, a)` is a bijection iff both coordinate maps are, and
`x ↦ round(f·x)` is a bijection of `ℤ` iff `|f| = 1`.

For the failure: recomputation applies the canonicalisation `h ↦ (s, a)` with `a` minimal
non-negative. C♯ enters as `(35, +1)`; `translate(2)` gives `(37, +1)`, sounding 65; but 65 *is*
step 38 with alteration 0, so recomputation returns `(38, 0)` and `translate(−2)` yields
`(36, 0)` = D, not C♯. ∎

**[verified]** Computationally, over every `(step, alteration)` with `step ∈ [20, 60)` and
`alteration ∈ [−2, 2]`: under stored spelling, **0 failures** for both the transposition
round-trip and the inversion involution. Under recomputation, failure on **every** altered
pitch — 4 of every 25 pitches in a two-octave span, being exactly the chromatic ones.

**Corollary 6.2.** Enharmonic distinction (§11) and the temporal analysis of accidentals are
representable only under stored spelling. They were not merely unimplemented in v0.1; they were
unrepresentable.

### 6.3 The two missing affine parameters

The full affine group of the plane has six parameters. The model uses four. The omitted two are
the shears, and they are not meaningless:

- **onset shear** — time offset proportional to pitch — is the **rolled or arpeggiated chord**,
  a block chord sheared into an arpeggio. One parameter, a real compositional operation,
  currently inexpressible. **[open]** Worth a case.
- **pitch shear** — pitch offset proportional to time — is glissando or portamento.

*Accelerando is not affine at all.* It is a nonlinear time warp and belongs in the monoid of §5.

---

## 7. The time domain

Everything in §§4–6 repeats on the duration vector `d ∈ ℚⁿ₊`:

- **uniform augmentation and diminution**: `d ↦ cd`, `c ∈ ℚ₊` — a group, `(ℚ₊, ×)`;
- **non-uniform time warp**: elementwise monotone map — a monoid with trivial unit group, by the
  same argument as Theorem 5.1;
- **quantisation to a metric grid** — the non-invertible step, exactly parallel to pitch
  rounding.

**Proposition 7.1 (structural symmetry).** Pitch and time carry isomorphic algebraic structure:
a small finite group of invertible symmetries, plus a monoid of monotone distortions whose unit
group is trivial. The metric grid plays in time the role the scale plays in pitch.

**Implementation note.** Time must be exact rational, not floating point. Once durations become
`Double`, `scale(2) ∘ scale(½) = id` stops being checkable with `=`, tolerances creep into the
matcher, and — as observed in the Cantus prototype — a `timeFactor = 0.5` silently loosens a
rhythm score until the *order of the transform list* is choosing the analysis. Rationals also
have an exact finite bit cost, which the scoring in §9 requires and which a `Double` does not.

---

## 8. Structural operations and the derivation program

### 8.1 Length-changing operations

These are not endomorphisms of a fixed `ℤⁿ`:

- **excise** `E[i:j]` — the CRISPR cut, a contiguous subsequence;
- **concatenate** `m₁ ⊕ m₂`;
- **elide** — overlap the last note of `m₁` with the first of `m₂`;
- **interpolate** — insert passing tones (the main source of surface noise);
- **project** `H` — realise the motif in another texture or voice.

`E` and `⊕` make the system a **graded monoid** over motif length. `H` is a map into a different
register/timbre coordinate and should be metadata, not pitch-time content, or it contaminates
the interval algebra.

**Design consequence.** Transformations must carry an **arity** `n → m`, not assume `n → n`.
Retrofitting this is painful.

### 8.2 The zipper: the one binary operation

`Z(x₁, x₂)` interleaves two phrases note by note. Everything else in the algebra is unary — a
monoid acting on phrases — so `Z` makes the structure an algebra with a product.

Three observations, none of which are in the source notes:

- **The zipper is compound melody** — a single line the ear resolves into two voices, which is
  precisely what Bach's solo violin and cello writing does. The notes propose the operator and,
  separately, choose the partitas as test repertoire. They are the same phenomenon.
- **The zipper is the inverse of voice separation.** A voice separator un-zips. The analysis
  direction of this operator is already implemented in AMT005 as `MPVoiceSeparator`. For a
  compound-melody movement, the derivation is: separate voices → derive each → zip.
- **[measured]** It predicts something checkable. On an 8-note figure formed by zipping a 4-note
  ascent against its own inversion:

  ```
  literal encoding of the zipped stream    217.0 b     27.12 b/note
  zipper program                           193.1 b     24.13 b/note
  the same notes as two stated seeds       267.5 b
  ```

  The literal encoding is expensive *because* the surface leaps wildly
  (60, 60, 62, 59, 64, 57, 67, 53) while the two implied voices are smooth. Therefore **the
  zipper's saving grows with the registral separation of the implied voices** — compression
  should jump discontinuously at exactly the passages where a listener begins hearing two voices.
  Testable on the partitas against published compound-melody analyses.

**[open]** Behaviour on unequal-length arguments (pad, truncate, or distribute proportionally),
and granularity (note, measure, or phrase).

### 8.3 Self-similarity

The **fractal string**: the seed's own intervals supply the transposition levels of its copies.
For each note `i` of a seed, place a copy of a child transposed by the seed's step-interval from
note 0 to note `i`, at onset `i · spacing`.

**[measured]** On the source notes' own example (steps 0, 3, 2, 7 above C4; durations 1, ½, ¼, ¼):

```
literal, 16 notes                    383.0 b     23.94 b/note
levels stated explicitly             249.9 b     — verified to reproduce the same phrase
levels derived (selfSimilar)         169.1 b     10.57 b/note
```

Deriving beats stating by 80.8 bits and beats literal by 2.3×. **The saving is exactly the cost
of restating the seed's own interval vector**, which is what self-similarity *means*, now
expressed as arithmetic rather than as a metaphor.

Nørgård's infinity series is the musical precedent and L-systems the formal one. The
construction is not novel; **pricing it is**, and pricing is what turns "this piece is
self-similar" from an observation into a measurement.

### 8.4 Derivations are programs

Since stretches do not commute, order is structure; and since music varies its variations, a
variant is itself a seed. The object describing a piece is therefore not "seed plus set of
transformations" but a **straight-line program**: a DAG whose leaves are seeds, whose internal
nodes are transformation applications, and whose root emits the score. Named definitions may be
cited more than once, so a shared subtree is paid for once and cited thereafter.

That is the whole reason a tree beats a list under MDL. In a fugue, the answer, the
countersubject entries and the stretto are not eleven independent facts; they are one fact cited
eleven times. A list must restate it. A program says `ref("subject")`.

Formally this is grammar induction over a parameterised rule set.

**[verified]** A minimal instance — a subject stated once and its diatonic answer cited three
times — costs 186.9 bits against 217.0 literal, and reproduces its own output exactly.

**Node set as implemented:** `seed`, `ref`, `apply`, `place`, `overlay`, `selfSimilar`, `zip`.

---

## 9. The description-length criterion

### 9.1 The criterion

This is what the transformational literature lacks and what makes the theory testable. A
derivation **explains** a passage if and only if

```
bits(seeds) + bits(transformation vocabulary) + bits(derivation DAG) + bits(residual)
      <   bits(literal encoding)
```

One criterion replaces eleven tuned constants. It penalises exotic transformations automatically,
because they cost more bits to name. It lets fragments compete fairly against full-length
matches. It makes cross-composer comparison a number — bits per note — rather than an adjective.

**This is the specific defence against Réti's fate.** With a rich enough transformation set any
two fragments can be related; Réti was demolished on exactly that. Nothing in his method
constrained the transformation budget. Here the budget is the whole mechanism.

### 9.2 Codes

Universal codes throughout, so that no free parameters enter through the pricing.

```
gamma(m)        = 2·⌊log₂ m⌋ + 1                       (Elias gamma, m ≥ 1)
integer(n)      = gamma(zigzag(n) + 1),  zigzag(n) = 2n if n ≥ 0 else −2n−1
rational(p/q)   = integer(p) + integer(q)
choice(prior π) = −log₂ π
index(of n)     = log₂ n
```

**[verified]** `gamma` must be computed from the integer's bit length, not from `log₂` on a
`Double`. The float version agreed over every value tested (1…4096), but "verified over a range"
is weaker than "cannot differ", and the exact version costs nothing. The same applies to
rounding: `Rational.roundedToInt` uses pure integer arithmetic, because rounding is load-bearing
in exactly the one map — `scale` — where non-invertibility lives.

### 9.3 The reuse threshold

**[verified]** Rough magnitudes for a 6-note motif: literal ≈ 50 bits; a transformation instance
≈ 24 bits; declaring a circus mirror on alphabet `[−12, 12]` ≈ 125 bits, paid once.

> **An exotic transformation must be reused about five times before it pays for itself.**

This is exactly the composer's intuition: an idiosyncratic operation counts as part of a piece's
logic only when it becomes a recurring device. One-off cleverness is scored as noise, correctly.

### 9.4 Uniform versus non-uniform, priced

A uniform transposition costs one parameter. A non-uniform additive vector over `n` notes costs
`n`. That, not irreversibility (§5.4), is the honest reason the circus mirror is expensive, and
it is what produces the threshold in §9.3.

### 9.5 A distance on transformation space

The notes ask for a metric, to place counter-themes "far enough to contrast, not so far as to
lose coherence." The cost model supplies one with no new machinery: the **conditional
description length**

```
d(a, b) = bits to describe b given a
```

symmetrised and normalised. This is Li–Vitányi normalised information distance. It is the
existing cost function run with one argument held fixed.

---

## 10. Similarity classes, priced

### 10.1 Definitions

On step-interval vectors `j` (reference) and `k` (candidate) of equal length:

| class | condition |
|---|---|
| **congruent** | `j = k` |
| **strictly similar** | for each `i`: `jᵢ = kᵢ = 0`, or `jᵢ·kᵢ > 0` |
| **inversely similar** | for each `i`: `jᵢ = kᵢ = 0`, or `jᵢ·kᵢ < 0` |
| **similar** | `jᵢ·kᵢ ≥ 0` for all `i` |

These are sign-vector conditions. Writing `σ(j) ∈ {−,0,+}ⁿ⁻¹`: strictly similar is `σ(k) = σ(j)`;
inversely similar is `σ(k) = −σ(j)`; plain similar is the looser componentwise-compatible
relation. The classes form a filtration by how much of the interval vector a claim pins down.

### 10.2 The degenerate case

**[verified]** `jᵢ·kᵢ ≥ 0` holds when `kᵢ = 0` and `jᵢ ≠ 0`. So a candidate that simply repeats
one pitch is "similar" to every motif of the right length. A flat line is similar to everything.

**[measured]** This is not hypothetical. Against a shuffled null model, four-note contour
matching scored 22.6% coverage on real music and **15.8% on shuffled** — about **70% of short
contour matches are chance**. Strictly similar should be the default; plain similar should never
be reported without its null-model baseline beside it.

### 10.3 Pricing replaces ranking

A strict-similarity claim specifies the sign vector and nothing else, buying `(n−1)·log₂3` bits:

```
n = 4:    4.8 bits
n = 6:    7.9 bits
n = 8:   11.1 bits
```

Against a literal six-note motif near 50 bits, a sign-vector claim explains about 8 — so it must
be cheap to state or frequently reused to survive. **That is the correct behaviour, and it is
why the tiers stop being a ranked list of names and become a single computation.** The
hand-asserted `hierarchicalOrder` array is replaced by arithmetic.

---

## 11. Modulation as a decision, not a description

### 11.1 The reframing

The source notes propose treating accidentals as field extensions with a *temporal* component:
an **extension rate** (how fast non-diatonic tones enter) and a **persistence** (how long the
extension lasts before resolving) — fast and fleeting versus slow and long-lasting.

Strip the field-extension language (§1, retracted) and the substance is exact and new. In the
algebra a note outside the declared space is carried as an `alteration`, and an alteration is a
*residual* that costs bits. Declaring a new space also costs bits, paid once. So the question
"is this chromaticism or modulation?" has an arithmetic answer:

> **Declare the new space exactly when the alterations it removes cost more than the
> declaration.**

### 11.2 The threshold

**[verified]** Computed from the implemented cost functions:

```
declare one space (C major)                        53.0 bits
declare one space (G major)                        59.0 bits
one alteration as a retune edit, mean over
  positions 1…40                                   15.2 bits

break-even                                    ≈ 3.9 altered notes
```

> **Up to about three accidentals is embellishment; four or more is modulation.**

Nobody tuned that. It falls out of the Elias-gamma codes and the size of a seven-note pattern.
It is close enough to how theorists hear the distinction to be worth taking seriously, and
precise enough to be wrong.

**Caveat, stated plainly.** The number 3.9 is a property of *this encoding*. A different
universal code shifts it. What is robust is the *ordering* and the existence of a crossover; the
specific value is code-dependent and must be reported as such.

### 11.3 Consequences

- **Extension rate** becomes alterations per bar.
- **Persistence** becomes the span between the first and last alteration attributable to one
  target key.
- **Temporal profile** becomes a plot of bits currently spent on alterations against time — a
  tension curve derived from the encoding rather than asserted.
- **Enharmonic distinction** (G♯ versus A♭) is the same issue in different dress: distinguishing
  them requires stored spelling, which §6.2 supplies.
- **The key-pointing effect** — F♯ in C major implying G — is **[open]**. Under MDL it would be
  the observation that a single alteration is cheaper to encode as a *partial* space declaration
  than as a residual, but no formulation of "partial declaration" has been settled.

### 11.4 The tower, recovered: Galois connections

The source notes keep returning to a tower picture: scale extensions stacked like
`ℚ ⊂ ℚ(√2) ⊂ ℚ(√2, √3)`, adjoining an accidental like adjoining a radical, with intermediate
extensions in between and a correspondence organising them. §1 retracted the *field* version of
this — `ℤ/12` has zero divisors, and a diatonic set is not a subring. But the intuition should
not be discarded with the formalism, because the modern skeleton of Galois theory is not about
fields at all. It is order-theoretic: an **antitone Galois connection** between two posets,
whose closed elements form dually isomorphic lattices. Fields-and-groups is one instance.
There is another instance sitting inside a score, exactly where the notes point.

Take the two posets to be sets of **time spans** `T` and sets of **pitches** `P` (spelled, per
§2.2), ordered by inclusion, with the maps

```
T ↦ P(T) = the set of pitches sounding within T
P ↦ T(P) = the largest union of spans using only pitches from P
```

This pair is an antitone Galois connection, so `P(T(·))` and `T(P(·))` are closure operators,
and the closed pairs — a span-set together with exactly the pitch material it uses — are
**formal concepts** in the sense of Formal Concept Analysis. They form a complete lattice.

That lattice *is* the tower, made rigorous:

- **Adjoining a radical** = passing to the join with the new pitch: the closure of
  `{C-major} ∪ {F♯}` is the smallest closed extension containing the intruder — precisely the
  "invasive species alters the local ecosystem" picture, as a closure operator.
- **Intermediate extensions** = intermediate elements of the concept lattice — the analogue of
  the fundamental theorem's intermediate fields, and they are *computable from the score*
  rather than posited.
- **Extension rate and persistence** (§11.1–11.2) become properties of a concept's extent: how
  fast its span-set grows, and how long it survives before the closure collapses back.
- **The tower diagram** the notes want to draw — `C → C+F♯ → G → …` — is a chain in this
  lattice, and the whole lattice shows which chains coexist and where they merge.

**[open]** What replaces the Galois *group* — the automorphisms fixing a base — is not yet
worked out; candidates are the invertible transformations of §4 that stabilise a concept.
**[open]** Connecting concept-lattice structure to the §11.2 declaration threshold: a space
declaration should be profitable exactly when a concept's extent is large enough, which would
tie the lattice to the bit criterion. Until then the honest statement is: the tower is real,
its correct formalisation is a Galois connection rather than a Galois extension, and the beauty
the notes locate "in the chords and melodies of one of the key extensions" is priced by the
§11.3 tension curve — the bits spent on alterations, plotted over the very spans the lattice
identifies.

### 11.5 The arc theorem: the tower's numbers are exact

Gregory's counting — C major is 7 of 12 notes; adjoin F♯ and the 8-note set contains the
chords of both C and G; adjoin C♯ too and the 9 notes contain C, G, and D; the further from C,
the more notes the extension needs — is not merely suggestive. It is a theorem about arcs.

**Theorem 11.1.** Order the twelve pitch classes by fifths: F–C–G–D–A–E–B–F♯–C♯–G♯–D♯–A♯.
Then (i) every major-key collection is an **arc of 7 consecutive positions** in this cyclic
order; (ii) extending an arc by `k` positions sharpwise yields a set of `7+k` notes containing
exactly `k+1` complete major keys, for `0 ≤ k ≤ 4`; (iii) at `k = 5` the arc closes and the
set contains all twelve keys at once.

**[verified]** Checked exhaustively: all 12 major keys are 7-arcs, and the extension chain from
C gives 1, 2, 3, 4, 5 keys inside for `k = 0…4` — precisely the counts in the source notes —
then jumps to 12 at `k = 5`. (The underlying classical fact is that the diatonic collection is
a *generated set* — seven consecutive fifths — in the sense of Clough–Douthett's diatonic set
theory; maximal evenness is the same property seen from the other side.)

Three consequences worth stating plainly.

**ℤ/12 is the algebraic closure.** The observation that "every key fits into ℤ/12, so it is
meaningless" is exactly right, and it completes the field analogy at the correct point: the
chromatic gamut plays the role of `ℚ̄`. The algebraic closure contains every root of every
polynomial and for that very reason carries no information about any particular equation; all
Galois-theoretic content lives in the *finite subextensions*. Likewise the chromatic set
contains every key and says nothing; all tonal content lives in which **arc** the music
currently inhabits. Theorem 11.1(iii) is the collapse into the closure, visible in the
computation.

**The equation-solving parallel is exact at the level of minimal closures.** "Solving
`3x = 5` needs no extension of ℚ; solving `x² − 2 = 0` forces √2; solving `(x²−2)(x²−3)`
forces √3 as well." Translate: the *chord you need* determines the *minimal arc containing
it*. A D-major triad `{D, F♯, A}` is unsolvable in the C arc; its minimal enclosing arc is the
8-note C∪G extension — F♯ is the radical the equation forces. This is the secondary dominant:
V-of-V in C is the musical `x² − 2 = 0`, the most common single-accidental event in tonal
music. And it makes the §11.3 **key-pointing effect** a definition rather than a metaphor:
F♯ "points to G" because the minimal closed extension of the current arc containing F♯ has G
as its new complete key. What the notes called math-like is, at this level, just math.

**What carries over and what does not.** The lattice of intermediate extensions generated by
independent adjunctions carries over: subsets of adjoined accidentals correspond to
intermediate arcs, with sharpwise and flatwise as the two independent directions of growth
(adjoining C♯ without F♯ leaves a *gap* in the arc — a genuinely chromatic, non-tonal set —
just as adjoining √3 does not yield √2). Two things do not carry over and should not be
claimed: degree multiplicativity (`[ℚ(√2,√3):ℚ] = 4` has no musical analogue, since arcs grow
additively), and the Galois *group* of an extension, which remains **[open]** as noted in
§11.4. The nearest existing structure to a group traversing the tower is Hook's **signature
transforms** — the operations that slide a key signature sharpwise or flatwise — which act on
the set of 7-arcs exactly as rotation acts on arcs of a 12-cycle.

**A pricing refinement this forces. [open]** §11.2 prices every space declaration from scratch
(53–59 bits). The arc picture says declarations should be priced as *slides*: a modulation to
an adjacent key is a one-position shift of the arc and should cost a few bits, a distant key
proportionally more — cost growing with circle-of-fifths distance. That changes the modulation
threshold from a constant into a function of key distance, and it yields a new falsifiable
prediction (No. 10): under MDL, near modulations are preferred explanations, so **modulation
frequency in real corpora should decay with fifths-distance** — which matches known tonal
practice and can be checked against annotated corpora directly.

### 11.6 The ℤ/7 lens: generic intervals, Myhill's property, and pointed arcs

The key of C, viewed on its own terms, is a copy of ℤ/7 — degree indices 1̂…7̂ — together with
an **embedding** into the chromatic lattice: `C D E F G A B ↦ 0 2 4 5 7 9 11`. Adding 1 in ℤ/7
lands 1 or 2 semitones away depending on where you stand. This pair — the degree lattice, the
embedding — is precisely the `Space`/`Pitch` structure of §2, and the two-sizes phenomenon is
not an irregularity to be tolerated but a *theorem with a name*:

**Theorem 11.2 (Myhill's property). [verified]** In the major embedding, *every* generic
interval — not only the step — comes in exactly two specific sizes:

```
generic step      →  1 or 2 semitones
generic third     →  3 or 4
generic fourth    →  5 or 6
generic fifth     →  6 or 7
generic sixth     →  8 or 9
generic seventh   →  10 or 11
```

Checked exhaustively over all seven positions for each generic interval. This is classical
diatonic set theory (Clough–Myerson's *cardinality equals variety*; Carey–Clampitt's
*well-formed scales* — the diatonic is well-formed because it is generated by the fifth, which
is also why it is an arc in §11.5's ordering). The point of citing it here: **Myhill's property
is the *cause* of the F–F–F–D phenomenon.** A diatonic transposition preserves the generic
interval (a third) while the specific size flips between its two values (−4 ↔ −3). The
"similar but not congruent" second statement of Beethoven 5, the tonal answer of fugue, and
the ±1-semitone tolerance result of §13.1 are all corollaries of one embedding property.

**The three readings of an adjoined F♯.** Set against a C-major context, a sounding F♯ admits
exactly three structural interpretations, and all three are representable in the algebra:

1. **Alteration** — F♯ = `(step F, +1)`: stay in C's frame; the chord built on D changes
   quality (D minor → D major) while every degree keeps its index. Priced as residual bits.
2. **Modulation** — the arc slides one position sharpwise *and the anchor re-latches to G*:
   "G maps to 1̂." Priced as an arc-slide plus re-anchor.
3. **Mode** — the arc slides but the anchor *stays on C*: C Lydian. **[verified]** the C Lydian
   collection and the G major collection are the *same set*; they differ only in which element
   is the tonic.

Reading 3 is the one the modulation threshold of §11.2 was silently missing, and it is common
practice — the Lydian IV-of-IV colour in popular music is exactly a D-major chord in a C
context that never resolves to G. Its existence forces a refinement of the arc theorem:

> **A key is a *pointed* arc.** The collection determines the arc; the tonic is a separate
> point on it. Modulation proper changes both arc and point (C → G). Modal shift changes the
> point only (C major → A minor: same arc, new point) or the arc only (C major → C Lydian:
> new arc, same point). The three readings of F♯ are: no change (alteration), both change
> (modulation), arc-only change (mode).

This decomposition makes §11.2's decision three-way rather than two-way, each branch with a
computable price: residual bits (reading 1), slide + re-anchor bits (reading 2), slide-only
bits (reading 3). Which reading wins on a given passage is decided by persistence — §11.2's
break-even — not by assertion. **[open]** Implement the three-way pricing; predict that
short-lived F♯s resolve to reading 1, F♯s followed by cadential confirmation on G to reading
2, and sustained F♯s over a C pedal to reading 3.

**On "inventing new mathematics."** The instinct that neither ℤ/7 nor ℤ/12 alone is the right
object is correct — the right object is the *triple* (degree lattice, embedding, anchor
point), with maps required to respect it. But the components are not new: the embedding and
its two-sizes behaviour are Clough–Myerson and Carey–Clampitt; the action is Lewin; the
pricing is Rissanen's MDL. What has no precedent is the *assembly* — spelled pitch as stored
state inside a cost-scored derivation algebra. New structure was needed and built; new axioms
were not. That is the honest version of the claim, and it is also the defensible one.

### 11.7 All keys at once: the classification of spaces

"The only difference between C major, C minor and C dorian is how 1̂, 2̂, 3̂ are mapped with
different jumps — and a slight change in that definition gives all keys, even those not
created by a circle of fifths." Correct, and it is the `Space` type verbatim: a tonic plus an
ascending pattern, with chromatic as the pattern (0,1,…,11) rather than a special case. Every
map, both theorems, the derivation programs and the pricing are pattern-independent by
construction.

What is *not* pattern-independent is the §11.5–11.6 superstructure — Myhill, the arc theorem,
key-pointing — and it fails in classifiable ways that correspond to things one can hear.
**[verified]** For each pattern: step sizes (with wrap), number of specific sizes per generic
interval, Myhill, single-interval generatedness, and the transposition stabilizer:

```
scale              steps      sizes/generic          Myhill   gen by   |stab|
C major            {1,2}      2,2,2,2,2,2            yes      fifth    1
C natural minor    {1,2}      2,2,2,2,2,2            yes      fifth    1
C dorian           {1,2}      2,2,2,2,2,2            yes      fifth    1
C harmonic minor   {1,2,3}    3,2,3,3,2,3            no       —        1
C melodic minor ↑  {1,2}      2,2,3,3,2,2            no       —        1
C pentatonic       {2,3}      2,2,2,2                yes      fifth    1
whole tone         {2}        1,1,1,1,1              no       step     6
octatonic          {1,2}      2,1,2,1,2,1,2          no       —        4
Hungarian minor    {1,2,3}    3,3,3,3,3,3            no       —        1
chromatic          {1}        1,1,…,1                no       semitone 12
```

Three consequences.

**Modes are the same row.** Major, natural minor and dorian are indistinguishable in every
column — they are rotations of one pattern, i.e. the same arc with a different anchor point,
which is exactly the pointed-arc statement of §11.6. The claim that opened this section is a
theorem about rotations.

**Three regimes, two axes.** The scales organise along *variety* (the sizes-per-generic
profile) and *symmetry* (the stabilizer):

1. **Well-formed** (major and its modes, pentatonic): fifth-generated, Myhill exactly,
   trivial stabilizer. The full §11.5–11.6 apparatus applies — arcs, towers, sharp
   key-pointing.
2. **Asymmetric, non-generated** (harmonic minor, melodic minor, Hungarian minor): no single
   generator, Myhill fails — harmonic minor's augmented second is a *third step size*, and
   Hungarian minor achieves three sizes for *every* generic interval, maximal variety. The
   arc theorem does not apply, so their extension towers are not fifths-chains; but the
   stabilizer is trivial, so key-pointing still works. These are the scales that are *in* the
   algebra but *off* the circle-of-fifths tower — precisely the "keys not created by a circle
   of fifths."
3. **Symmetric — Messiaen's modes of limited transposition** (whole tone, octatonic,
   chromatic): non-trivial stabilizer. Messiaen's celebrated category is, in this table, one
   column: `|stab| > 1` ⟺ the pattern is periodic.

**Key-pointing degrades with symmetry, by arithmetic.** A transposition of a scale with
stabilizer of order σ carries only `log₂(12/σ)` bits — the cost model prices whole-tone
transposition at `log₂ 2 = 1` bit and chromatic transposition at 0. Minimal-arc closure
(§11.5) is unique for regime 1, non-unique in proportion to σ for regime 3. This is the
formal content of the whole-tone scale's "floating" quality: its anchor is almost
information-free. And it explains a line from the Beethoven analysis (Set 5's structural map,
p. 15: *"diminished 7th chords exploited — maximum harmonic instability"*): the diminished
seventh is the octatonic's symmetric core, stabilizer order 4, so it points four ways at once
— which is exactly why it is *the* classical modulation pivot. Maximum instability = maximum
stabilizer, as an equation rather than a metaphor.

One observation held at arm's length: the diatonic row — two sizes everywhere, no symmetry —
maximises interval variety subject to evenness while carrying full key information. It sits
between whole-tone (too even: no variety, no anchor) and Hungarian minor (maximal variety, no
tower). That the historically dominant scale occupies this particular extreme point resonates
with §12.4's sweet-spot claim, but the resonance is noted, not asserted.

---

## 12. Style, and the aesthetic hypothesis

### 12.1 Signatures

Style signatures require a shared alphabet with computable costs. The old thirty-case enum with
`[String: Double]` parameters supplied neither. The transform algebra does: every transformation
is a composition of typed constructors with an exact bit cost, so a frequency distribution over
Σ and an n-gram model over Σ are both well defined, and barycentric mixing of two signatures is
mixing two distributions over the same measurable space.

The one number that makes this publishable rather than suggestive is **bits per note**. "Bach's
grammar differs from the Beatles'" becomes "Bach compresses to 3.1 b/note under a shared
transformation alphabet, the Beatles to 4.7" — a claim with a unit, comparable across corpora,
falsifiable by anyone who re-runs it.

### 12.2 Two cautions

**[open]** **MDL analyses are not unique.** Several encodings of the same passage often come
within a few bits of each other, and n-grams computed from "the" derivation would be reading
noise. Either commit to the strict argmin and report the margin to the runner-up, or marginalise
over the top-`k` encodings weighted by `2^(−bits)`. The second is more honest and not much
harder.

**[open]** **Classification needs the null model too.** A classifier separating Bach from the
Beatles on transformation features will report high accuracy even on shuffled labels if the
feature space is large enough. Report accuracy minus chance, with chance measured.

### 12.3 The aesthetic hypothesis

The motivating claim is that "musical beauty is immediately recognisable to our ears, and there
must be a natural mathematical process which causes that beauty to be recognised."

As stated this is not testable. The information-theoretic version is, and there is existing work
to connect to: **Marcus Pearce's IDyOM** models musical expectation by information content and
predicts listener responses — surprise ratings, pupil dilation, neural signals — from statistical
learning. That is the closest existing research, it is information-theoretic, and it is the
baseline.

**[conjecture]** The claim that would extend it: **grammatical description length adds
predictive power over IDyOM's statistical description length.** Specific, falsifiable, and the
right shape for a first external result.

### 12.4 The sweet spot, formalised

The governing aesthetic intuition is a two-sided constraint: **minimal seeds and minimal
transformations** — since with enough of either anything can be recreated and the analysis
proves nothing — while avoiding both extremes: the monotone end (repeated pitches, scales) and
the chaotic end (twelve-tone-like patternlessness). The sweet spot between them is the goal.

MDL formalises this axis directly, and the piece under study already sits on it. **[measured]**
Literal encoding cost of five sequences of identical length (1362 notes):

```
repeated single pitch        1.00 b/note      ← monotone extreme
monotonous scale             3.40 b/note
BEETHOVEN op18/1, real       4.16 b/note      ← the music
same pitches, shuffled       7.39 b/note
uniform random pitches       8.49 b/note      ← chaotic extreme
```

Real Beethoven lies strictly between order and chaos — compressible, but far from degenerate.

But raw bits per note is not the beauty number, because both extremes score *low or high* on it
monotonically. The right quantity is the **two-part split** at the MDL-optimal analysis:

```
L(piece) = L(model) + L(residual | model)
```

Define the **structure content** `S(piece) = L(model*)` — the bits invested in seeds,
vocabulary and derivation at the optimum. Then:

- **monotone extreme**: tiny model, tiny residual → `S` small;
- **chaotic extreme**: nothing compresses, the optimal model is *empty* and everything is
  residual → `S` small again;
- **the conjectured sweet spot**: `S` large — much of the piece is genuinely structured, and
  the structure itself is rich.

`S` is (a computable proxy for) Kolmogorov **sophistication**, and the same idea appears as
Gell-Mann's *effective complexity* and is cousin to Bennett's *logical depth*. Both extremes
score low; only material that is deeply but not trivially patterned scores high. **[conjecture]**
Beloved melodies have high structure content `S` relative to length; monotone exercises and
shuffled controls both score low. This is the precise form of "navigating the sweet spot", and
it is measurable with the machinery already built.

**Cross-piece comparison** then has a natural formal object. Each analysed piece yields a
vocabulary `Σᵢ`; the right thing to compare is not the lists but the **submonoids ⟨Σᵢ⟩ they
generate** inside the full transformation monoid (and the subgroups `⟨Σᵢ⟩ ∩ G_inv` inside the
invertible part, where genuine group theory applies). **[conjecture]** Across acknowledged
masterpieces the intersection `⟨Σ₁⟩ ∩ ⟨Σ₂⟩ ∩ ⋯` is small and non-trivial — a candidate
*canonical vocabulary* — while the per-piece complements carry style. One great piece
deconstructed gives `Σ₁`; the second gives the first intersection; that is the order of work.

---

## 13. Empirical results to date

### 13.1 The dominance result

**[measured]** Test piece: Beethoven Op. 18 No. 1, movement I, Violin I (1362 notes). Seed: the
bar-1 turn figure `[65, 65, 67, 65, 64, 65]`. Null model: the same piece with its pitch sequence
randomly shuffled, 300 trials, seed held fixed.

| method | coverage, real music | coverage, shuffled | z |
|---|---|---|---|
| strict contour sign, 6-note | 19.4% | **8.0% ± 1.8%** | +6.5 |
| strict contour sign, 4-note | 22.6% | **15.8% ± 1.8%** | +3.8 |
| soft sign, 6-note | 20.7% | 1.0% ± 0.7% | +29.0 |
| exact intervals, 6-note | 7.9% | 0.0% ± 0.0% | +312 |
| **exact intervals ±1 semitone, 6-note** | **24.7%** | **0.1% ± 0.2%** | **+127** |

> **Exact interval matching with ±1 semitone tolerance achieves higher coverage than strict
> contour-sign matching (24.7% vs 19.4%) with a false-positive rate roughly 80× lower (0.1% vs
> 8.0%).**

Contour tiers are not merely unnecessary; they are **strictly dominated**. At six notes, 8 of
the 19.4 points are chance. At four notes, 15.8 of 22.6 are chance. Strict sign at *eight* notes
scores **below** chance (1.2% vs 4.2%), because greedy claiming lets junk matches consume notes
that real matches needed.

Two readings to guard against. Soft sign scoring well is an artefact: the seed is full of small
intervals, so its soft signature is mostly zeros, which shuffled large intervals rarely produce.
And the ±1 tolerance is absorbing major-versus-minor variants of the same interval — which is
the diatonic phenomenon, and crude confirmation of the scale-degree argument. A proper
scale-degree representation should capture the same gain more cleanly and also handle modulation.

### 13.2 Compression results

**[verified]** All from the implemented cost functions, all reproducing their target phrase
exactly.

| construction | literal | model | b/note |
|---|---|---|---|
| subject + answer cited 3× | 217.0 b | 186.9 b | — |
| fractal, levels stated | 383.0 b | 249.9 b | 15.62 |
| fractal, levels derived | 383.0 b | **169.1 b** | **10.57** |
| zipper (compound melody) | 217.0 b | 193.1 b | 24.13 |

### 13.3 Verification status of the implementation

**[verified]** 32 of 32 algebra laws pass in the Python mirror, including every law that the
previous design's self-test asserted plus the extended checks that caught its two defects.
**[open]** The Swift transliteration has not been compiled — no Swift toolchain is reachable
from the development environment. Arithmetic verified, syntax not.

---

## 14. Falsifiable predictions

The list that makes this a theory rather than a formalism.

1. **[conjecture]** `RI`-related passages are perceptually more similar than `R`- or `I`-related
   ones (Corollary 4.1).
2. **[conjecture]** In annotated corpora, passages with ≤3 accidentals attributable to one
   target key are heard as chromatic embellishment; ≥4 are heard as modulation (§11.2).
3. **[conjecture]** Compression jumps discontinuously at compound-melody passages, and the jump
   scales with registral separation of the implied voices (§8.2).
4. **[conjecture]** The countersubject of a fugue lies in the orbit of the subject, at lower cost
   than stating it literally. One number, one yes or no, on BWV 847.
5. **[conjecture]** The same operator set applies at every hierarchical level — motif, phrase,
   section, movement — with only the mask and interpolate operators requiring rescaling.
6. **[conjecture]** Bits per note under a shared alphabet separates composers, and the separation
   survives a shuffled-label null model.
7. **[conjecture]** Grammatical description length adds predictive power over IDyOM's statistical
   description length in modelling listener expectation (§12.3).
8. **[conjecture]** Structure content `S` (§12.4) is high for beloved melodies and low for both
   monotone and shuffled controls of the same length — the sweet-spot claim, as one number.
9. **[conjecture]** The generated submonoids `⟨Σᵢ⟩` of independently analysed masterpieces have
   a small non-trivial intersection — a canonical vocabulary — with style carried by the
   complements (§12.4).
10. **[conjecture]** Under arc-slide pricing of modulation (§11.5), near modulations are
    preferred explanations, so modulation frequency in real corpora decays with
    circle-of-fifths distance.
11. **[conjecture]** Under three-way pricing of an adjoined accidental (§11.6), short-lived
    accidentals encode as alterations, accidentals followed by cadential confirmation as
    modulations, and sustained accidentals over a stable bass as modal shifts — matching how
    listeners and analysts actually classify them.

---

## 15. Open problems

1. **Segmentation is entangled with discovery.** One cannot enumerate "the pieces of the melody"
   without knowing where they begin, and the boundaries depend on which transformations are
   permitted. Needs joint search or iteration to a fixed point.
2. **Approximate matching.** Real occurrences carry ornaments and passing tones. Requires a
   transformation-aware edit distance, and this is where the combinatorial explosion lives.
3. **Harmonic licensing.** In tonal music a "transposition" is usually a diatonic sequence
   licensed by the harmony. The transformation set may need harmonic context as a parameter.
4. **Is the residual meaningful?** If a piece compresses to 40% and the rest is residual, is the
   residual the composer's freedom or a missing operator? The theory needs a stance on when to
   stop inventing transformations.
5. **The residual model under spelled pitch.** A retune that changes `step` and one that changes
   `alteration` are musically different events and should be priced differently. Unresolved.
6. **Onset shear** (§6.3) — one parameter, buys arpeggiation, not yet implemented.
7. **Quotient groups.** Classifying movements by cosets `G/H` requires `H` normal in `G`, which
   is well defined only on the invertible part `G_inv ≅ Dₙ × ℤ/2`. The monoid has no such
   structure. Say so explicitly or the vocabulary will be applied where it does not hold.
8. **Key-pointing** (§11.3).

---

## 16. Provenance

| section | origin |
|---|---|
| §2.4, §4, §5, §7, §8.1, §8.4, §9.1–9.3, §15.1–15.4 | *The Motivic Transformation Algebra* v0.1 |
| §3, §10, §11, §12 | Concepts / Algebraic Music Theory Notes §§1–12 and add-ons |
| §6.1, §6.3, §8.3, §5.4 | Group Action Composition §§III–V |
| §8.2, §9.5, §12.3, §14.5 | Notes 5/24, dialogue section |
| §13.1 | Cantus code review, §4 |
| §2.2, §2.3, §6.2, §9.2, §13.2, §13.3 | this revision |

Corrections introduced in this revision: the Galois retraction (§1); the invertibility
retraction (§1, §6.2); the vector/irreversibility correction (§5.4); the code-dependence caveat
on the modulation threshold (§11.2).

---

## 17. Implementation map

| concept | type in `MotifAlgebra` |
|---|---|
| space (§2.1) | `Space` |
| spelled pitch (§2.2) | `Pitch(step:alteration:)` |
| phrase, total order (§2.3) | `Phrase`, `Note.canonicallyPrecedes` |
| translate / signed scale (§6.1) | `PitchMap`, `TimeMap` — two cases each |
| composition (§4, §6) | `Transform.then(_:)` |
| exact time (§7) | `Rational` |
| program (§8.4) | `Derivation`, `Program` |
| zipper (§8.2) | `Derivation.zip` |
| self-similarity (§8.3) | `Derivation.selfSimilar` |
| codes (§9.2) | `Cost` |
| criterion (§9.1) | `Verdict.explains` |
| similarity classes (§10) | `Similarity` |

Not yet implemented: residual and edits (§15.5), onset shear (§6.3), excise / elide /
interpolate (§8.1), null-model harness (§13.1), corpus tooling (§12).
