BEGIN {
    FS = ","
    factor = multiplier * 50 / ( max - min )
    offsets[0] = 50
    print "{"
    print "\"actions\": ["
    last_at = 0
}
{
    at = int( $1 * 1000 )
    if ( NR == FNR ) {
        offsets[at] = $2
        printf "at: %d offset: %f stored: %f\n", at, $2, offsets[at] > "/dev/stderr"
    }
    else {
        value = $4
        offset = offsets[at]
        norm = value * factor * -1
        if ( at != 0 ) {
            int_at = int( ( at + last_at ) / 2 )
            int_norm = value * factor
            action(int_norm, int_at)
        }
        action(norm, at)
        separator = ","
        last_at = at
    }
}
END {
    print " ], "
    printf "\"metadata\":{\"creator\":\"audio-funscripter\",\"description\":\"Procedurally generated\",\"duration\":%d}", last_at
    print " } "
}
function action( norm, at ) {
    norm_offset = norm + offset
    pos = int( norm_offset )
    pos > 100 ? pos = 100 : pos = pos
    pos < 0 ? pos = 0 : pos = pos
    printf "value: %f, offset: %f, norm: %f, norm_offset: %f, pos: %d\n", value, offset, norm, norm_offset, pos > "/dev/stderr"
    printf "%s{\"pos\": \"%s\", \"at\": \"%s\"}\n", separator, pos, at
}
