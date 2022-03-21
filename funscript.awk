BEGIN {
    FS = ","
    direction = 1
    factor = 50 / ( max - min )
    print "{"
    print "\"actions\": ["
}
{
    if ( NR == FNR ) {
        action[int($1)] = $2
        printf "at: %d offset: %d stored: %d\n", int($1), $2, action[int($1)] > "/dev/stderr"
    }
    else {
        value = $4
        at = int( $1 * 1000 )
        offset = action[int($1)]
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
