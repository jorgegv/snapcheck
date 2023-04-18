# Snapcheck Rules

## Rule file syntax

As usual:

- Comments start with # and continue to end of the line
- Blank lines are ignored
- Syntax is case insensitive except for symbol names
- Rule syntax: one rule per line, with one of the syntaxes:

```
INCLUDE <file>
DEFINE <symbol> = <address+/-offset>
<type> AT <address+/-offset> IS <value>
<type> AT <address+/-offset> IS_NOT <value>
<type> AT <address+/-offset> BETWEEN <low_value> <high_value>
REGISTER <register> IS <value>
REGISTER <register> BETWEEN <low_value> <high_value>
BLOCK AT <address+/-offset> LENGTH <length> IS <value>
```

- `type`:
  - One of UINT8, UINT16, UINT32, INT8, INT16, INT32
  - BYTE is aliased to UINT8
  - WORD is aliased to UINT16
  - DWORD is aliased to UINT32
  - CHAR is aliased to INT8

- `address+/-offset`:
  - Addresses can be specified in decimal or hex
  - Hex can be specified with 0x or $ prefixes
  - Offset must be specified with + or - right after the address (no space)
  - Offset can also be in dec or hex, with same format as address
  - Symbols can be used instead of an immediate address (symbols can come
  from a .MAP file or defined with a DEFINE rule)

- `value`:
  - Values can be specified in decimal or hex
  - Hex can be specified with 0x or $ prefixes
  - Symbols can be used instead of an immediate value (symbols can come
  from a .MAP file or defined with a DEFINE rule)
  - NULL is predefined to be 0x0000

- `register`:
  - One of: af bc de hl af1 bc1 de1 hl1 ix iy sp pc i r iff1 iff2 im
  - Some of those are pseudoregisters

## Example rules

```
UINT8 AT 0xC000 IS 200
BYTE AT game_state+12 BETWEEN 0 5
BLOCK AT 0xD000 LENGTH 257 IS 0xD1
DEFINE int_vector_address 0xD1D1
WORD AT int_vector_address+1 IS _isr_function
WORD AT int_vector_address+1 IS_NOT NULL
REGISTER IM IS 2
REGISTER SP BETWEEN 0xD101 0xD1D0
```
