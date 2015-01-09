!***************************************************************************************************
!
!  File Name: apexsh.f90
!  Authors: John Emmert, Art Richmond
!  Date: 11/13/2009
!  Version: 1.0
!  Description: Converts geodetic coordinates to and from Quasi-Dipole and Modified
!               Apex Coordinates.
!  References: Richmond, A. D., Ionospheric Electrodynamics Using Magnetic Apex Coordinates,
!                J. Geomag. Geoelectr., 47, 191-212, 1995.
!              Emmert, J. T., A. D. Richmond, and D. P. Drob, A computationally compact
!                representation of Magnetic-Apex and Quasi-Dipole coordinates with smooth base
!                vectors, J. Geophys. Res., 115, doi:10.1029/2010JA015326, 2010.
!
!***************************************************************************************************
!
!  LOADAPXSH
!  Loads spherical harmonic coefficients (created by MAKEAPXSH) for coordinate conversions. Must be
!  run before calling the conversion routines.
!
!  CALL LOADAPXSH (DATAFILE, EPOCH)
!
!  INPUT ARGUMENTS
!    DATAFILE  Name of data file, generated by MAKEAPXSH, containing the conversion coefficients
!    EPOCH     Date for which coordinates are desired (decimal years, yyyy.y, single precision)
!
!***************************************************************************************************
!
!  APXG2Q
!  Converts geodetic to Quasi-Dipole coordinates
!  Must call LOADAPXSH first. All arguments are single precision, except for VECFLAG, which is a
!  4-byte integers.
!
!  CALL APXG2Q (GLAT, GLON, ALT, VECFLAG, QLAT, QLON, F1, F2, F)
!
!  INPUT ARGUMENTS
!    GLAT     Geodetic latitude (degrees)
!    GLON     Geodetic longitude (degrees)
!    ALT      Altitude (km)
!    VECFLAG  Set this flag to zero to calculate coordinates only, without base vectors. The base
!             vector output arguments will be filled with -9999.
!
!  OUTPUT ARGUMENTS
!    QLAT      Quasi-Dipole latitude (degrees)
!    QLON      Quasi-Dipole longitude (degrees)
!    F1,F2     Quasi-Dipole coordinates base vectors described in Richmond (1995). The two elements
!              of each vector contain the geodetic east and north components. F1 points in the QD
!              east direction, and F2 points in the QD north direction.
!    F         F = |F1 x F2|, as described in Richmond (1995)
!
!***************************************************************************************************
!
!  APXG2ALL
!  Converts geodetic to Quasi-Dipole and Modified Apex coordinates
!  Must call LOADAPXSH first. All arguments are single precision, except for MAFLAG and VECFLAG,
!  which are 4-byte integers.
!
!  CALL APXG2ALL (GLAT, GLON, ALT, HR, VECFLAG, &
!                 QLAT, QLON, MLAT, MLON, &
!                 F1,F2,F, D1,D2,D3,D, E1,E2,E3)
!
!  INPUT ARGUMENTS
!    GLAT     Geodetic latitude (degrees)
!    GLON     Geodetic longitude (degrees)
!    ALT      Altitude (km)
!    HR       Modified Apex coordinates reference altitude (km)
!    VECFLAG  Set this flag to zero to calculate coordinates only, without base vectors. The base
!             vector output arguments will be filled with -9999.
!
!  OUTPUT ARGUMENTS
!    QLAT      Quasi-Dipole latitude (degrees)
!    QLON      Quasi-Dipole longitude (degrees)
!    MLAT      Modified Apex latitude (degrees)
!    MLON      Modified Apex longitude (degrees)
!    F1,F2     Quasi-Dipole coordinates base vectors described in Richmond (1995). The two elements
!              of each vector contain the geodetic east and north components. F1 points in the QD
!              east direction, and F2 points in the QD north direction.
!    F         F = |F1 x F2|, as described in Richmond (1995)
!    D1,D2,D3  Modified Apex coordinates base vectors described in Richmond (1995). The three
!              elements of each vector contain the geodetic east, north, and up components.
!              D1 and D2 are generally perpendicular to the magnetic field and point in the
!              magnetic east and downward/equatorward directions. D3 points along the magnetic
!              field.
!    D         D = |D1 x D2|, as described in Richmond (1995)
!    E1,E2,E3  Modified Apex coordinates base vectors described in Richmond (1995). The three
!              elements of each vector contain the geodetic east, north, and up components.
!              E1 and E2 are generally perpendicular to the magnetic field and point in the
!              magnetic east and downward/equatorward directions. E3 points along the magnetic
!              field.
!
!***************************************************************************************************
!
!  APXQ2G
!  Converts Quasi-Dipole to geodetic coordinates
!  All arguments are single precision.
!
!  CALL APXQ2G (QLAT, QLON, ALT, PREC, GLAT, GLON, ERROR)
!
!  INPUT ARGUMENTS
!    QLAT   Quasi-Dipole latitude (degrees)
!    QLON   Quasi-Dipole longitude (degrees)
!    ALT    Altitude (km)
!    PREC   Precision of output (degrees). A negative value of this argument produces a low-
!           precision calculation of geodetic lat and lon based only on their spherical harmonic
!           representation. A positive value causes the routine to iterate until feeding the output
!           glat and glon coordinates into APXG2Q reproduces the input qlat and qlon to within
!           the specified precision.
!
!  OUTPUT ARGUMENTS
!    GLAT   Geodetic latitude (degrees)
!    GLON   Geodetic longitude (degrees)
!    ERROR  The angular difference (degrees) between the input qlat and qlon coordinates and the
!           qlat and qlon produced by feeding the output glat and glon into APG2ALL.
!
!***************************************************************************************************

       module apxshmodule

       implicit none

       integer(4)               :: nterm, nmax, mmax, lmax, nepoch, ntermsh
       integer(4)               :: vecflag
      
       real(8), allocatable     :: coeff0(:,:,:)
       real(8), allocatable     :: qcoeff0(:,:), gcoeff0(:,:)
       real(8), allocatable     :: xqcoeff(:), yqcoeff(:), zqcoeff(:)
       real(8), allocatable     :: dxqdrhocoeff(:), dyqdrhocoeff(:), dzqdrhocoeff(:)
       real(8), allocatable     :: xgcoeff(:), ygcoeff(:), zgcoeff(:)
       real(8), allocatable     :: sh(:), shgradtheta(:), shgradphi(:)
       real(8), allocatable     :: polynomq(:), dpolynomq(:), polynomg(:)
       real(8), allocatable     :: pbar(:,:), vbar(:,:), wbar(:,:)
       real(4), allocatable     :: epochgrid(:)
      
       real(8)                  :: h, Reph, rho
       real(8)                  :: xq, yq, zq
       real(8)                  :: qlat, qlon
       real(8)                  :: sinqlat, cosqlat, cosqlon, sinqlon
       real(8)                  :: xqgrad(1:3), yqgrad(1:3), zqgrad(1:3)
       real(8)                  :: qlatgrad(1:3), qlongrad(1:3)
      
       real(8), parameter       :: pi=3.14159265358979323846D0
       real(8), parameter       :: dtor=pi/180D0, pid2=pi/2D0, twopi=2D0*pi
       real(8), parameter       :: Req=6378.1370D0, eps=1.D0/298.257223563D0
       real(8), parameter       :: Re=Req*(1-eps/3D0), ecc2=eps*(2-eps)
       real(4), parameter       :: missing=-9999E0

!   Req = Equatorial radius of Earth in km (WGS84 value)
!   eps = flatness of ellipsoidal Earth (WGS84 value)
!   Re = Mean radius of Earth in km
!   ecc2 = squared eccentricity of ellipsoidal Earth

       character(128)           :: datafile
       real(4)                  :: epoch
       real(4)                  :: altlastq, altlastg
       logical                  :: loadflag = .true.

     end module apxshmodule

!***************************************************************************************************

     subroutine loadapxsh(datafilenew,epochnew)

    use apxshmodule

    implicit none

    character(128)              :: datafilenew, datafilelast=''
    real(4)                     :: epochnew, epochlast=-999.0
    real(8)                     :: we0, we1
    integer(4)                  :: iepoch0, iepoch1, iterm, icoord

    !CHECK FILE, GET DIMENSIONS, AND ALLOCATE ARRAYS
    if ((datafilenew .ne. datafilelast) .or. (loadflag)) then
      datafile = datafilenew
      open(unit=23,file=trim(datafile),status='old',form='formatted')
      read(23,*) nepoch, nmax, mmax, lmax, nterm
      call allocatearrays
      read(23,*) epochgrid, coeff0
      close(23)
    endif
    
    !LOAD COEFFICIENTS AND INTEPOLATE TO SELECTED EPOCH
    if ((epochnew .ne. epochlast) .or. (datafilenew .ne. datafilelast) .or.(loadflag)) then
      epoch = epochnew
      if (epoch .lt. epochgrid(0)) epoch=epochgrid(0)
      if (epoch .gt. epochgrid(nepoch-1)) epoch=epochgrid(nepoch-1)
      if (nepoch .eq. 1) then
        iepoch0 = 0
        iepoch1 = 0
        we0 = 1D0
        we1 = 0D0
      else
        iepoch0 = nepoch - 1
        do while ((epochgrid(iepoch0) .ge. epoch) .and. (iepoch0 .gt. 0))
          iepoch0 = iepoch0 - 1
        enddo
        iepoch1 = iepoch0 + 1
        we0 = dble( (epochgrid(iepoch1) - epoch) / (epochgrid(iepoch1)-epochgrid(iepoch0)) )
        we1 = 1D0 - we0
      endif
      do icoord = 0, 2
      do iterm = 0, nterm-1
        qcoeff0(iterm,icoord)= we0*coeff0(iterm,iepoch0,icoord)  +we1*coeff0(iterm,iepoch1,icoord)
        gcoeff0(iterm,icoord)= we0*coeff0(iterm,iepoch0,icoord+3)+we1*coeff0(iterm,iepoch1,icoord+3)
      enddo
      enddo
      altlastq = -999.0
      altlastg = -999.0
    endif

    !UPDATE LOAD VARIABLES
    loadflag = .false.
    datafilelast = datafilenew
    epochlast = epochnew

    return

end subroutine loadapxsh

!***************************************************************************************************

subroutine allocatearrays

    use apxshmodule

    implicit none

    external alfbasisinit

    !RESET ARRAYS
    if (allocated(epochgrid)) deallocate(epochgrid)
    if (allocated(coeff0)) deallocate(coeff0)
    if (allocated(gcoeff0)) deallocate(gcoeff0)
    if (allocated(qcoeff0)) deallocate(qcoeff0)
    if (allocated(xqcoeff)) deallocate(xqcoeff)
    if (allocated(yqcoeff)) deallocate(yqcoeff)
    if (allocated(zqcoeff)) deallocate(zqcoeff)
    if (allocated(dxqdrhocoeff)) deallocate(dxqdrhocoeff)
    if (allocated(dyqdrhocoeff)) deallocate(dyqdrhocoeff)
    if (allocated(dzqdrhocoeff)) deallocate(dzqdrhocoeff)
    if (allocated(xgcoeff)) deallocate(xgcoeff)
    if (allocated(ygcoeff)) deallocate(ygcoeff)
    if (allocated(zgcoeff)) deallocate(zgcoeff)
    if (allocated(sh)) deallocate(sh)
    if (allocated(shgradphi)) deallocate(shgradphi)
    if (allocated(shgradtheta)) deallocate(shgradtheta)
    if (allocated(polynomq)) deallocate(polynomq)
    if (allocated(dpolynomq)) deallocate(dpolynomq)
    if (allocated(polynomg)) deallocate(polynomg)
    if (allocated(pbar)) deallocate(pbar)
    if (allocated(vbar)) deallocate(vbar)
    if (allocated(wbar)) deallocate(wbar)

    !ALLOCATE ARRAYS
    ntermsh = mmax*(2*nmax - mmax + 1) + nmax + 1
    allocate(    epochgrid(0:nepoch-1) )
    allocate(       coeff0(0:nterm-1, 0:nepoch-1, 0:5) )
    allocate(      qcoeff0(0:nterm-1, 0:2) )
    allocate(      gcoeff0(0:nterm-1, 0:2) )
    allocate(      xqcoeff(0:ntermsh-1) )
    allocate(      yqcoeff(0:ntermsh-1) )
    allocate(      zqcoeff(0:ntermsh-1) )
    allocate( dxqdrhocoeff(0:ntermsh-1) )
    allocate( dyqdrhocoeff(0:ntermsh-1) )
    allocate( dzqdrhocoeff(0:ntermsh-1) )
    allocate(      xgcoeff(0:ntermsh-1) )
    allocate(      ygcoeff(0:ntermsh-1) )
    allocate(      zgcoeff(0:ntermsh-1) )
    allocate(           sh(0:ntermsh-1) )
    allocate(  shgradtheta(0:ntermsh-1) )
    allocate(    shgradphi(0:ntermsh-1) )
    allocate(     polynomq(0:lmax) )
    allocate(    dpolynomq(0:lmax) )
    allocate(     polynomg(0:lmax) )
    allocate(         pbar(0:nmax, 0:mmax) )
    allocate(         vbar(0:nmax, 0:mmax) )
    allocate(         wbar(0:nmax, 0:mmax) )
    polynomq(0) = 1D0
    dpolynomq(0) = 0D0
    polynomg(0) = 1D0
    pbar = 0
    vbar = 0
    wbar = 0
    call alfbasisinit(nmax,mmax)

    return

end subroutine allocatearrays

!***************************************************************************************************

subroutine apxg2q(glat,glon,alt,vecflagin,qlatout,qlonout,f1,f2,f)

    use apxshmodule

    implicit none

    real(4), intent(in)         :: glat, glon, alt
    integer(4), intent(in)      :: vecflagin
    real(4), intent(out)        :: qlatout, qlonout
    real(4), intent(out)        :: f1(1:2), f2(1:2), f

    integer(4)               :: i, l, iterm, itermsh
    real(8)                  :: theta, phi
    real(8)                  :: costheta, Jtemp, J, r

    !INITIALIZE OUTPUT ARGUMENTS    
    qlat = missing
    qlon = missing
    f1 = missing
    f2 = missing
    f = missing

    !CHECK THAT COEFFICIENTS ARE LOADED
    if (loadflag) then
      print *, 'No coefficients loaded. Call LOADAPXSH first.'
      return
    endif

    !COPY INPUT FLAG
    vecflag = vecflagin     
    
    !COMPUTE SPATIAL COEFFICIENTS AND THEIR VERTICAL GRADIENTS FOR THE SPECIFIED HEIGHT
    if (alt .ne. altlastq) then
      h = dble(alt)
      Reph = Re + h
      rho = Re / Reph
      do l = 1, lmax
        polynomq(l) = polynomq(l-1)*rho
        dpolynomq(l) = dble(l)*polynomq(l-1)
      enddo
      xqcoeff = 0
      yqcoeff = 0
      zqcoeff = 0
      dxqdrhocoeff = 0
      dyqdrhocoeff = 0
      dzqdrhocoeff = 0
      do itermsh = 0, ntermsh-1
        do l = 0, lmax
          iterm = l*ntermsh + itermsh
          xqcoeff(itermsh) = xqcoeff(itermsh) + qcoeff0(iterm,0)*polynomq(l)
          yqcoeff(itermsh) = yqcoeff(itermsh) + qcoeff0(iterm,1)*polynomq(l)
          zqcoeff(itermsh) = zqcoeff(itermsh) + qcoeff0(iterm,2)*polynomq(l)
          dxqdrhocoeff(itermsh) = dxqdrhocoeff(itermsh) + qcoeff0(iterm,0)*dpolynomq(l)
          dyqdrhocoeff(itermsh) = dyqdrhocoeff(itermsh) + qcoeff0(iterm,1)*dpolynomq(l)
          dzqdrhocoeff(itermsh) = dzqdrhocoeff(itermsh) + qcoeff0(iterm,2)*dpolynomq(l)
        enddo
      enddo
      altlastq = alt
    endif

    !COMPUTE SPHERICAL HARMONICS
    theta = (90D0 - dble(glat)) * dtor
    phi = glon * dtor
    call shcalc(theta,phi)

    !COMPUTE AND RETURN QUASI-DIPOLE COORDINATES
    xq = dot_product(sh, xqcoeff)
    yq = dot_product(sh, yqcoeff)
    zq = dot_product(sh, zqcoeff)
    qlon = datan2(yq,xq)
    cosqlon = dcos(qlon)
    sinqlon = dsin(qlon)
    qlat = datan2(zq,dsqrt(xq*xq + yq*yq))
    cosqlat = dcos(qlat)
    sinqlat = dsin(qlat)
    qlonout = sngl(qlon / dtor)
    qlatout = sngl(qlat / dtor)

    !BASE VECTOR CALCULATIONS
    if (vecflag .ne. 0) then    

      !COMPUTE HORIZONTAL GRADIENT KERNELS OF QUASI-DIPOLE CARTESIAN COORDINATES
      xqgrad(1) = dot_product(shgradphi, xqcoeff)
      yqgrad(1) = dot_product(shgradphi, yqcoeff)
      zqgrad(1) = dot_product(shgradphi, zqcoeff)
      xqgrad(2) = -dot_product(shgradtheta, xqcoeff)
      yqgrad(2) = -dot_product(shgradtheta, yqcoeff)
      zqgrad(2) = -dot_product(shgradtheta, zqcoeff)

      !COMPUTE ADJUSTMENTS TO GRADIENTS FOR ELLIPSOIDAL EARTH
      costheta = dcos(theta)
      Jtemp = 1D0 - ecc2*costheta*costheta
      r = Req / dsqrt(Jtemp)
      J = (h + (1 - ecc2) * r / Jtemp) / Reph
      r = (h + r) / Reph

      !COMPUTE HORIZONTAL GEODETIC GRADIENTS OF QD LATITUDE AND LONGITUDE
      qlatgrad(1) = (-( cosqlon*xqgrad(1) + sinqlon*yqgrad(1))*sinqlat + cosqlat*zqgrad(1)) / r
      qlatgrad(2) = (-( cosqlon*xqgrad(2) + sinqlon*yqgrad(2))*sinqlat + cosqlat*zqgrad(2)) / J
      qlongrad(1) =   (-sinqlon*xqgrad(1) + cosqlon*yqgrad(1)) / r
      qlongrad(2) =   (-sinqlon*xqgrad(2) + cosqlon*yqgrad(2)) / J

      !RETURN QUASI-DIPOLE BASE VECTORS
      f1(1) = sngl( qlatgrad(2))
      f1(2) = sngl(-qlatgrad(1))
      f2(1) = sngl(-qlongrad(2))
      f2(2) = sngl(qlongrad(1))
      f = f1(1)*f2(2) - f1(2)*f2(1)

    endif

    return

end subroutine apxg2q

!***************************************************************************************************

subroutine apxg2all(glat,glon,alt,hr,vecflagin, &
                    qlatout,qlonout, mlat,mlon, f1,f2,f, d1,d2,d3,d, e1,e2,e3)

    use apxshmodule

    implicit none

    real(4), intent(in)         :: glat, glon, alt, hr
    integer(4), intent(in)      :: vecflagin
    real(4), intent(out)        :: qlatout, qlonout, mlat, mlon
    real(4), intent(out)        :: f1(1:2), f2(1:2), f
    real(4), intent(out)        :: d1(1:3), d2(1:3), d3(1:3), d
    real(4), intent(out)        :: e1(1:3), e2(1:3), e3(1:3)

    integer(4)               :: i
    real(8)                  :: cosmlat, Rrat, denom

    if (loadflag) then
      print *, 'No coordinates loaded. Call LOADAPXSH first.'
      stop
    endif

    !INITIALIZE OUTPUT ARGUMENTS    
    mlat = missing
    mlon = missing
    d1 = missing
    d2 = missing
    d3 = missing
    d = missing
    e1 = missing
    e2 = missing
    e3 = missing

    !COMPUTE QUASI-DIPOLE COORDINATES
    call apxg2q(glat,glon,alt,vecflagin,qlatout,qlonout,f1,f2,f)
    if (qlatout .eq. missing) return

    !COMPUTE AND RETURN MODIFIED APEX COORDINATES
    mlon = qlonout
    Rrat = (Re + dble(hr)) / Reph
    cosmlat = cosqlat * dsqrt(Rrat)
    if (cosmlat .le. 1D0) then
      mlat = sngl(dacos(cosmlat) / dtor)
      if (qlat .lt. 0D0) mlat = -mlat
    endif

    !MODIFIED APEX BASE VECTOR CALCULATIONS
    if (vecflag .ne. 0) then    

      !COMPUTE VERTICAL GRADIENTS OF QUASI-DIPOLE COORDINATES
      xqgrad(3) = dot_product(sh, dxqdrhocoeff)
      yqgrad(3) = dot_product(sh, dyqdrhocoeff)
      zqgrad(3) = dot_product(sh, dzqdrhocoeff)
      qlatgrad(3) = rho*((cosqlon*xqgrad(3) + sinqlon*yqgrad(3))*sinqlat - cosqlat*zqgrad(3))
      qlongrad(3) = rho* (sinqlon*xqgrad(3) - cosqlon*yqgrad(3))

      !COMPUTE MA BASE VECTORS
      denom = 4D0/Rrat - 3D0*cosqlat*cosqlat
      if (denom .le. 0) return
      denom = dsqrt(denom)
      do i = 1, 3
        d1(i) = sngl(Rrat*dsqrt(Rrat)*qlongrad(i))
        d2(i) = sngl(-2D0*Rrat*sinqlat*qlatgrad(i)/denom)
      enddo
      d2(3) = d2(3) - sngl(Rrat*cosqlat/denom)
      e3(1) = d1(2)*d2(3) - d1(3)*d2(2)
      e3(2) = d1(3)*d2(1) - d1(1)*d2(3)
      e3(3) = d1(1)*d2(2) - d1(2)*d2(1)
      d = e3(1)**2 + e3(2)**2 + e3(3)**2
      do i=1,3
        d3(i) = e3(i)/d
      enddo
      d = sqrt(d)
      e1(1) = d2(2)*d3(3) - d2(3)*d3(2)
      e1(2) = d2(3)*d3(1) - d2(1)*d3(3)
      e1(3) = d2(1)*d3(2) - d2(2)*d3(1)
      e2(1) = d3(2)*d1(3) - d3(3)*d1(2)
      e2(2) = d3(3)*d1(1) - d3(1)*d1(3)
      e2(3) = d3(1)*d1(2) - d3(2)*d1(1)

    endif

    return

end subroutine apxg2all

!***************************************************************************************************

subroutine apxq2g(qlat0,qlon0,alt,prec,glatout,glonout,error)

    use apxshmodule

    implicit none

    real(4), intent(in)         :: qlat0, qlon0, alt, prec
    real(4), intent(out)        :: glatout, glonout, error

    integer(4)               :: l, iterm, itermsh, vecflagin, niter
    real(4)                  :: qlatout, qlonout, errorlast
    real(4)                  :: mlon, f1(1:2), f2(1:2), f
    real(8)                  :: theta, phi
    real(8)                  :: sinqlon0, cosqlon0, sinqlat0, cosqlat0, cotqlat0, zfact
    real(8)                  :: glat, glon
    real(8)                  :: xg, yg, zg, cosglat
    real(8)                  :: xggrad(1:2), yggrad(1:2), zggrad(1:2)
    real(8)                  :: delqlon, delqlat, delxq, delyq, denom
    real(8)                  :: coserror

    if (loadflag) then
      print *, 'No coordinates loaded. Call LOADAPXSH first.'
      stop
    endif

    !COMPUTE SPATIAL COEFFICIENTS FOR THE SPECIFIED HEIGHT
    if (alt .ne. altlastg) then
      rho = Re / (Re + dble(alt))
      do l = 1, lmax
        polynomg(l) = polynomg(l-1)*rho
      enddo
      xgcoeff = 0
      ygcoeff = 0
      zgcoeff = 0
      do itermsh = 0, ntermsh-1
        do l = 0, lmax
          iterm = l*ntermsh + itermsh
          xgcoeff(itermsh) = xgcoeff(itermsh) + gcoeff0(iterm,0)*polynomg(l)
          ygcoeff(itermsh) = ygcoeff(itermsh) + gcoeff0(iterm,1)*polynomg(l)
          zgcoeff(itermsh) = zgcoeff(itermsh) + gcoeff0(iterm,2)*polynomg(l)
        enddo
      enddo
      altlastg = alt
    endif

    !COMPUTE SPHERICAL HARMONICS
    phi = dble(qlon0) * dtor
    theta = (90D0 - dble(qlat0)) * dtor
    vecflag = 1
    call shcalc(theta,phi)

    !COMPUTE INITIAL GEODETIC COORDINATES
    xg = dot_product(sh, xgcoeff)
    yg = dot_product(sh, ygcoeff)
    zg = dot_product(sh, zgcoeff)
    glon = datan2(yg,xg)
    glat = datan2(zg,dsqrt(xg*xg + yg*yg))
    glatout = sngl(glat / dtor)
    glonout = sngl(glon / dtor)
    error = missing

    !COMPUTE REFINED GEODETIC COORDINATES
    if (prec .ge. 0) then
      xggrad(1) = dot_product(shgradphi, xgcoeff)
      yggrad(1) = dot_product(shgradphi, ygcoeff)
      zggrad(1) = dot_product(shgradphi, zgcoeff)
      xggrad(2) = -dot_product(shgradtheta, xgcoeff)
      yggrad(2) = -dot_product(shgradtheta, ygcoeff)
      zggrad(2) = -dot_product(shgradtheta, zgcoeff)
      vecflagin = 1
      call apxg2q(glatout,glonout,alt,vecflagin,qlatout,qlonout,f1,f2,f)
      cosqlat0 = dsin(theta)
      sinqlat0 = dcos(theta)
      coserror = sinqlat0*sinqlat+cosqlat0*cosqlat*cos(phi-qlon)
      if (coserror .gt. 1) coserror = 1D0
      error = sngl(acos(coserror) / dtor)
      niter = 0
      errorlast = 9999.0
      !OUTSIDE OF QD POLES
      if ((abs(qlat0) .lt. 88.0) .and. (error .gt. prec)) then
        vecflagin = 0
        do while ((error .gt. prec) .and. (niter .lt. 10) .and. (error .lt. 1.3*errorlast))
          delqlon = phi - qlon
          if (abs(delqlon) .gt. pi) delqlon = -sign(twopi-abs(delqlon),delqlon)
          delqlon = cosqlat0 * delqlon
          delqlat = pid2 - theta - qlat
          xg = xg + xggrad(1)*delqlon + xggrad(2)*delqlat
          yg = yg + yggrad(1)*delqlon + yggrad(2)*delqlat
          zg = zg + zggrad(1)*delqlon + zggrad(2)*delqlat
          glonout = sngl(datan2(yg,xg) / dtor)
          glatout = sngl(datan2(zg,dsqrt(xg*xg + yg*yg)) / dtor)
          call apxg2q(glatout,glonout,alt,vecflagin,qlatout,qlonout,f1,f2,f)
          coserror = sinqlat0*sinqlat+cosqlat0*cosqlat*cos(phi-qlon)
          if (coserror .gt. 1) coserror = 1D0
          errorlast = error
          error = sngl(acos(coserror) / dtor)
          niter = niter + 1
        enddo
      !NEAR QD POLES
      else if (error .gt. prec) then
        cosqlon0 = dcos(phi)
        sinqlon0 = dsin(phi)
        cotqlat0 = cosqlat0 / sinqlat0
        cosglat = dcos(glat)
        vecflagin = 1
        do while ((error .gt. prec) .and. (niter .lt. 10) .and. (error .lt. 1.3*errorlast))
          zfact = zq * cotqlat0
          delxq = zfact * cosqlon0 - xq
          delyq = zfact * sinqlon0 - yq
          denom = xqgrad(1)*yqgrad(2) - xqgrad(2)*yqgrad(1)
          glon = glon + (delxq*yqgrad(2) - delyq*xqgrad(2)) / denom / cosglat
          glat = glat + (delyq*xqgrad(1) - delxq*yqgrad(1)) / denom
          glonout = sngl(glon / dtor)
          glatout = sngl(glat / dtor)
          call apxg2q(glatout,glonout,alt,vecflagin,qlatout,qlonout,f1,f2,f)
          coserror = sinqlat0*sinqlat+cosqlat0*cosqlat*cos(phi-qlon)
          if (coserror .gt. 1) coserror = 1D0
          errorlast = error
          error = sngl(acos(coserror) / dtor)
          niter = niter + 1
        enddo
      endif
    endif

    return

end subroutine apxq2g

!***************************************************************************************************

subroutine shcalc(theta,phi)

    use apxshmodule

    implicit none

    real(8), intent(in)      :: theta, phi

    integer(4)               :: n, m, i, i1
    real(8)                  :: mphi, cosmphi, sinmphi

    call alfbasis(nmax,mmax,theta,pbar,vbar,wbar)
    i = 0
    i1 = 0
    do n = 0, nmax
      sh(i) = pbar(n,0)
      shgradtheta(i1) =  vbar(n,0)
      shgradphi(i1) = 0
      i = i + 1
      i1 = i1 + 1
    enddo
    do m = 1, mmax
      mphi = dble(m) * phi
      cosmphi = dcos(mphi)
      sinmphi = dsin(mphi)
      do n = m, nmax
        sh(i)   = pbar(n,m) * cosmphi
        sh(i+1) = pbar(n,m) * sinmphi
        i = i + 2
      enddo
      if (vecflag .ne. 0) then
        do n = m, nmax
          shgradtheta(i1)   =  vbar(n,m) * cosmphi
          shgradtheta(i1+1) =  vbar(n,m) * sinmphi
          shgradphi(i1)     = -wbar(n,m) * sinmphi
          shgradphi(i1+1)   =  wbar(n,m) * cosmphi
          i1 = i1 + 2
        enddo
      endif
    enddo

end subroutine shcalc

!***************************************************************************************************

module alfbasismodule

    implicit none

    integer(4)           :: nmax0
    integer(4)           :: mmax0
    real(8), allocatable :: anm(:,:)
    real(8), allocatable :: cm(:)
    real(8), allocatable :: bnm(:,:)
    real(8), allocatable :: dnm(:,:)
    real(8), allocatable :: en(:)
    real(8), allocatable :: marr(:)
    real(8), allocatable :: narr(:)

end module alfbasismodule

!***************************************************************************************************

subroutine alfbasisinit(nmax0in,mmax0in)

    use alfbasismodule

    implicit none

    integer(4), intent(in) :: nmax0in, mmax0in
    integer(8)             :: n, m

    nmax0 = nmax0in
    mmax0 = mmax0in
    if (allocated(anm)) deallocate(anm, bnm, cm, dnm, en, marr, narr)
    allocate( anm(0:nmax0, 0:mmax0) )
    allocate( bnm(0:nmax0, 0:mmax0) )
    allocate( cm(0:mmax0) )
    allocate( dnm(0:nmax0, 0:mmax0) )
    allocate( en(0:nmax0) )
    allocate( marr(0:mmax0) )
    allocate( narr(0:nmax0) )

    do n = 1, nmax0
      narr(n) = dble(n)
      en(n)    = dsqrt(dble(n*(n+1)))
      anm(n,0) = dsqrt( dble((2*n-1)*(2*n+1)) ) / narr(n)
      bnm(n,0) = dsqrt( dble((2*n+1)*(n-1)*(n-1)) / dble(2*n-3) ) / narr(n)
    enddo
    do m = 1, mmax0
      marr(m) = dble(m)
      cm(m)    = dsqrt(dble(2*m+1)/dble(2*m))
      do n = m+1, nmax0
        anm(n,m) = dsqrt( dble((2*n-1)*(2*n+1)) / dble((n-m)*(n+m)) )
        bnm(n,m) = dsqrt( dble((2*n+1)*(n+m-1)*(n-m-1)) / dble((n-m)*(n+m)*(2*n-3)) )
        dnm(n,m) = dsqrt( dble((n-m)*(n+m)*(2*n+1)) / dble(2*n-1) )
      enddo
    enddo

    return

end subroutine alfbasisinit

!***************************************************************************************************

subroutine alfbasis(nmax,mmax,theta,P,V,W)

    use alfbasismodule

    implicit none

    integer(4), intent(in)  :: nmax, mmax
    real(8), intent(in)     :: theta
    real(8), intent(out)    :: P(0:nmax,0:mmax)
    real(8), intent(out)    :: V(0:nmax,0:mmax)
    real(8), intent(out)    :: W(0:nmax,0:mmax)

    integer(4)              :: n, m
    real(8)                 :: x, y
    real(8), parameter      :: p00=0.70710678118654746D0

    P(0,0) = p00
    x = dcos(theta)
    y = dsin(theta)
    do m = 1, mmax
      W(m,m) = cm(m) * P(m-1,m-1)
      P(m,m) = y * W(m,m)
      do n = m+1, nmax
        W(n,m) = anm(n,m) * x * W(n-1,m) - bnm(n,m) * W(n-2,m)
        P(n,m) = y * W(n,m)
        V(n,m) = narr(n) * x * W(n,m) - dnm(n,m) * W(n-1,m)
        W(n-2,m) = marr(m) * W(n-2,m)
      enddo
      W(nmax-1,m) = marr(m) * W(nmax-1,m)
      W(nmax,m) = marr(m) * W(nmax,m)
      V(m,m) = x * W(m,m)
    enddo
    P(1,0) = anm(1,0) * x * P(0,0)
    V(1,0) = -en(1) * P(1,1)
    do n = 2, nmax
      P(n,0) = anm(n,0) * x * P(n-1,0) - bnm(n,0) * P(n-2,0)
      V(n,0) = -en(n) * P(n,1)
    enddo

    return

end subroutine alfbasis

!***************************************************************************************************
