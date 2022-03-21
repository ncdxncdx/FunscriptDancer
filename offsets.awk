BEGIN {
    FS = ","
    factor = 50 / ( max - min )
}
{
    time = $1
    input = $4
    output = ( input -min ) * factor + 25
    printf "%f,%f\n", time, output
}
