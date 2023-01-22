# .into-utf8.nu / unicode.nu

# Local aliases
alias remove = do {|x| str replace -sa ($x | into string) ''}
alias replace = str replace -sa
alias contains = str contains
alias ncontains = str contains -n


# Parse text as hex and print Unicode character.
export def "from unicode" [
  --decimal (-d)  # From decimal instead of hex.
] {
  let temp = [(metadata $in).span, $in]
  let span = $temp.0
  let uni = $temp.1
  $uni | each {
    |e|
    let uni = ($e | into string)
    let decimal = (
      if ($uni | contains '&#') and ($uni | ncontains '&#x')
      and (($uni | ncontains '0x') and ($uni | ncontains '\u')) {
        true
      } else {
        $decimal
      }
    )
    let uni = ($uni | uni-normalize)
    if $decimal {
      $uni | into hex | into utf8 $span | decode utf8
    } else {
      $uni | into utf8 $span | decode utf8
    }
  }
}

def uni-normalize [] {
  $in | remove '0x' |
  remove 'U+' |
  remove '&#x' | remove '&#' |
  remove '{' | remove '}' |
  replace '\u' ' ' |
  replace ';' ' ' | str trim
}

# Convert hex-represented Unicode into UTF-8
export def "into utf8" [
  --raw (-r) # Output as raw octets instead of Nushell's binary primitive
  --decimal (-d) # Treat input as decimal
  span?: string # Only useful when called by other functions. Do not fill it.
] {
  # A shame there is not yet pattern matching in Nushell, while `$in` can be
  # used only once and at the beginning of a function.
  let temp = [(metadata $in).span, $in]
  let span = if $span != null {
    $span
  } else {
    $temp.0
  }
  let in_hexes = $temp.1
  
  $in_hexes | each {
    |in_hex|
    $in_hex | split row ' ' | each {
      |in_hex|
      let in_hex = if $decimal {
        # Without limiting it, it returns something but not exactly the result...
        try { let _ = ($in_hex | into int) } catch {
          panic {
            msg: "Input cannot be parsed as decimal"
            label: "Try removing `-d` if input was hex"
            span: $span
          }
        }
        $in_hex | into int
      } else {
        try { let _ = ($in_hex | into int -r 16) } catch {
          panic {
            msg: "Input cannot be parsed as hex"
            label: "Invalid hex"
            span: $span
          }
        }
        $in_hex
      }
      let in_int = ($in_hex | into int -r 16)
      if $in_int < 0 {
        panic { # fancy error make
          msg: "Invalid hex"
          label: "Unicode hex cannot be a negative number"
          span: $span
        }
      }
      let octets = if $in_int < 0x80 {
        [] | prepend ($in_int | into radix 2)
      } else {
        get-octets $in_int
      }
      if $raw {
        stringify-octets $octets
      } else {
        binarize-octets $octets
      }
      } | if $raw {
      $in | str join ' '
    } else {
      $in | bytes collect
    }
  }
}

def get-octets [in_int: int] {
  mut octets = []
  mut in_bytes = ($in_int | into radix 2)
  let octet_meta = get-octet-meta $in_int
  let prefix = ($octet_meta | get prefix)
  mut octet_num = ($octet_meta | get octet)
  while $octet_num > 1 {
    $octets = ($octets | prepend (
      "10" + ($in_bytes | str substring '-6,')
    ))
    $in_bytes = ($in_bytes | str substring ',-6')
    if ($in_bytes | str length) < 6 {
      $in_bytes = ($in_bytes | str lpad -l 6 -c '0')
    }
    $octet_num -= 1
  }
  let remaining = (8 - ($prefix | str length))

  $octets | prepend ($prefix + ($in_bytes | str lpad -l $remaining -c '0'))
}

def get-octet-meta [in_int: int] {
  # ASCII-compatibles are previously handled
  [0x800, 0x10000, 0x200000, 0x4000000, 0x80000000] | each {
    |el ind|
    if $in_int < $el {
      {
        prefix: ("0" | str lpad -l ($ind + 3) -c "1"),
        octet: ($ind + 2)
      }
    }
  } | get 0
}

def stringify-octets [octets: list] {
  $octets | each {
    |e| $e | into int -r 2 | into hex | into string | '0x' + $in
  } | str join ' '
}

def binarize-octets [octets: list] {
  $octets | str join | into int -r 2 | into binary |
  bytes remove -a 0x[00] | bytes reverse
}


# Get Unicode representation of character(s)
export def "into unicode" [
  --html(-w)      # HTML Style, p.ex. `&#x13000;`
  --c (-c)        # `\u13000`
  --rust (-r)     # `\u{13000}`
  --decimal (-d)  # Use decimal instead of hex. Does not work with `--c` and `--rust`.
  --unicode (-u)  # `U+13000`
] {
  let temp = [(metadata $in).span, $in]
  let span = $temp.0
  let in_chars = $temp.1

  $in_chars | each {
    |in_chars|
    let $u_chars = ($in_chars | split chars | each {
      |e| $e | utf82unicode | str upcase
    })
    if $html {
      if $decimal {
        $u_chars | into int -r 16 | into string | each {
          |e| '&#' + $e + ';'
        } | str join
      } else {
        $u_chars | each {
          |e| '&#x' + $e + ';'
        } | str join
      }
    } else if $c {
      $u_chars | each {
        |e| '\u' + $e
      } | str join
    } else if $rust {
      $u_chars | each {
        |e| '\u{' + $e + '}'
      } | str join
    } else if $unicode {
      $u_chars | each {
        |e| 'U+' + $e
      } | str join ' '
    } else if $decimal {
      $u_chars | into int -r 16 | into string | str join ' '
    } else {
      $u_chars | each {
        |e| '0x' + $e
      } | str join ' '
    }
  }
}

# Convert UTF-8 to Unicode hex
def utf82unicode [] {
  let utf8_hex = ($in | encode utf8 | into radix 16 | 
  if ($in | str length) mod 2 != 0 {'0' + $in} else {$in} | into string)
  mut utf8_hex = $utf8_hex
  mut utf8_bytes = []
  while not ($utf8_hex | is-empty) {
    let byte = ($utf8_hex | str substring ',2' | '0x' + $in)
    $utf8_hex = ($utf8_hex | str substring '2,')
    $utf8_bytes = ($utf8_bytes | append $byte)
  }
  $utf8_bytes | into radix 2 -f 16 | str lpad -l 8 -c '0' | each {
    |e|
    [0 10 110 1110 11110 111110 1111110] | into string | each {
      |prefix ind|
      if ($e | str starts-with $prefix) {
        $e | str substring $'($ind + 1),'
      }
    } | get 0
  } | str join  | into radix 16 -f 2
}

export def "bytes from-string" [] {
  # Not sure why, but `str trim` is buggy here, by Nu 0.74
  # And comments inside closure will make it malfunction... How strange!
  $in | each {
    |e| 
    $e | into string | split row ' ' |
    into int -r 16 | into binary |
    bytes remove -a 0x[00] | bytes collect
  }
}

# TBD or never, since it's not really something important
def test [] {
  let test_data = null
  assert-eq 1 1 4
  echo OK
}

def assert-eq [x y info] {
  if $x == $y {true} else {panic $info}
}

def panic [info] {
  error make {
    msg: $info.msg
    label: {
      text: $info.label
      start: $info.span.start
      end: $info.span.end
    }
  }
}
