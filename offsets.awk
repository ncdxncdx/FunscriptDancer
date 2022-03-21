BEGIN {
    FS = ","
    factor = range / ( max - min )
}
{
    time = $1
    input = $4
    output = ( input - min ) * factor + ( ( 100 - range ) / 2 )
    printf "%f,%f\n", time, output
}
