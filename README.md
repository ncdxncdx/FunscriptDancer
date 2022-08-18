# FunscriptDancer

## Dependencies

Audio analysis is performed with:

[Sonic Annotator](https://vamp-plugins.org/sonic-annotator/)

This needs to be installed, and the binary added to the PATH [(For Windows)](https://helpdeskgeek.com/windows-10/add-windows-path-environment-variable/).

[Vamp Plugin Pack](https://code.soundsoftware.ac.uk/projects/vamp-plugin-pack)

Only BBC's and Paul Brossier's (Aubio) plugins are required.

Note that the word length (32 bit or 64 bit) of `sonic-annotator` and the Vamp plugins must match. If in doubt, you probably want the 64 bit versions.

## Running from source

Install Julia, e.g. by using [Juliaup](https://github.com/JuliaLang/juliaup)

Checkout this repo.

Run `julia --project -t auto -e "using FunscriptDancer; julia_main()"` from the repo root.

Note that on first run this will download and precompile the **entire** internet.

Also note that Julia is just-in-time compiled. Each bit of code will be compiled when it is called for the first time in a run. Once the Funscript preview is visible it should be snappy: before then, expect sluggishness.

## Prepackaged binaries

In principle it is possible to build relocatable packages for Windows/MacOS/Linux using Julia.

In practice this turns out to be flaky.

And the resulting packages are huge: this is partly because Julia's app build isn't terribly efficient, partly because dependencies aren't shy about depending on all sorts of things that the end user may or may not actually want.

Releases will be provided whenever I've got the damn thing to work to my satisfaction.