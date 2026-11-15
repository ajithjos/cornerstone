# Learning product definition

Cornerstone delivers one assignable playbook. The persisted curriculum name is `playlist`; “playbook” is its user-facing name. A pathway orders related playbooks. Subjects and areas organise browsing, stages organise progression, and skills describe what evidence can establish.

## Four explicit sections

Every playbook declares, in order:

- **Teach**: owner-only teaching rationale, sequence, examples, correction advice and answer keys. Shared guidance is referenced by several playbooks, not copied per lesson. This section stays accessible during learning, practice and checking.
- **Learn**: the learner's durable explanation, worked examples and reference tables; readable and printable.
- **Practice**: reusable practice capabilities and paper exercises. A new attempt generates a fresh valid set. An unfinished attempt resumes its issued plan. A completed attempt can be followed by another. Written levels belong here, inside their playbook.
- **Checkpoint**: independent work with explicit coverage, accuracy and optional time criteria. A generated checkpoint uses the same runtime capabilities as practice with assessment rules. Paper checkpoints carry explicit marking targets.

Owners see all four. Learners receive only Learn, Practice and Checkpoint from the backend; Teach is not merely hidden by Flutter. Viewing a learner's work never changes the owner's active identity. Profile switching is a separate action.

## Assignment and completion

Assign a playbook to an explicitly selected learner. Materials are reusable assets inside the playbook, not separately assigned work. Opening a material retains its playbook and section context.

An assignment completes when all its checkpoints are completed successfully. Reading and unlimited practice do not require artificial completion actions. Submitted failed checkpoints remain unfinished and can be attempted again. A completed checkpoint is not automatically evidence that every broader skill is confirmed: that requires representative skill coverage.

`completion_percent`, `checkpoint_count` and `completed_checkpoint_count` describe this contract. Session counts remain internal execution statistics.

## Ownership

Authored files declare section membership, skills, runtime parameters and assessment criteria. Rust compiles these into explicit owner and learner delivery contracts and owns generation, marking, assignments, evidence and progress. Flutter renders those contracts. Independently delivered activity packages render backend-owned exercises inside the app frame using the host's appearance contract.

There is one current model and one initial database migration. This cutover requires a fresh database. It does not migrate or reinterpret older assignments, package pins or activity instances.
