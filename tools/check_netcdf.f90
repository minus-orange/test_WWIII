program check_netcdf
  use netcdf, only : nf90_inq_libvers
  implicit none

  print '(a)', 'NetCDF-Fortran link check: '//trim(nf90_inq_libvers())
end program check_netcdf
