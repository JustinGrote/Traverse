function Convert-HashToString
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $Hash
    )
    $hashstr = "@{"
    $keys = $Hash.keys
    foreach ($key in $keys)
    {
        $v = $Hash[$key]
        if ($key -match "\s")
        {
            $hashstr += "`"$key`"" + "=" + "`"$v`"" + ";"
        }
        else
        {
            $hashstr += $key + "=" + "`"$v`"" + ";"
        }
    }
    $hashstr += "}"
    return $hashstr
}