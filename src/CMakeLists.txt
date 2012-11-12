set(cpufreq_pxd
  cpufreq/_cpufreq.pxd
  cpufreq/cpufreq.pxd
  )
set(cpufreq_py
  cpufreq/__init__.py
  )
set(cpufreq_pyx
  cpufreq/cpufreq.pyx
  )
foreach(pyx ${cpufreq_pyx})
  cython_set_link_libraries("${pyx}" cpupower)
endforeach()

cython_module(SOURCES ${cpufreq_py} ${cpufreq_pyx}
  PXD_FILES ${cpufreq_pxd})
