## MODIFIED Requirements

### Requirement: Instruction budget
Where the engine meters instructions, a call SHALL stop with a budget error when it runs more instructions than
its budget. The native engine SHALL meter instructions. The js engine does not meter. A budget SHALL be from 1 to
9223372036854775807 instructions, the range of a positive 64-bit integer. The native engine SHALL enforce every
budget in this range exactly, on every platform that it supports, including Windows, where a C `long` has 32 bits.
The native engine SHALL enforce the budget with every C compiler that builds it, including MSVC.

#### Scenario: Budget range
- **WHEN** a caller makes budgets of 1, 2147483648, 5000000000 and 9223372036854775807, and budgets of 0 and -1
- **THEN** the first four are accepted with the same count, and the last two are refused with a limit error that
  names the rule

#### Scenario: Budget above 2^31 on native
- **WHEN** a guest loop needs more than 2148483648 instructions, and it runs once with a budget of exactly its
  instruction count and once with a budget of 1 instruction less, on native
- **THEN** the first call completes and the second call stops with a budget error

#### Scenario: Runaway loop on native
- **WHEN** a guest loops forever in a call with a budget of 1,000,000 instructions on native
- **THEN** the call stops with a budget error and the instance is not usable for more calls

#### Scenario: Budget with every C compiler
- **WHEN** the native engine is built with a C compiler that has no computed goto, such as MSVC, and a guest loops
  forever in a call with a budget of 1,000,000 instructions
- **THEN** the call stops with a budget error, as with a compiler that has computed goto
