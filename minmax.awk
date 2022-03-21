BEGIN {
    FS=","
    max=0
    min=10000
}
{
    value = $4
    if ( value > max )
        max = value
    if ( value < min )
        min = value
}
END {
    print min,max
}
