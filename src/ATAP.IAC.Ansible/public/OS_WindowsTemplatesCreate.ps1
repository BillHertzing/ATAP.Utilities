$sample_conf =  @'
# Sample configuration file for some OS_Windows program
# second line
'@
set-content -path './sample.conf.j2' -Value $sample_conf

