BEGIN {
    FS = ","
    direction = 1
    factor = multiplier * 50 / ( max - min )
    action[0] = 50
    print "{"
    print "\"actions\": ["
}
{
    at = int( $1 * 1000 )
    if ( NR == FNR ) {
        action[at] = $2
        printf "at: %d offset: %f stored: %f\n", at, $2, action[at] > "/dev/stderr"
    }
    else {
        value = $4
        offset = action[at]
        norm = value * direction * factor
        norm_offset = norm + offset
        printf "value: %f, offset: %f, norm: %f, norm_offset: %f\n", value, offset, norm, norm_offset > "/dev/stderr"
        pos = int( 50 + norm )
        pos > 100 ? pos = 100 : pos = pos
        pos < 0 ? pos = 0 : pos = pos
        direction = direction * -1
        printf "%s{\"pos\": \"%s\", \"at\": \"%s\"}\n", separator, pos, at
        separator = ","
        end = at
    }
}
END {
    print " ], "
    printf "\"metadata\":{\"creator\":\"audio-funscripter\",\"description\":\"Procedurally generated\",\"duration\":%d}", end
    print " } "
}
