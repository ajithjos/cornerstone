# Addition And Subtraction Foundations Brief

This is a worked example of the [Curriculum slice brief template](../curriculum-slice-brief-template.md).

It is an example brief, not the canonical product architecture. For the object model and source-format guidance, read [Planning, authoring, and runtime](../../architecture/planning-authoring-and-runtime.md).

Use this as the working brief for the first addition and subtraction route in Cornerstone.

The goal is not to cover all of arithmetic at once. The goal is to give a parent or coach one direct route for teaching addition and subtraction facts through `20` from a small set of memorised anchors.

## Identity

- Subject id: `maths`
- Subject title: Maths
- Area id: `arithmetic`
- Area title: Arithmetic

## Learner Context

- Target age range: 7 to 9
- Typical current level: can count and solve some written sums, but core facts are not yet automatic
- Why this area matters now: secure anchor facts make later written arithmetic much easier and reduce frustration in daily work
- Common learner mistakes or blockers:
  - counting in ones instead of recalling facts
  - weak fact families through `10`
  - confusion between addition and subtraction as inverse operations
  - no secure memory for doubles or `10 + n`
  - no clear method for `8 + 7` or `15 - 8`

## Desired Outcome

- What should the learner be able to do after this slice?
  - recall the fact families for totals through `10`
  - recall doubles through `20` and `10 + n` facts without hesitation
  - derive the remaining addition and subtraction facts through `20` by bridging through `10`
  - move from paper practice to short computer-based drills without confusion
- What should a parent or coach notice in real life?
  - the learner answers familiar facts faster
  - the learner stalls less often during written arithmetic
  - the learner can explain relationships such as `7 + 3 = 10`, `10 - 3 = 7`, and `8 + 7 = 8 + 2 + 5`
- What counts as weak, partial, or secure performance?
  - weak: still counts most facts one by one, misses anchor facts, or cannot explain a bridge-through-`10` step
  - partial: succeeds in grouped practice but slows down or breaks down in mixed review
  - secure: answers most facts accurately in mixed sets, with only occasional hesitation, and can explain the method sensibly

## Candidate Stages

### Stage: Fact Families Through 10

- What it means in plain language: the learner studies totals `1` to `10` in order and knows the matching subtraction facts from the same families
- Skills that belong inside it:
  - compose numbers to `10`
  - subtract within `10` from known facts

### Stage: Doubles And Add 10

- What it means in plain language: the learner memorises the next small set of anchor facts worth knowing cold
- Skills that belong inside it:
  - recall doubles through `20`
  - add `10` to single digits

### Stage: Bridge Through 10 Addition

- What it means in plain language: the learner can solve addition facts through `20` by making `10` first
- Skills that belong inside it:
  - bridge through `10` for addition

### Stage: Bridge Through 10 Subtraction

- What it means in plain language: the learner can solve subtraction facts through `20` by stepping back to `10` first
- Skills that belong inside it:
  - bridge through `10` for subtraction

## Candidate Skills

### Fact Families Through 10

- Skill title: Compose numbers to `10`
  - successful performance: gives the addition pairs for totals `1` to `10`, including zero pairs, without recounting
  - likely mistakes or misconceptions: remembers only a few famous facts such as `5 + 5`
  - out of scope: bridge-through-`10` methods
- Skill title: Subtract within `10` from known facts
  - successful performance: reads subtraction from a known addition family and answers without starting from `1`
  - likely mistakes or misconceptions: treats subtraction as a separate topic or mishandles zero facts
  - out of scope: two-digit subtraction methods

### Doubles And Add 10

- Skill title: Recall doubles through `20`
  - successful performance: answers `1 + 1` through `10 + 10` quickly in mixed order
  - likely mistakes or misconceptions: knows a chant but not the individual fact when it is isolated
  - out of scope: multiplication doubles language
- Skill title: Add `10` to single digits
  - successful performance: answers `10 + 1` through `10 + 9` immediately and recognises the commuted form after teaching
  - likely mistakes or misconceptions: treats each teen answer as a fresh count
  - out of scope: adding any two two-digit numbers

### Bridge Through 10 Addition

- Skill title: Bridge through `10` for addition
  - successful performance: splits one addend to complete `10` and then adds the leftover part
  - likely mistakes or misconceptions: counts on one by one instead of choosing the part that makes `10`
  - out of scope: written column addition

### Bridge Through 10 Subtraction

- Skill title: Bridge through `10` for subtraction
  - successful performance: steps back to `10` first and then subtracts the rest
  - likely mistakes or misconceptions: counts backward in ones or chooses the wrong first step to reach `10`
  - out of scope: regrouping in written subtraction

## Materials And Delivery

- likely material types:
  - `lesson_note` for learner-facing explanation, worked examples, and textbook-style fact pages
  - `teaching_note` for the parent cues that govern what to memorise and what to derive
  - `worksheet` for paper practice at a basic level and an advanced level
  - one `quick_check` stop point per playlist or stage boundary
  - one short computer-based `drill` for randomised practice once the method is clear
  - every playlist should include at least one `lesson_note`, one practice step, and one `quick_check`
- expected session length: 10 to 15 minutes
- expected cadence or number of sessions:
  - 4 to 5 sessions per week
  - 1 teaching or guided practice session
  - 2 to 3 short practice sessions
  - 1 mixed review or check session
- where review or recap should appear:
  - every playlist should include one mixed review session before moving on
  - weak anchor facts should reappear in later sessions even after a stage looks mostly secure
- notes that a parent, teacher, or coach will need during delivery:
  - stop a session before frustration climbs too high
  - prefer speed after accuracy, not before it
  - keep oral recall, paper practice, and quick checks separate enough that the learner knows the purpose of each
  - use the computer for short random drills only after the anchor facts or strategy have been taught clearly in a `lesson_note` or guided session

## Existing Repo Context

- existing ids or files to preserve:
  - keep `maths` and `arithmetic`
  - keep the core model of stage, skill, material, playlist, assignment, session, evidence, and progress
- files that may change:
  - `content/library/registry.yaml`
  - `content/library/maths/arithmetic/arithmetic-fact-fluency/pathway.md`
  - stage, skill, playlist, and material files under `content/library/maths/arithmetic/arithmetic-fact-fluency/`
- files that must not change for the first content pass:
  - learner runtime concepts such as assignment, session, evidence, and progress
  - Flutter app structure beyond small usability fixes unless a clearer pathway surface is being added deliberately

## Constraints And Open Questions

- vocabulary or tone constraints:
  - use direct parent-facing language
  - prefer `fact families`, `anchor facts`, `make 10`, and `bridge through 10`
  - avoid vague discovery language; teach directly and name the exact facts to memorise
- family, classroom, or accessibility constraints:
  - this is parent-led or coach-led teaching, not a classroom program
  - sessions should work with paper first and computer second
  - no voice input or handwriting recognition is required for MVP
- anything that must not be generated:
  - long abstract explanations
  - oversized playlists that try to cover all arithmetic at once
  - tightly coupled gamification or reward mechanics
- unresolved questions that need answers before authoring continues:
  - do you want a later follow-on pathway for near-doubles as a named strategy, or is that sufficiently covered by the bridge-through-`10` route?
  - should advanced checks later include the commuted form `n + 10`, or should the taught memorised list stay only as `10 + n`?
  - how aggressively should a ten-year-old be allowed to skip ahead after the first two checks?