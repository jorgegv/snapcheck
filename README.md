# SNAPCHECK

SNAPCHECK (`snapcheck.pl`) is a debugging tool you can use for games for
which you have the source available.  In my particular case, I'm using the
tool fo debugging games developed with my RAGE1 engine, but the tool is
useful in other environments.

The scenario which this tool tries to improve is the following:

- The game triggers some unknown bug, which makes it behave erratically, or
  even hangs it.

- When this happens, there are lots of things that may be happening in a
  constrained environment like the ZX Spectrum: corrupted stack due to too
  many call nesting levels, memory corruption due to rogue pointers...

- The usual method is to start inspecting data structures with breakpoints
  and memory dumps in an emulator, until an unexpected value is found and
  then trace up to that point with the debugger.

- The problem may have been identified with this checks or not, and probably
  the process will have to be repeated with a new memory address or data
  structure until a new problematic value or event is found.

- When there is no source level debugger (like in Z88DK, my current
  development platform), this is quite cumbersome and involves checking lots
  of files back and forth: C sources, generated ASM files, .LIS files, .MAP
  files, etc.  and having a lot of program state in mind when analyzing. 
  The search for a bug can be quite tedious and error prone.  And even more:
  _the procedure is always the same for all RAGE1 games._

- It would be great to specify a lot of assertions that should be true at
  any point during the game, check them at runtime to ensure the correct
  game state, and discover where are the discrepancies.  This could be
  possible by sprinkling `assert` macros all over the source, but with such
  a memory constrained machine as the Speccy, soon the assertions take away
  a lot of memory for our game.

- An alternative could be to check the assertions externally: let the game
  run in release mode with no instrumentation, and instead analyze the
  current memory map for wrong contents.

- SNAPCHECK does exactly this: it takes as input a snapshot of your game in
  SZX format, and processes it through a set of predefined rules that must
  be true during program execution.  It then reports the failures it finds,
  which hopefully will point you in the right direction searching for the
  problem.

Examples of rules:

- SP register must be between 0x8000 and 0x8080 (example values) when in EI
  mode

- IM must be 2 at all times

- Byte value at address 0xABCD must be between 0 and 5 (for a lives counter)

- Word value at address [_game_state+12] must be between 0x5000 and 0x9000
  (rules can use address symbols from a .MAP file)

- ...etc.

The main benefit of this tool is that the rule database is the same for all
RAGE1 games (i.e.  the assertions can be reused if they are defined
carefully and/or using symbols) and so new rules can be added as needed in
order to debug new problems.

Also it can serve trace problems found by users, if they are able to take a
snapshot of the game just when the bug is happening.

Finally, the analyzed game is the real one, no special instrumentation is
needed to be compiled in.

The rule syntax and some examples are described in the [RULES](RULES.md) file.
