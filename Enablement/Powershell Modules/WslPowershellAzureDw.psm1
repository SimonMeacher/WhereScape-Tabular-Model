#  (c) Wherescape Inc 2020. WhereScape Inc permits you to copy this Module solely for use with the RED software, and to modify this Module 
#  for the purposes of using that modified Module with the RED software, but does not permit copying or modification for any other purpose.            
#==============================================================================
# Module Name      :    WslPowershellAzureDw
# DBMS Name        :    Modules specific to Azure Synapse
# Description      :    Generic powershell functions module used by many
#                       different templates, scripts and database specific
#                       modules
# Author           :    Wherescape Inc
#==============================================================================
# Notes / History
#
#==============================================================================

<#
.DESCRIPTION
Used to run any SQL against AzureDw
.EXAMPLE
$return_Msg = Run-AzureDw-RedSQL "SELECT * FROM stage_customers" -dsn "dssdemo" "Some Error $step"
#>
function Run-AzureDw-RedSQL {
    param(
        $sql = '',
        $dsn = '',
        $uid = '',
        $pwd = '',
        $failureMsg = '',
        [ref] $status = ([ref] $status),
        $odbcConn,
        [switch]$notrans
    )
    $AzureDwResult = Run-RedSQL -sql $sql -dsn $dsn -uid $uid -pwd $pwd -odbcConn $odbcConn -notrans:$notrans
    if ( $AzureDwResult[1] -eq 1 ){
      if ( $AzureDwResult[2] -ge 0 ){
        $null = WsWrkError -Message "Step ${step}: rows applied: $($AzureDwResult[2])"
      }
      else {
        $null = WsWrkError -Message "Step ${step}: completed"
      }
    }
    else {
      $db_msg = ($AzureDwResult[3][$AzureDwResult[3].Count - 1]).replace("'","''")
      $db_code = $db_msg.substring($db_msg.indexOf('[')+1,$db_msg.indexOf(']')-$db_msg.indexOf('[')-1)
      $null = WsWrkAudit -Status "E" -Message "Step ${step}: An error has occurred: $db_msg" -DBMessage "$db_msg" -DBCode "$db_code"
      for($i = 0; $i -lt [math]::Ceiling($sql.length/250); $i ++) {
        $len = $sql.length - (($i*250)+1)
        if ( $len -gt 250 ) {
            $len = 250
        }
        $null = WsWrkError -Message "$( $sql.substring(($i*250)+1,$len) )"
      }
    }
    $status.value = $AzureDwResult[1]
    return $AzureDwResult[0], $AzureDwResult[2], $failureMsg
}
# SIG # Begin signature block
# MIIYXgYJKoZIhvcNAQcCoIIYTzCCGEsCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUR//XL7QfGhU7o/UZ0+5JM3fZ
# 69ygghNxMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggVWMIIEPqADAgECAhAZGjLLdZyXuM+sEY3VEn9JMA0GCSqGSIb3DQEBCwUAMIHK
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsT
# FlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOjA4BgNVBAsTMShjKSAyMDA2IFZlcmlT
# aWduLCBJbmMuIC0gRm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxRTBDBgNVBAMTPFZl
# cmlTaWduIENsYXNzIDMgUHVibGljIFByaW1hcnkgQ2VydGlmaWNhdGlvbiBBdXRo
# b3JpdHkgLSBHNTAeFw0xNDAzMDQwMDAwMDBaFw0yNDAzMDMyMzU5NTlaMIGRMQsw
# CQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xHzAdBgNV
# BAsTFlN5bWFudGVjIFRydXN0IE5ldHdvcmsxQjBABgNVBAMTOVN5bWFudGVjIENs
# YXNzIDMgRXh0ZW5kZWQgVmFsaWRhdGlvbiBDb2RlIFNpZ25pbmcgQ0EgLSBHMjCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANAYAu7too0IWGMPJtfdInuI
# 9uTH7DsmGHjTx6QgU42DfKU/fqXIK0ffDfWm2cMdJZNgz3zc6gMsvnh/XEhtpwLZ
# Sfih6+uaYXyfwCbW3BXYuBB8ILpe9Cj2qOqnXHzGnJCQNDy2Iqz+ugw6HtZehLZb
# 8KOBcHiKjUZSe/zbSfMpExF0T40Ws8LjoC3HAwSdzMNy4Q4M+wKO8SYXe26u+Lcz
# i6ZhS0Xf8iVEx/ewmCM23Ch5Cuibcoio2Oiue38KZEWl8FeSmncGRR7rn+hm83p9
# koFfAC0euPZWE1piDbdHoY9y74NeguCUmOGspa2GN+Cn07qxPnrrRajxwUR94gMC
# AwEAAaOCAW0wggFpMBIGA1UdEwEB/wQIMAYBAf8CAQAwLwYDVR0fBCgwJjAkoCKg
# IIYeaHR0cDovL3Muc3ltY2IuY29tL3BjYTMtZzUuY3JsMBYGA1UdJQEB/wQMMAoG
# CCsGAQUFBwMDMA4GA1UdDwEB/wQEAwIBBjAuBggrBgEFBQcBAQQiMCAwHgYIKwYB
# BQUHMAGGEmh0dHA6Ly9zLnN5bWNkLmNvbTBfBgNVHSAEWDBWMFQGBFUdIAAwTDAj
# BggrBgEFBQcCARYXaHR0cHM6Ly9kLnN5bWNiLmNvbS9jcHMwJQYIKwYBBQUHAgIw
# GRoXaHR0cHM6Ly9kLnN5bWNiLmNvbS9ycGEwKQYDVR0RBCIwIKQeMBwxGjAYBgNV
# BAMTEVN5bWFudGVjUEtJLTEtNjI5MB0GA1UdDgQWBBQWZt5KNONQpxGGA7Fsqcas
# zVlumzAfBgNVHSMEGDAWgBR/02Wnwt3su/AwCfNDOfoCrzMxMzANBgkqhkiG9w0B
# AQsFAAOCAQEAP1sZ8/oT1XU4Klrun1qgTKkdxcyU7t4V/vUQbqQbpWSDVBhYxAso
# oYXDTnTl/4l8/tXtPLpxn1YCJo8WKoj+sKMnIs5L4jiOAKY6hl+d5T6o3mRJQXRB
# If0HyIQX2h1lMILLJk851gQnpIGxS0nDI4t+AjIYJ7erC/MYcrak7mcGbzimWI3g
# 8X5dpGDGqOVQX+DouuKPmVi2taCodvGi8RyIQXJ+UpebCjaZjVD3Aes85/AiauU1
# jGM2ihqx2WdmX5ca76ggnfAvumzO2ZSFAPFY8X3JfCK1B10CxuYLv6uTk/8nGI4z
# Nn5XNPHDrwTBhPFWs+iHgzb40wox3G4sbTCCBXowggRioAMCAQICEDydyVOnyOZj
# TqD1ObLWXxwwDQYJKoZIhvcNAQELBQAwgZExCzAJBgNVBAYTAlVTMR0wGwYDVQQK
# ExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1c3Qg
# TmV0d29yazFCMEAGA1UEAxM5U3ltYW50ZWMgQ2xhc3MgMyBFeHRlbmRlZCBWYWxp
# ZGF0aW9uIENvZGUgU2lnbmluZyBDQSAtIEcyMB4XDTE3MDMyOTAwMDAwMFoXDTIw
# MDUxNjIzNTk1OVowgfsxEzARBgsrBgEEAYI3PAIBAxMCTloxGTAXBgsrBgEEAYI3
# PAIBAgwIQXVja2xhbmQxGTAXBgsrBgEEAYI3PAIBAQwIQXVja2xhbmQxHTAbBgNV
# BA8TFFByaXZhdGUgT3JnYW5pemF0aW9uMRAwDgYDVQQFEwcxMjM4MDUwMQswCQYD
# VQQGEwJOWjERMA8GA1UECAwIQXVja2xhbmQxETAPBgNVBAcMCEF1Y2tsYW5kMSQw
# IgYDVQQKDBtXaGVyZVNjYXBlIFNvZnR3YXJlIExpbWl0ZWQxJDAiBgNVBAMMG1do
# ZXJlU2NhcGUgU29mdHdhcmUgTGltaXRlZDCCASIwDQYJKoZIhvcNAQEBBQADggEP
# ADCCAQoCggEBALSy8dZRg1AvmUDuRL1ytrXm0kRMlJ0jI00zm0v41j0Xu2+aCsjh
# XWUiTjxGkMOajDa2YLODn+CqJnte3FAIqe+ODx617ft1eBW5bk/OL5ihSg0vq33P
# KA8MiBy1/Pn6FTgyk9Fv3RjxsKkDWfPuhD8AmmVvYGC7OGI0kfUo/g2Z+7tbppmE
# N7GpkZZvZISeD6OxgR1hplwfkoDvcYWLrClGstSThcXBtt8z52FcWwCspcsKlyO1
# jXtVGV6ZbB+INgtQSxladTqEOHs/Tp56zSYzS9QGF1j+mSHvgs95zBtWZNFcwNsO
# vG+9FZw5CBGN95CP7wU0Mkfl5lCVTAViPk0CAwEAAaOCAWAwggFcMAkGA1UdEwQC
# MAAwDgYDVR0PAQH/BAQDAgeAMCsGA1UdHwQkMCIwIKAeoByGGmh0dHA6Ly9zdy5z
# eW1jYi5jb20vc3cuY3JsMGAGA1UdIARZMFcwVQYFZ4EMAQMwTDAjBggrBgEFBQcC
# ARYXaHR0cHM6Ly9kLnN5bWNiLmNvbS9jcHMwJQYIKwYBBQUHAgIwGQwXaHR0cHM6
# Ly9kLnN5bWNiLmNvbS9ycGEwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwMwHwYDVR0j
# BBgwFoAUFmbeSjTjUKcRhgOxbKnGrM1ZbpswHQYDVR0OBBYEFA+ADtouni0+SnxY
# groTYcLKkpAzMFgGCCsGAQUFBwEBBEwwSjAfBggrBgEFBQcwAYYTaHR0cDovL3N3
# LnN5bWNkLmNvbTAnBggrBgEFBQcwAoYbaHR0cDovL3N3MS5zeW1jYi5jb20vc3cu
# Y3J0MA0GCSqGSIb3DQEBCwUAA4IBAQBaDA1ysLvhgM1kbikULiTPUMOY3rhIN8Nr
# d+j0vOnnHNQDel4K5tAC/lwIqp5aapiXn5D8CWpEKmIo9zhxZJ6gW7H3Ow+eJo2R
# l4m38dgCVvizLS3anqMG1iRtDpUaBbZYCcOwruGGMQTZZ9SDTzLOXnnOhljyDA55
# 3ke/nRknXkya73td/y9X5KoUfQZs3YJ44/0UGLxy93ugy80B51YynTDyPC5XlwDM
# HLnCZvr6ofNU5LfOtwWPStPMQA5wKJnJ96Lc5OYoFly1VF1dYQLSdzTGqnBqIUTa
# avSWlXi8+jWu4eP3q8w9vEJ0G5NZ+MmD0Q7+C2sASUbwU5dMkAoWMYIEVzCCBFMC
# AQEwgaYwgZExCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29yazFCMEAGA1UEAxM5
# U3ltYW50ZWMgQ2xhc3MgMyBFeHRlbmRlZCBWYWxpZGF0aW9uIENvZGUgU2lnbmlu
# ZyBDQSAtIEcyAhA8nclTp8jmY06g9Tmy1l8cMAkGBSsOAwIaBQCgeDAYBgorBgEE
# AYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwG
# CisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBTjJGTE
# syAB3d6XCoA8pmZTf2siWzANBgkqhkiG9w0BAQEFAASCAQBEM+5JonfuUxhjnzsf
# PiSuwYHhmP8SzZflkUdviLqr1201JMf4DEBl2NqSTTIg6dhcviIsv6gReDyaLvs6
# tdF7BVwf0uKA1r7ytYOXXfl0Qf5hoyMFHji450Qb4/lB+rERy5Wc1g1CcThOjTHd
# PUia6CmQ+3lefdL2S7R9mnl2oQkffSKH2f6UT+zDdjTY2XxJYA9TKVF81MmeftA5
# BGc63CUgcC7KogIPeswN/DyukJWKa1HPmgrync3tN5LIyIHfGbnhMB+8W2t4gUsS
# SfE/oMnuzEntmCTIr7R7Eion3hHKUl5CQDJnemXBBrz3G1Gu5Hy0AI0waSC4mTHS
# 0YaDoYICCzCCAgcGCSqGSIb3DQEJBjGCAfgwggH0AgEBMHIwXjELMAkGA1UEBhMC
# VVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYDVQQDEydTeW1h
# bnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzICEA7P9DjI/r81bgTY
# apgbGlAwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJ
# KoZIhvcNAQkFMQ8XDTE5MDUxOTIyNDIwNVowIwYJKoZIhvcNAQkEMRYEFNuCWyNo
# kUfULNh808oNb9XRNQImMA0GCSqGSIb3DQEBAQUABIIBAAT9zRhDHyYSEptbZYhj
# w9V7ajF0E01udSZ8Uv1kAv7PFdIPDYBK75fqvaCCkXrW0skSB8ARBfeS1+kc0qmf
# TE62ei3ga8Ap+49ieuLcjNBrmpa2XcCXEGBAt77KKsdBgOSyLWGN9wdIZSu6XVax
# bT8iLChzU96nD9mBnndYGibl/5ezxqu7UCRrXNi5M62nAVZkmRyZyegSY9h7aHb0
# gO5sxSywlhN1QsgXxA3V5D4HYTeVLUdj6t4INQb6uLqj/j+o8Pq/TyftcMbvYJ0Z
# fyyUB02Gw5W1UAXmHEC9nYQYp7rs9kPholzsPPDk37PccT36Vhvr8HNizGfeAAi4
# Zfc=
# SIG # End signature block
