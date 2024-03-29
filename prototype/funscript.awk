BEGIN {
    FS = ","
    factor = multiplier * 50 / ( max - min )
    offsets[0] = 50
    last_at = 0
    last_pos = 50
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
        if ( at != last_at ) {
            int_at2 = int( ( at + last_at ) / 2 )
            pos = ( value * factor ) + offset
            peak( pos, int_at2, last_pos, last_at )
            last_at = int_at2
            last_pos = pos
        }
        pos = ( value * factor * -1 ) + offset
        peak( pos, at, last_pos, last_at )
        last_at = at
        last_pos = pos
    }
}
function peak( pos, at, last_pos, last_at ) {
    printf "pos %d, at %d, last_pos %d, last_at %d\n", pos, at, last_pos, last_at> "/dev/stderr"
    if ( last_pos < 0 ) {
        tmp_at = int_at( pos, at, last_pos, last_at, 0 )
        action( 0, tmp_at )
    }
    else if ( last_pos > 100 ) {
        tmp_at = int_at( pos, at, last_pos, last_at, 100 )
        action( 100, tmp_at )
    }

    if ( pos > 100 ) {
        tmp_at = int_at( pos, at, last_pos, last_at, 100 )
        action( 100, tmp_at )
        action( 200 - pos, at )
    }
    else if ( pos < 0 ) {
        tmp_at = int_at( pos, at, last_pos, last_at, 0 )
        action( 0, tmp_at )
        action( -pos, at )
    }
    else {
        action( pos, at )
    }
}
function action( pos, at ) {
    pos > 100 ? pos = 100 : pos = pos
    pos < 0 ? pos = 0 : pos = pos
    printf "%s{\"pos\":\"%s\",\"at\":\%s\}\n", separator, int( pos ), at
    separator = ","
}
function int_at( pos, at, last_pos, last_at, limit ) {
    before_ratio = abs( last_pos - limit )
    after_ratio = abs( pos - limit )

    return int( ( before_ratio * at + after_ratio * last_at ) / ( after_ratio + before_ratio ) )
}
function abs( v ) {
    v += 0
    return v < 0 ? -v : v
}
