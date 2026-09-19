#!/usr/bin/env perl
# scripts/lint/ascii_sweep.pl
# One-time, whole-repo ASCII migration for markdown prose.
#
# Converts the curated set of non-ASCII characters (below) to their approved
# ASCII replacements, skipping fenced code blocks so ASCII-art / inline code
# is never touched. This is a one-time migration tool; the ongoing gate is
# markdownlint-cli2 (.markdownlint-cli2.mjs + scripts/lint/doc-ascii.mjs).
#
# Usage: scripts/lint/ascii_sweep.pl [--check] FILE...
#   default    rewrite each FILE in place
#   --check    report remaining non-ASCII prose; exit 1 if any
#
# Approved mapping (chore ruling 2026-09-19):
#   em/en dash -> - ;  arrows -> -> / <- / <-> ;  checkmark -> [x] ;
#   cross -> [ ] ;  multiples >= <= != == ;  times -> x ;  minus -> - ;
#   ellipsis -> ... ;  bullet -> * ;  dagger -> (drop) ;  section/pilcrow
#   wording -> [section]/[para] left verbatim (rare, hand-edited).
use strict;
use warnings;
use open ':std', ':encoding(UTF-8)';

my $CHECK = (@ARGV && $ARGV[0] eq "--check") ? 1 : 0;
shift @ARGV if $CHECK;

# codepoint -> ASCII replacement ('' removes the char)
my %MAP = (
  0x2014 => "--",   # — em dash
  0x2013 => "-",    # – en dash
  0x00AD => "",     # soft hyphen
  0x2192 => "->",   # →
  0x2190 => "<-",   # ←
  0x2194 => "<->",  # ↔
  0x2191 => "^",    # ↑
  0x2193 => "v",    # ↓
  0x21D2 => "=>",   # ⇒
  0x2260 => "!=",   # ≠
  0x2264 => "<=",   # ≤
  0x2265 => ">=",   # ≥
  0x2261 => "==",   # ≡
  0x00D7 => "x",    # ×
  0x2212 => "-",    # −
  0x2026 => "...",  # …
  0x2022 => "*",    # •
  0x2713 => "[x]",  # ✓
  0x2714 => "[x]",  # ✔
  0x2705 => "[x]",  # ✅
  0x274C => "[ ]",  # ❌
  0x2717 => "[ ]",  # ✗
  0x2B1C => "[ ]",  # ⬜
  0x00E9 => "e",    # é
  0x2011 => "-",    # non-breaking hyphen
  0x2019 => "'",    # ' right single quote
  0xFE0F => "",     # variation selector
  0x2020 => "",     # † dagger (drop)
  0x00A7 => "",     # § section sign (drop)
  0x00B6 => "",     # ¶ pilcrow (drop)
  0x00B9 => "^1",   # ¹ superscript one
  0x23ED => "->",   # ⏭ skip-forward
  0x26A0 => "[!]",  # ⚠ warning
  0x2500 => "-",    # ─ box horizontal (prose quotes; fences skipped)
  0x2502 => "|",    # │ box vertical
  0x251C => "+",    # ┌ box corner
  0x2514 => "-",    # ┘ box corner
  0x00B2 => "2",    # ² superscript two
  0x23F3 => "[p]",  # ⏳ hourglass = pending
  0x1F7E1 => "[y]", # 🟡 yellow = partial
  0x1F50D => "[r]", # 🔍 magnifier = refer
  0x1F512 => "[l]", # 🔒 lock
  # U+D83D* broken surrogates (U+D800-DFFF) removed below
);

my $bad = 0;
for my $f (@ARGV) {
  open(my $fd, "<:encoding(UTF-8)", $f) or die "open $f: $!";
  my @lines = <$fd>;
  close $fd;

  my @out; my $infence = 0;
  if ($CHECK) {
    # pure detector: distinct codepoints outside fences, unmapped flagged
    my %seen; my $inf = 0;
    for my $line (@lines) {
      if ($line =~ /^[ \t]*(```|~~~)/) { $inf = !$inf; next; }
      next if $inf;
      for my $c (grep { ord($_) > 127 } split(//, $line)) {
        my $cp = ord($c);
        my $known = defined $MAP{$cp} || ($cp >= 0xD800 && $cp <= 0xDFFF);
        $seen{sprintf("U+%04X%s", $cp, $known ? "" : " UNMAPPED")}++;
      }
    }
    for my $k (sort keys %seen) { print "$f: $k x $seen{$k}\n"; }
    next;
  }
  for my $line (@lines) {
    if ($line =~ /^[ \t]*(```|~~~)/) { $infence = !$infence; push @out, $line; next; }
    if ($infence) { push @out, $line; next; }
    $line =~ s/([\x{0080}-\x{10FFFF}])/
      my $cp = ord($1);
      if (defined $MAP{$cp}) { $MAP{$cp} }
      elsif ($cp >= 0xD800 && $cp <= 0xDFFF) { "" }  # broken surrogate
      else { $bad=1; "[U+".sprintf("%04X",$cp)."]" }
    /gex;
    push @out, $line;
  }

  if ($CHECK) {
    # report lines still holding unconverted non-ascii OUTSIDE fences
    my $sc = 0; my $inf = 0;
    for my $L (@out) {
      if ($L =~ /^[ \t]*(```|~~~)/) { $inf = !$inf; next; }
      next if $inf;
      ++$sc if $L =~ /[^\x00-\x7F]/;
    }
    print "$f: $sc residual line(s)\n" if $sc;
    next;
  }
  # abort (no write) on any unmapped codepoint: never invent replacements
  if ($bad) { print STDERR "ABORT $f: unmapped non-ASCII remains; add a mapping first\n"; exit 2; }
  open(my $w, ">:encoding(UTF-8)", $f) or die "write $f: $!";
  print $w @out;
  close $w;
}
exit $bad;