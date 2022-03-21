BEGIN {
    FS = ","
    factor = range / ( log( max ) - log( min ) )
}
{
    time = $1
    input = $4
    output = ( log( input ) - log( min ) ) * factor + ( ( 100 - range ) / 2 )
    printf "%f,%f\n", time, output
}
