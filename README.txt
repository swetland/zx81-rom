
This is Z80 assembly source for the ZX81 ROM.

This version came from this URL -- I cannot find the author or more context:
https://cdn.hackaday.io/files/289631239152992/ZX81_dual_2018-02-09.htm

This repository tracks the original as I tidied it up to build under z80asm
and will track any further cleanup I do.


It appears to be derived from this version (dated 13-DEC-2004):

https://www.tablix.org/~avian/spectrum/rom/
https://www.tablix.org/~avian/spectrum/rom/zx81.htm

"These files were originally hosted at www.wearmouth.demon.co.uk and
maintained by Geoff Wearmouth. Unfortunately that website went off-line
sometime around the end of 2015 and as of 2017 no copies were available
for the casual reader. To keep this valuable historical resource available,
some files from that website have been preserved here. Files hosted on
this website are from a snapshot captured on 1 September 2015. They were
not modified, except for this index page, which was copy-edited for
readability."

The original files are archived in the mirror/ subdirectory for reference.


The hackaday hosted version folds together the original and "shoulders of
giants" (enhanced) rom sources with conditional build directives, but more
importantly uses descriptive labels like LIST-TOP instead of address-based
labels like L0433 which the original rom listing does.

