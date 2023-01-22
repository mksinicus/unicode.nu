# unicode.nu

Nushell module with Unicode-related utility functions

## Dependency

Yes we have a dependency...

This script depends on utilities provided by my `into-hex.nu`, which can be
accessed [here](https://github.com/mksinicus/my-nushell-scripts/blob/main/.into-hex.nu).

You can simply concatenate two files into a standalone Nushell module.

## Usage

`use path/to/unicode.nu *`. Do not use `source`, we have local aliases and 
helper functions here.

The following functions are exported. All functions here support cellpath.

- `from unicode`: Parse text as hex or decimal and print corresponding Unicode
  character(s). Supports multiple formats (HTML entity, C-style and Rust-style
  Unicode escape). Can autodetect HTML entity decimal or hexadecimal 
  representation, but fails at mixture of both.
- `into utf8`: Parse hex or decimal Unicode representation into utf8 bytes. Can
  be either Nushell's binary primitive or raw string.
- `into unicode`: Parse text into string of Unicode representation. Supported
  formats include HTML entity (both hexadecimal and decimal, but not at the 
  same time), C-style and Rust-style Unicode escape, and the usual 
  representation (p.ex. `U+13000`), and string of hexadecimals separated by 
  whitespace.
- `bytes from-string`: Parse string into Nushell's binary primitive.

## Notes

This script is somehow experimental and is a toy project. There are many
implementations serving similar functions in the wild, more substratal and
self-contained than mine --- this script of mine relies heavily on Nushell's
builtin functions and data types --- like websites that provide such
conversion, mostly powered by JavaScript. But I would like to do it in terminal
without Node or Python.

The behavior of this script many be subject to change of the Nushell language.
I will be maintaining it as long as I use Nushell anyway (presumably for a
long while).
