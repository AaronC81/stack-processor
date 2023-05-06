# Memory

| Stack        | Periphs | Code/Data                 |

Stack starts at right and grows downwards

# Flags

- Overflow

# Instructions

TODO: Size of values on the stack? Variable or not?
TODO: consistent suffix for "indirect"?

## Simple Stack Operations
- `push x (x10 {4})` - Push integer constant `x` to the stack
- `push0 (x11)` - Push 0 to the stack
- `pop (x02)` - Discard value from stack
- `swap` - Swap top two items
- `dup` - Duplicate top item

## Memory Operations
- `load addr` - Load value from immediate memory location, then push it to the stack
- `store addr` - Pop value from stack, and store it in immediate memory location
- `load-indirect` - Pop memory location from stack, read it, then push it to the stack
- `store-indirect` - Pop memory location from stack, pop value from stack, then write value to memory location

## Arithmetic
- `add` - Pop `b`, pop `a`, push `a+b`
- `sub` -         ^         push `a-b`
- `inc (x20)` - Pop `a`, push `a+1`

## Routines
- `br addr` - Pop memory location from stack, branch to it
- `call addr` - Pop memory location from stack, push address of next instruction, then branch to it
- `br-indirect`/`call-indirect` - self-explanatory
- `ret` - Pop memory location from stack, and branch to it
- `halt (xFF)` - Stop doing anything
- `nop (x00)` - Do nothing

TODO: conditionals?

# Example Program

```python
push 5
call double
call serial_write
halt

double:
    dup
    add
    swap    # Common pattern, since it allows you to 
    ret     # return something on the top of the stack

serial_write:
    store 0x1234 # Peripheral address
    ret
```
