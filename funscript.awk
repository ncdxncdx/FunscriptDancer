BEGIN {
    FS = ","
    factor = multiplier * 50 / ( log( max ) - log( min ) )
    offsets[0] = 50
    last_at = 0
}
{
    at = int( $1 * 1000 )
    if ( NR == FNR ) {
        offsets[at] = $2
        printf "at: %d offset: %f stored: %f\n", at, $2, offsets[at] > "/dev/stderr"
    }
    else {
        value = log( $4 )
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
function action( norm, at ) {
    norm_offset = norm + offset
    pos = int( norm_offset )
    pos > 100 ? pos = 100 : pos = pos
    pos < 0 ? pos = 0 : pos = pos
    printf "value: %f, offset: %f, norm: %f, norm_offset: %f, pos: %d\n", value, offset, norm, norm_offset, pos > "/dev/stderr"
    printf "%s{\"pos\":\"%s\",\"at\":\"%s\"}", separator, pos, at
}
